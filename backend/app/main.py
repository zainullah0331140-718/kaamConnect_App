"""KaamConnect FastAPI application entrypoint."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models  # noqa: F401  (ensures ORM models are registered)
from .config import settings
from .database import Base, engine
from .routers import admin, auth, users
from .seed import seed_demo_data


@asynccontextmanager
async def lifespan(_app: FastAPI):
    if settings.is_production and settings.jwt_secret.startswith("dev-only"):
        raise RuntimeError(
            "JWT_SECRET must be configured with a strong value in production"
        )

    Base.metadata.create_all(bind=engine)

    if settings.seed_demo_data:
        seed_demo_data()

    yield


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description=(
        "Authentication and authorization API for the KaamConnect "
        "Flutter application (JWT access/refresh tokens, role-based access "
        "control for customer, provider and admin)."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(users.router, prefix=settings.api_v1_prefix)
app.include_router(admin.router, prefix=settings.api_v1_prefix)


@app.get("/")
def root() -> dict:
    return {
        "name": settings.app_name,
        "version": "1.0.0",
        "docs": "/docs",
        "api": settings.api_v1_prefix,
    }


@app.get(f"{settings.api_v1_prefix}/health")
def health() -> dict:
    return {"status": "ok"}
