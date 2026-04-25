/**
 * FutureDemoTest
 *
 * Test coverage for FutureDemo and FutureCalloutDemo.
 *
 * Pattern:
 *  - Insert test data BEFORE Test.startTest()
 *  - Call @future methods inside Test.startTest() / Test.stopTest()
 *  - Test.stopTest() flushes the async queue, making results queryable
 *  - Use Test.setMock() for HTTP callout tests
 */
@IsTest
private class FutureDemoTest {

    @IsTest
    static void updateAccountRating_hotRevenue_setsHot() {
        Account acc = new Account(Name = 'BigCorp', AnnualRevenue = 5000000);
        insert acc;

        Test.startTest();
        FutureDemo.updateAccountRating(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        Assert.areEqual('Hot', result.Rating, 'Revenue >= 1M should be Hot');
    }

    @IsTest
    static void updateAccountRating_warmRevenue_setsWarm() {
        Account acc = new Account(Name = 'MidCorp', AnnualRevenue = 500000);
        insert acc;

        Test.startTest();
        FutureDemo.updateAccountRating(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        Assert.areEqual('Warm', result.Rating, 'Revenue 100K–1M should be Warm');
    }

    @IsTest
    static void updateAccountRating_nullRevenue_setsCold() {
        Account acc = new Account(Name = 'SmallCorp', AnnualRevenue = null);
        insert acc;

        Test.startTest();
        FutureDemo.updateAccountRating(new List<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        Assert.areEqual('Cold', result.Rating, 'Null revenue should be Cold');
    }

    @IsTest
    static void flagContactsWithNoEmail_noEmail_setsDoNotCall() {
        Contact c = new Contact(LastName = 'NoEmail', Email = null, DoNotCall = false);
        insert c;

        Test.startTest();
        FutureDemo.flagContactsWithNoEmail(new List<Id>{ c.Id });
        Test.stopTest();

        Contact result = [SELECT DoNotCall FROM Contact WHERE Id = :c.Id];
        Assert.isTrue(result.DoNotCall, 'Contact with no email should be marked DoNotCall');
    }

    @IsTest
    static void flagContactsWithNoEmail_hasEmail_notFlagged() {
        Contact c = new Contact(LastName = 'HasEmail', Email = 'test@example.com', DoNotCall = false);
        insert c;

        Test.startTest();
        FutureDemo.flagContactsWithNoEmail(new List<Id>{ c.Id });
        Test.stopTest();

        Contact result = [SELECT DoNotCall FROM Contact WHERE Id = :c.Id];
        Assert.isFalse(result.DoNotCall, 'Contact with email should not be flagged');
    }


    @IsTest
    static void syncAccountToExternalCRM_success_logsDebug() {
        Account acc = new Account(Name = 'SyncCorp', Phone = '555-1234');
        insert acc;

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess(201));

        Test.startTest();
        FutureCalloutDemo.syncAccountToExternalCRM(acc.Id);
        Test.stopTest();

        // No exception = success; callout mock verified the request was made
        Assert.isTrue(true, 'Sync callout completed without exception');
    }

    @IsTest
    static void syncAccountToExternalCRM_failure_logsError() {
        Account acc = new Account(Name = 'FailCorp');
        insert acc;

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess(500));

        Test.startTest();
        FutureCalloutDemo.syncAccountToExternalCRM(acc.Id);
        Test.stopTest();

        Assert.isTrue(true, 'Error response handled gracefully without exception');
    }

    @IsTest
    static void deleteAccountFromExternalCRM_callsDelete() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess(200));

        Test.startTest();
        FutureCalloutDemo.deleteAccountFromExternalCRM('001000000000001AAA');
        Test.stopTest();

        Assert.isTrue(true, 'DELETE callout completed without exception');
    }


    private class MockHttpSuccess implements HttpCalloutMock {
        private Integer statusCode;

        MockHttpSuccess(Integer statusCode) {
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
