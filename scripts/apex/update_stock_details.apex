/**
 * Script to update or create a Stock__c record from the external API.
 * Ensures the required External_API_Symbol__c is provided so upsert succeeds.
 */
String symbol = 'DIS';
Stock__c result = StockDataService.upsertStockFromAPI(symbol);
// Optionally inspect result in Anonymous Apex logs
// System.debug('Updated stock: ' + result);