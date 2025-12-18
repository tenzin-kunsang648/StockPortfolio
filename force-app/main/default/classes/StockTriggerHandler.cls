/**
 * Handler for Stock__c trigger
 * Manages business logic when stock records change
 */
public with sharing class StockTriggerHandler {
    
    /**
     * Main entry point from trigger
     */
    public static void handle(
        List<Stock__c> newList, 
        Map<Id, Stock__c> oldMap
    ) {
        // Find stocks with price changes
        Set<Id> stocksWithPriceChanges = getStocksWithPriceChanges(newList, oldMap);
        
        if (stocksWithPriceChanges.isEmpty()) {
            return;
        }
        
        // Find affected portfolios and recalculate
        Set<Id> affectedPortfolioIds = getAffectedPortfolioIds(stocksWithPriceChanges);
        
        if (!affectedPortfolioIds.isEmpty()) {
            PortfolioPositionTriggerHandler.updatePortfolioTotals(affectedPortfolioIds);
        }
    }
    
    /**
     * Identify stocks where Current_Price__c changed
     * Only price changes affect portfolio calculations
     */
    private static Set<Id> getStocksWithPriceChanges(
        List<Stock__c> newList, 
        Map<Id, Stock__c> oldMap
    ) {
        Set<Id> stocksWithChanges = new Set<Id>();
        
        for (Stock__c stock : newList) {
            Stock__c oldStock = oldMap.get(stock.Id);
            
            if (oldStock != null && stock.Current_Price__c != oldStock.Current_Price__c) {
                stocksWithChanges.add(stock.Id);
            }
        }
        
        return stocksWithChanges;
    }
    
    /**
     * Find all portfolios that have positions with the updated stocks
     * When stock price changes, Current_Value__c formula on positions recalculates,
     * so we need to update Total_Value__c on the portfolios
     */
    private static Set<Id> getAffectedPortfolioIds(Set<Id> stockIds) {
        Set<Id> portfolioIds = new Set<Id>();
        
        List<Portfolio_Position__c> positions = [
            SELECT Portfolio__c
            FROM Portfolio_Position__c
            WHERE Stock__c IN :stockIds
            AND Portfolio__c != null
        ];
        
        for (Portfolio_Position__c pos : positions) {
            portfolioIds.add(pos.Portfolio__c);
        }
        
        return portfolioIds;
    }
}

