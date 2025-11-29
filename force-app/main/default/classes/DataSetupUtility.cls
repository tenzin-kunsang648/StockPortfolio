public class DataSetupUtility {
    
    /**
     * Call this manually to fetch real prices from API
     * Run ONCE to populate Stock__c with live data
     */
    public static void fetchRealStockPrices() {
        List<String> symbols = new List<String>{
            'AAPL', 'MSFT', 'NVDA', 'GOOGL', 'AMZN', 
            'META', 'TSLA', 'AMD', 'NFLX', 'INTC', 'DIS'
        };
        
        for (String symbol : symbols) {
            try {
                Stock__c stock = StockDataService.upsertStockFromAPI(symbol);
                System.debug('SUCCESS! ' + stock.Name + ': $' + stock.Current_Price__c);
            } catch (Exception e) {
                System.debug('ERROR! ' + symbol + ': ' + e.getMessage());
            }
        }
    }
}