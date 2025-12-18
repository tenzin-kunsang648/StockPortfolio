/**
 * Service class for calling ML Risk Prediction API
 * Integrates with Python Flask API to get risk predictions for stocks
 */
public with sharing class RiskPredictionService {
    
    // TODO: Configure this URL in Custom Metadata or Named Credential
    // For production, use a Named Credential instead of hardcoding
    private static final String API_BASE_URL = 'https://your-api-url.com'; // Replace with your API URL
    
    /**
     * Predict risk score for a single stock
     * @param stockId The Id of the Stock__c record
     * @return RiskPredictionResult with risk score and level
     */
    @AuraEnabled
    public static RiskPredictionResult predictRisk(Id stockId) {
        try {
            // Get stock data
            Stock__c stock = [
                SELECT Id, Name, Current_Price__c, Previous_Close__c,
                       Day_Change__c, Volume__c, Market_Cap__c
                FROM Stock__c
                WHERE Id = :stockId
                LIMIT 1
            ];
            
            // Prepare request payload
            Map<String, Object> payload = buildPayload(stock);
            
            // Call API
            HttpResponse response = callRiskAPI('/predict', payload);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
                    response.getBody()
                );
                
                // Update stock record
                stock.Risk_Score__c = (Decimal) result.get('risk_score');
                stock.Risk_Level__c = (String) result.get('risk_level');
                update stock;
                
                return new RiskPredictionResult(
                    (Decimal) result.get('risk_score'),
                    (String) result.get('risk_level'),
                    true,
                    null
                );
            } else {
                String errorMsg = 'API returned status: ' + response.getStatusCode();
                return new RiskPredictionResult(null, null, false, errorMsg);
            }
            
        } catch (Exception e) {
            System.debug('Error in predictRisk: ' + e.getMessage());
            return new RiskPredictionResult(null, null, false, e.getMessage());
        }
    }
    
    /**
     * Predict risk scores for multiple stocks (batch)
     * @param stockIds List of Stock__c record Ids
     * @return Map of Stock Id to RiskPredictionResult
     */
    @AuraEnabled
    public static Map<Id, RiskPredictionResult> predictRiskBatch(List<Id> stockIds) {
        Map<Id, RiskPredictionResult> results = new Map<Id, RiskPredictionResult>();
        
        try {
            // Get all stock data
            List<Stock__c> stocks = [
                SELECT Id, Name, Current_Price__c, Previous_Close__c,
                       Day_Change__c, Volume__c, Market_Cap__c
                FROM Stock__c
                WHERE Id IN :stockIds
            ];
            
            // Prepare batch payload
            List<Map<String, Object>> stocksPayload = new List<Map<String, Object>>();
            Map<String, Id> symbolToId = new Map<String, Id>();
            
            for (Stock__c stock : stocks) {
                Map<String, Object> stockPayload = buildPayload(stock);
                stockPayload.put('symbol', stock.Name);
                stocksPayload.add(stockPayload);
                symbolToId.put(stock.Name, stock.Id);
            }
            
            Map<String, Object> batchPayload = new Map<String, Object>{
                'stocks' => stocksPayload
            };
            
            // Call batch API
            HttpResponse response = callRiskAPI('/predict/batch', batchPayload);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(
                    response.getBody()
                );
                
                List<Object> apiResults = (List<Object>) responseData.get('results');
                List<Stock__c> stocksToUpdate = new List<Stock__c>();
                
                for (Object resultObj : apiResults) {
                    Map<String, Object> result = (Map<String, Object>) resultObj;
                    String symbol = (String) result.get('symbol');
                    Id stockId = symbolToId.get(symbol);
                    
                    if (stockId != null && result.containsKey('risk_score')) {
                        Stock__c stock = new Stock__c(
                            Id = stockId,
                            Risk_Score__c = (Decimal) result.get('risk_score'),
                            Risk_Level__c = (String) result.get('risk_level')
                        );
                        stocksToUpdate.add(stock);
                        
                        results.put(stockId, new RiskPredictionResult(
                            (Decimal) result.get('risk_score'),
                            (String) result.get('risk_level'),
                            true,
                            null
                        ));
                    } else if (stockId != null) {
                        results.put(stockId, new RiskPredictionResult(
                            null, null, false,
                            (String) result.get('error')
                        ));
                    }
                }
                
                // Update all stocks
                if (!stocksToUpdate.isEmpty()) {
                    update stocksToUpdate;
                }
            } else {
                // Return error for all stocks
                for (Id stockId : stockIds) {
                    results.put(stockId, new RiskPredictionResult(
                        null, null, false,
                        'API returned status: ' + response.getStatusCode()
                    ));
                }
            }
            
        } catch (Exception e) {
            System.debug('Error in predictRiskBatch: ' + e.getMessage());
            // Return error for all stocks
            for (Id stockId : stockIds) {
                results.put(stockId, new RiskPredictionResult(
                    null, null, false, e.getMessage()
                ));
            }
        }
        
        return results;
    }
    
    /**
     * Predict risk for all stocks in a portfolio
     * @param portfolioId The Id of the Portfolio__c record
     */
    @AuraEnabled
    public static void predictRiskForPortfolio(Id portfolioId) {
        try {
            // Get all stock IDs in portfolio
            List<Portfolio_Position__c> positions = [
                SELECT Stock__c
                FROM Portfolio_Position__c
                WHERE Portfolio__c = :portfolioId
                AND Stock__c != null
            ];
            
            List<Id> stockIds = new List<Id>();
            for (Portfolio_Position__c pos : positions) {
                stockIds.add(pos.Stock__c);
            }
            
            if (!stockIds.isEmpty()) {
                predictRiskBatch(stockIds);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error predicting risk for portfolio: ' + e.getMessage());
        }
    }
    
    /**
     * Build request payload from Stock record
     */
    private static Map<String, Object> buildPayload(Stock__c stock) {
        // Calculate day change percent if not available
        Decimal dayChangePercent = stock.Day_Change__c;
        if (dayChangePercent == null && stock.Previous_Close__c != null && 
            stock.Previous_Close__c != 0 && stock.Current_Price__c != null) {
            dayChangePercent = ((stock.Current_Price__c - stock.Previous_Close__c) / 
                               stock.Previous_Close__c) * 100;
        }
        
        return new Map<String, Object>{
            'day_change_percent' => dayChangePercent != null ? dayChangePercent : 0,
            'volume' => stock.Volume__c != null ? stock.Volume__c : 0,
            'market_cap' => stock.Market_Cap__c != null ? stock.Market_Cap__c : 0,
            'current_price' => stock.Current_Price__c != null ? stock.Current_Price__c : 0,
            'previous_close' => stock.Previous_Close__c != null ? stock.Previous_Close__c : 
                               (stock.Current_Price__c != null ? stock.Current_Price__c : 0)
        };
    }
    
    /**
     * Make HTTP call to Risk Prediction API
     */
    private static HttpResponse callRiskAPI(String endpoint, Map<String, Object> payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_BASE_URL + endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(30000); // 30 seconds timeout
        
        Http http = new Http();
        return http.send(req);
    }
    
    /**
     * Wrapper class for risk prediction results
     */
    public class RiskPredictionResult {
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        
        public RiskPredictionResult(Decimal riskScore, String riskLevel, 
                                   Boolean success, String errorMessage) {
            this.riskScore = riskScore;
            this.riskLevel = riskLevel;
            this.success = success;
            this.errorMessage = errorMessage;
        }
    }
}

