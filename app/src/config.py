"""
Application configuration via environment variables (12-factor).
Uses pydantic-settings for validation and type coercion.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # -- Application
    app_name: str = "eks-gitops-platform"
    app_version: str = "0.1.0"
    environment: str = "dev"
    debug: bool = False
    log_level: str = "INFO"

    # -- Server
    host: str = "0.0.0.0"
    port: int = 8000
    workers: int = 1

    # -- Database (PostgreSQL via asyncpg)
    database_url: str = "postgresql+asyncpg://app:changeme@localhost:5432/app"
    db_pool_size: int = 20
    db_max_overflow: int = 10
    db_pool_timeout: int = 30
    db_echo: bool = False

    # -- Observability
    otlp_endpoint: str = "http://tempo.monitoring.svc.cluster.local:4317"
    metrics_enabled: bool = True
    tracing_enabled: bool = True
    tracing_sample_rate: float = 1.0

    # -- Security
    cors_origins: list[str] = ["*"]
    trusted_hosts: list[str] = ["*"]

    @property
    def is_production(self) -> bool:
        return self.environment == "prod"

    @property
    def effective_log_level(self) -> str:
        if self.debug:
            return "DEBUG"
        return self.log_level.upper()


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton — parsed once at startup."""
    return Settings()
