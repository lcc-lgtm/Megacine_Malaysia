import uuid
from collections import Counter
from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.entities import Movie, UserBookmark
from app.schemas.catalog import BookmarkToggleResponseDTO, MovieDTO, RecommendedMoviesResponseDTO


class BookmarkService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def list_bookmarked_movies(self, user_id: uuid.UUID) -> list[MovieDTO]:
        stmt = (
            select(Movie)
            .join(UserBookmark, UserBookmark.movie_id == Movie.id)
            .where(UserBookmark.user_id == user_id)
            .order_by(UserBookmark.created_at.desc())
        )
        movies = (await self.db.execute(stmt)).scalars().all()
        return [MovieDTO.model_validate(m) for m in movies]

    async def add_bookmark(self, user_id: uuid.UUID, movie_id: uuid.UUID) -> BookmarkToggleResponseDTO:
        exists = (await self.db.execute(select(Movie.id).where(Movie.id == movie_id))).scalar_one_or_none()
        if not exists:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found")
        stmt = (
            insert(UserBookmark)
            .values(user_id=user_id, movie_id=movie_id)
            .on_conflict_do_nothing(constraint="uq_user_bookmarks_pair")
        )
        await self.db.execute(stmt)
        await self.db.commit()
        return BookmarkToggleResponseDTO(movie_id=movie_id, bookmarked=True)

    async def remove_bookmark(self, user_id: uuid.UUID, movie_id: uuid.UUID) -> BookmarkToggleResponseDTO:
        stmt = delete(UserBookmark).where(
            UserBookmark.user_id == user_id,
            UserBookmark.movie_id == movie_id,
        )
        await self.db.execute(stmt)
        await self.db.commit()
        return BookmarkToggleResponseDTO(movie_id=movie_id, bookmarked=False)

    async def get_recommendations(self, user_id: uuid.UUID) -> RecommendedMoviesResponseDTO:
        bookmarked = await self.list_bookmarked_movies(user_id)
        bookmarked_ids = [m.id for m in bookmarked]

        genre_counts = Counter(m.genre for m in bookmarked if m.genre)
        preferred_genres = [g for g, _ in genre_counts.most_common()]

        all_active = (
            await self.db.execute(
                select(Movie)
                .where(Movie.status.in_(["NOW_SHOWING", "COMING_SOON"]))
                .order_by(Movie.release_date.desc().nullslast(), Movie.created_at.desc())
            )
        ).scalars().all()

        if preferred_genres:
            genre_rank = {g: idx for idx, g in enumerate(preferred_genres)}
            recommended = [m for m in all_active if m.genre in genre_rank]
            recommended.sort(key=lambda m: (genre_rank[m.genre], m.id in bookmarked_ids))
        else:
            recommended = list(all_active)

        return RecommendedMoviesResponseDTO(
            preferred_genres=preferred_genres,
            bookmarked_movie_ids=bookmarked_ids,
            movies=[MovieDTO.model_validate(m) for m in recommended],
        )
