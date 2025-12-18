/**
 * Trigger on Stock__c
 * Handles business logic when stock records are updated
 */
trigger StockTrigger on Stock__c (after update) {
    StockTriggerHandler.handle(Trigger.new, Trigger.oldMap);
}
