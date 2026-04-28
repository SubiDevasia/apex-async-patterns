/**
 * PlatformEventPublisher
 *
 * Demonstrates publishing Platform Events using EventBus.publish().
 * Platform Events decouple the publisher from the subscriber — the publisher
 * fires and forgets; subscribers (triggers, flows, external systems) react
 * asynchronously.
 *
 * Key rules:
 *  - EventBus.publish() is DML — counts against DML limits (150 per transaction)
 *  - Events are committed to the bus only when the transaction commits
 *  - If the transaction rolls back, no events are delivered
 *  - Use HighVolume events (eventType=HighVolume) for high-throughput scenarios
 *
 * Usage:
 *   PlatformEventPublisher.publishJobEvent('BatchJob', accountId, 'Success', 'Done');
 *   PlatformEventPublisher.publishBulkJobEvents(eventList);
 */
public class PlatformEventPublisher {

    /**
     * Publishes a single AsyncJob__e event.
     *
     * @param jobType   Type of async job (e.g. 'BatchJob', 'QueueableJob')
     * @param recordId  Salesforce record Id related to the job
     * @param status    Job outcome: 'Success', 'Failed', 'Processing'
     * @param message   Human-readable detail or error message
     */
    public static void publishJobEvent(
        String jobType,
        String recordId,
        String status,
        String message
    ) {
        AsyncJob__e event = new AsyncJob__e(
            JobType__c  = jobType,
            RecordId__c = recordId,
            Status__c   = status,
            Message__c  = message
        );

        Database.SaveResult result = EventBus.publish(event);

        if (result.isSuccess()) {
            System.debug('AsyncJob__e published — Type: ' + jobType + ' | Status: ' + status);
        } else {
            System.debug(LoggingLevel.ERROR,
                'Failed to publish AsyncJob__e: ' + result.getErrors()[0].getMessage());
        }
    }

    /**
     * Publishes a list of AsyncJob__e events in bulk.
     * More efficient than publishing one at a time when processing many records.
     *
     * @param events  List of pre-built AsyncJob__e records
     */
    public static void publishBulkJobEvents(List<AsyncJob__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = EventBus.publish(events);

        Integer successCount = 0;
        Integer errorCount   = 0;

        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                successCount++;
            } else {
                errorCount++;
                System.debug(LoggingLevel.ERROR,
                    'Bulk publish error: ' + result.getErrors()[0].getMessage());
            }
        }

        System.debug('Bulk publish complete — Success: ' + successCount + ' | Failed: ' + errorCount);
    }
}
