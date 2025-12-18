/**
 * Handler for Portfolio_Position__c trigger
 * Manages business logic when positions change
 */
public with sharing class PortfolioPositionTriggerHandler {
    
    /**
     * Main entry point from trigger
     */
    public static void handle(
        List<Portfolio_Position__c> newList, 
        List<Portfolio_Position__c> oldList, 
        System.TriggerOperation operationType
    ) {
        // Collect affected portfolios
        Set<Id> portfolioIds = getAffectedPortfolioIds(newList, oldList);
        
        if (portfolioIds.isEmpty()) {
            return;
        }
        
        // Recalculate portfolio totals
        updatePortfolioTotals(portfolioIds);
    }
    
    /**
     * Extract Portfolio IDs from trigger context
     * Handles all trigger operations (insert, update, delete, undelete)
     */
    private static Set<Id> getAffectedPortfolioIds(
        List<Portfolio_Position__c> newList, 
        List<Portfolio_Position__c> oldList
    ) {
        Set<Id> portfolioIds = new Set<Id>();
        
        if (newList != null) {
            for (Portfolio_Position__c pos : newList) {
                if (pos.Portfolio__c != null) {
                    portfolioIds.add(pos.Portfolio__c);
                }
            }
        }
        
        if (oldList != null) {
            for (Portfolio_Position__c pos : oldList) {
                if (pos.Portfolio__c != null) {
                    portfolioIds.add(pos.Portfolio__c);
                }
            }
        }
        
        return portfolioIds;
    }
    
    /**
     * Recalculate and update Total_Value__c on Portfolio records
     * Sums Current_Value__c from all positions in each portfolio
     * Called from both Portfolio_Position__c and Stock__c triggers
     */
    public static void updatePortfolioTotals(Set<Id> portfolioIds) {
        // Query all positions with their calculated Current_Value__c
        // Current_Value__c is a formula: Share__c * Stock__r.Current_Price__c
        List<Portfolio_Position__c> positions = [
            SELECT Id, Portfolio__c, Current_Value__c
            FROM Portfolio_Position__c
            WHERE Portfolio__c IN :portfolioIds
        ];
        
        // Aggregate totals by portfolio
        Map<Id, Decimal> totalsByPortfolio = aggregatePositionValues(positions, portfolioIds);
        
        // Update portfolio records
        updatePortfolioRecords(totalsByPortfolio);
    }
    
    /**
     * Sum Current_Value__c for each portfolio
     */
    private static Map<Id, Decimal> aggregatePositionValues(
        List<Portfolio_Position__c> positions, 
        Set<Id> portfolioIds
    ) {
        Map<Id, Decimal> totalsByPortfolio = new Map<Id, Decimal>();
        
        // Initialize all portfolios to 0
        for (Id portfolioId : portfolioIds) {
            totalsByPortfolio.put(portfolioId, 0);
        }
        
        // Sum position values
        for (Portfolio_Position__c pos : positions) {
            if (pos.Portfolio__c != null) {
                Decimal currentTotal = totalsByPortfolio.get(pos.Portfolio__c);
                Decimal positionValue = pos.Current_Value__c != null ? pos.Current_Value__c : 0;
                totalsByPortfolio.put(pos.Portfolio__c, currentTotal + positionValue);
            }
        }
        
        return totalsByPortfolio;
    }
    
    /**
     * Update Portfolio records with calculated totals
     */
    private static void updatePortfolioRecords(Map<Id, Decimal> totalsByPortfolio) {
        List<Portfolio__c> portfoliosToUpdate = new List<Portfolio__c>();
        
        for (Id portfolioId : totalsByPortfolio.keySet()) {
            portfoliosToUpdate.add(new Portfolio__c(
                Id = portfolioId,
                Total_Value__c = totalsByPortfolio.get(portfolioId)
            ));
        }
        
        if (!portfoliosToUpdate.isEmpty()) {
            try {
                update portfoliosToUpdate;
            } catch (Exception e) {
                System.debug('Error updating Portfolio Total_Value__c: ' + e.getMessage());
                // Don't throw - allow trigger to complete
            }
        }
    }
}
