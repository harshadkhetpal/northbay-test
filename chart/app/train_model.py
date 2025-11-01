#!/usr/bin/env python3
"""Training script for Dubai Real Estate Price Prediction Model."""
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
import joblib
import os

def generate_synthetic_dubai_data(n_samples=1000):
    """Generate synthetic Dubai real estate data for training."""
    np.random.seed(42)
    
    # Dubai locations with different price factors
    locations = [
        "dubai_marina", "downtown", "business_bay", "jlt", "jbr",
        "difc", "palm_jumeirah", "emirates_hills", "arabian_ranches",
        "dubai_hills", "motor_city"
    ]
    location_factors = {
        "dubai_marina": 1.0, "downtown": 1.2, "business_bay": 1.1,
        "jlt": 0.9, "jbr": 1.0, "difc": 1.3, "palm_jumeirah": 1.4,
        "emirates_hills": 1.2, "arabian_ranches": 0.8, "dubai_hills": 0.9,
        "motor_city": 0.7
    }
    
    # Property types
    property_types = ["apartment", "villa", "townhouse", "studio", "penthouse"]
    property_factors = {
        "apartment": 1.0, "villa": 1.5, "townhouse": 1.2,
        "studio": 0.7, "penthouse": 1.8
    }
    
    data = []
    for _ in range(n_samples):
        location = np.random.choice(locations)
        property_type = np.random.choice(property_types)
        
        bedrooms = np.random.randint(0, 6)
        bathrooms = np.random.randint(1, 4)
        area_sqft = np.random.uniform(500, 3000)
        floor = np.random.randint(0, 50)
        building_age = np.random.randint(0, 20)
        
        has_parking = np.random.choice([0, 1])
        has_balcony = np.random.choice([0, 1])
        has_gym = np.random.choice([0, 1])
        has_pool = np.random.choice([0, 1])
        near_metro = np.random.choice([0, 1])
        furnished = np.random.choice([0, 1])
        
        # Calculate price based on features
        base_price = 500000
        location_factor = location_factors[location]
        property_factor = property_factors[property_type]
        
        price = (
            base_price * location_factor * property_factor +
            bedrooms * 100000 +
            bathrooms * 50000 +
            (area_sqft / 1000) * 300000 +
            (50 - floor) * 2000 +
            (20 - building_age) * 5000 +
            has_parking * 50000 +
            has_balcony * 30000 +
            has_gym * 40000 +
            has_pool * 60000 +
            near_metro * 30000 +
            furnished * 80000
        )
        
        # Add some noise
        price += np.random.normal(0, price * 0.1)
        price = max(200000, price)  # Minimum price
        
        # Encode location and property type
        location_encoded = location_factor
        property_encoded = property_factor
        
        data.append([
            bedrooms, bathrooms, area_sqft, location_encoded, property_encoded,
            floor / 50.0, building_age / 50.0, has_parking, has_balcony,
            has_gym, has_pool, near_metro, furnished, price
        ])
    
    df = pd.DataFrame(data, columns=[
        "bedrooms", "bathrooms", "area_sqft", "location_factor", "property_factor",
        "floor_norm", "age_norm", "has_parking", "has_balcony",
        "has_gym", "has_pool", "near_metro", "furnished", "price"
    ])
    
    return df

def train_model():
    """Train the Dubai Real Estate prediction model."""
    print("Generating synthetic Dubai real estate data...")
    df = generate_synthetic_dubai_data(n_samples=2000)
    
    # Features (X) and target (y)
    feature_columns = [
        "bedrooms", "bathrooms", "area_sqft", "location_factor", "property_factor",
        "floor_norm", "age_norm", "has_parking", "has_balcony",
        "has_gym", "has_pool", "near_metro", "furnished"
    ]
    X = df[feature_columns].values
    y = df["price"].values
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    print(f"Training samples: {len(X_train)}, Test samples: {len(X_test)}")
    
    # Train Random Forest model
    print("Training Random Forest model...")
    model = RandomForestRegressor(
        n_estimators=100,
        max_depth=15,
        min_samples_split=5,
        random_state=42,
        n_jobs=-1
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    mae = mean_absolute_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)
    
    print(f"\nModel Performance:")
    print(f"  Mean Absolute Error: AED {mae:,.2f}")
    print(f"  R² Score: {r2:.4f}")
    print(f"  Average Price: AED {y_test.mean():,.2f}")
    print(f"  MAE as % of average: {(mae / y_test.mean()) * 100:.2f}%")
    
    # Save model
    model_dir = "/app/models"
    os.makedirs(model_dir, exist_ok=True)
    model_path = os.path.join(model_dir, "dubai_realestate_model.pkl")
    joblib.dump(model, model_path)
    print(f"\nModel saved to: {model_path}")
    
    return model

if __name__ == "__main__":
    train_model()

