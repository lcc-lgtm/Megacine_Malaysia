import json
import os
import uuid
from typing import Any
import httpx
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import Movie, Order, Seat, ShowtimeSeat
from app.schemas.ai import AIResponseDTO
from app.services.bookmark_service import BookmarkService

SUPPORTED_MODELS = ("gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-4-hydrogen")


class AIService:
    def __init__(self, db: AsyncSession, google_oauth_token: str | None = None) -> None:
        self.db = db
        self.api_key = os.getenv("GEMINI_API_KEY", "").strip()
        self.google_oauth_token = (google_oauth_token or "").strip()
        self.default_model = os.getenv("GEMINI_MODEL", "gemini-3.8-flash").strip()
        self.custom_base_url = os.getenv("GEMINI_API_BASE_URL", "").strip().rstrip("/")

    def _resolve_endpoint(self, model_name: str) -> tuple[str, dict[str, str]]:
        headers = {"Content-Type": "application/json"}

        # 优先支持前端透传的 Google 账户 OAuth 凭证；否则使用服务器配置的 API Key
        if self.google_oauth_token:
            headers["Authorization"] = f"Bearer {self.google_oauth_token}"
            base = self.custom_base_url or "https://generativelanguage.googleapis.com/v1beta"
            return f"{base}/models/{model_name}:generateContent", headers

        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Neither GEMINI_API_KEY nor Google OAuth token is available.",
            )

        if self.custom_base_url:
            headers["x-goog-api-key"] = self.api_key
            return f"{self.custom_base_url}/models/{model_name}:generateContent", headers

        # 自动适配 AQ. 开头（Vertex AI Express / 新版 Key）与传统 AI Studio Key
        if self.api_key.startswith("AQ."):
            url = f"https://aiplatform.googleapis.com/v1/publishers/google/models/{model_name}:generateContent?key={self.api_key}"
            return url, headers

        headers["x-goog-api-key"] = self.api_key
        return f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent", headers

    async def _call_gemini_json(
        self, system_instruction: str, user_prompt: str, model: str | None = None
    ) -> tuple[dict[str, Any], str]:
        target_model = model if model in SUPPORTED_MODELS else self.default_model
        url, headers = self._resolve_endpoint(target_model)

        payload = {
            "system_instruction": {"parts": [{"text": system_instruction}]},
            "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
            "generationConfig": {
                "temperature": 0.4,
                "responseMimeType": "application/json",
            },
        }
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, headers=headers, json=payload)

        if resp.status_code >= 400:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Gemini API ({target_model}) error {resp.status_code}: {resp.text[:300]}",
            )
        data = resp.json()
        try:
            raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
            parsed = json.loads(raw_text)
            if not isinstance(parsed, dict):
                return {"reply": str(parsed), "config": {}}, target_model
            return parsed, target_model
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to parse Gemini JSON output: {exc}",
            ) from exc

    async def chat_concierge(
        self, user_id: uuid.UUID, prompt: str, location: str | None, model: str | None = None
    ) -> AIResponseDTO:
        movies = (
            await self.db.execute(
                select(Movie).where(Movie.status.in_(["NOW_SHOWING", "COMING_SOON"])).limit(25)
            )
        ).scalars().all()
        recs = await BookmarkService(self.db).get_recommendations(user_id)
        orders = (
            await self.db.execute(
                select(Order).where(Order.user_id == user_id).order_by(Order.created_at.desc()).limit(5)
            )
        ).scalars().all()

        movie_ctx = [
            {
                "id": str(m.id),
                "title": m.title,
                "genre": m.genre,
                "duration_minutes": m.duration_minutes,
                "language": m.language,
                "rating": m.rating,
                "status": m.status,
                "synopsis": (m.synopsis or "")[:160],
            }
            for m in movies
        ]
        order_ctx = [
            {
                "order_no": o.order_no,
                "status": o.status,
                "total_myr": float(o.total_amount),
                "created_at": o.created_at.isoformat(),
            }
            for o in orders
        ]

        system_prompt = (
            "You are Megacine Malaysia's friendly Cinema AI Concierge. "
            "Reply in the exact same language the user uses (Chinese or English). "
            "Ground answers strictly in the provided real-time movies, user orders, and policies:\n"
            "- Seat hold timeout: 5 minutes.\n"
            "- Max seats per order: 6 seats.\n"
            "- Refund cutoff: full refund allowed up to 60 minutes before showtime.\n"
            "Return STRICT JSON with exactly two keys:\n"
            '{"reply": "concise helpful text", "config": {"recommended_movie_ids": ["uuid1"], "intent": "movie_recommendation|policy_support|order_help|general"}}'
        )
        user_payload = json.dumps(
            {
                "user_prompt": prompt,
                "selected_location": location or "All Locations",
                "user_preferred_genres": recs.preferred_genres,
                "available_movies": movie_ctx,
                "user_recent_orders": order_ctx,
            },
            ensure_ascii=False,
        )
        res, used_model = await self._call_gemini_json(system_prompt, user_payload, model=model)
        valid_ids = {str(m.id) for m in movies}
        cfg = res.get("config") if isinstance(res.get("config"), dict) else {}
        raw_ids = cfg.get("recommended_movie_ids") if isinstance(cfg.get("recommended_movie_ids"), list) else []
        cfg["recommended_movie_ids"] = [mid for mid in raw_ids if str(mid) in valid_ids][:5]
        return AIResponseDTO(
            reply=str(res.get("reply") or "Here are my suggestions."),
            config=cfg,
            model_used=used_model,
        )

    async def pick_best_seats(
        self, showtime_id: uuid.UUID, party_size: int, preference: str, model: str | None = None
    ) -> AIResponseDTO:
        stmt = (
            select(ShowtimeSeat, Seat)
            .join(Seat, Seat.id == ShowtimeSeat.seat_id)
            .where(ShowtimeSeat.showtime_id == showtime_id, ShowtimeSeat.status == "AVAILABLE")
            .order_by(Seat.row_label.asc(), Seat.seat_number.asc())
        )
        rows = (await self.db.execute(stmt)).all()
        if len(rows) < party_size:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Only {len(rows)} seats available for this showtime.",
            )

        seat_map = {}
        avail_list = []
        for ss, seat in rows:
            sid = str(ss.id)
            label = f"{seat.row_label}{seat.seat_number}"
            seat_map[sid] = label
            avail_list.append(
                {
                    "id": sid,
                    "label": label,
                    "row": seat.row_label,
                    "col": seat.seat_number,
                    "zone": seat.seat_zone,
                    "price": float(ss.price),
                }
            )

        system_prompt = (
            "You are a cinema seat-selection AI. Pick the best contiguous seats from the provided AVAILABLE list "
            "matching the requested party_size and user preference (prefer middle-back center seats when unspecified). "
            "Never invent seat IDs. Return STRICT JSON:\n"
            '{"reply": "short explanation why these seats are great", "config": {"selected_seat_ids": ["uuid1", "uuid2"]}}'
        )
        user_payload = json.dumps(
            {"party_size": party_size, "preference": preference, "available_seats": avail_list},
            ensure_ascii=False,
        )
        res, used_model = await self._call_gemini_json(
            system_prompt, user_payload, model=model or "gemini-3.5-flash-lite"
        )
        cfg = res.get("config") if isinstance(res.get("config"), dict) else {}
        raw_ids = cfg.get("selected_seat_ids") if isinstance(cfg.get("selected_seat_ids"), list) else []

        picked = []
        for sid in raw_ids:
            s = str(sid)
            if s in seat_map and s not in picked:
                picked.append(s)
            if len(picked) == party_size:
                break
        if len(picked) < party_size:
            for item in avail_list:
                if item["id"] not in picked:
                    picked.append(item["id"])
                if len(picked) == party_size:
                    break

        cfg["selected_seat_ids"] = picked
        cfg["seat_labels"] = [seat_map[sid] for sid in picked]
        return AIResponseDTO(
            reply=str(res.get("reply") or f"Selected best {party_size} seats: {', '.join(cfg['seat_labels'])}"),
            config=cfg,
            model_used=used_model,
        )

    async def autofill_movie(self, title: str, notes: str, model: str | None = None) -> AIResponseDTO:
        system_prompt = (
            "You are a cinema catalog assistant for Malaysia (FINAS ratings: U, P12, 13, 16, 18). "
            "Given a movie title and optional notes, generate accurate catalog metadata. Return STRICT JSON:\n"
            '{"reply": "short confirmation message", "config": {"synopsis": "2-sentence engaging plot", '
            '"genre": "Sci-Fi|Action|Drama|Comedy|Horror|Animation|Thriller", "rating": "P12", '
            '"language": "English", "duration_minutes": 120}}'
        )
        user_payload = json.dumps({"title": title, "notes": notes}, ensure_ascii=False)
        res, used_model = await self._call_gemini_json(
            system_prompt, user_payload, model=model or "gemini-3.5-flash-lite"
        )
        cfg = res.get("config") if isinstance(res.get("config"), dict) else {}
        return AIResponseDTO(
            reply=str(res.get("reply") or "Metadata generated."),
            config=cfg,
            model_used=used_model,
        )
