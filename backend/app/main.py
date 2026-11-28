from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from app.api.internal.ops import router as ops_router
from app.api.v1.admin import router as admin_router
from app.api.v1.ai import router as ai_router
from app.api.v1.auth import router as auth_router
from app.api.v1.catalog import router as catalog_router
from app.api.v1.cinemas import router as cinemas_router
from app.api.v1.bookmarks import router as bookmarks_router
from app.api.v1.orders import router as orders_router
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(
    title="Megacine Malaysia API",
    version="1.1.1",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(ops_router)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(catalog_router, prefix="/api/v1")
app.include_router(cinemas_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
app.include_router(ai_router, prefix="/api/v1")
app.include_router(bookmarks_router, prefix="/api/v1")
app.include_router(orders_router, prefix="/api/v1")

# Mount Admin Web Portal directly under /admin on the same Render domain
ADMIN_WEB_DIR = Path(__file__).resolve().parents[2] / "admin-web"
if ADMIN_WEB_DIR.is_dir():
    app.mount("/admin", StaticFiles(directory=str(ADMIN_WEB_DIR), html=True), name="admin-web")


@app.get("/", include_in_schema=False)
async def root_redirect() -> RedirectResponse:
    return RedirectResponse(url="/admin/?v=3" if ADMIN_WEB_DIR.is_dir() else "/docs")
