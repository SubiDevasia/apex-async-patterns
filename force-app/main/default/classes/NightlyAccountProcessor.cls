/**
 * NightlyAccountProcessor
 *
 * Demonstrates the Schedulable interface — running Apex on a cron schedule.
 * This class schedules AccountProcessorBatch to run nightly, showing the
 * common pattern of combining Schedulable + Batch.
 *
 * Key rules:
 *  - Implement execute(SchedulableContext) — called at each scheduled time
 *  - Schedule via System.schedule(name, cronExpression, schedulable)
 *  - Max 100 scheduled jobs per org
 *  - Cron format: Seconds Minutes Hours Day-of-month Month Day-of-week Year
 *
 */
public class NightlyAccountProcessor implements Schedulable {

    private String industry;

    public NightlyAccountProcessor() {
        this.industry = 'Technology';
    }

    public NightlyAccountProcessor(String industry) {
        this.industry = industry;
    }

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new AccountProcessorBatch(industry), 200);

        System.debug('NightlyAccountProcessor triggered.'
            + ' | Industry: ' + industry
            + ' | JobId: '    + ctx.getTriggerId());
    }

    // ── Scheduling helpers ────────────────────────────────────────────────────

    /**
     * Schedules this job to run every day at 2:00 AM.
     * Returns the CronTrigger Id — save it to abort later.
     */
    public static String scheduleNightly() {
        return System.schedule(
            'Nightly Account Processor',
            '0 0 2 * * ?',
            new NightlyAccountProcessor()
        );
    }

    /**
     * Schedules this job for a specific industry on a custom cron.
     *
     * @param jobName    Unique name for the scheduled job
     * @param cronExp    Cron expression
     * @param industry   Industry to pass to AccountProcessorBatch
     */
    public static String scheduleForIndustry(String jobName, String cronExp, String industry) {
        return System.schedule(jobName, cronExp, new NightlyAccountProcessor(industry));
    }

    /**
     * Aborts a scheduled job by CronTrigger Id.
     *
     * @param cronTriggerId  Id returned from System.schedule()
     */
    public static void abortSchedule(String cronTriggerId) {
        System.abortJob(cronTriggerId);
    }
}
