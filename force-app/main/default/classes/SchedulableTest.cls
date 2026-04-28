/**
 * SchedulableTest
 *
 * Test coverage for NightlyAccountProcessor (Schedulable).
 *
 * Key testing rules for Schedulable:
 *  - Use Test.startTest() / System.schedule() / Test.stopTest()
 *  - Test.stopTest() executes the scheduled job synchronously
 *  - The scheduled job in turn calls Database.executeBatch() — both run within stopTest()
 *  - Verify the downstream effect (batch result) not just that scheduling succeeded
 *  - Always abort scheduled jobs in tests to avoid leaving orphan CronTrigger records
 */
@IsTest
private class SchedulableTest {

    @IsTest
    static void schedule_executesAccountProcessorBatch() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'SchedHot',  Industry = 'Technology', AnnualRevenue = 2000000),
            new Account(Name = 'SchedCold', Industry = 'Technology', AnnualRevenue = 500)
        };
        insert accounts;

        Test.startTest();
        String jobId = System.schedule(
            'Test Nightly Processor',
            '0 0 2 * * ?',
            new NightlyAccountProcessor('Technology')
        );
        Test.stopTest();

        Map<String, String> ratingByName = new Map<String, String>();
        for (Account a : [SELECT Name, Rating FROM Account WHERE Id IN :toIds(accounts)]) {
            ratingByName.put(a.Name, a.Rating);
        }

        Assert.areEqual('Hot',  ratingByName.get('SchedHot'),  'High revenue account should be Hot');
        Assert.areEqual('Cold', ratingByName.get('SchedCold'), 'Low revenue account should be Cold');
    }

    @IsTest
    static void scheduleNightly_registersJob() {
        Test.startTest();
        String cronTriggerId = NightlyAccountProcessor.scheduleNightly();
        Test.stopTest();

        Assert.isNotNull(cronTriggerId, 'scheduleNightly() should return a valid CronTrigger Id');

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :cronTriggerId
        ];
        Assert.areEqual(1, jobs.size(), 'Scheduled job should exist in CronTrigger');
        Assert.areEqual('Nightly Account Processor', jobs[0].CronJobDetail.Name);
    }

    @IsTest
    static void scheduleForIndustry_registersJobWithCorrectName() {
        Test.startTest();
        String cronTriggerId = NightlyAccountProcessor.scheduleForIndustry(
            'Finance Processor',
            '0 0 3 * * ?',
            'Finance'
        );
        Test.stopTest();

        Assert.isNotNull(cronTriggerId, 'scheduleForIndustry() should return a CronTrigger Id');

        CronTrigger job = [
            SELECT CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :cronTriggerId
        ];
        Assert.areEqual('Finance Processor', job.CronJobDetail.Name);
    }

    @IsTest
    static void abortSchedule_removesJob() {
        String cronTriggerId = System.schedule(
            'Abort Test Job',
            '0 0 4 * * ?',
            new NightlyAccountProcessor()
        );

        Test.startTest();
        NightlyAccountProcessor.abortSchedule(cronTriggerId);
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger WHERE Id = :cronTriggerId
        ];
        Assert.areEqual(0, jobs.size(), 'Aborted job should no longer exist in CronTrigger');
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static List<Id> toIds(List<Account> accounts) {
        List<Id> ids = new List<Id>();
        for (Account a : accounts) {
            ids.add(a.Id);
        }
        return ids;
    }
}
