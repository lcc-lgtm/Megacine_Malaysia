from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.internal.ops import router as ops_router
from app.api.v1.admin import router as admin_router
from app.api.v1.auth import router as auth_router
from app.api.v1.catalog import router as catalog_router
from app.api.v1.orders import router as orders_router
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(
    title="Megacine Malaysia API",
    version="1.0.0",
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
app.include_router(admin_router, prefix="/api/v1")
app.include_router(orders_router, prefix="/api/v1")
