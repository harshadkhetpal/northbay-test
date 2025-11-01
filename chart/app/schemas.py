"""Pydantic schemas for request/response validation."""
from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum

class PropertyType(str, Enum):
    """Dubai property types."""
    APARTMENT = "apartment"
    VILLA = "villa"
    TOWNHOUSE = "townhouse"
    STUDIO = "studio"
    PENTHOUSE = "penthouse"

class DubaiLocation(str, Enum):
    """Popular Dubai locations."""
    DUBAI_MARINA = "dubai_marina"
    DOWNTOWN = "downtown"
    BUSINESS_BAY = "business_bay"
    JLT = "jlt"
    JBR = "jbr"
    DIFC = "difc"
    PALM_JUMEIRAH = "palm_jumeirah"
    EMIRATES_HILLS = "emirates_hills"
    ARABIAN_RANCHES = "arabian_ranches"
    DUBAI_HILLS = "dubai_hills"
    MOTOR_CITY = "motor_city"

class SalePredictionRequest(BaseModel):
    """Request schema for sale price prediction."""
    property_type: PropertyType = Field(..., description="Type of property")
    bedrooms: int = Field(..., ge=0, le=10, description="Number of bedrooms")
    bathrooms: int = Field(..., ge=0, le=10, description="Number of bathrooms")
    area_sqft: float = Field(..., gt=0, description="Property area in square feet")
    location: DubaiLocation = Field(..., description="Dubai location/area")
    floor: Optional[int] = Field(None, ge=0, description="Floor number (0 for ground)")
    building_age_years: Optional[int] = Field(None, ge=0, description="Building age in years")
    has_parking: bool = Field(True, description="Has parking space")
    has_balcony: bool = Field(False, description="Has balcony")
    has_gym: bool = Field(False, description="Building has gym")
    has_pool: bool = Field(False, description="Building has pool")
    near_metro: bool = Field(False, description="Near Dubai Metro")
    furnished: bool = Field(False, description="Property is furnished")

class RentPredictionRequest(BaseModel):
    """Request schema for rental price prediction."""
    property_type: PropertyType
    bedrooms: int = Field(..., ge=0, le=10)
    bathrooms: int = Field(..., ge=0, le=10)
    area_sqft: float = Field(..., gt=0)
    location: DubaiLocation
    floor: Optional[int] = None
    building_age_years: Optional[int] = None
    has_parking: bool = True
    has_balcony: bool = False
    has_gym: bool = False
    has_pool: bool = False
    near_metro: bool = False
    furnished: bool = False
    contract_type: str = Field("annual", description="annual or monthly")

class PredictionResponse(BaseModel):
    """Response schema for predictions."""
    predicted_price_aed: float = Field(..., description="Predicted price in AED")
    price_per_sqft_aed: float = Field(..., description="Price per square foot in AED")
    location_premium: Optional[float] = Field(None, description="Location premium factor")
    confidence_score: float = Field(..., ge=0, le=1, description="Model confidence score")
    model_version: str = Field(..., description="Model version used")
    prediction_timestamp: str = Field(..., description="Timestamp of prediction")

class HealthResponse(BaseModel):
    """Health check response."""
    status: str
    model_loaded: bool
    model_version: Optional[str] = None
    uptime_seconds: Optional[float] = None

