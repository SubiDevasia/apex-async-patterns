/**
 * BatchWithCallout
 *
 * Demonstrates Database.Batchable + Database.AllowsCallouts — making HTTP
 * callouts from within a batch job.
 *
 * Key rules:
 *  - Must implement Database.AllowsCallouts to enable HTTP calls in execute()
 *  - One callout per execute() chunk (bulk payload) — not one per record
 *  - Callouts are NOT allowed in start() or finish()
 *  - Cannot be chained with another batch that also does callouts in the same transaction
 *
 */
public class BatchWithCallout implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Phone, Industry
            FROM Account
            WHERE Industry != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExternalCRM/api/v1/accounts/bulk');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(buildBulkPayload(scope));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200) {
            System.debug('Bulk sync succeeded for ' + scope.size() + ' records'
                + ' | JobId: ' + bc.getJobId());
        } else {
            System.debug(LoggingLevel.ERROR,
                'Bulk sync failed [' + res.getStatusCode() + ']'
                + ' | Records: ' + scope.size()
                + ' | Body: ' + res.getBody());
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('BatchWithCallout finished. JobId: ' + bc.getJobId());
    }

    private static String buildBulkPayload(List<Account> accounts) {
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        for (Account acc : accounts) {
            records.add(new Map<String, Object>{
                'salesforceId' => acc.Id,
                'name'         => acc.Name,
                'phone'        => acc.Phone,
                'industry'     => acc.Industry
            });
        }
        return JSON.serialize(records);
    }
}
