from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    jwt_expiry_hours: int = 72
    jwt_refresh_expiry_days: int = 30
    cors_origins: str = ""
    frontend_url: str = "http://localhost"
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    smtp_tls: bool = True

    model_config = {"env_file": ".env"}


settings = Settings()
