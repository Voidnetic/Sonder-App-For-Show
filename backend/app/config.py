from pydantic_settings import BaseSettings, SettingsConfigDict


def _split(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql://sonder:sonder@localhost:5432/sonder"
    jwt_secret: str = "change-this-in-production"
    jwt_expires_minutes: int = 10080  # 7 days
    cors_origins: str = "*"
    port: int = 8000
    upload_dir: str = "uploads"

    # OAuth client IDs whose Google ID tokens are accepted, comma separated. For Android this is the
    # *Web* client ID that the app passes as serverClientId. Empty = Google sign-in is turned off.
    google_client_ids: str = ""
    # Accounts that may review reports at /api/admin/..., comma separated emails.
    admin_emails: str = ""
    # Shown on the privacy policy and account deletion pages.
    support_email: str = ""
    developer_name: str = "the Sonder team"

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return _split(self.cors_origins)

    @property
    def google_client_id_list(self) -> list[str]:
        return _split(self.google_client_ids)

    @property
    def admin_email_list(self) -> list[str]:
        return [email.lower() for email in _split(self.admin_emails)]


settings = Settings()
