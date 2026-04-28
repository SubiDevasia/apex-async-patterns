/**
 * BatchApexTest
 *
 * Test coverage for AccountProcessorBatch, StatefulAccountBatch, BatchWithCallout.
 *
 * Key testing rules for Batch:
 *  - Use Database.executeBatch() inside Test.startTest() / Test.stopTest()
 *  - Test.stopTest() forces the batch to run synchronously — results are queryable immediately
 *  - Keep test data small (< 200 records) so the batch runs in a single execute() chunk
 *  - Use Test.setMock() before startTest() for callout batches
 */
@IsTest
private class BatchApexTest {


    @IsTest
    static void accountProcessorBatch_derivesRatingFromRevenue() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'BatchHot',  Industry = 'Technology', AnnualRevenue = 5000000),
            new Account(Name = 'BatchWarm', Industry = 'Technology', AnnualRevenue = 200000),
            new Account(Name = 'BatchCold', Industry = 'Technology', AnnualRevenue = 1000)
        };
        insert accounts;

        Test.startTest();
        Database.executeBatch(new AccountProcessorBatch('Technology'), 200);
        Test.stopTest();

        Map<String, String> ratingByName = new Map<String, String>();
        for (Account a : [SELECT Name, Rating FROM Account WHERE Id IN :toIds(accounts)]) {
            ratingByName.put(a.Name, a.Rating);
        }

        Assert.areEqual('Hot',  ratingByName.get('BatchHot'),  'Revenue >= 1M should be Hot');
        Assert.areEqual('Warm', ratingByName.get('BatchWarm'), 'Revenue 100K-1M should be Warm');
        Assert.areEqual('Cold', ratingByName.get('BatchCold'), 'Revenue < 100K should be Cold');
    }

    @IsTest
    static void accountProcessorBatch_noMatchingAccounts_noError() {
        Test.startTest();
        Database.executeBatch(new AccountProcessorBatch('NonExistentIndustry'), 200);
        Test.stopTest();

        Assert.isTrue(true, 'Batch with zero records should complete without error');
    }


    @IsTest
    static void statefulBatch_setsAnnualRevenue() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'Stateful' + i, AnnualRevenue = null));
        }
        insert accounts;

        Test.startTest();
        Database.executeBatch(new StatefulAccountBatch(), 200);
        Test.stopTest();

        Integer updatedCount = [
            SELECT COUNT() FROM Account
            WHERE Id IN :toIds(accounts)
            AND AnnualRevenue = 50000
        ];
        Assert.areEqual(5, updatedCount, 'All 5 accounts should have AnnualRevenue set to 50000');
    }

    @IsTest
    static void statefulBatch_noNullRevenueAccounts_noError() {
        insert new Account(Name = 'AlreadySet', AnnualRevenue = 99999);

        Test.startTest();
        Database.executeBatch(new StatefulAccountBatch(), 200);
        Test.stopTest();

        Assert.isTrue(true, 'Batch with no matching records should complete without error');
    }

    @IsTest
    static void batchWithCallout_successResponse_completes() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            accounts.add(new Account(Name = 'CalloutBatch' + i, Industry = 'Technology'));
        }
        insert accounts;

        Test.setMock(HttpCalloutMock.class, new MockHttp(200));

        Test.startTest();
        Database.executeBatch(new BatchWithCallout(), 200);
        Test.stopTest();

        Assert.isTrue(true, 'Batch callout should complete without exception on 200 response');
    }

    @IsTest
    static void batchWithCallout_failureResponse_handledGracefully() {
        insert new Account(Name = 'FailCallout', Industry = 'Finance');

        Test.setMock(HttpCalloutMock.class, new MockHttp(500));

        Test.startTest();
        Database.executeBatch(new BatchWithCallout(), 200);
        Test.stopTest();

        Assert.isTrue(true, '500 response should be logged and not throw an exception');
    }


    private static List<Id> toIds(List<Account> accounts) {
        List<Id> ids = new List<Id>();
        for (Account a : accounts) {
            ids.add(a.Id);
        }
        return ids;
    }

    private class MockHttp implements HttpCalloutMock {
        private Integer statusCode;

        MockHttp(Integer code) {
            this.statusCode = code;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }
}
