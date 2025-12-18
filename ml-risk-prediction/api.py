"""
Flask API for Stock Risk Prediction
Serves risk predictions to Salesforce via REST API
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import numpy as np
import json
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for Salesforce calls

# Load model and scaler
MODEL_PATH = 'models/risk_model.pkl'
SCALER_PATH = 'models/scaler.pkl'
FEATURE_NAMES_PATH = 'models/feature_names.json'

try:
    model = joblib.load(MODEL_PATH)
    scaler = joblib.load(SCALER_PATH)
    with open(FEATURE_NAMES_PATH, 'r') as f:
        feature_names = json.load(f)
    print("Model loaded successfully")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None
    scaler = None
    feature_names = []

def calculate_features(stock_data):
    """
    Calculate derived features from raw stock data
    """
    features = {}
    
    # Extract raw values
    day_change_percent = stock_data.get('day_change_percent', 0)
    volume = stock_data.get('volume', 0)
    market_cap = stock_data.get('market_cap', 0)
    current_price = stock_data.get('current_price', 0)
    previous_close = stock_data.get('previous_close', current_price)
    
    # Calculate derived features
    features['day_change_percent'] = day_change_percent
    features['volume'] = volume if volume > 0 else 1  # Avoid division by zero
    features['market_cap'] = market_cap if market_cap > 0 else 1
    features['current_price'] = current_price if current_price > 0 else 1
    features['price_volatility'] = abs(day_change_percent)
    
    # Volume ratio (normalized, using a simple approach)
    # In production, use historical average
    features['volume_ratio'] = 1.0  # Default, should be calculated from historical data
    
    # Price change ratio
    if previous_close > 0:
        features['price_change_ratio'] = abs(current_price - previous_close) / previous_close
    else:
        features['price_change_ratio'] = 0
    
    return features

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None
    })

@app.route('/predict', methods=['POST'])
def predict():
    """
    Predict risk score for a stock
    
    Expected JSON payload:
    {
        "day_change_percent": 2.5,
        "volume": 1000000,
        "market_cap": 5000000000,
        "current_price": 150.50,
        "previous_close": 147.25
    }
    """
    if model is None or scaler is None:
        return jsonify({
            'error': 'Model not loaded. Please train the model first.'
        }), 500
    
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Calculate features
        features = calculate_features(data)
        
        # Prepare feature vector in correct order
        feature_vector = [features.get(name, 0) for name in feature_names]
        feature_array = np.array(feature_vector).reshape(1, -1)
        
        # Scale features
        scaled_features = scaler.transform(feature_array)
        
        # Predict
        risk_score = model.predict(scaled_features)[0]
        
        # Ensure score is between 0-100
        risk_score = max(0, min(100, risk_score))
        
        # Determine risk level
        if risk_score < 30:
            risk_level = 'Low'
        elif risk_score < 60:
            risk_level = 'Medium'
        else:
            risk_level = 'High'
        
        return jsonify({
            'risk_score': round(float(risk_score), 2),
            'risk_level': risk_level,
            'features_used': features
        })
    
    except Exception as e:
        return jsonify({
            'error': f'Prediction error: {str(e)}'
        }), 500

@app.route('/predict/batch', methods=['POST'])
def predict_batch():
    """
    Predict risk scores for multiple stocks at once
    
    Expected JSON payload:
    {
        "stocks": [
            {
                "symbol": "AAPL",
                "day_change_percent": 2.5,
                "volume": 1000000,
                "market_cap": 5000000000,
                "current_price": 150.50,
                "previous_close": 147.25
            },
            ...
        ]
    }
    """
    if model is None or scaler is None:
        return jsonify({
            'error': 'Model not loaded. Please train the model first.'
        }), 500
    
    try:
        data = request.get_json()
        stocks = data.get('stocks', [])
        
        if not stocks:
            return jsonify({'error': 'No stocks provided'}), 400
        
        results = []
        
        for stock in stocks:
            try:
                features = calculate_features(stock)
                feature_vector = [features.get(name, 0) for name in feature_names]
                feature_array = np.array(feature_vector).reshape(1, -1)
                scaled_features = scaler.transform(feature_array)
                risk_score = model.predict(scaled_features)[0]
                risk_score = max(0, min(100, risk_score))
                
                if risk_score < 30:
                    risk_level = 'Low'
                elif risk_score < 60:
                    risk_level = 'Medium'
                else:
                    risk_level = 'High'
                
                results.append({
                    'symbol': stock.get('symbol', 'UNKNOWN'),
                    'risk_score': round(float(risk_score), 2),
                    'risk_level': risk_level
                })
            except Exception as e:
                results.append({
                    'symbol': stock.get('symbol', 'UNKNOWN'),
                    'error': str(e)
                })
        
        return jsonify({
            'results': results,
            'count': len(results)
        })
    
    except Exception as e:
        return jsonify({
            'error': f'Batch prediction error: {str(e)}'
        }), 500

if __name__ == '__main__':
    # Run on port 5000 by default
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)

