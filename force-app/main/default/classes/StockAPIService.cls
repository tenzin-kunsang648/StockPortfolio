/**
 * StockAPIService.cls
 * 
 * This class serves as a service layer for interacting with external stock APIs.
 * We will be interacting with Alpha Vantage API for stock market data.
 * It is designed to handle API requests and responses related to stock data.
 */
public with sharing class StockAPIService {

    private static final String BASE_URL = 'callout:AlphaVantage/query';
    private static String instance = 'Alpha_Vantage';

    private static String getApiKeyFromCustomMetadata() {
        API_Configuration__mdt config = API_Configuration__mdt.getInstance(instance);

        if(config == NULL || String.isBlank(config.API_Key__c)){
            throw new StockAPIException('API Configuration "' + instance + '" not found or API Key is missing.');
        }
        
        System.debug('Configuration loaded successfully');
        System.debug('API Key: ' + config.API_Key__c);
        return config.API_Key__c;
    }

     /**
     * Fetch real-time quote for a stock symbol
     */
    public static StockQuote getStockQuote(String symbol) {
        try {
            String endpoint = BASE_URL + 
                '?function=GLOBAL_QUOTE' +
                '&symbol=' + EncodingUtil.urlEncode(symbol, 'UTF-8') +
                '&apikey=' + getApiKey();
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setTimeout(120000);
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                return parseStockQuote(response.getBody(), symbol);
            } else {
                throw new StockAPIException('API Error: ' + response.getStatus());
            }
            
        } catch (Exception e) {
            System.debug('Error fetching stock quote: ' + e.getMessage());
            throw new StockAPIException('Failed to fetch stock data: ' + e.getMessage());
        }
    }
    
    /**
     * Parse API response into StockQuote wrapper
     */
    private static StockQuote parseStockQuote(String jsonResponse, String symbol) {
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
        Map<String, Object> globalQuote = (Map<String, Object>) response.get('Global Quote');
        
        if (globalQuote == null || globalQuote.isEmpty()) {
            throw new StockAPIException('Invalid symbol or API limit reached');
        }
        
        StockQuote quote = new StockQuote();
        quote.symbol = symbol;
        quote.price = Decimal.valueOf((String) globalQuote.get('05. price'));
        quote.previousClose = Decimal.valueOf((String) globalQuote.get('08. previous close'));
        quote.change = Decimal.valueOf((String) globalQuote.get('09. change'));
        quote.changePercent = (String) globalQuote.get('10. change percent');
        quote.volume = Long.valueOf((String) globalQuote.get('06. volume'));
        quote.lastUpdated = DateTime.now();
        
        return quote;
    }

    /**
     * Fetch company overview/fundamentals
     */
    public static CompanyOverview getCompanyOverview(String symbol) {
        try {
            String endpoint = BASE_URL + 
                '?function=OVERVIEW' +
                '&symbol=' + EncodingUtil.urlEncode(symbol, 'UTF-8') +
                '&apikey=' + getApiKey();
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setTimeout(120000);
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                return parseCompanyOverview(response.getBody(), symbol);
            } else {
                throw new StockAPIException('API Error: ' + response.getStatus());
            }
            
        } catch (Exception e) {
            System.debug('Error fetching company overview: ' + e.getMessage());
            throw new StockAPIException('Failed to fetch company data: ' + e.getMessage());
        }
    }
    
    /**
     * Parse company overview response
     */
    private static CompanyOverview parseCompanyOverview(String jsonResponse, String symbol) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
        
        CompanyOverview overview = new CompanyOverview();
        overview.symbol = symbol;
        overview.name = (String) data.get('Name');
        overview.description = (String) data.get('Description');
        overview.sector = (String) data.get('Sector');
        overview.industry = (String) data.get('Industry');
        overview.marketCap = String.isNotBlank((String) data.get('MarketCapitalization')) ? 
            Long.valueOf((String) data.get('MarketCapitalization')) : null;
        
        return overview;
    }

    /**
     * Batch fetch multiple stock quotes
     */
    public static Map<String, StockQuote> getMultipleStockQuotes(Set<String> symbols) {
        Map<String, StockQuote> quotes = new Map<String, StockQuote>();
        
        for (String symbol : symbols) {
            try {
                StockQuote quote = getStockQuote(symbol);
                quotes.put(symbol, quote);
                
                // Alpha Vantage free tier: 5 calls per minute
                // Add delay between calls
                if (symbols.size() > 1) {
                    // Note: Can't actually pause in Apex, handle this with Queueable
                    System.debug('Fetched quote for: ' + symbol);
                }
            } catch (Exception e) {
                System.debug('Failed to fetch quote for ' + symbol + ': ' + e.getMessage());
            }
        }
        
        return quotes;
    }
    
    /**
     * Wrapper class for a Stock Quote response from Alpha Vantage API.
     */
    public class StockQuote {
        public String symbol;
        public Decimal price;
        public Decimal previousClose;
        public Decimal change;
        public String changePercent;
        public Long volume;
        public DateTime lastUpdated;
    }

    /**
     * Wrapper class for Company Overview data
     */
    public class CompanyOverview {
        public String symbol;
        public String name;
        public String description;
        public String sector;
        public String industry;
        public Long marketCap;
    }

    /**
     * Custom exception for handling Stock API related errors.
     */
    public class StockAPIException extends Exception {}
}