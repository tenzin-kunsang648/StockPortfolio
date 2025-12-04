# Technical Guide

## Architecture Overview

### Data Model
- **Portfolio__c** - User's investment portfolio
- **Stock__c** - Stock data with real-time prices from API
- **Portfolio_Position__c** - Individual holdings in a portfolio
- **Transaction__c** - Buy/sell history

### Key Components

**Apex Classes:**
- `StockAPIService` - Alpha Vantage API integration
- `StockDataService` - Stock CRUD operations
- `PortfolioService` - Portfolio management
- `StockSearchController` - LWC backend
- `StockPriceRefreshBatch` - Scheduled price updates

**LWC Components:**
- `portfolioContainer` - Parent component managing modal state
- `portfolioDashboard` - Main dashboard with summary and holdings table
- `stockSearch` - Stock search and add functionality

### Data Flow
```
User Action → LWC Component → Apex Controller → Service Layer → Database/API
```

### API Integration

**Alpha Vantage API:**
- Endpoint: `https://www.alphavantage.co/query`
- Functions used: `GLOBAL_QUOTE`, `OVERVIEW`
- Rate limit: 5 calls/minute (free tier)
- Configuration: Custom Metadata Type `API_Configuration__mdt`

### Automation

**Batch Job:**
- Class: `StockPriceRefreshBatch`
- Schedule: Runs during market hours
- Function: Updates all stock prices from API

**Trigger:**
- `StockTrigger` on Stock__c
- Updates portfolio values when stock prices change

### Formulas & Rollups

**Portfolio_Position__c formulas:**
- `Current_Value__c` = Shares × Stock.Current_Price (cross-object)
- `Gain_Loss__c` = Current_Value - Total_Cost_Basis
- `Gain_Loss_Percent__c` = (Gain_Loss / Total_Cost_Basis) × 100

**Portfolio__c rollups:**
- `Total_Value__c` - SUM of position current values (trigger-based)
- `Total_Cost_Basis__c` - SUM of position cost basis

---

## Setup Instructions

### 1. Deploy Code
```bash
sfdx force:source:deploy -p force-app/main/default
```

### 2. Configure API
1. Setup → Custom Metadata Types → API Configuration
2. New record: "Alpha_Vantage"
3. Add API Key field

### 3. Schedule Batch Job
```apex
// Execute in Anonymous Apex
System.schedule('Stock Price Refresh - 9AM', '0 0 9 * * ?', new StockPriceRefreshScheduler());
System.schedule('Stock Price Refresh - 12PM', '0 0 12 * * ?', new StockPriceRefreshScheduler());
System.schedule('Stock Price Refresh - 3PM', '0 0 15 * * ?', new StockPriceRefreshScheduler());
```

### 4. Add Component to Page
1. Portfolio record page → Edit
2. Add "Portfolio Container" component
3. Save & Activate

---

## Testing

### Create Sample Data
```apex
// Anonymous Apex
DataFactory.createSamplePortfolio();
```

### Manual API Test
```apex
// Test API connection
Stock__c stock = StockDataService.upsertStockFromAPI('AAPL');
System.debug('Stock: ' + stock);
```

---

[← Back to README](../README.md)