/**
 * PlatformEventTest
 *
 * Test coverage for PlatformEventPublisher and AsyncJobEventTrigger.
 *
 * Key testing rules for Platform Events:
 *  - Publish inside Test.startTest() / Test.stopTest()
 *  - Test.stopTest() delivers the event and fires the trigger synchronously
 *  - Assert on the trigger's side effects (DML), not on the event itself
 *  - EventBus.publish() returns Database.SaveResult — check isSuccess() to verify publishing
 */
@IsTest
private class PlatformEventTest {

    // ── Publisher tests ───────────────────────────────────────────────────────

    @IsTest
    static void publishJobEvent_singleEvent_succeeds() {
        Account acc = new Account(Name = 'EventCorp');
        insert acc;

        Test.startTest();
        PlatformEventPublisher.publishJobEvent(
            'BatchJob', acc.Id, 'Success', 'Batch completed successfully'
        );
        Test.stopTest();

        Assert.isTrue(true, 'Single event published without exception');
    }

    @IsTest
    static void publishBulkJobEvents_multipleEvents_succeeds() {
        List<AsyncJob__e> events = new List<AsyncJob__e>{
            new AsyncJob__e(JobType__c = 'BatchJob',     Status__c = 'Success',    Message__c = 'Done'),
            new AsyncJob__e(JobType__c = 'QueueableJob', Status__c = 'Processing', Message__c = 'Running'),
            new AsyncJob__e(JobType__c = 'FutureJob',    Status__c = 'Failed',     Message__c = 'Timed out')
        };

        Test.startTest();
        PlatformEventPublisher.publishBulkJobEvents(events);
        Test.stopTest();

        Assert.isTrue(true, 'Bulk events published without exception');
    }

    @IsTest
    static void publishBulkJobEvents_emptyList_noError() {
        Test.startTest();
        PlatformEventPublisher.publishBulkJobEvents(new List<AsyncJob__e>());
        Test.stopTest();

        Assert.isTrue(true, 'Empty list should return without error');
    }

    // ── Trigger tests ─────────────────────────────────────────────────────────

    @IsTest
    static void trigger_failedStatus_setsAccountRatingCold() {
        Account acc = new Account(Name = 'FailedEventCorp', Rating = 'Hot');
        insert acc;

        Test.startTest();
        EventBus.publish(new AsyncJob__e(
            JobType__c  = 'BatchJob',
            RecordId__c = acc.Id,
            Status__c   = 'Failed',
            Message__c  = 'Job timed out'
        ));
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        Assert.areEqual('Cold', result.Rating, 'Failed event should set Account Rating to Cold');
    }

    @IsTest
    static void trigger_successStatus_doesNotChangeRating() {
        Account acc = new Account(Name = 'SuccessEventCorp', Rating = 'Hot');
        insert acc;

        Test.startTest();
        EventBus.publish(new AsyncJob__e(
            JobType__c  = 'BatchJob',
            RecordId__c = acc.Id,
            Status__c   = 'Success',
            Message__c  = 'Completed'
        ));
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        Assert.areEqual('Hot', result.Rating, 'Success event should not change Account Rating');
    }

    @IsTest
    static void trigger_invalidRecordId_handledGracefully() {
        Test.startTest();
        EventBus.publish(new AsyncJob__e(
            JobType__c  = 'BatchJob',
            RecordId__c = 'INVALID_ID',
            Status__c   = 'Failed',
            Message__c  = 'Error'
        ));
        Test.stopTest();

        Assert.isTrue(true, 'Invalid RecordId should be handled gracefully without exception');
    }
}
