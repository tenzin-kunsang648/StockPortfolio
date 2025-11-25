/**
 * Controller for Stock Search LWC
 */
public with sharing class StockSearchController {
    
    /**
     * Search for stocks by symbol or company name
     */
    @AuraEnabled(cacheable=True)
    public static List<Stock__c> searchStocks(String searchTerm) {
        try{
            return StockDataService.searchStocks(searchTerm);
        } catch (Exception e) {
            throw new AuraHandledException('Error searching stock: ' + e.getMessage());
        }
    }
    
    /**
     * Add stock to portfolio
     */
    @AuraEnabled
    public static Portfolio_Position__c addStockToPortfolio(
        Id portfolioId,
        Id stockId,
        Decimal shares,
        Decimal pricePerShare
    ) {
        try {
            // Get stock symbol
            Stock__c stock = [SELECT Name FROM Stock__c WHERE Id = :stockId LIMIT 1];
            
            // Add position
            return PortfolioService.addPosition(
                portfolioId,
                stock.Name,
                shares,
                pricePerShare
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error adding stock: ' + e.getMessage());
        }
    }
    
    /**
     * Get portfolio positions with current values
     */
    @AuraEnabled(cacheable=true)
    public static List<PositionWrapper> getPortfolioPositions(Id portfolioId) {
        try {
            List<Portfolio_Position__c> positions = [
                SELECT Id, Stock__c, Stock__r.Name, Stock__r.Company_Name__c,
                       Stock__r.Current_Price__c, Stock__r.Day_Change__c,
                       Stock__r.Day_Change_Amount__c,
                       Shares__c, Average_Cost__c, Total_Cost_Basis__c,
                       Current_Value__c, Gain_Loss__c, Gain_Loss_Percent__c
                FROM Portfolio_Position__c
                WHERE Portfolio__c = :portfolioId
                ORDER BY Current_Value__c DESC
            ];
            
            List<PositionWrapper> wrappers = new List<PositionWrapper>();
            for (Portfolio_Position__c pos : positions) {
                wrappers.add(new PositionWrapper(pos));
            }
            
            return wrappers;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching positions: ' + e.getMessage());
        }
    }
    
    /**
     * Get portfolio summary
     */
    @AuraEnabled(cacheable=true)
    public static PortfolioSummary getPortfolioSummary(Id portfolioId) {
        try {
            Portfolio__c portfolio = [
                SELECT Id, Name, Total_Value__c, Total_Cost_Basis__c,
                       Total_Gain_Loss__c, Total_Gain_Loss_Percent__c
                FROM Portfolio__c
                WHERE Id = :portfolioId
                LIMIT 1
            ];
            
            return new PortfolioSummary(portfolio);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching portfolio: ' + e.getMessage());
        }
    }
    
    /**
     * Remove shares from position (sell)
     */
    @AuraEnabled
    public static void sellShares(Id positionId, Decimal shares, Decimal pricePerShare) {
        try {
            PortfolioService.removePosition(positionId, shares, pricePerShare);
        } catch (Exception e) {
            throw new AuraHandledException('Error selling shares: ' + e.getMessage());
        }
    }
    
    /**
     * Refresh stock price from API
     */
    @AuraEnabled
    public static Stock__c refreshStockPrice(Id stockId) {
        try {
            Stock__c stock = [SELECT External_API_Symbol__c FROM Stock__c WHERE Id = :stockId LIMIT 1];
            return StockDataService.upsertStockFromAPI(stock.External_API_Symbol__c);
        } catch (Exception e) {
            throw new AuraHandledException('Error refreshing price: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper classes for cleaner JSON serialization
     */
    public class PositionWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Id stockId;
        @AuraEnabled public String stockSymbol;
        @AuraEnabled public String companyName;
        @AuraEnabled public Decimal currentPrice;
        @AuraEnabled public Decimal dayChange;
        @AuraEnabled public Decimal dayChangeAmount;
        @AuraEnabled public Decimal shares;
        @AuraEnabled public Decimal averageCost;
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public Decimal currentValue;
        @AuraEnabled public Decimal gainLoss;
        @AuraEnabled public Decimal gainLossPercent;
        @AuraEnabled public String gainLossClass;
        
        public PositionWrapper(Portfolio_Position__c pos) {
            this.id = pos.Id;
            this.stockId = pos.Stock__c;
            this.stockSymbol = pos.Stock__r.Name;
            this.companyName = pos.Stock__r.Company_Name__c;
            this.currentPrice = pos.Stock__r.Current_Price__c;
            this.dayChange = pos.Stock__r.Day_Change__c;
            this.dayChangeAmount = pos.Stock__r.Day_Change_Amount__c;
            this.shares = pos.Shares__c;
            this.averageCost = pos.Average_Cost__c;
            this.totalCost = pos.Total_Cost_Basis__c;
            this.currentValue = pos.Current_Value__c;
            this.gainLoss = pos.Gain_Loss__c;
            this.gainLossPercent = pos.Gain_Loss_Percent__c;
            this.gainLossClass = (this.gainLoss != null && this.gainLoss >= 0) ? 
                'slds-text-color_success' : 'slds-text-color_error';
        }
    }
    
    public class PortfolioSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal totalValue;
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public Decimal gainLoss;
        @AuraEnabled public Decimal gainLossPercent;
        
        public PortfolioSummary(Portfolio__c p) {
            this.id = p.Id;
            this.name = p.Name;
            this.totalValue = p.Total_Value__c;
            this.totalCost = p.Total_Cost_Basis__c;
            this.gainLoss = p.Total_Gain_Loss__c;
            this.gainLossPercent = p.Total_Gain_Loss_Percent__c;
        }
    }
}