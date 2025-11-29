/**
 * Data Factory - Creates sample data for testing and demo
 * Can be called from Anonymous Apex to populate real data
 */
public class DataFactory {
    
    /**
     * Create stocks WITHOUT API calls (placeholder data)
     */
    public static List<Stock__c> createStocks() {
        List<Stock__c> stocks = new List<Stock__c>{
            new Stock__c(
                Name = 'AAPL',
                External_API_Symbol__c = 'AAPL',
                Company_Name__c = 'Apple Inc.',
                Current_Price__c = 178.50,
                Previous_Close__c = 175.20,
                Day_Change__c = 1.88,
                Volume__c = 45000000,
                Sector__c = 'Technology'
            ),
            new Stock__c(
                Name = 'MSFT',
                External_API_Symbol__c = 'MSFT',
                Company_Name__c = 'Microsoft Corporation',
                Current_Price__c = 395.80,
                Previous_Close__c = 390.50,
                Day_Change__c = 1.36,
                Volume__c = 22000000,
                Sector__c = 'Technology'
            ),
            new Stock__c(
                Name = 'NVDA',
                External_API_Symbol__c = 'NVDA',
                Company_Name__c = 'NVIDIA Corporation',
                Current_Price__c = 520.30,
                Previous_Close__c = 510.00,
                Day_Change__c = 2.02,
                Volume__c = 35000000,
                Sector__c = 'Technology'
            ),
            new Stock__c(
                Name = 'GOOGL',
                External_API_Symbol__c = 'GOOGL',
                Company_Name__c = 'Alphabet Inc.',
                Current_Price__c = 142.90,
                Previous_Close__c = 140.75,
                Day_Change__c = 1.53,
                Volume__c = 18000000,
                Sector__c = 'Technology'
            ),
            new Stock__c(
                Name = 'AMZN',
                External_API_Symbol__c = 'AMZN',
                Company_Name__c = 'Amazon.com Inc.',
                Current_Price__c = 175.60,
                Previous_Close__c = 172.30,
                Day_Change__c = 1.92,
                Volume__c = 28000000,
                Sector__c = 'Consumer Cyclical'
            ),
            new Stock__c(
                Name = 'META',
                External_API_Symbol__c = 'META',
                Company_Name__c = 'Meta Platforms Inc.',
                Current_Price__c = 510.20,
                Previous_Close__c = 505.00,
                Day_Change__c = 1.03,
                Volume__c = 15000000,
                Sector__c = 'Technology'
            ),
            new Stock__c(
                Name = 'TSLA',
                External_API_Symbol__c = 'TSLA',
                Company_Name__c = 'Tesla Inc.',
                Current_Price__c = 252.40,
                Previous_Close__c = 248.90,
                Day_Change__c = 1.41,
                Volume__c = 85000000,
                Sector__c = 'Consumer Cyclical'
            ),
            new Stock__c(
                Name = 'AMD',
                External_API_Symbol__c = 'AMD',
                Company_Name__c = 'Advanced Micro Devices',
                Current_Price__c = 135.70,
                Previous_Close__c = 132.50,
                Day_Change__c = 2.42,
                Volume__c = 42000000,
                Sector__c = 'Technology'
            ),
            new Stock__c(
                Name = 'NFLX',
                External_API_Symbol__c = 'NFLX',
                Company_Name__c = 'Netflix Inc.',
                Current_Price__c = 642.30,
                Previous_Close__c = 635.00,
                Day_Change__c = 1.15,
                Volume__c = 8000000,
                Sector__c = 'Communication Services'
            ),
            new Stock__c(
                Name = 'INTC',
                External_API_Symbol__c = 'INTC',
                Company_Name__c = 'Intel Corporation',
                Current_Price__c = 45.20,
                Previous_Close__c = 46.80,
                Day_Change__c = -3.42,
                Volume__c = 52000000,
                Sector__c = 'Technology'
            ),
            new Stock__c(
                Name = 'DIS',
                External_API_Symbol__c = 'DIS',
                Company_Name__c = 'The Walt Disney Company',
                Current_Price__c = 110.50,
                Previous_Close__c = 112.30,
                Day_Change__c = -1.60,
                Volume__c = 12000000,
                Sector__c = 'Communication Services'
            )
        };
        
        insert stocks;
        return stocks;
    }
    
    /**
     * Create a sample portfolio with positions
     */
    public static Portfolio__c createSamplePortfolio() {
        // Create stocks first
        List<Stock__c> stocks = createStocks();
        
        // Create portfolio
        Portfolio__c portfolio = new Portfolio__c(
            Name = 'Tech & Growth Portfolio',
            OwnerId = UserInfo.getUserId()
        );
        insert portfolio;
        
        // Create positions
        List<Portfolio_Position__c> positions = new List<Portfolio_Position__c>();
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[0].Id, // AAPL
            Share__c = 25,
            Average_Cost__c = 145.30
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[1].Id, // MSFT
            Share__c = 15,
            Average_Cost__c = 370.50
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[2].Id, // NVDA
            Share__c = 10,
            Average_Cost__c = 485.20
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[3].Id, // GOOGL
            Share__c = 8,
            Average_Cost__c = 138.75
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[4].Id, // AMZN
            Share__c = 12,
            Average_Cost__c = 168.90
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[5].Id, // META
            Share__c = 7,
            Average_Cost__c = 492.30
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[6].Id, // TSLA
            Share__c = 5,
            Average_Cost__c = 245.80
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[7].Id, // AMD
            Share__c = 20,
            Average_Cost__c = 124.50
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[8].Id, // NFLX
            Share__c = 4,
            Average_Cost__c = 625.40
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[9].Id, // INTC
            Share__c = 30,
            Average_Cost__c = 48.75
        ));
        
        positions.add(new Portfolio_Position__c(
            Portfolio__c = portfolio.Id,
            Stock__c = stocks[10].Id, // DIS
            Share__c = 15,
            Average_Cost__c = 112.30
        ));
        
        insert positions;
        
        // Create some transactions for history
        List<Transaction__c> transactions = new List<Transaction__c>();
        
        transactions.add(new Transaction__c(
            Portfolio_Position__c = positions[0].Id,
            Transaction_Type__c = 'Buy',
            Share__c = 15,
            Price_Per_Share__c = 150.00,
            Transaction_Date__c = Date.today().addDays(-60),
            Notes__c = 'Initial purchase'
        ));
        
        transactions.add(new Transaction__c(
            Portfolio_Position__c = positions[0].Id,
            Transaction_Type__c = 'Buy',
            Share__c = 10,
            Price_Per_Share__c = 138.50,
            Transaction_Date__c = Date.today().addDays(-30),
            Notes__c = 'Added on dip'
        ));
        
        insert transactions;
        
        return portfolio;
    }
}