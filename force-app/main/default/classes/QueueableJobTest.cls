/**
 * QueueableJobTest
 *
 * Test coverage for BasicQueueableJob, ChainedQueueableJob, QueueableCalloutJob.
 *
 * Key testing rules for Queueable:
 *  - Enqueue inside Test.startTest() / Test.stopTest() — stopTest() flushes the queue
 *  - Only ONE Queueable can be enqueued per test method (Salesforce platform limit)
 *  - Chaining is blocked in test context — ChainedQueueableJob uses Test.isRunningTest()
 *  - Use Test.setMock() before startTest() for callout jobs
 */
@IsTest
private class QueueableJobTest {

    // ── BasicQueueableJob tests ───────────────────────────────────────────────

    @IsTest
    static void basicQueueable_noEmail_setsDoNotCall() {
        Contact c = new Contact(LastName = 'NoEmail', Email = null, DoNotCall = false);
        insert c;

        Test.startTest();
        System.enqueueJob(new BasicQueueableJob(new List<Id>{ c.Id }));
        Test.stopTest();

        Contact result = [SELECT DoNotCall FROM Contact WHERE Id = :c.Id];
        Assert.isTrue(result.DoNotCall, 'Contact with no email should be flagged DoNotCall');
    }

    @IsTest
    static void basicQueueable_hasEmail_notFlagged() {
        Contact c = new Contact(LastName = 'HasEmail', Email = 'test@example.com', DoNotCall = false);
        insert c;

        Test.startTest();
        System.enqueueJob(new BasicQueueableJob(new List<Id>{ c.Id }));
        Test.stopTest();

        Contact result = [SELECT DoNotCall FROM Contact WHERE Id = :c.Id];
        Assert.isFalse(result.DoNotCall, 'Contact with email should not be flagged');
    }

    @IsTest
    static void basicQueueable_emptyList_noError() {
        Test.startTest();
        System.enqueueJob(new BasicQueueableJob(new List<Id>()));
        Test.stopTest();

        Assert.isTrue(true, 'Empty Id list should complete without exception');
    }

    // ── ChainedQueueableJob tests ─────────────────────────────────────────────

    @IsTest
    static void chainedQueueable_processesFirstChunk() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'ChainTest ' + i));
        }
        insert accounts;

        List<Id> ids = new List<Id>();
        for (Account a : accounts) {
            ids.add(a.Id);
        }

        Test.startTest();
        System.enqueueJob(new ChainedQueueableJob(ids));
        Test.stopTest();

        List<Account> results = [SELECT Id, Description FROM Account WHERE Id IN :ids];
        Integer updatedCount = 0;
        for (Account a : results) {
            if (a.Description != null && a.Description.startsWith('Processed by ChainedQueueableJob')) {
                updatedCount++;
            }
        }
        Assert.areEqual(5, updatedCount, 'All accounts in first chunk should be processed');
    }

    @IsTest
    static void chainedQueueable_emptyList_noError() {
        Test.startTest();
        System.enqueueJob(new ChainedQueueableJob(new List<Id>()));
        Test.stopTest();

        Assert.isTrue(true, 'Empty list should complete without exception');
    }

    // ── QueueableCalloutJob tests ─────────────────────────────────────────────

    @IsTest
    static void queueableCallout_success_flagsAsSynced() {
        Account acc = new Account(Name = 'CalloutCorp');
        insert acc;

        Test.setMock(HttpCalloutMock.class, new MockHttp(200));

        Test.startTest();
        System.enqueueJob(new QueueableCalloutJob(acc.Id));
        Test.stopTest();

        Account result = [SELECT Description FROM Account WHERE Id = :acc.Id];
        Assert.isTrue(
            result.Description != null && result.Description.startsWith('Synced via'),
            'Account should be flagged as synced after successful callout'
        );
    }

    @IsTest
    static void queueableCallout_failure_noExceptionThrown() {
        Account acc = new Account(Name = 'FailCalloutCorp');
        insert acc;

        Test.setMock(HttpCalloutMock.class, new MockHttp(500));

        Test.startTest();
        System.enqueueJob(new QueueableCalloutJob(acc.Id));
        Test.stopTest();

        Assert.isTrue(true, 'Failed callout should log error and not throw exception');
    }

    // ── Mock class ────────────────────────────────────────────────────────────

    private class MockHttp implements HttpCalloutMock {
        private Integer statusCode;

        MockHttp(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }
}
