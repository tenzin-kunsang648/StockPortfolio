/**
 * Service class for managing Stock__c records
 * Handles CRUD operations and syncing with external API
 */
public with sharing class StockDataService {
    
    /**
     * Create or update stock record with latest data from API
     */
    public static Stock__c upsertStockFromAPI(String symbol) {
        try {
            // Fetch data from API
            StockAPIService.StockQuote quote = StockAPIService.getStockQuote(symbol);
            StockAPIService.CompanyOverview overview = StockAPIService.getCompanyOverview(symbol);
            
            // querying existing stock record
            List<Stock__c> existingStocks = [
                SELECT Id, Name, Company_Name__c, External_API_Symbol__c
                FROM Stock__c
                WHERE External_API_Symbol__c = :symbol
                LIMIT 1
            ];
            
            Stock__c stock;
            if (!existingStocks.isEmpty()) {
                stock = existingStocks[0];
            } else {
                stock = new Stock__c();
                stock.Name = symbol;
                stock.External_API_Symbol__c = symbol;
            }
            
            // update fields from API data
            stock.Company_Name__c = overview.name;
            stock.Current_Price__c = quote.price;
            stock.Previous_Close__c = quote.previousClose;
            stock.Day_Change_Amount__c = quote.change;
            stock.Volume__c = quote.volume;
            stock.Market_Cap__c = overview.marketCap;
            stock.Last_Updated__c = quote.lastUpdated;
            stock.Sector__c = overview.sector;
            stock.Industry__c = overview.industry;
            
            // Calculate day change percentage
            if (quote.previousClose != null && quote.previousClose != 0) {
                stock.Day_Change__c = (quote.change / quote.previousClose) * 100;
            }
            
            upsert stock External_API_Symbol__c;
            
            return stock;
            
        } catch (Exception e) {
            System.debug('Error upserting stock: ' + e.getMessage());
            throw new StockDataException('Failed to update stock data: ' + e.getMessage());
        }
    }
    
    /**
     * Refresh prices for all tracked stocks
     */
    public static List<Stock__c> refreshAllStockPrices() {
        List<Stock__c> stocks = [
            SELECT Id, Name, External_API_Symbol__c
            FROM Stock__c
            WHERE External_API_Symbol__c != null
        ];
        
        List<Stock__c> updatedStocks = new List<Stock__c>();
        
        for (Stock__c stock : stocks) {
            try {
                Stock__c updated = upsertStockFromAPI(stock.External_API_Symbol__c);
                updatedStocks.add(updated);
            } catch (Exception e) {
                System.debug('Failed to refresh ' + stock.Name + ': ' + e.getMessage());
            }
        }
        
        return updatedStocks;
    }
    
    /**
     * Get stock by symbol, fetch from API if not found
     */
    public static Stock__c getOrCreateStock(String symbol) {
        List<Stock__c> existingStocks = [
            SELECT Id, Name, Current_Price__c, Company_Name__c, 
                   Day_Change__c, Day_Change_Amount__c, Volume__c
            FROM Stock__c
            WHERE External_API_Symbol__c = :symbol
            LIMIT 1
        ];
        
        if (!existingStocks.isEmpty()) {
            return existingStocks[0];
        } else {
            return upsertStockFromAPI(symbol);
        }
    }
    
    /**
     * Search stocks by symbol or company name
     */
    public static List<Stock__c> searchStocks(String searchTerm) {
        String searchPattern = '%' + searchTerm + '%';
        
        return [
            SELECT Id, Name, Company_Name__c, Current_Price__c, 
                   Day_Change__c, Day_Change_Amount__c, Sector__c
            FROM Stock__c
            WHERE Name LIKE :searchPattern 
               OR Company_Name__c LIKE :searchPattern
            ORDER BY Name
            LIMIT 50
        ];
    }
    
    /**
     * Get stocks by sector
     */
    public static Map<String, List<Stock__c>> getStocksBySector() {
        List<Stock__c> stocks = [
            SELECT Id, Name, Company_Name__c, Current_Price__c, 
                   Day_Change__c, Sector__c
            FROM Stock__c
            WHERE Sector__c != null
            ORDER BY Sector__c, Name
        ];

        Map<String, List<Stock__c>> stocksBySector = new Map<String, List<Stock__c>>();

        for (Stock__c stock: stocks) {
            if(!stocksBySector.containsKey(stock.Sector__c)) {
                stocksBySector.put(stock.Sector__c, new List<Stock__c>());
            }
            stocksBySector.get(stock.Sector__c).add(stock);
        }

        return stocksBySector;

    }
    
    /**
     * Custom exception class
     */
    public class StockDataException extends Exception {}
}