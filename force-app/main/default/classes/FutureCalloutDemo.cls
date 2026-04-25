/**
 * FutureCalloutDemo
 *
 * Demonstrates @future(callout=true) — the only way to make an HTTP callout
 * from a trigger context (where callouts are otherwise prohibited).
 * 
 */
public class FutureCalloutDemo {

    /**
     * POST a single Account record to an external CRM after it is saved.
     * Triggered asynchronously so the originating DML is not blocked by
     * the HTTP round-trip.
     *
     * @param accountId  Id of the Account to sync
     */
    @future(callout=true)
    public static void syncAccountToExternalCRM(Id accountId) {
        Account acc = [
            SELECT Id, Name, Phone, Website, Industry, AnnualRevenue
            FROM Account
            WHERE Id = :accountId
        ];

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExternalCRM/api/v1/accounts');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(buildPayload(acc));
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 201) {
            System.debug('Account synced successfully: ' + acc.Name);
        } else {
            System.debug(LoggingLevel.ERROR,
                'Sync failed [' + res.getStatusCode() + ']: ' + res.getBody());
        }
    }

    /**
     * DELETE a record from the external system when it is removed from Salesforce.
     * Accepts a String id (serialised before deletion) because the SObject
     * cannot be passed to a @future method.
     *
     * @param accountId  Salesforce Id (as String) of the deleted Account
     */
    @future(callout=true)
    public static void deleteAccountFromExternalCRM(String accountId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExternalCRM/api/v1/accounts/' + accountId);
        req.setMethod('DELETE');
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        System.debug('DELETE response [' + res.getStatusCode() + '] for Id: ' + accountId);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static String buildPayload(Account acc) {
        Map<String, Object> payload = new Map<String, Object>{
            'salesforceId'  => acc.Id,
            'name'          => acc.Name,
            'phone'         => acc.Phone,
            'website'       => acc.Website,
            'industry'      => acc.Industry,
            'annualRevenue' => acc.AnnualRevenue
        };
        return JSON.serialize(payload);
    }
}
