# Stock Risk Prediction ML Service

Machine learning service for predicting stock risk scores, integrated with Salesforce.

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Train the Model

```bash
python train_model.py
```

This will:
- Generate synthetic training data (replace with real data in production)
- Train a Random Forest model
- Save the model to `models/risk_model.pkl`
- Save the scaler to `models/scaler.pkl`

### 3. Run the API Server

**Development:**
```bash
python api.py
```

**Production (using Gunicorn):**
```bash
gunicorn -w 4 -b 0.0.0.0:5000 api:app
```

The API will be available at `http://localhost:5000`

## API Endpoints

### Health Check
```
GET /health
```

### Single Prediction
```
POST /predict
Content-Type: application/json

{
    "day_change_percent": 2.5,
    "volume": 1000000,
    "market_cap": 5000000000,
    "current_price": 150.50,
    "previous_close": 147.25
}
```

Response:
```json
{
    "risk_score": 45.23,
    "risk_level": "Medium",
    "features_used": {...}
}
```

### Batch Prediction
```
POST /predict/batch
Content-Type: application/json

{
    "stocks": [
        {
            "symbol": "AAPL",
            "day_change_percent": 2.5,
            "volume": 1000000,
            "market_cap": 5000000000,
            "current_price": 150.50,
            "previous_close": 147.25
        }
    ]
}
```

## Deployment Options

### Option 1: Heroku
1. Create `Procfile`: `web: gunicorn -w 4 -b 0.0.0.0:$PORT api:app`
2. Deploy: `git push heroku main`

### Option 2: AWS Lambda
Use Zappa or Serverless Framework to deploy Flask app

### Option 3: Docker
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "api:app"]
```

### Option 4: Local Development
Run locally and use ngrok for Salesforce to access:
```bash
ngrok http 5000
```

## Integration with Salesforce

See the Salesforce Apex class `RiskPredictionService` for integration code.

## Model Features

The model uses the following features:
- `day_change_percent`: Daily price change percentage
- `volume`: Trading volume
- `market_cap`: Market capitalization
- `current_price`: Current stock price
- `price_volatility`: Calculated volatility metric
- `volume_ratio`: Normalized volume ratio
- `price_change_ratio`: Price change ratio

## Risk Score Interpretation

- **0-30**: Low Risk
- **30-60**: Medium Risk
- **60-100**: High Risk

## Production Considerations

1. **Replace synthetic data**: Use real historical stock data for training
2. **Add authentication**: Implement API key or OAuth for security
3. **Add logging**: Log all predictions for monitoring
4. **Model retraining**: Schedule periodic retraining with new data
5. **Error handling**: Add comprehensive error handling and validation
6. **Rate limiting**: Implement rate limiting to prevent abuse

