# Salesforce Integration Guide

This guide explains how to integrate the Python ML Risk Prediction service with Salesforce.

## Overview

The integration consists of:
1. **Python ML Service**: Flask API that serves risk predictions
2. **Salesforce Apex Class**: `RiskPredictionService` that calls the API
3. **Custom Fields**: `Risk_Score__c` and `Risk_Level__c` on Stock__c object

## Setup Steps

### 1. Deploy Python API

First, deploy your Python API to a hosting service:

**Option A: Heroku**
```bash
cd ml-risk-prediction
heroku create your-risk-api
git push heroku main
```

**Option B: AWS Lambda/API Gateway**
- Use Zappa or Serverless Framework
- See Flask deployment guides

**Option C: Local Development with ngrok**
```bash
# Terminal 1: Run API
python api.py

# Terminal 2: Expose with ngrok
ngrok http 5000
# Use the ngrok URL (e.g., https://abc123.ngrok.io)
```

### 2. Configure API URL in Salesforce

**Option A: Update Apex Class (Quick Start)**

Edit `RiskPredictionService.cls`:
```apex
private static final String API_BASE_URL = 'https://your-api-url.com';
```

**Option B: Use Named Credential (Recommended for Production)**

1. Setup → Named Credentials → New
2. Label: `Risk_Prediction_API`
3. URL: `https://your-api-url.com`
4. Identity Type: Named Principal
5. Authentication Protocol: Password Authentication (if needed)
6. Save

Then update `RiskPredictionService.cls`:
```apex
private static final String API_BASE_URL = 'callout:Risk_Prediction_API';
```

**Option C: Use Custom Metadata (Best Practice)**

1. Create Custom Metadata Type: `API_Configuration__mdt`
2. Add field: `Risk_API_URL__c` (URL type)
3. Create record with your API URL
4. Update Apex to read from metadata:
```apex
API_Configuration__mdt config = API_Configuration__mdt.getInstance('Default');
String apiUrl = config.Risk_API_URL__c;
```

### 3. Deploy Salesforce Components

```bash
# Deploy custom fields
sfdx force:source:deploy -p force-app/main/default/objects/Stock__c/fields/Risk_Score__c.field-meta.xml
sfdx force:source:deploy -p force-app/main/default/objects/Stock__c/fields/Risk_Level__c.field-meta.xml

# Deploy Apex class
sfdx force:source:deploy -p force-app/main/default/classes/RiskPredictionService.cls
```

### 4. Test the Integration

**In Developer Console or VS Code:**

```apex
// Test single stock prediction
Id stockId = 'a0X...'; // Your Stock__c Id
RiskPredictionService.RiskPredictionResult result = 
    RiskPredictionService.predictRisk(stockId);
System.debug('Risk Score: ' + result.riskScore);
System.debug('Risk Level: ' + result.riskLevel);

// Test batch prediction
List<Id> stockIds = new List<Id>{'a0X...', 'a0Y...'};
Map<Id, RiskPredictionService.RiskPredictionResult> results = 
    RiskPredictionService.predictRiskBatch(stockIds);

// Test portfolio prediction
Id portfolioId = 'a0Z...'; // Your Portfolio__c Id
RiskPredictionService.predictRiskForPortfolio(portfolioId);
```

**In Lightning Web Component:**

```javascript
import predictStockRisk from '@salesforce/apex/StockSearchController.predictStockRisk';

// Call the method
predictStockRisk({ stockId: this.stockId })
    .then(result => {
        console.log('Risk Score:', result.riskScore);
        console.log('Risk Level:', result.riskLevel);
    })
    .catch(error => {
        console.error('Error:', error);
    });
```

## Usage Examples

### Example 1: Predict Risk When Stock is Added

Add to `StockDataService.upsertStockFromAPI()`:
```apex
// After updating stock data
RiskPredictionService.predictRisk(stock.Id);
```

### Example 2: Predict Risk for All Portfolio Stocks

Add button to Portfolio record page:
```html
<lightning-button 
    label="Calculate Risk Scores" 
    onclick={handleCalculateRisk}>
</lightning-button>
```

```javascript
handleCalculateRisk() {
    predictPortfolioRisk({ portfolioId: this.recordId })
        .then(() => {
            // Refresh data
            this.refresh();
        });
}
```

### Example 3: Scheduled Risk Prediction

Create a scheduled Apex class:
```apex
global class RiskPredictionScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        // Get all stocks updated in last 24 hours
        List<Stock__c> stocks = [
            SELECT Id FROM Stock__c 
            WHERE Last_Updated__c = LAST_N_DAYS:1
        ];
        
        List<Id> stockIds = new List<Id>();
        for (Stock__c s : stocks) {
            stockIds.add(s.Id);
        }
        
        if (!stockIds.isEmpty()) {
            RiskPredictionService.predictRiskBatch(stockIds);
        }
    }
}
```

Schedule it:
```apex
String cron = '0 0 2 * * ?'; // Daily at 2 AM
System.schedule('Daily Risk Prediction', cron, new RiskPredictionScheduler());
```

## API Request/Response Format

### Single Prediction Request
```json
POST /predict
{
    "day_change_percent": 2.5,
    "volume": 1000000,
    "market_cap": 5000000000,
    "current_price": 150.50,
    "previous_close": 147.25
}
```

### Single Prediction Response
```json
{
    "risk_score": 45.23,
    "risk_level": "Medium",
    "features_used": {...}
}
```

### Batch Prediction Request
```json
POST /predict/batch
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

## Security Considerations

1. **API Authentication**: Add API key authentication to your Flask API
2. **HTTPS**: Always use HTTPS in production
3. **Named Credentials**: Use Salesforce Named Credentials for secure credential management
4. **Rate Limiting**: Implement rate limiting on the API
5. **Error Handling**: Handle API failures gracefully

## Troubleshooting

### API Not Responding
- Check API URL is correct
- Verify API is running and accessible
- Check firewall/network settings
- Test API with Postman/curl

### Authentication Errors
- Verify Named Credential configuration
- Check API key/credentials are correct

### Null Risk Scores
- Ensure Stock__c records have required fields populated:
  - `Current_Price__c`
  - `Volume__c`
  - `Market_Cap__c`
  - `Day_Change__c` or `Previous_Close__c`

### Timeout Errors
- Increase timeout in `RiskPredictionService.callRiskAPI()`
- Optimize API response time
- Consider async processing for large batches

## Next Steps

1. Replace synthetic training data with real historical stock data
2. Add more features to the model (e.g., beta, P/E ratio, sector trends)
3. Implement model versioning and A/B testing
4. Add monitoring and logging
5. Create Lightning Web Component to display risk scores
6. Add risk alerts and notifications

