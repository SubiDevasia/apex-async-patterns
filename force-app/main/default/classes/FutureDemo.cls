/**
 * FutureDemo
 *
 * Demonstrates the @future annotation for running logic asynchronously
 * outside of the current transaction.
 *
 */
public class FutureDemo {

    /**
     * Updates Account Rating based on AnnualRevenue.
     * Called asynchronously so the rating derivation does not block
     * the originating transaction.
     *
     * @param accountIds  List of Account Ids to process
     */
    
    @future
    public static void updateAccountRating(List<Id> accountIds) {
        List<Account> accounts = [
            SELECT Id, AnnualRevenue, Rating
            FROM Account
            WHERE Id IN :accountIds
        ];

        List<Account> toUpdate = new List<Account>();

        for (Account acc : accounts) {
            String newRating = deriveRating(acc.AnnualRevenue);
            if (newRating != acc.Rating) {
                acc.Rating = newRating;
                toUpdate.add(acc);
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    /**
     * Marks Contacts as DoNotCall when they have no email address.
     * Demonstrates passing a Set<Id> (converted to List for @future compatibility).
     *
     * @param contactIds  List of Contact Ids to evaluate
     */
    @future
    public static void flagContactsWithNoEmail(List<Id> contactIds) {
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
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static String deriveRating(Decimal annualRevenue) {
        if (annualRevenue == null)    return 'Cold';
        if (annualRevenue >= 1000000) return 'Hot';
        if (annualRevenue >= 100000)  return 'Warm';
        return 'Cold';
    }
}
