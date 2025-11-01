"""FastAPI application for Dubai Real Estate Price Prediction."""
from fastapi import FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
import logging
import time
from datetime import datetime
from contextlib import asynccontextmanager

from schemas import (
    SalePredictionRequest,
    RentPredictionRequest,
    PredictionResponse,
    HealthResponse
)
from model import get_model
from config import settings

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Track startup time
start_time = time.time()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager - load model on startup."""
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"Loading model from: {settings.MODEL_PATH}")
    
    # Load model on startup
    try:
        model = get_model()
        logger.info(f"Model loaded successfully. Version: {model.model_version}")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
    
    yield
    
    logger.info("Shutting down application")

# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Dubai Real Estate Price Prediction API - Predict property sale and rental prices",
    lifespan=lifespan
)

@app.get("/", response_model=dict)
async def root():
    """Root endpoint."""
    return {
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "operational",
        "endpoints": {
            "health": "/health",
            "predict_sale": "/predict/sale",
            "predict_rent": "/predict/rent",
            "model_info": "/model/info"
        }
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    model = get_model()
    uptime = time.time() - start_time
    
    return HealthResponse(
        status="healthy" if model.model is not None else "degraded",
        model_loaded=model.model is not None,
        model_version=model.model_version if model.model is not None else None,
        uptime_seconds=round(uptime, 2)
    )

@app.get("/model/info", response_model=dict)
async def model_info():
    """Get model information."""
    model = get_model()
    return {
        "model_version": model.model_version,
        "model_loaded": model.model is not None,
        "model_path": settings.MODEL_PATH,
        "supported_locations": [
            "dubai_marina", "downtown", "business_bay", "jlt", "jbr",
            "difc", "palm_jumeirah", "emirates_hills", "arabian_ranches",
            "dubai_hills", "motor_city"
        ],
        "supported_property_types": [
            "apartment", "villa", "townhouse", "studio", "penthouse"
        ]
    }

@app.post("/predict/sale", response_model=PredictionResponse)
async def predict_sale_price(request: SalePredictionRequest):
    """
    Predict property sale price in AED.
    
    Accepts property features and returns predicted sale price.
    """
    try:
        model = get_model()
        request_dict = request.dict()
        prediction = model.predict_sale_price(request_dict)
        return PredictionResponse(**prediction)
    except Exception as e:
        logger.error(f"Error in sale prediction: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Prediction failed: {str(e)}"
        )

@app.post("/predict/rent", response_model=PredictionResponse)
async def predict_rent_price(request: RentPredictionRequest):
    """
    Predict property rental price in AED (annual or monthly).
    
    Accepts property features and returns predicted rental price.
    """
    try:
        model = get_model()
        request_dict = request.dict()
        prediction = model.predict_rent_price(request_dict)
        return PredictionResponse(**prediction)
    except Exception as e:
        logger.error(f"Error in rent prediction: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Prediction failed: {str(e)}"
        )

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler."""
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"}
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

