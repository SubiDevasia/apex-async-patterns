/**
 * QueueableCalloutJob
 *
 * Demonstrates Queueable + Database.AllowsCallouts — the preferred pattern
 * for making HTTP callouts with full governor limit isolation per execution.
 *
 * Advantages over @future(callout=true):
 *  - Can accept SObject parameters (not just primitives)
 *  - Returns a job Id for tracking
 *  - Can be chained to process multiple records sequentially
 *  - Can be called from a Batch finish() method
 *
 * Usage:
 *   System.enqueueJob(new QueueableCalloutJob(accountId));
 */
public class QueueableCalloutJob implements Queueable, Database.AllowsCallouts {

    private Id accountId;

    public QueueableCalloutJob(Id accountId) {
        this.accountId = accountId;
    }

    public void execute(QueueableContext ctx) {
        Account acc = [
            SELECT Id, Name, Phone, Website, Industry, AnnualRevenue
            FROM Account
            WHERE Id = :accountId
        ];

        HttpResponse res = sendSyncRequest(acc);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            flagAsSynced(acc.Id);
            System.debug('QueueableCalloutJob — synced: ' + acc.Name
                + ' | JobId: ' + ctx.getJobId());
        } else {
            System.debug(LoggingLevel.ERROR,
                'QueueableCalloutJob — sync failed [' + res.getStatusCode() + '] '
                + 'for: ' + acc.Name + ' | Body: ' + res.getBody());
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private HttpResponse sendSyncRequest(Account acc) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExternalCRM/api/v1/accounts/' + acc.Id);
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(buildPayload(acc));
        req.setTimeout(10000);

        return new Http().send(req);
    }

    private void flagAsSynced(Id accId) {
        update new Account(
            Id = accId,
            Description = 'Synced via QueueableCalloutJob on ' + System.now()
        );
    }

    private static String buildPayload(Account acc) {
        return JSON.serialize(new Map<String, Object>{
            'salesforceId'  => acc.Id,
            'name'          => acc.Name,
            'phone'         => acc.Phone,
            'website'       => acc.Website,
            'industry'      => acc.Industry,
            'annualRevenue' => acc.AnnualRevenue
        });
    }
}
