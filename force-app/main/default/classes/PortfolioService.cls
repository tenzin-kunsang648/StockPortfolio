/**
 * Service class for Portfolio management
 * Handles portfolio operations, positions, and transactions
 */
public with sharing class PortfolioService {
    
    /**
     * Create a new portfolio for the current user
     */
    public static Portfolio__c createPortfolio(String portfolioName) {
        Portfolio__c portfolio = new Portfolio__c(
            Name = portfolioName,
            OwnerId = UserInfo.getUserId(),
            Created_Date__c = Date.today()
        );
        
        insert portfolio;
        return portfolio;
    }
    
    /**
     * Add stock position to portfolio (Buy transaction)
     */
    public static Portfolio_Position__c addPosition(
        Id portfolioId, 
        String stockSymbol, 
        Decimal shares, 
        Decimal pricePerShare
    ) {
        // Get or create stock record
        Stock__c stock = StockDataService.getOrCreateStock(stockSymbol);
        
        // Check if position already exists
        List<Portfolio_Position__c> existingPositions = [
            SELECT Id, Shares__c, Average_Cost__c, Total_Cost_Basis__c
            FROM Portfolio_Position__c
            WHERE Portfolio__c = :portfolioId
            AND Stock__c = :stock.Id
            LIMIT 1
        ];
        
        Portfolio_Position__c position;
        
        if (!existingPositions.isEmpty()) {
            // Update existing position - calculate new average cost
            position = existingPositions[0];
            Decimal currentValue = position.Shares__c * position.Average_Cost__c;
            Decimal newValue = shares * pricePerShare;
            Decimal totalShares = position.Shares__c + shares;
            
            position.Average_Cost__c = (currentValue + newValue) / totalShares;
            position.Shares__c = totalShares;
        } else {
            // Create new position
            position = new Portfolio_Position__c(
                Portfolio__c = portfolioId,
                Stock__c = stock.Id,
                Shares__c = shares,
                Average_Cost__c = pricePerShare
            );
        }
        
        upsert position;
        
        // Create transaction record
        Transaction__c transaction = new Transaction__c(
            Portfolio_Position__c = position.Id,
            Transaction_Type__c = 'Buy',
            Shares__c = shares,
            Price_Per_Share__c = pricePerShare,
            Transaction_Date__c = Date.today()
        );
        insert transaction;
        
        return position;
    }
    
    /**
     * Remove shares from position (Sell transaction)
     */
    public static Portfolio_Position__c removePosition(
        Id positionId,
        Decimal shares,
        Decimal pricePerShare
    ) {
        Portfolio_Position__c position = [
            SELECT Id, Shares__c, Average_Cost__c
            FROM Portfolio_Position__c
            WHERE Id = :positionId
            LIMIT 1
        ];
        
        if (position.Shares__c < shares) {
            throw new PortfolioException('Cannot sell more shares than owned');
        }
        
        position.Shares__c -= shares;
        
        // Delete position if all shares sold
        if (position.Shares__c == 0) {
            delete position;
        } else {
            update position;
        }
        
        // Create sell transaction
        Transaction__c transaction = new Transaction__c(
            Portfolio_Position__c = position.Id,
            Transaction_Type__c = 'Sell',
            Shares__c = shares,
            Price_Per_Share__c = pricePerShare,
            Transaction_Date__c = Date.today()
        );
        insert transaction;
        
        return position;
    }
    
    /**
     * Get portfolio with all positions and current values
     */
    public static PortfolioWrapper getPortfolioDetails(Id portfolioId) {
        Portfolio__c portfolio = [
            SELECT Id, Name, Total_Value__c, Total_Cost_Basis__c, 
                   Total_Gain_Loss__c, Total_Gain_Loss_Percent__c, Created_Date__c
            FROM Portfolio__c
            WHERE Id = :portfolioId
            LIMIT 1
        ];
        
        List<Portfolio_Position__c> positions = [
            SELECT Id, Stock__c, Stock__r.Name, Stock__r.Company_Name__c,
                   Stock__r.Current_Price__c, Stock__r.Day_Change__c,
                   Shares__c, Average_Cost__c, Total_Cost_Basis__c,
                   Current_Value__c, Gain_Loss__c, Gain_Loss_Percent__c
            FROM Portfolio_Position__c
            WHERE Portfolio__c = :portfolioId
            ORDER BY Current_Value__c DESC
        ];
        
        PortfolioWrapper wrapper = new PortfolioWrapper();
        wrapper.portfolio = portfolio;
        wrapper.positions = positions;
        wrapper.calculateMetrics();
        
        return wrapper;
    }
    
    /**
     * Get user's portfolios
     */
    public static List<Portfolio__c> getUserPortfolios() {
        return [
            SELECT Id, Name, Total_Value__c, Total_Gain_Loss__c, 
                   Total_Gain_Loss_Percent__c, Created_Date__c
            FROM Portfolio__c
            WHERE OwnerId = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
        ];
    }
    
    /**
     * Get transaction history for a position
     */
    public static List<Transaction__c> getPositionTransactions(Id positionId) {
        return [
            SELECT Id, Transaction_Type__c, Shares__c, Price_Per_Share__c,
                   Total_Amount__c, Transaction_Date__c, Notes__c
            FROM Transaction__c
            WHERE Portfolio_Position__c = :positionId
            ORDER BY Transaction_Date__c DESC
        ];
    }
    
    /**
     * Calculate portfolio performance metrics
     */
    public static Map<String, Decimal> calculatePerformanceMetrics(Id portfolioId) {
        PortfolioWrapper details = getPortfolioDetails(portfolioId);
        
        Map<String, Decimal> metrics = new Map<String, Decimal>();
        metrics.put('totalValue', details.portfolio.Total_Value__c);
        metrics.put('totalCost', details.portfolio.Total_Cost_Basis__c);
        metrics.put('totalGainLoss', details.portfolio.Total_Gain_Loss__c);
        metrics.put('totalGainLossPercent', details.portfolio.Total_Gain_Loss_Percent__c);
        metrics.put('positionCount', details.positions.size());
        
        // Calculate diversification (largest position as % of total)
        if (!details.positions.isEmpty() && details.portfolio.Total_Value__c > 0) {
            Decimal largestPosition = details.positions[0].Current_Value__c;
            metrics.put('largestPositionPercent', 
                (largestPosition / details.portfolio.Total_Value__c) * 100);
        }
        
        return metrics;
    }
    
    /**
     * Wrapper class for portfolio with positions
     */
    public class PortfolioWrapper {
        public Portfolio__c portfolio;
        public List<Portfolio_Position__c> positions;
        public Decimal totalValue = 0;
        public Decimal totalCost = 0;
        public Decimal totalGainLoss = 0;
        public Map<String, Decimal> sectorAllocation = new Map<String, Decimal>();
        
        public void calculateMetrics() {
            for (Portfolio_Position__c pos : positions) {
                totalValue += pos.Current_Value__c != null ? pos.Current_Value__c : 0;
                totalCost += pos.Total_Cost_Basis__c != null ? pos.Total_Cost_Basis__c : 0;
            }
            totalGainLoss = totalValue - totalCost;
        }
    }
    
    /**
     * Custom exception
     */
    public class PortfolioException extends Exception {}
}