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

    # First start on an empty database (e.g. a new Railway Postgres): create the tables automatically.
    auto_create_schema: bool = True
    # Also load the demo users/moments. Off by default: their password is public, so never in production.
    seed_demo_data: bool = False

    # Cloudflare R2 photo storage. When these are empty, photos are saved in upload_dir on the server's disk
    # (fine on a laptop, but Railway's disk is wiped on every deploy).
    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket: str = ""
    # How long a photo link handed to the app stays valid.
    photo_url_expires_seconds: int = 3600

    # Sending emails (verification and password-reset codes). Set ONE of:
    #   RESEND_API_KEY                     Resend (resend.com), sent over HTTPS
    #   GMAIL_CLIENT_ID/CLIENT_SECRET/REFRESH_TOKEN
    #                                      a Gmail account through the Gmail API, over HTTPS (see DEPLOY.md).
    #                                      Use this on Railway's Hobby plan, which blocks SMTP.
    #   SMTP_HOST/PORT/USERNAME/PASSWORD   any SMTP server, e.g. Gmail with an app password (Railway Pro only)
    # plus EMAIL_FROM (the address the codes come from). With neither, verification is switched off and
    # email/password accounts work exactly as before.
    resend_api_key: str = ""
    gmail_client_id: str = ""
    gmail_client_secret: str = ""
    gmail_refresh_token: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    email_from: str = ""
    email_from_name: str = "Sonder"

    # Firebase Cloud Messaging: the service account key JSON (raw, or base64 of it). Empty = no push.
    firebase_service_account: str = ""

    @property
    def email_enabled(self) -> bool:
        return bool(
            self.email_from and (self.resend_api_key or self.gmail_enabled or (self.smtp_host and self.smtp_password))
        )

    @property
    def gmail_enabled(self) -> bool:
        return bool(self.gmail_client_id and self.gmail_client_secret and self.gmail_refresh_token)

    @property
    def email_provider(self) -> str:
        if self.resend_api_key:
            return "Resend"
        return "Gmail API" if self.gmail_enabled else "SMTP"

    @property
    def r2_enabled(self) -> bool:
        return bool(self.r2_account_id and self.r2_access_key_id and self.r2_secret_access_key and self.r2_bucket)

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
