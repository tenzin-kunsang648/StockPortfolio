/**
 * Trigger on Portfolio_Position__c
 * Handles business logic when positions are created, updated, deleted, or undeleted
 */
trigger PortfolioPositionTrigger on Portfolio_Position__c (
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    PortfolioPositionTriggerHandler.handle(Trigger.new, Trigger.old, Trigger.operationType);
}
