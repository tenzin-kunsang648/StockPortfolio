/**
 * Scheduler wrapper class
 * Allows the batch to run on a schedule (like a cron job)
 */
public class StockPriceRefreshScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Batch size of 100 to maximize batch API efficiency
        // Each batch makes ONE API call for up to 100 stocks
        Database.executeBatch(new StockPriceRefreshBatch(), 100);
    }
}