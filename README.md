# apex-async-patterns

A reference implementation of every major Apex asynchronous pattern in Salesforce. Each module is self-contained, fully tested, and deployed-verified against a real org.

---

## Patterns Covered

| # | Pattern | Interface / Annotation | Best For |
|---|---------|----------------------|----------|
| 1 | [@future](#1-future-methods) | `@future` | Fire-and-forget, small async tasks |
| 2 | [Queueable](#2-queueable-apex) | `implements Queueable` | Chaining, complex types, job tracking |
| 3 | [Batch](#3-batch-apex) | `implements Database.Batchable` | Millions of records, bulk processing |
| 4 | [Schedulable](#4-schedulable-apex) | `implements Schedulable` | Recurring jobs on a cron schedule |
| 5 | [Platform Events](#5-platform-events) | `EventBus.publish()` | Event-driven, decoupled architecture |

---

## Folder Structure

```
force-app/main/default/
├── classes/
│   ├── FutureDemo.cls                  # @future — Account rating, Contact flagging
│   ├── FutureCalloutDemo.cls           # @future(callout=true) — HTTP POST/DELETE
│   ├── FutureDemoTest.cls
│   ├── BasicQueueableJob.cls           # Queueable — flag contacts with no email
│   ├── ChainedQueueableJob.cls         # Queueable — self-chaining in 200-record chunks
│   ├── QueueableCalloutJob.cls         # Queueable + Database.AllowsCallouts
│   ├── QueueableJobTest.cls
│   ├── AccountProcessorBatch.cls       # Batchable — bulk Account rating update
│   ├── StatefulAccountBatch.cls        # Batchable + Database.Stateful
│   ├── BatchWithCallout.cls            # Batchable + Database.AllowsCallouts
│   ├── BatchApexTest.cls
│   ├── NightlyAccountProcessor.cls     # Schedulable — wraps AccountProcessorBatch
│   ├── SchedulableTest.cls
│   ├── PlatformEventPublisher.cls      # EventBus.publish() single + bulk
│   └── PlatformEventTest.cls
├── objects/
│   └── AsyncJob__e/                    # Platform Event (HighVolume)
│       └── fields/
│           ├── JobType__c.field-meta.xml
│           ├── RecordId__c.field-meta.xml
│           ├── Status__c.field-meta.xml
│           └── Message__c.field-meta.xml
├── triggers/
│   └── AsyncJobEventTrigger.trigger    # Subscribes to AsyncJob__e
├── externalCredentials/
│   └── ExternalCRM.externalCredential-meta.xml
└── namedCredentials/
    └── ExternalCRM.namedCredential-meta.xml
```

---

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) `sf` v2+
- An authenticated Salesforce org (`sf org login web`)
- Node.js (for ESLint/Prettier tooling)

---

## Setup

### 1. Clone and install

```bash
git clone https://github.com/<your-username>/apex-async-patterns.git
cd apex-async-patterns
npm install
```

### 2. Authorize your org

```bash
sf org login web --alias my-org --set-default
```

### 3. Create Named Credential (required for callout patterns)

In **Setup → Named Credentials → External Credentials**, create:

| Field | Value |
|---|---|
| Label | `ExternalCRM` |
| Name | `ExternalCRM` |
| Authentication Protocol | `No Authentication` |

Then in **Named Credentials**, create:

| Field | Value |
|---|---|
| Label | `ExternalCRM` |
| Name | `ExternalCRM` |
| URL | `https://api.externalcrm.example.com` |
| External Credential | `ExternalCRM` |
| Enabled for Callouts | ✅ |

---

## Deploy

### Deploy all patterns at once

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org my-org \
  --test-level RunLocalTests \
  --wait 10
```

### Deploy a single module

```bash
# Module 1 — @future
sf project deploy start \
  --source-dir force-app/main/default/classes \
  --target-org my-org \
  --test-level RunSpecifiedTests \
  --tests FutureDemoTest \
  --wait 10
```

---

## Pattern Reference

### 1. @future Methods

Run a method asynchronously in a separate transaction. Simplest async pattern.

**Key limits**
- Parameters must be primitives or collections of primitives (no SObjects)
- Max 50 `@future` calls per transaction
- Cannot call `@future` from another `@future` or batch context
- Add `callout=true` to allow HTTP calls

**Files:** `FutureDemo.cls`, `FutureCalloutDemo.cls`

```apex
// Basic @future
FutureDemo.updateAccountRating(new List<Id>{ accountId });

// @future with HTTP callout
FutureCalloutDemo.syncAccountToExternalCRM(accountId);
```

---

### 2. Queueable Apex

More powerful than `@future` — supports complex types, returns a job Id, and can chain.

**Key limits**
- Max 50 jobs enqueued per transaction
- Only ONE child job can be chained per `execute()`
- Implement `Database.AllowsCallouts` for HTTP calls
- Chaining blocked inside test context

**Files:** `BasicQueueableJob.cls`, `ChainedQueueableJob.cls`, `QueueableCalloutJob.cls`

```apex
// Enqueue a basic job
Id jobId = System.enqueueJob(new BasicQueueableJob(contactIds));

// Self-chaining across large datasets
System.enqueueJob(new ChainedQueueableJob(allAccountIds));

// Queueable with HTTP callout
System.enqueueJob(new QueueableCalloutJob(accountId));
```

---

### 3. Batch Apex

Process millions of records in chunks, each with its own governor limit reset.

**Key limits**
- Default chunk size: 200 records (max: 2000)
- Max 5 concurrent batch jobs per org
- Use `Database.Stateful` to preserve state across chunks
- Use `Database.AllowsCallouts` for HTTP — one callout per `execute()` chunk

**Files:** `AccountProcessorBatch.cls`, `StatefulAccountBatch.cls`, `BatchWithCallout.cls`

```apex
// Standard batch
Database.executeBatch(new AccountProcessorBatch('Technology'), 200);

// Stateful batch — tracks counts across chunks
Database.executeBatch(new StatefulAccountBatch(), 200);

// Batch with HTTP callout
Database.executeBatch(new BatchWithCallout(), 200);
```

---

### 4. Schedulable Apex

Run Apex on a cron schedule. Most commonly used to kick off a batch job.

**Key limits**
- Max 100 scheduled jobs per org
- Cron format: `Seconds Minutes Hours Day Month DayOfWeek Year`

**Files:** `NightlyAccountProcessor.cls`

```apex
// Schedule via helper
NightlyAccountProcessor.scheduleNightly();

// Schedule a custom industry/time
NightlyAccountProcessor.scheduleForIndustry(
    'Finance Nightly',
    '0 0 3 * * ?',
    'Finance'
);

// Abort a scheduled job
NightlyAccountProcessor.abortSchedule(cronTriggerId);
```

**Common cron expressions**

| Expression | Meaning |
|---|---|
| `0 0 2 * * ?` | Every day at 2:00 AM |
| `0 0 2 ? * MON` | Every Monday at 2:00 AM |
| `0 0 1 1 * ? *` | 1st of every month at 1:00 AM |

---

### 5. Platform Events

Publish-subscribe event bus. Publisher and subscriber are fully decoupled.

**Key limits**
- `EventBus.publish()` counts as DML (max 150 per transaction)
- Events are only delivered if the publishing transaction commits
- Platform Event triggers only support `after insert`
- HighVolume events are not stored in Salesforce — use Standard Volume for replay

**Files:** `PlatformEventPublisher.cls`, `AsyncJobEventTrigger.trigger`, `AsyncJob__e` object

```apex
// Publish a single event
PlatformEventPublisher.publishJobEvent(
    'BatchJob',
    accountId,
    'Failed',
    'Batch timed out after 10 minutes'
);

// Publish in bulk
List<AsyncJob__e> events = new List<AsyncJob__e>{
    new AsyncJob__e(JobType__c = 'QueueableJob', Status__c = 'Success', RecordId__c = accId)
};
PlatformEventPublisher.publishBulkJobEvents(events);
```

**AsyncJob__e fields**

| Field | Type | Purpose |
|---|---|---|
| `JobType__c` | Text(50) | Type of async job |
| `RecordId__c` | Text(18) | Related Salesforce record Id |
| `Status__c` | Text(20) | `Success`, `Failed`, `Processing` |
| `Message__c` | Text(255) | Detail or error message |

---

## Running Tests

```bash
# Run all tests
sf apex run test \
  --target-org my-org \
  --test-level RunLocalTests \
  --wait 10 \
  --result-format human

# Run a specific test class
sf apex run test \
  --target-org my-org \
  --class-names FutureDemoTest \
  --wait 10
```

**Test coverage summary**

| Test Class | Tests | Covers |
|---|---|---|
| `FutureDemoTest` | 7 | `FutureDemo`, `FutureCalloutDemo` |
| `QueueableJobTest` | 7 | `BasicQueueableJob`, `ChainedQueueableJob`, `QueueableCalloutJob` |
| `BatchApexTest` | 6 | `AccountProcessorBatch`, `StatefulAccountBatch`, `BatchWithCallout` |
| `SchedulableTest` | 4 | `NightlyAccountProcessor` |
| `PlatformEventTest` | 6 | `PlatformEventPublisher`, `AsyncJobEventTrigger` |
| **Total** | **30** | |

---

## Choosing the Right Pattern

```
Need to run something async?
│
├── Small task, no chaining needed?
│   └── @future
│
├── Need job Id, complex types, or chaining?
│   └── Queueable
│
├── Processing large datasets (thousands+)?
│   └── Batch Apex
│       ├── Need running totals across chunks? → + Database.Stateful
│       └── Need HTTP callouts?               → + Database.AllowsCallouts
│
├── Need to run on a schedule (nightly, weekly)?
│   └── Schedulable (usually wraps Batch)
│
└── Need decoupled publish/subscribe across systems?
    └── Platform Events
```

---

## License

MIT
