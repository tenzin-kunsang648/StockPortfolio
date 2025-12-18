# Quick Start Guide

## What Was Created

This solution provides a complete ML risk prediction system integrated with Salesforce:

### Python ML Components
- **`train_model.py`**: Trains a Random Forest model for risk prediction
- **`api.py`**: Flask REST API that serves predictions
- **`requirements.txt`**: Python dependencies
- **`quick_start.sh`**: Automated setup script

### Salesforce Components
- **`RiskPredictionService.cls`**: Apex class to call the Python API
- **`Risk_Score__c` field**: Stores risk score (0-100) on Stock__c
- **`Risk_Level__c` field**: Stores risk level (Low/Medium/High) on Stock__c
- **Updated `StockSearchController.cls`**: Added methods to predict risk

## Quick Setup (5 minutes)

### 1. Setup Python API

```bash
cd ml-risk-prediction
./quick_start.sh
```

Or manually:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python train_model.py
python api.py
```

### 2. Deploy to Salesforce

```bash
# Deploy custom fields
sfdx force:source:deploy -p force-app/main/default/objects/Stock__c/fields/Risk_Score__c.field-meta.xml
sfdx force:source:deploy -p force-app/main/default/objects/Stock__c/fields/Risk_Level__c.field-meta.xml

# Deploy Apex class
sfdx force:source:deploy -p force-app/main/default/classes/RiskPredictionService.cls
sfdx force:source:deploy -p force-app/main/default/classes/StockSearchController.cls
```

### 3. Configure API URL

Edit `RiskPredictionService.cls` and update:
```apex
private static final String API_BASE_URL = 'https://your-api-url.com';
```

For local testing with ngrok:
```bash
ngrok http 5000
# Use the ngrok URL (e.g., https://abc123.ngrok.io)
```

### 4. Test It!

In Developer Console:
```apex
Id stockId = 'a0X...'; // Your Stock__c Id
RiskPredictionService.RiskPredictionResult result = 
    RiskPredictionService.predictRisk(stockId);
System.debug(result);
```

## How It Works

1. **Training**: The model learns from stock features (volatility, volume, market cap, etc.)
2. **Prediction**: API receives stock data, returns risk score (0-100)
3. **Integration**: Salesforce calls API, updates Stock records with risk scores

## Next Steps

1. **Deploy API**: Deploy to Heroku, AWS, or your preferred hosting
2. **Use Real Data**: Replace synthetic training data with historical stock data
3. **Add UI**: Create Lightning Web Component to display risk scores
4. **Automate**: Schedule daily risk predictions

See `INTEGRATION_GUIDE.md` for detailed instructions.

