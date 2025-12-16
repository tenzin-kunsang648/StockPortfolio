/**
 * Queueable class to refresh a single stock asynchronously
 * Publishes Platform Event when complete
 */
public class SingleStockRefreshQueueable implements Queueable, Database.AllowsCallouts {
    
    private String stockSymbol;
    private Id stockId;
    private Id portfolioId;
    private Id userId;
    
    public SingleStockRefreshQueueable(String stockSymbol, Id stockId, Id portfolioId, Id userId) {
        this.stockSymbol = stockSymbol;
        this.stockId = stockId;
        this.portfolioId = portfolioId;
        this.userId = userId;
    }
    
    public void execute(QueueableContext context) {
        Boolean success = false;
        
        try {
            // Fetch quote first
            StockAPIService.StockQuote quote = StockAPIService.getStockQuote(stockSymbol);
            
            // Wait 15 seconds between calls to respect rate limits
            Long startTime = System.currentTimeMillis();
            while (System.currentTimeMillis() - startTime < 15000) {
                // Busy wait
            }
            
            // Then fetch company overview
            StockAPIService.CompanyOverview overview = StockAPIService.getCompanyOverview(stockSymbol);
            
            // Update the stock record
            Stock__c stock = [
                SELECT Id, Name, External_API_Symbol__c
                FROM Stock__c
                WHERE Id = :stockId
                LIMIT 1
            ];
            
            stock.Company_Name__c = overview.name;
            stock.Current_Price__c = quote.price;
            stock.Previous_Close__c = quote.previousClose;
            stock.Day_Change_Amount__c = quote.change;
            stock.Volume__c = quote.volume;
            stock.Market_Cap__c = overview.marketCap;
            stock.Last_Updated__c = quote.lastUpdated;
            stock.Sector__c = overview.sector;
            stock.Industry__c = overview.industry;
            
            if (quote.previousClose != null && quote.previousClose != 0) {
                stock.Day_Change__c = (quote.change / quote.previousClose) * 100;
            }
            
            update stock;
            
            success = true;
            System.debug('Successfully refreshed: ' + stockSymbol);
            
        } catch (Exception e) {
            System.debug('Error refreshing stock: ' + e.getMessage());
        }
        
        // Publish event
        publishRefreshEvent(success);
    }
    
    private void publishRefreshEvent(Boolean success) {
        Portfolio_Refresh_Complete__e event = new Portfolio_Refresh_Complete__e(
            Portfolio_Id__c = portfolioId,
            User_Id__c = userId,
            Stock_Symbol__c = stockSymbol,
            Current_Count__c = 1,
            Total_Stocks__c = 1,
            Success_Count__c = success ? 1 : 0,
            Failure_Count__c = success ? 0 : 1,
            Is_Complete__c = true,
            Error_Messages__c = null
        );
        
        List<Database.SaveResult> results = EventBus.publish(new List<Portfolio_Refresh_Complete__e>{ event });
        
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                System.debug('Error publishing event: ' + result.getErrors());
            }
        }
    }
}