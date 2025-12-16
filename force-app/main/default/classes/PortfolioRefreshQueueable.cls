/**
 * Queueable chain to refresh all stocks in a portfolio
 * Publishes One Platform Event when ALL stocks are complete TESTING
 */
public class PortfolioRefreshQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<StockWrapper> stocksToRefresh;
    private Integer currentIndex;
    private Id portfolioId;
    private Id userId;
    private Integer successCount;
    private Integer failureCount;
    private List<String> errors;
    
    public class StockWrapper {
        public Id stockId;
        public String stockSymbol;
        
        public StockWrapper(Id stockId, String stockSymbol) {
            this.stockId = stockId;
            this.stockSymbol = stockSymbol;
        }
    }
    
    // Constructor for initial call
    public PortfolioRefreshQueueable(List<StockWrapper> stocks, Id portfolioId, Id userId) {
        this.stocksToRefresh = stocks;
        this.portfolioId = portfolioId;
        this.userId = userId;
        this.currentIndex = 0;
        this.successCount = 0;
        this.failureCount = 0;
        this.errors = new List<String>();
    }
    
    // Constructor for chaining
    private PortfolioRefreshQueueable(List<StockWrapper> stocks, Integer currentIndex, 
                                       Id portfolioId, Id userId, Integer successCount, 
                                       Integer failureCount, List<String> errors) {
        this.stocksToRefresh = stocks;
        this.currentIndex = currentIndex;
        this.portfolioId = portfolioId;
        this.userId = userId;
        this.successCount = successCount;
        this.failureCount = failureCount;
        this.errors = errors;
    }
    
    public void execute(QueueableContext context) {
        // Check if all stocks are processed
        if (currentIndex >= stocksToRefresh.size()) {
            return;  // Should not reach here
        }
        
        StockWrapper currentStock = stocksToRefresh[currentIndex];
        Boolean stockSuccess = false;
        
        try {
            // Fetch quote first
            StockAPIService.StockQuote quote = StockAPIService.getStockQuote(currentStock.stockSymbol);
            
            // Wait 15 seconds between calls to respect rate limits
            Long startTime = System.currentTimeMillis();
            while (System.currentTimeMillis() - startTime < 15000) {
                // Busy wait
            }
            
            // Then fetch company overview
            StockAPIService.CompanyOverview overview = StockAPIService.getCompanyOverview(currentStock.stockSymbol);
            
            // Update the stock record
            Stock__c stock = [
                SELECT Id, Name, External_API_Symbol__c
                FROM Stock__c
                WHERE Id = :currentStock.stockId
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
            
            successCount++;
            stockSuccess = true;
            System.debug('Successfully refreshed: ' + currentStock.stockSymbol);
            
        } catch (Exception e) {
            failureCount++;
            errors.add(currentStock.stockSymbol + ': ' + e.getMessage());
            System.debug('Error refreshing ' + currentStock.stockSymbol + ': ' + e.getMessage());
        }

        Long startTime = System.currentTimeMillis();
        while (System.currentTimeMillis() - startTime < 5000) {
            // Busy wait for 5 seconds
        }

        
        // Determine if this is the last stock
        Boolean isLastStock = (currentIndex + 1 >= stocksToRefresh.size());
        
        // Publish progress event
        publishProgressEvent(currentStock.stockSymbol, isLastStock);
        
        // Chain to next stock if more remain
        if (!isLastStock) {
            System.enqueueJob(new PortfolioRefreshQueueable(
                stocksToRefresh,
                currentIndex + 1,
                portfolioId,
                userId,
                successCount,
                failureCount,
                errors
            ));
        } else {
            // Last stock - send email notification
            sendCompletionEmail();
        }
    }

    /**
     * Publish progress event after each stock
     */
    private void publishProgressEvent(String stockSymbol, Boolean isComplete) {
        Portfolio_Refresh_Complete__e event = new Portfolio_Refresh_Complete__e(
            Portfolio_Id__c = portfolioId,
            Stock_Symbol__c = stockSymbol,
            Current_Count__c = currentIndex + 1,
            Total_Stocks__c = stocksToRefresh.size(),
            Success_Count__c = successCount,
            Failure_Count__c = failureCount,
            Is_Complete__c = isComplete,
            Error_Messages__c = errors.isEmpty() ? null : String.join(errors, '\n')
        );
        
        List<Database.SaveResult> results = EventBus.publish(new List<Portfolio_Refresh_Complete__e>{ event });
        
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                System.debug('Error publishing progress event: ' + result.getErrors());
            }
        }
    }

    /**
     * Send email notification to user when refresh completes
     */
    private void sendCompletionEmail() {
        try {
            // Get user and portfolio details
            User user = [SELECT Id, Email, Name FROM User WHERE Id = :userId LIMIT 1];
            Portfolio__c portfolio = [
                SELECT Id, Name, Total_Value__c, Total_Gain_Loss__c, Total_Gain_Loss_Percent__c
                FROM Portfolio__c 
                WHERE Id = :portfolioId 
                LIMIT 1
            ];
            
            // Build email content
            String subject = 'Portfolio Refresh Complete: ' + portfolio.Name;
            String body = buildEmailBody(user, portfolio);
            
            // Send email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ user.Email });
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            mail.setSaveAsActivity(false);
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            
            System.debug('Completion email sent to: ' + user.Email);
            
        } catch (Exception e) {
            System.debug('Error sending completion email: ' + e.getMessage());
        }
    }
    
    /**
     * Build HTML email body
     */
    private String buildEmailBody(User user, Portfolio__c portfolio) {
        String successIcon = '✅';
        String warningIcon = '⚠️';
        String errorIcon = '❌';
        
        String statusIcon = failureCount == 0 ? successIcon : 
                        (successCount > 0 ? warningIcon : errorIcon);
        
        String statusMessage;
        if (failureCount == 0) {
            statusMessage = 'All stocks updated successfully!';
        } else if (successCount > 0) {
            statusMessage = successCount + ' stocks updated, ' + failureCount + ' failed.';
        } else {
            statusMessage = 'All stock updates failed.';
        }
        
        String gainLossColor = portfolio.Total_Gain_Loss__c >= 0 ? '#2E844A' : '#C23934';
        String gainLossSign = portfolio.Total_Gain_Loss__c >= 0 ? '+' : '';
        
        String emailBody = '<html><body style="font-family: Arial, sans-serif; color: #333;">';
        emailBody += '<div style="max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">';
        
        // Header
        emailBody += '<div style="background-color: #0176D3; color: white; padding: 20px; text-align: center; border-radius: 5px;">';
        emailBody += '<h1 style="margin: 0;">Portfolio Refresh Complete</h1>';
        emailBody += '</div>';
        
        // Greeting
        emailBody += '<div style="background-color: white; padding: 20px; margin-top: 20px; border-radius: 5px;">';
        emailBody += '<p>Hi ' + user.Name + ',</p>';
        emailBody += '<p>Your portfolio refresh has completed.</p>';
        
        // Status Summary
        emailBody += '<div style="background-color: #f0f0f0; padding: 15px; border-radius: 5px; margin: 20px 0;">';
        emailBody += '<h2 style="margin-top: 0;">' + statusIcon + ' ' + statusMessage + '</h2>';
        emailBody += '<ul style="list-style: none; padding: 0;">';
        emailBody += '<li><strong>Portfolio:</strong> ' + portfolio.Name + '</li>';
        emailBody += '<li><strong>Total Stocks:</strong> ' + stocksToRefresh.size() + '</li>';
        emailBody += '<li><strong>Successful:</strong> ' + successCount + '</li>';
        if (failureCount > 0) {
            emailBody += '<li><strong>Failed:</strong> ' + failureCount + '</li>';
        }
        emailBody += '</ul>';
        emailBody += '</div>';
        
        // Portfolio Summary
        emailBody += '<h3>Portfolio Summary</h3>';
        emailBody += '<table style="width: 100%; border-collapse: collapse;">';
        emailBody += '<tr style="background-color: #f9f9f9;">';
        emailBody += '<td style="padding: 10px; border: 1px solid #ddd;"><strong>Total Value</strong></td>';
        emailBody += '<td style="padding: 10px; border: 1px solid #ddd; text-align: right;">$' + 
                    String.valueOf(portfolio.Total_Value__c != null ? portfolio.Total_Value__c.setScale(2) : 0) + '</td>';
        emailBody += '</tr>';
        emailBody += '<tr>';
        emailBody += '<td style="padding: 10px; border: 1px solid #ddd;"><strong>Total Gain/Loss</strong></td>';
        emailBody += '<td style="padding: 10px; border: 1px solid #ddd; text-align: right; color: ' + gainLossColor + ';"><strong>' +
                    gainLossSign + '$' + String.valueOf(portfolio.Total_Gain_Loss__c != null ? portfolio.Total_Gain_Loss__c.setScale(2) : 0) +
                    ' (' + gainLossSign + String.valueOf(portfolio.Total_Gain_Loss_Percent__c != null ? portfolio.Total_Gain_Loss_Percent__c.setScale(2) : 0) + '%)</strong></td>';
        emailBody += '</tr>';
        emailBody += '</table>';
        
        // Errors (if any)
        if (!errors.isEmpty()) {
            emailBody += '<h3 style="color: #C23934;">Errors</h3>';
            emailBody += '<div style="background-color: #FEF5F1; padding: 15px; border-left: 4px solid #C23934; border-radius: 3px;">';
            emailBody += '<ul style="margin: 0; padding-left: 20px;">';
            for (String error : errors) {
                emailBody += '<li>' + error + '</li>';
            }
            emailBody += '</ul>';
            emailBody += '</div>';
        }
        
        // Call to Action
        emailBody += '<div style="text-align: center; margin-top: 30px;">';
        emailBody += '<a href="' + URL.getOrgDomainUrl().toExternalForm() + '/' + portfolioId + '" ';
        emailBody += 'style="background-color: #0176D3; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">View Portfolio</a>';
        emailBody += '</div>';
        
        emailBody += '</div>'; // Close white box
        
        // Footer
        emailBody += '<div style="text-align: center; margin-top: 20px; color: #666; font-size: 12px;">';
        emailBody += '<p>This is an automated notification from your Stock Portfolio Tracker.</p>';
        emailBody += '</div>';
        
        emailBody += '</div>'; // Close container
        emailBody += '</body></html>';
        
        return emailBody;
    }
}