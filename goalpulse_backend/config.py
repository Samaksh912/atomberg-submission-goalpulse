"""Application settings loaded from environment / .env file."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Configuration for the GoalPulse API.

    Values are read from environment variables (or a `.env` file located in
    the project root).
    """

    firebase_project_id: str = ""
    firebase_service_account_json: str = ""  # base64‑encoded JSON
    gemini_api_key: str = ""
    sendgrid_api_key: str = ""
    frontend_url: str = "http://localhost:3000"
    environment: str = "development"

    class Config:
        env_file = ".env"


settings = Settings()
