/**
 * AccountProcessorBatch
 *
 * Demonstrates the standard Database.Batchable pattern for processing
 * large volumes of records safely within governor limits.
 *
 * Key rules:
 *  - start()   — returns a QueryLocator (up to 50M records) or Iterable
 *  - execute() — called once per chunk (default 200 records, max 2000)
 *  - finish()  — called once after all chunks complete; good for notifications
 *  - Each execute() runs in its own transaction with fresh governor limits
 *  - Max 5 concurrent batch jobs; max 100 queued
 *
 */
public class AccountProcessorBatch implements Database.Batchable<SObject> {

    private String industry;

    public AccountProcessorBatch(String industry) {
        this.industry = industry;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, AnnualRevenue, Rating
            FROM Account
            WHERE Industry = :industry
            AND Rating = null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        for (Account acc : scope) {
            acc.Rating = deriveRating(acc.AnnualRevenue);
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT TotalJobItems, NumberOfErrors, JobItemsProcessed, Status
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];

        System.debug('AccountProcessorBatch finished.'
            + ' | Status: '    + job.Status
            + ' | Chunks: '    + job.TotalJobItems
            + ' | Processed: ' + job.JobItemsProcessed
            + ' | Errors: '    + job.NumberOfErrors);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static String deriveRating(Decimal revenue) {
        if (revenue == null)    return 'Cold';
        if (revenue >= 1000000) return 'Hot';
        if (revenue >= 100000)  return 'Warm';
        return 'Cold';
    }
}
