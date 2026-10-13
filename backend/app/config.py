from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql://sonder:sonder@localhost:5432/sonder"
    jwt_secret: str = "change-this-in-production"
    jwt_expires_minutes: int = 10080  # 7 days
    cors_origins: str = "*"
    port: int = 8000
    upload_dir: str = "uploads"

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()
