"""ML model loading and prediction logic."""
import joblib
import numpy as np
import pandas as pd
from typing import Dict, Any, Optional
import logging
from datetime import datetime
import os

logger = logging.getLogger(__name__)

class DubaiRealEstateModel:
    """Dubai Real Estate Price Prediction Model."""
    
    def __init__(self, model_path: str):
        """Initialize and load the ML model."""
        self.model_path = model_path
        self.model = None
        self.model_version = os.getenv("MODEL_VERSION", "v1.0.0")
        self.load_model()
    
    def load_model(self):
        """Load the trained model from disk."""
        try:
            if os.path.exists(self.model_path):
                self.model = joblib.load(self.model_path)
                logger.info(f"Model loaded successfully from {self.model_path}")
            else:
                logger.warning(f"Model file not found at {self.model_path}, using dummy model")
                self.model = self._create_dummy_model()
        except Exception as e:
            logger.error(f"Error loading model: {e}, using dummy model")
            self.model = self._create_dummy_model()
    
    def _create_dummy_model(self):
        """Create a simple rule-based model for demo purposes."""
        # This is a placeholder that uses heuristics
        # In production, you'd have a trained scikit-learn model
        class DummyModel:
            def predict(self, X):
                # Simple rule-based prediction
                # Price = base_price * location_factor * size_factor * amenities_factor
                predictions = []
                for row in X:
                    base_price = 500000  # Base AED
                    location_factor = row[3] * 1.5  # Location encoded
                    size_factor = (row[2] / 1000) * 1.2  # Area factor
                    amenities = sum(row[7:]) * 50000  # Amenities bonus
                    price = (base_price + location_factor * 200000 + size_factor * 300000 + amenities)
                    predictions.append(price)
                return np.array(predictions)
        
        return DummyModel()
    
    def encode_features(self, request_data: Dict[str, Any]) -> np.ndarray:
        """Encode request data into model features."""
        # Location encoding (Dubai areas)
        location_map = {
            "dubai_marina": 1.0, "downtown": 1.2, "business_bay": 1.1,
            "jlt": 0.9, "jbr": 1.0, "difc": 1.3, "palm_jumeirah": 1.4,
            "emirates_hills": 1.2, "arabian_ranches": 0.8, "dubai_hills": 0.9,
            "motor_city": 0.7
        }
        
        # Property type encoding
        property_type_map = {
            "apartment": 1.0, "villa": 1.5, "townhouse": 1.2,
            "studio": 0.7, "penthouse": 1.8
        }
        
        location_factor = location_map.get(request_data.get("location", "dubai_marina"), 1.0)
        property_factor = property_type_map.get(request_data.get("property_type", "apartment"), 1.0)
        
        features = np.array([
            request_data.get("bedrooms", 0),
            request_data.get("bathrooms", 0),
            request_data.get("area_sqft", 1000),
            location_factor,
            property_factor,
            request_data.get("floor", 5) / 50.0 if request_data.get("floor") else 0.1,  # Normalized floor
            request_data.get("building_age_years", 5) / 50.0 if request_data.get("building_age_years") else 0.1,  # Normalized age
            int(request_data.get("has_parking", True)),
            int(request_data.get("has_balcony", False)),
            int(request_data.get("has_gym", False)),
            int(request_data.get("has_pool", False)),
            int(request_data.get("near_metro", False)),
            int(request_data.get("furnished", False))
        ]).reshape(1, -1)
        
        return features
    
    def predict_sale_price(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """Predict property sale price."""
        features = self.encode_features(request_data)
        prediction = self.model.predict(features)[0]
        
        area_sqft = request_data.get("area_sqft", 1000)
        price_per_sqft = prediction / area_sqft if area_sqft > 0 else 0
        
        location_factor = self._get_location_factor(request_data.get("location", "dubai_marina"))
        
        return {
            "predicted_price_aed": round(float(prediction), 2),
            "price_per_sqft_aed": round(price_per_sqft, 2),
            "location_premium": round(location_factor - 1.0, 2),
            "confidence_score": 0.85,  # In real model, use model's confidence
            "model_version": self.model_version,
            "prediction_timestamp": datetime.utcnow().isoformat() + "Z"
        }
    
    def predict_rent_price(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """Predict property rental price (annual)."""
        # Rental is typically 7-10% of sale price annually
        sale_prediction = self.predict_sale_price(request_data)
        annual_rent = sale_prediction["predicted_price_aed"] * 0.08  # 8% yield
        
        contract_type = request_data.get("contract_type", "annual")
        if contract_type == "monthly":
            monthly_rent = annual_rent / 12
            return {
                **sale_prediction,
                "predicted_price_aed": round(monthly_rent, 2),
                "price_per_sqft_aed": round(monthly_rent / request_data.get("area_sqft", 1000), 2),
                "rental_type": "monthly"
            }
        else:
            return {
                **sale_prediction,
                "predicted_price_aed": round(annual_rent, 2),
                "price_per_sqft_aed": round(annual_rent / request_data.get("area_sqft", 1000), 2),
                "rental_type": "annual"
            }
    
    def _get_location_factor(self, location: str) -> float:
        """Get location premium factor."""
        location_map = {
            "dubai_marina": 1.0, "downtown": 1.2, "business_bay": 1.1,
            "jlt": 0.9, "jbr": 1.0, "difc": 1.3, "palm_jumeirah": 1.4,
            "emirates_hills": 1.2, "arabian_ranches": 0.8, "dubai_hills": 0.9,
            "motor_city": 0.7
        }
        return location_map.get(location, 1.0)

# Global model instance
model_instance: Optional[DubaiRealEstateModel] = None

def get_model() -> DubaiRealEstateModel:
    """Get or initialize the global model instance."""
    global model_instance
    if model_instance is None:
        from config import settings
        model_instance = DubaiRealEstateModel(settings.MODEL_PATH)
    return model_instance

