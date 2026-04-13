from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    jwt_expiry_hours: int = 72
    jwt_refresh_expiry_days: int = 30
    cors_origins: str = ""

    model_config = {"env_file": ".env"}


settings = Settings()
