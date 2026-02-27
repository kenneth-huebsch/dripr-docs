# Restart Stuck Campaigns - Product Requirements Document

**Status:** Not Started

**Existing File:** `python/cron_jobs/restart_stuck_campaigns.py` (placeholder, contains only `# TODO: Implement this`)

## Overview

Implement an automated mechanism to detect and restart campaigns that are stuck in `ERROR` or stale intermediate states. When a campaign errors out (e.g., data fetching failure, email build failure, Gmail auth failure), both the campaign and its associated email record are left in non-terminal states with no recovery path. This feature resets those campaigns back to `DORMANT` so they can be retried on their next scheduled send cycle, and properly cleans up their orphaned email records.

## Problem Statement

When a campaign encounters an error at any stage of its lifecycle, the system sets `Campaign.campaign_status = ERROR` and halts processing. There is currently **no automated recovery mechanism**, which means:

1. **Errored campaigns never send again** unless manually intervened in the database
2. **Orphaned email records accumulate** in non-terminal states (`WAITING_FOR_DATA` with `delivery_status=NULL`, or `READY`/`ERROR` with `delivery_status=READY_TO_SEND`), and are never cleaned up
3. The `error_campaigns` audit flags these campaigns daily but no automated action is taken
4. The `invalid_email_statuses` audit does not catch orphaned emails because they don't have a terminal `delivery_status`

### Current Error Scenarios

Errors can occur at multiple stages, each leaving the email record in a different state:

| Error Stage | Campaign Status | Email `status` | Email `delivery_status` | Email State Description |
|---|---|---|---|---|
| Data fetching (property, listings, etc.) | `ERROR` | `WAITING_FOR_DATA` | `NULL` | Placeholder created but never populated |
| Email content building | `ERROR` | `WAITING_FOR_DATA` or `READY` | `NULL` or `READY_TO_SEND` | Partially or fully built but campaign errored |
| Email sending (Gmail/Postmark failure) | `ERROR` | `ERROR` | `READY_TO_SEND` | Fully built, send attempt failed |

In all cases, neither the campaign nor the email record is ever automatically cleaned up.

### Related Existing Infrastructure

- **`error_campaigns` audit** (`cron_jobs/audits/error_campaigns.py`): Already detects enabled campaigns stuck in ERROR state and logs warnings. Does not take corrective action.
- **`invalid_email_statuses` audit** (`cron_jobs/audits/invalid_email_statuses.py`): Checks for emails with terminal `delivery_status` but `status != COMPLETE`. Does NOT catch the orphaned emails described above because they lack a terminal `delivery_status`.
- **`emails_should_be_expired` audit** (`cron_jobs/audits/emails_should_be_expired.py`): Checks for unapproved `READY_TO_SEND` emails that should have been expired. Does NOT catch errored or placeholder emails.
- **`expire_pending_emails()`** (`db_client.py`): Only targets `status=READY, delivery_status=READY_TO_SEND, approved=0`. Does NOT clean up errored or placeholder emails.
- **`edit_campaign_to_dormant()`** (`db_client.py`): Resets a campaign to DORMANT and clears `current_email_id`. Currently only called after successful email sending. This is the model for what the restart logic should do to the campaign.

---

## Key Concepts

### What "Restart" Means

Restarting a stuck campaign involves two actions:

1. **Reset the campaign** back to `DORMANT` with all sub-statuses set to `DORMANT`, clear `error_text`, and clear `current_email_id`
2. **Mark the orphaned email as terminal** so it doesn't linger in a non-terminal state

### Choosing a Terminal State for Orphaned Emails

The orphaned email needs to reach a terminal state. There are two options:

**Option A: Use `DeliveryStatus.EXPIRED` + `SubStatus.COMPLETE`**
- Pro: No schema changes required, reuses existing enum values
- Pro: `EXPIRED` already means "this email will never be sent"
- Con: Slightly overloads the meaning of `EXPIRED` (currently means "stale unapproved email", would now also mean "cleaned up after error")

**Option B: Add a new `DeliveryStatus.FAILED`**
- Pro: Semantically distinct from `EXPIRED` - clearly communicates "this email was attempted but failed" or "this email was abandoned due to an error"
- Pro: Better for analytics (can distinguish user-neglect expirations from system failures)
- Con: Requires adding a new enum value (no migration needed since MySQL stores enums as strings)
- Con: Must update the `invalid_email_statuses` audit terminal status list and the delivery status priority system

**Recommendation:** Option B (`FAILED`) is cleaner long-term, but Option A is acceptable if you want to avoid adding a new enum value. The PRD tasks below use Option A for simplicity, but note where Option B would differ.

### Retry vs. Restart

This feature does **not** retry the failed operation. It resets the campaign to `DORMANT` so it will be picked up again on its next natural send cycle (based on `fixed_send_day` and `every_n_months`). The backlog item "If an email fails to build, it should try again the next every_n_months 3 times" is a separate future enhancement that could build on top of this.

### What Should NOT Be Restarted

- **Campaigns with `campaign_status = UNSUBSCRIBED`**: These are intentionally disabled due to bounces, spam complaints, or unsubscribes. Do not restart.
- **Campaigns with `enabled = 0`**: The user has manually disabled these. Do not restart.
- **Campaigns stuck in non-ERROR intermediate states** (e.g., `WAITING_FOR_DATA` for too long): These are a different problem ("stuck campaigns" vs "errored campaigns"). Consider handling these separately with a staleness threshold, but they could be included in this cron job with an age-based check.

---

## Tasks

### Task 1: Implement `restart_stuck_campaigns.py`

**File:** `python/cron_jobs/restart_stuck_campaigns.py`

Create a cron job that:

1. Queries for all campaigns where:
   - `campaign_status = ERROR`
   - `enabled = 1`
2. For each errored campaign:
   - If `current_email_id` is set, look up the email record and mark it as terminal:
     - Set `Email.status = SubStatus.COMPLETE`
     - Set `Email.delivery_status = DeliveryStatus.EXPIRED` (or `FAILED` if Option B)
   - Reset the campaign using the same pattern as `edit_campaign_to_dormant()`:
     - `campaign_status = DORMANT`
     - All sub-statuses (`property_status`, `active_listing_status`, `recent_sale_status`, `local_market_data_status`, `intro_status`, `home_report_analysis_status`, `email_creation_status`) = `DORMANT`
     - `current_email_id = NULL`
     - `error_text = NULL`
   - **Do NOT update `last_sent_email_datetime`** (unlike `edit_campaign_to_dormant()` which sets it to now). The email was never sent, so the send history should not change.
   - **Do NOT update `last_scheduled_send_date`**. This was already set when the placeholder email was created. Leaving it means the next cycle will calculate correctly based on the schedule that was already committed.
3. Log each restart action for monitoring

**Important considerations:**
- Use `with_for_update()` to prevent race conditions with other pollers
- Process each campaign in its own transaction so one failure doesn't roll back all restarts
- This should run as a scheduled cron job (e.g., daily or every few hours)

### Task 2: Handle Orphaned Emails Without `current_email_id`

There's an edge case where `current_email_id` was already cleared or never set, but an orphaned email still exists for that campaign. After restarting the campaign (Task 1), also query for any emails belonging to that campaign that are in non-terminal states:

- `Email.campaign_id = campaign.id`
- `Email.status NOT IN (COMPLETE)` and `Email.delivery_status NOT IN (SENT, DELIVERED, OPENED, BOUNCED, SPAM_COMPLAINT, UNSUBSCRIBED, EXPIRED)`

Mark these as terminal too. This is a safety net.

### Task 3: Consider Handling Stale Intermediate Campaigns

Optionally, also detect campaigns stuck in intermediate states for too long (not just `ERROR`):

- `campaign_status = WAITING_FOR_DATA` for more than X hours (e.g., 24 hours)
- `campaign_status = WAITING_FOR_HOME_ANALYSIS` for more than X hours
- `campaign_status = READY_TO_CREATE_EMAIL` with `email_creation_status != READY` for more than X hours
- `campaign_status = READY_TO_SEND_EMAIL` for more than X hours

These could indicate a lost SQS message or a silent failure. The same restart logic applies. Use `Campaign.creation_datetime` or add a `status_updated_at` timestamp to detect staleness (adding a timestamp field is more reliable but requires a migration).

This task is optional for v1 but recommended for robustness.

### Task 4: Add a `restart_count` Field (Optional)

To support future retry-limiting logic (backlog item: "try again 3 times, then stay in error"), consider adding:

- `Campaign.restart_count` (Integer, default 0)
- Increment on each restart
- If `restart_count >= MAX_RESTARTS` (e.g., 3), do NOT restart - leave in ERROR state for manual review

This is optional for v1 but would make the retry-limit feature trivial to implement later.

### Task 5: Update Audits

After implementation, consider whether the existing audits need updating:

- **`error_campaigns` audit**: Could be reduced to only flag campaigns that have exceeded their restart limit (if Task 4 is implemented), or campaigns that keep erroring repeatedly
- **`invalid_email_statuses` audit**: If Option B (`FAILED`) is chosen, add `DeliveryStatus.FAILED` to the `terminal_statuses` list
- **`emails_should_be_expired` audit**: No changes needed - it specifically targets unapproved `READY_TO_SEND` emails, which is a different concern

### Task 6: Deploy as Scheduled Cron Job

Add the restart job to the cron scheduling infrastructure:

- Recommended frequency: Every 6 hours (frequent enough to recover quickly, infrequent enough to not spam)
- Should run independently from the daily `issue_auditor`
- Log summary: "Restarted X campaign(s)" or "No stuck campaigns found"

---

## Files to Modify

1. `python/cron_jobs/restart_stuck_campaigns.py` - Main implementation (replace TODO placeholder)
2. `python/shared_resources/db_client.py` - Add `restart_errored_campaign()` method (or similar) that handles the campaign reset + email cleanup in a single method
3. `python/shared_resources/models.py` - Add `DeliveryStatus.FAILED` (only if Option B is chosen)
4. `python/cron_jobs/audits/invalid_email_statuses.py` - Add `FAILED` to terminal statuses (only if Option B is chosen)
5. `docs/campaign-state-machine.md` - Document the restart flow and error recovery

---

## Impact Assessment

- **Risk**: Low - restarting to DORMANT is the safest recovery action since it just puts the campaign back in the queue for its next natural cycle
- **Data safety**: No data is deleted. The orphaned email record is preserved with a terminal status for auditing. Campaign data (property data, listings, etc.) from the failed cycle may still exist in the database but will be overwritten on the next cycle.
- **Migration**: None required for Option A. Option B adds a new enum string value which MySQL handles without migration.
- **Testing**: Should verify that restarted campaigns are picked up correctly on their next send cycle, and that orphaned emails are properly marked terminal
