"""Configuration management from environment variables and Key Vault."""
import os
from typing import Optional

class Settings:
    """Application settings."""
    
    # Model configuration
    MODEL_PATH: str = os.getenv("MODEL_PATH", "/app/models/dubai_realestate_model.pkl")
    MODEL_VERSION: str = os.getenv("MODEL_VERSION", "v1.0.0")
    
    # Server configuration
    APP_NAME: str = "Dubai Real Estate Price Prediction API"
    APP_VERSION: str = os.getenv("APP_VERSION", "1.0.0")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    
    # Key Vault secrets (mounted via CSI driver)
    KEY_VAULT_SECRETS_PATH: Optional[str] = os.getenv("KEY_VAULT_SECRETS_PATH", None)
    
    # Dubai-specific settings
    DEFAULT_CURRENCY: str = "AED"
    
    # Health check
    HEALTH_CHECK_ENABLED: bool = os.getenv("HEALTH_CHECK_ENABLED", "true").lower() == "true"

settings = Settings()

