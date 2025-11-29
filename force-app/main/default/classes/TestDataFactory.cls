@isTest
public class TestDataFactory {
    
    @isTest
    static void testCreateSampleData() {
        Test.startTest();
        
        Portfolio__c portfolio = DataFactory.createSamplePortfolio();
        
        // Verify data was created
        System.assertNotEquals(null, portfolio.Id, 'Portfolio should be created');
        
        List<Portfolio_Position__c> positions = [
            SELECT Id, Stock__r.Name, Share__c
            FROM Portfolio_Position__c
            WHERE Portfolio__c = :portfolio.Id
        ];
        
        System.assertEquals(11, positions.size(), 'Should have 11 positions');
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreateStocks() {
        Test.startTest();
        
        List<Stock__c> stocks = DataFactory.createStocks();
        
        System.assertEquals(11, stocks.size(), 'Should create 11 stocks');
        System.assertNotEquals(null, stocks[0].Current_Price__c, 'Should have prices');
        
        Test.stopTest();
    }
}