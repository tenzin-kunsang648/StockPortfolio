"""
Stock Risk Prediction Model Training Script
Trains a machine learning model to predict stock risk scores based on market data
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, r2_score
import joblib
import os

def generate_synthetic_training_data(n_samples=1000):
    """
    Generate synthetic training data for risk prediction.
    In production, replace this with real historical stock data.
    
    Risk factors:
    - Price volatility (day change %)
    - Volume (trading activity)
    - Market cap (company size)
    - Price level (absolute price)
    """
    np.random.seed(42)
    
    data = {
        'day_change_percent': np.random.normal(0, 3, n_samples),  # % change
        'volume': np.random.lognormal(15, 1, n_samples),  # Trading volume
        'market_cap': np.random.lognormal(20, 2, n_samples),  # Market capitalization
        'current_price': np.random.lognormal(4, 1, n_samples),  # Stock price
        'previous_close': np.random.lognormal(4, 1, n_samples),  # Previous close
    }
    
    df = pd.DataFrame(data)
    
    # Calculate derived features
    df['price_volatility'] = abs(df['day_change_percent'])
    df['volume_ratio'] = df['volume'] / df['volume'].mean()
    df['price_change_ratio'] = abs(df['current_price'] - df['previous_close']) / df['previous_close']
    
    # Calculate risk score (0-100, higher = more risky)
    # Risk increases with:
    # - Higher volatility
    # - Lower market cap (smaller companies = riskier)
    # - Higher price changes
    # - Lower volume (less liquid = riskier)
    
    risk_score = (
        df['price_volatility'] * 10 +  # Volatility component
        (1 / (df['market_cap'] / df['market_cap'].max())) * 30 +  # Inverse market cap
        df['price_change_ratio'] * 100 * 20 +  # Price change component
        (1 / (df['volume_ratio'] + 0.1)) * 20  # Inverse volume (liquidity)
    )
    
    # Normalize to 0-100 range
    risk_score = (risk_score - risk_score.min()) / (risk_score.max() - risk_score.min()) * 100
    df['risk_score'] = risk_score
    
    return df

def train_risk_model():
    """Train the risk prediction model"""
    
    print("Generating training data...")
    df = generate_synthetic_training_data(n_samples=2000)
    
    # Select features for training
    feature_columns = [
        'day_change_percent',
        'volume',
        'market_cap',
        'current_price',
        'price_volatility',
        'volume_ratio',
        'price_change_ratio'
    ]
    
    X = df[feature_columns]
    y = df['risk_score']
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Train Random Forest model
    print("Training Random Forest model...")
    model = RandomForestRegressor(
        n_estimators=100,
        max_depth=10,
        min_samples_split=5,
        random_state=42,
        n_jobs=-1
    )
    
    model.fit(X_train_scaled, y_train)
    
    # Evaluate model
    y_pred = model.predict(X_test_scaled)
    mse = mean_squared_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)
    
    print(f"\nModel Performance:")
    print(f"  Mean Squared Error: {mse:.2f}")
    print(f"  R² Score: {r2:.4f}")
    print(f"  RMSE: {np.sqrt(mse):.2f}")
    
    # Save model and scaler
    os.makedirs('models', exist_ok=True)
    joblib.dump(model, 'models/risk_model.pkl')
    joblib.dump(scaler, 'models/scaler.pkl')
    
    # Save feature names for API
    import json
    with open('models/feature_names.json', 'w') as f:
        json.dump(feature_columns, f)
    
    print("\nModel saved to models/risk_model.pkl")
    print("Scaler saved to models/scaler.pkl")
    print("Feature names saved to models/feature_names.json")
    
    return model, scaler, feature_columns

if __name__ == '__main__':
    train_risk_model()
    print("\nTraining complete!")

