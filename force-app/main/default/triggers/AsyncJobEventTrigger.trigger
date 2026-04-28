/**
 * AsyncJobEventTrigger
 *
 * Subscribes to AsyncJob__e Platform Events.
 * Fires asynchronously after the publishing transaction commits.
 *
 * Key rules:
 *  - Only 'after insert' is supported for Platform Event triggers
 *  - Use Trigger.new to access published events
 *  - Trigger runs in its own transaction — failures don't affect the publisher
 */
trigger AsyncJobEventTrigger on AsyncJob__e (after insert) {

    List<Id> failedAccountIds = new List<Id>();

    for (AsyncJob__e event : Trigger.new) {
        System.debug('AsyncJob__e received'
            + ' | Type: '     + event.JobType__c
            + ' | Status: '   + event.Status__c
            + ' | RecordId: ' + event.RecordId__c
            + ' | Message: '  + event.Message__c);

        if (event.Status__c == 'Failed' && String.isNotBlank(event.RecordId__c)) {
            try {
                Id recordId = (Id) event.RecordId__c;
                if (recordId.getSObjectType() == Account.SObjectType) {
                    failedAccountIds.add(recordId);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Invalid RecordId in event: ' + event.RecordId__c);
            }
        }
    }

    if (!failedAccountIds.isEmpty()) {
        List<Account> accounts = [
            SELECT Id, Rating
            FROM Account
            WHERE Id IN :failedAccountIds
        ];
        for (Account acc : accounts) {
            acc.Rating = 'Cold';
        }
        update accounts;
    }
}
