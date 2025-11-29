/**
 * Batch class to refresh stock prices from API
 * Schedule to run during market hours to update data
 */
public class StockPriceRefreshBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    private Integer successCount = 0;
    private Integer failureCount = 0;
    private List<String> errors = new List<String>();
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query all stocks that need price updates
        return Database.getQueryLocator([
            SELECT Id, Name, External_API_Symbol__c, Last_Updated__c
            FROM Stock__c
            WHERE External_API_Symbol__c != null
            ORDER BY Last_Updated__c ASC NULLS FIRST
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Stock__c> scope) {
        for (Stock__c stock : scope) {
            try {
                // Fetch updated quote from API
                StockAPIService.StockQuote quote = StockAPIService.getStockQuote(stock.External_API_Symbol__c);
                
                // Update stock record
                stock.Current_Price__c = quote.price;
                stock.Previous_Close__c = quote.previousClose;
                stock.Day_Change_Amount__c = quote.change;
                stock.Volume__c = quote.volume;
                stock.Last_Updated__c = quote.lastUpdated;
                
                // Calculate percentage change
                if (quote.previousClose != null && quote.previousClose != 0) {
                    stock.Day_Change__c = (quote.change / quote.previousClose) * 100;
                }
                
                successCount++;
                
            } catch (Exception e) {
                failureCount++;
                errors.add(stock.Name + ': ' + e.getMessage());
                System.debug('Error updating ' + stock.Name + ': ' + e.getMessage());
            }
        }
        
        // Update all stocks in scope
        try {
            update scope;
        } catch (Exception e) {
            System.debug('Error updating stocks: ' + e.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // Log results
        System.debug('Stock Price Refresh Complete');
        System.debug('Success: ' + successCount);
        System.debug('Failures: ' + failureCount);
        
        if (!errors.isEmpty()) {
            System.debug('Errors: ' + String.join(errors, ', '));
        }
        
        // Optionally send email notification to admins
        if (failureCount > 0) {
            sendErrorNotification();
        }
        
        // Recalculate portfolio values after price updates
        recalculatePortfolioValues();
    }
    
    private void sendErrorNotification() {
        // sending email only to me in case of error
        List<User> admins = [
            SELECT Id, Email
            FROM User
            WHERE Name = 'Tenzin Kunsang'
            AND IsActive = true
            LIMIT 1
        ];
        
        if (admins.isEmpty()) return;
        
        List<String> toAddresses = new List<String>();
        for (User admin : admins) {
            toAddresses.add(admin.Email);
        }
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject('Stock Price Refresh Errors');
        mail.setPlainTextBody(
            'Stock price refresh completed with errors.\n\n' +
            'Success: ' + successCount + '\n' +
            'Failures: ' + failureCount + '\n\n' +
            'Errors:\n' + String.join(errors, '\n')
        );
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug('Error sending notification email: ' + e.getMessage());
        }
    }
    
    private void recalculatePortfolioValues() {
        // Trigger portfolio value recalculation
        // This will update rollup summaries and formulas
        List<Portfolio__c> portfolios = [
            SELECT Id, Total_Value__c
            FROM Portfolio__c
            LIMIT 1000
        ];
        
        if (!portfolios.isEmpty()) {
            // Touch portfolios to recalculate formulas
            update portfolios;
        }
    }
    
    /**
     * Schedule this batch to run every hour during market hours
     * Run in Anonymous Apex or setup via Schedule Apex:
     * 
     * System.schedule('Stock Price Refresh - 9AM EST', '0 0 9 * * ?', new StockPriceRefreshScheduler());
     * System.schedule('Stock Price Refresh - 12PM EST', '0 0 12 * * ?', new StockPriceRefreshScheduler());
     * System.schedule('Stock Price Refresh - 3PM EST', '0 0 15 * * ?', new StockPriceRefreshScheduler());
     * 
     * CRON Syntax - https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm
     * 0 0 15 * * ?
    // │ │  │ │ │ │
    // │ │  │ │ │ └─ Day of week (? = any)
    // │ │  │ │ └─── Month (1-12)
    // │ │  │ └───── Day of month (1-31)
    // │ │  └─────── Hour (0-23, in Salesforce org timezone)
    // │ └────────── Minute (0-59)
    // └──────────── Second (always 0)
     */
}