"""Application configuration loaded from environment variables."""

import os
from functools import lru_cache

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:  # pragma: no cover - dotenv is optional at runtime
    pass


def _as_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _as_list(value: str | None, default: list[str]) -> list[str]:
    if not value:
        return default
    return [item.strip() for item in value.split(",") if item.strip()]


class Settings:
    def __init__(self) -> None:
        self.app_name = os.getenv("APP_NAME", "KaamConnect API")
        self.environment = os.getenv("ENVIRONMENT", "development")
        self.api_v1_prefix = os.getenv("API_V1_PREFIX", "/api/v1")

        self.database_url = os.getenv(
            "DATABASE_URL", "sqlite:///./kaamconnect.db"
        )

        self.jwt_secret = os.getenv(
            "JWT_SECRET", "dev-only-change-me-with-a-long-random-secret"
        )
        self.jwt_algorithm = os.getenv("JWT_ALGORITHM", "HS256")
        self.access_token_expire_minutes = int(
            os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30")
        )
        self.refresh_token_expire_days = int(
            os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30")
        )
        self.password_reset_expire_minutes = int(
            os.getenv("PASSWORD_RESET_EXPIRE_MINUTES", "30")
        )

        self.cors_origins = _as_list(
            os.getenv("CORS_ORIGINS"),
            [
                "*",
            ],
        )

        self.seed_demo_data = _as_bool(
            os.getenv("SEED_DEMO_DATA"), default=True
        )
        # When no email provider is configured, the reset token is returned in
        # the API response so the mobile app's reset flow remains usable.
        self.expose_reset_token = _as_bool(
            os.getenv("EXPOSE_RESET_TOKEN"), default=True
        )

        # Demo / bootstrap admin account (matches the app's quick-fill chip).
        self.admin_email = os.getenv(
            "ADMIN_EMAIL", "zainullah0331140@gmail.com"
        ).lower()
        self.admin_password = os.getenv("ADMIN_PASSWORD", "AdminPass123!")
        self.admin_full_name = os.getenv("ADMIN_FULL_NAME", "Zain Ullah")

    @property
    def is_production(self) -> bool:
        return self.environment.strip().lower() in {"production", "prod"}

    @property
    def cors_allow_credentials(self) -> bool:
        # Browsers reject wildcard origins combined with credentials.
        return "*" not in self.cors_origins


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
