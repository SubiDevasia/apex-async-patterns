/**
 * BasicQueueableJob
 *
 * Demonstrates the Queueable interface — the most flexible async pattern.
 * Unlike @future, Queueable:
 *  - Accepts SObject and complex type parameters
 *  - Returns a job Id (AsyncApexJob) for monitoring
 *  - Can be chained (one child job per execution)
 *  - Supports up to 50 enqueued jobs per transaction
 *
 * Usage:
 *   List<Id> ids = new List<Id>{ '003...' };
 *   System.enqueueJob(new BasicQueueableJob(ids));
 */
public class BasicQueueableJob implements Queueable {

    private List<Id> contactIds;

    public BasicQueueableJob(List<Id> contactIds) {
        this.contactIds = contactIds;
    }

    public void execute(QueueableContext ctx) {
        List<Contact> toUpdate = new List<Contact>();

        for (Contact c : [
            SELECT Id, Email, DoNotCall
            FROM Contact
            WHERE Id IN :contactIds
            AND Email = null
            AND DoNotCall = false
        ]) {
            c.DoNotCall = true;
            toUpdate.add(c);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        System.debug('BasicQueueableJob completed. JobId: ' + ctx.getJobId()
            + ' | Updated: ' + toUpdate.size());
    }
}
