/**
 * StatefulAccountBatch
 *
 * Demonstrates Database.Stateful — preserves instance variable values
 * across all execute() chunks so you can accumulate totals and errors.
 *
 * With Database.Stateful:
 *  - Instance variables survive across chunks
 *  - Useful for: record counts, error logs, running totals, summary emails
 *  - Trade-off: slightly slower serialisation between chunks
 *
 * Usage:
 *   Database.executeBatch(new StatefulAccountBatch(), 200);
 */
public class StatefulAccountBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Integer totalProcessed = 0;
    private Integer totalErrors    = 0;
    private List<String> errorLog  = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, AnnualRevenue
            FROM Account
            WHERE AnnualRevenue = null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Account> toUpdate = new List<Account>();

        for (Account acc : scope) {
            acc.AnnualRevenue = 50000;
            toUpdate.add(acc);
        }

        List<Database.SaveResult> results = Database.update(toUpdate, false);

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                totalProcessed++;
            } else {
                totalErrors++;
                errorLog.add(toUpdate[i].Name + ': ' + results[i].getErrors()[0].getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('StatefulAccountBatch finished.'
            + ' | Processed: ' + totalProcessed
            + ' | Errors: '    + totalErrors);

        if (!errorLog.isEmpty()) {
            System.debug('Error log:\n' + String.join(errorLog, '\n'));
        }
    }
}
