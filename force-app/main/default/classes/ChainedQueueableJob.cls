/**
 * ChainedQueueableJob
 *
 * Demonstrates Queueable chaining — processing a large list of records
 * across multiple async executions by passing remaining Ids to a new job.
 *
 * Why chain instead of looping?
 *  - Each Queueable execution has its own governor limits
 *  - Chaining lets you process millions of records without hitting DML/SOQL limits
 *  - Each link in the chain runs as a separate async transaction
 *
 * Key constraint:
 *  - Only ONE child job can be enqueued per execute() call
 *  - Chaining is blocked inside test context — guarded with Test.isRunningTest()
 *
 * Usage:
 *   List<Id> allIds = new List<Id>{ '001...' }; // can be thousands
 *   System.enqueueJob(new ChainedQueueableJob(allIds));
 */
public class ChainedQueueableJob implements Queueable {

    private List<Id> accountIds;
    private static final Integer CHUNK_SIZE = 200;

    public ChainedQueueableJob(List<Id> accountIds) {
        this.accountIds = accountIds;
    }

    public void execute(QueueableContext ctx) {
        List<Id> currentChunk = slice(accountIds, 0, CHUNK_SIZE);
        List<Id> remaining    = slice(accountIds, CHUNK_SIZE, accountIds.size());

        processChunk(currentChunk);

        System.debug('ChainedQueueableJob — JobId: ' + ctx.getJobId()
            + ' | Processed: ' + currentChunk.size()
            + ' | Remaining: ' + remaining.size());

        if (!remaining.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new ChainedQueueableJob(remaining));
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private void processChunk(List<Id> ids) {
        List<Account> toUpdate = new List<Account>();

        for (Account acc : [
            SELECT Id, Description
            FROM Account
            WHERE Id IN :ids
        ]) {
            acc.Description = 'Processed by ChainedQueueableJob — ' + System.now();
            toUpdate.add(acc);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static List<Id> slice(List<Id> source, Integer fromIdx, Integer toIdx) {
        List<Id> result = new List<Id>();
        Integer boundary = Math.min(toIdx, source.size());
        for (Integer i = fromIdx; i < boundary; i++) {
            result.add(source[i]);
        }
        return result;
    }
}
