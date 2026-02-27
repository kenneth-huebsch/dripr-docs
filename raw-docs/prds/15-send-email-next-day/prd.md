# Product Requirements Document: Send Email Next Day for First-Time Campaigns

## Overview
This feature implements a "next-day send" delay for emails created from first-time campaigns. This gives new users a chance to review and refine their campaigns before emails are sent to their clients, reducing the risk of sending incorrect or unpolished emails.

## Background
Currently, when a campaign is created and enabled, the system immediately:
1. Fetches data for the campaign
2. Creates the email
3. Sends the email (if `check_before_sending=0`) or waits for approval (if `check_before_sending=1`)

This can be problematic for new users who are still learning the system and may create campaigns with errors or incomplete information. Also, we plan to make check_before_sending=0 the default value.

## Goals
- **Primary Goal**: Prevent immediate email sends for first-time campaigns, giving users at least one day to review and refine their campaigns
- **Secondary Goal**: Maintain existing approval workflow while adding next-day delay enforcement
- **Tertiary Goal**: Ensure subsequent emails from the same campaign follow normal scheduling (no delay)

## User Stories

### Story 1: First-Time Campaign with Manual Approval
**As a** new user  
**I want** my first campaign email to be delayed until the next day even if I approve it immediately  
**So that** I have time to review and refine my campaign before it's sent to my client

**Acceptance Criteria:**
- When a campaign is created for the first time (`last_sent_email_datetime IS NULL`)
- And `check_before_sending == 1` (manual approval required)
- The email is created immediately
- But the email cannot be sent until at least 24 hours after campaign creation
- Even if the user approves the email immediately, it waits until the next day
- If the user doesn't approve within 24 hours, the email still waits for approval AND the 24-hour delay

### Story 2: First-Time Campaign without Manual Approval
**As a** new user  
**I want** my first campaign email to be automatically sent the next day  
**So that** I have time to review my campaign before it's automatically sent

**Acceptance Criteria:**
- When a campaign is created for the first time (`last_sent_email_datetime IS NULL`)
- And `check_before_sending == 0` (no manual approval)
- The email is created immediately
- But the email is automatically sent only after 24 hours have passed since campaign creation
- The system waits until the next day before sending

### Story 3: Subsequent Campaign Emails
**As a** user with an existing campaign  
**I want** subsequent emails from my campaign to follow normal scheduling  
**So that** my recurring campaigns work as expected

**Acceptance Criteria:**
- When a campaign has sent emails before (`last_sent_email_datetime IS NOT NULL`)
- The next-day delay does NOT apply
- Emails follow normal scheduling based on `every_n_months` and approval status
- Manual approval emails send immediately upon approval (if approved after the scheduled time)
- Auto-send emails send immediately when ready (if past the scheduled time)

## Functional Requirements

### FR1: First-Time Campaign Detection
- **Requirement**: The system must identify first-time campaigns
- **Definition**: A campaign is considered "first-time" if `Campaign.last_sent_email_datetime IS NULL` (meaning no email has ever been sent)
- **Implementation Note**: This check should occur when determining if an email is ready to send

### FR2: Next-Day Delay Calculation
- **Requirement**: For first-time campaigns, emails must wait at least 24 hours after campaign creation before sending
- **Calculation**: `campaign.creation_datetime + 24 hours <= current_datetime`
- **Timezone**: All datetime comparisons must use UTC
- **Precision**: The delay is exactly 24 hours from campaign creation time. The actual send time may be later if the email sender worker only runs during working hours (16:00-23:00 UTC), which is acceptable.

### FR3: Email Creation Behavior (Unchanged)
- **Requirement**: Email creation should happen immediately when campaign is ready
- **Behavior**: 
  - Data fetching happens immediately
  - Email creation happens immediately after data is fetched
  - Email status is set based on `check_before_sending`:
    - If `check_before_sending == 1`: `Email.approved = 0`, `Campaign.campaign_status = WAITING_FOR_MANUAL_APPROVAL`
    - If `check_before_sending == 0`: `Email.approved = 1`, `Campaign.campaign_status = READY_TO_SEND_EMAIL`

### FR4: Email Sending Behavior - Manual Approval
- **Requirement**: For first-time campaigns with `check_before_sending == 1`:
  - Email must be approved (`Email.approved == 1`) AND
  - At least 24 hours must have passed since campaign creation
- **Behavior**:
  - If user approves before 24 hours: Email waits until 24 hours have passed, then becomes eligible for sending during the next working hours window
  - If user approves after 24 hours: Email becomes eligible immediately, but will only send when the email_manager worker runs during working hours (16:00-23:00 UTC)
  - If user never approves: Email never sends (existing behavior)
  - **Working Hours**: The email_manager thread only runs during working hours, so the actual send may occur after the 24-hour mark if it falls outside working hours - this is acceptable

### FR5: Email Sending Behavior - Auto-Send
- **Requirement**: For first-time campaigns with `check_before_sending == 0`:
  - Email must wait until at least 24 hours have passed since campaign creation
  - Then email becomes eligible for automatic sending (subject to normal sending constraints)
- **Behavior**:
  - Email is created with `Email.approved == 1`
  - Email status is `READY_TO_SEND_EMAIL`
  - But email is not eligible for sending until 24 hours after campaign creation
  - Once 24 hours have passed, email becomes eligible and will be picked up by the email_manager worker during the next working hours window (16:00-23:00 UTC)
  - **Working Hours**: The email_manager thread only runs during working hours, so the actual send may occur after the 24-hour mark if it falls outside working hours - this is acceptable

### FR6: Subsequent Campaign Emails
- **Requirement**: For campaigns that have sent emails before (`last_sent_email_datetime IS NOT NULL`):
  - Next-day delay does NOT apply (per-campaign basis)
  - Normal scheduling rules apply:
    - Emails are scheduled based on `last_sent_email_datetime + every_n_months`
    - Manual approval emails send immediately upon approval (if past scheduled time)
    - Auto-send emails send immediately when ready (if past scheduled time)
- **Note**: This is per-campaign, not per-user. Each individual campaign gets one "first-time" delay on its first email only.

### FR7: Database Query Modification
- **Requirement**: The `get_email_ready_to_send()` query must be updated to exclude first-time campaign emails that haven't waited 24 hours
- **Current Query**: `Email.status == READY_TO_SEND_EMAIL AND Email.approved == 1`
- **New Query**: Add condition: `AND (Campaign.last_sent_email_datetime IS NOT NULL OR Campaign.creation_datetime <= UTC_TIMESTAMP() - INTERVAL 1 DAY)`
- **Note**: This ensures only emails from non-first-time campaigns OR first-time campaigns that have waited 24 hours are eligible

## Technical Requirements

### TR1: Database Schema
- **Schema change required**: Make `Campaign.last_sent_email_datetime` nullable
- **Migration needed**: 
  - Convert existing `datetime.min` values to NULL
  - Update model default from `datetime.datetime.min` to `None`
  - Make column nullable: `Column(DateTime, nullable=True, default=None)`
- **Use existing fields**:
  - `Campaign.creation_datetime` - to determine when campaign was created
  - `Campaign.last_sent_email_datetime` - to determine if campaign is first-time (NULL means never sent)
  - `Email.approved` - existing approval flag
  - `Email.status` - existing status field

### TR2: Query Modification
- **File**: `python/shared_resources/db_client.py`
- **Function**: `get_email_ready_to_send()`
- **Change**: Add JOIN to Campaign table and add condition to exclude first-time campaigns that haven't waited 24 hours
- **SQL Logic**: 
  ```sql
  WHERE Email.status == READY_TO_SEND_EMAIL 
    AND Email.approved == 1
    AND (
      Campaign.last_sent_email_datetime IS NOT NULL 
      OR Campaign.creation_datetime <= UTC_TIMESTAMP() - INTERVAL 1 DAY
    )
  ```
- **Note**: Using `IS NOT NULL` is cleaner and more semantically correct than comparing to `datetime.min`
- **Dev/Staging Override**: Use environment variable `FIRST_TIME_CAMPAIGN_DELAY_HOURS` to configure delay duration:
  - Production: `FIRST_TIME_CAMPAIGN_DELAY_HOURS=24` (default)
  - Staging/Dev: `FIRST_TIME_CAMPAIGN_DELAY_HOURS=0` (no delay for testing)
  - Custom: `FIRST_TIME_CAMPAIGN_DELAY_HOURS=1` (1 hour delay for faster testing)
  - If not set, defaults to 24 hours

### TR3: Email Approval Logic
- **File**: `python/shared_resources/db_client.py`
- **Function**: `approve_email_by_email_id()`
- **Change**: No changes required - approval just sets `Email.approved = 1`
- **Note**: The delay enforcement happens in the query, not in the approval function

### TR4: Email Creation Logic
- **File**: `python/email_manager/email_manager.py`
- **Function**: `build_email()` and `poll_db_for_campaigns_ready_to_create_email()`
- **Change**: No changes required - emails are created immediately as before
- **Note**: The delay enforcement happens when querying for emails ready to send

### TR5: Campaign Status Updates
- **File**: `python/email_manager/email_manager.py`
- **Function**: `poll_db_for_emails_ready_to_send()`
- **Change**: No changes required - when email is sent, `last_sent_email_datetime` is updated, making subsequent emails non-first-time

## Edge Cases

### EC1: Campaign Created Near Midnight UTC
- **Scenario**: Campaign created at 23:30 UTC, email should be eligible at 00:30 UTC next day
- **Handling**: Use `INTERVAL 1 DAY` which handles day boundaries correctly

### EC2: Campaign Disabled and Re-enabled
- **Scenario**: User creates campaign, disables it before email is sent, then re-enables it
- **Handling**: If `last_sent_email_datetime IS NULL`, it's still a first-time campaign and delay applies

### EC3: Multiple Emails Created Before First Send
- **Scenario**: User creates campaign, email is created, user edits campaign, new email is created before first email is sent
- **Handling**: All emails from first-time campaigns are subject to the delay. Once ANY email is sent, `last_sent_email_datetime` is updated and subsequent emails are not delayed. This applies per-campaign, not per-user.

### EC4: Campaign Edit After 24 Hours
- **Scenario**: User creates campaign, waits 25 hours, then edits the campaign (which may create a new email)
- **Handling**: If `last_sent_email_datetime IS NULL` (no email has been sent yet), the new email is still subject to the 24-hour delay from the original campaign creation time. Only campaigns that have never sent an email get the delay.

### EC5: Campaign Created via Bulk Upload
- **Scenario**: User bulk uploads multiple campaigns
- **Handling**: Each campaign is evaluated independently. Each campaign with `last_sent_email_datetime IS NULL` gets the delay.

### EC6: Timezone Considerations
- **Scenario**: User in different timezone creates campaign
- **Handling**: All datetime comparisons use UTC. The "next day" is based on UTC, not user's local timezone.

## UI Requirements

### UR1: Email Scheduled Send Date Display
- **Requirement**: Users must be notified when their email will be sent
- **Implementation**: 
  - Show campaign status as normal (`WAITING_FOR_MANUAL_APPROVAL` or `READY_TO_SEND_EMAIL`)
  - Add a visual indicator (tooltip, badge, or info icon) showing "Scheduled to send on [date/time]"
  - Calculate scheduled send date as: `campaign.creation_datetime + 24 hours` (rounded to next working hours window if applicable)
  - Display should be clear and non-intrusive

### UR2: First-Time Campaign Indicator
- **Requirement**: Users should understand why their email is delayed
- **Implementation**:
  - Show indicator only for campaigns where `last_sent_email_datetime IS NULL` AND `campaign.creation_datetime + 24 hours > current_datetime`
  - Message: "This is your first email for this campaign. It will be sent 24 hours after campaign creation to give you time to review."
  - Display in campaign details page and email table

### UR3: Scheduled Send Time Calculation
- **Requirement**: Show accurate scheduled send time
- **Implementation**:
  - Calculate: `campaign.creation_datetime + 24 hours`
  - If the calculated time falls outside working hours (16:00-23:00 UTC), show the next working hours window start time
  - Format: Display in user-friendly format (e.g., "Jan 15, 2024 at 4:00 PM UTC" or convert to user's local timezone)

## Success Metrics
- **Primary Metric**: Percentage of first-time campaigns that send emails within 24 hours (should be 0%)
- **Secondary Metric**: User feedback on whether the delay helped them refine campaigns
- **Tertiary Metric**: Reduction in support tickets related to incorrect emails from new users
- **UI Metric**: User engagement with scheduled send date indicator (clicks, views)

## Implementation Notes

### Phase 1: Database Migration
1. Create Alembic migration to:
   - Make `Campaign.last_sent_email_datetime` nullable
   - Convert existing `datetime.min` values to NULL
   - Update any indexes if needed
2. Update `Campaign` model to use `default=None` instead of `default=datetime.datetime.min`
3. Test migration on development database

### Phase 2: Backend Implementation
1. Add environment variable support:
   - Read `FIRST_TIME_CAMPAIGN_DELAY_HOURS` from environment (default: 24)
   - Use this value in query calculation instead of hardcoded 24 hours
   - Log the configured delay duration on startup
2. Modify `get_email_ready_to_send()` query to exclude first-time campaigns that haven't waited the configured delay
3. Add JOIN to Campaign table in the query
4. Update query to use `INTERVAL {delay_hours} HOUR` instead of `INTERVAL 1 DAY` for flexibility
5. Update any code that checks `last_sent_email_datetime == datetime.min` to use `IS NULL` instead
6. Ensure `calculate_next_send_datetime()` handles NULL correctly (should already work with existing `if last_sent_email_datetime else creation_datetime` pattern)
7. Test with both manual approval and auto-send scenarios
8. Verify working hours integration (emails become eligible after delay, but only send during working hours)
9. Test with `FIRST_TIME_CAMPAIGN_DELAY_HOURS=0` to verify dev override works

### Phase 3: Testing
1. Unit tests for query logic (NULL handling)
2. Integration tests for first-time campaign scenarios
3. Edge case testing (midnight boundaries, timezone handling, working hours boundaries)
4. Test that emails become eligible exactly after configured delay (24 hours in production, configurable in dev)
5. Test that emails wait for working hours if delay mark falls outside window
6. Test migration: verify existing campaigns with `datetime.min` are converted to NULL
7. Test ORDER BY behavior with NULL values (ensure NULL campaigns sort correctly)
8. Test environment variable override: verify `FIRST_TIME_CAMPAIGN_DELAY_HOURS=0` disables delay

### Phase 4: UI Implementation
1. Add API endpoint or extend existing endpoint to return scheduled send date/time for campaigns
2. Add indicator component for delayed emails in campaign details page
3. Show scheduled send date/time in email table
4. Add tooltip/info message explaining the delay for first-time campaigns
5. Update campaign status display to show scheduled send time

## Dev/Staging Configuration

### Testing Workaround
For development and staging environments, use the `FIRST_TIME_CAMPAIGN_DELAY_HOURS` environment variable to reduce or eliminate the delay:

**Recommended Settings:**
- **Production**: `FIRST_TIME_CAMPAIGN_DELAY_HOURS=24` (or omit, defaults to 24)
- **Staging**: `FIRST_TIME_CAMPAIGN_DELAY_HOURS=0` (no delay for testing)
- **Local Dev**: `FIRST_TIME_CAMPAIGN_DELAY_HOURS=0` (no delay for rapid iteration)
- **Integration Testing**: `FIRST_TIME_CAMPAIGN_DELAY_HOURS=1` (1 hour delay for faster but realistic testing)

**Implementation:**
- Read environment variable at startup in `email_manager.py` (similar to `ONLY_SEND_EMAILS_DURING_WORKING_HOURS`)
- Use `INTERVAL {delay_hours} HOUR` in SQL query instead of hardcoded `INTERVAL 1 DAY`
- Log the configured delay on startup: `Logger.logger.info(f"First-time campaign delay: {delay_hours} hours")`
- Default to 24 hours if environment variable is not set

**Example `.env` file entries:**
```bash
# Production
FIRST_TIME_CAMPAIGN_DELAY_HOURS=24

# Staging/Dev
FIRST_TIME_CAMPAIGN_DELAY_HOURS=0
```

## Dependencies
- No new dependencies required
- Requires database migration (Alembic)
- Compatible with existing email sending infrastructure
- Existing code patterns already handle NULL correctly (`if last_sent_email_datetime else creation_datetime`)
- Environment variable configuration (similar to `ONLY_SEND_EMAILS_DURING_WORKING_HOURS`)

## Risks
- **Low Risk**: Query modification is straightforward
- **Low Risk**: Schema change is simple (making column nullable)
- **Low Risk**: Migration is straightforward (convert `datetime.min` to NULL)
- **Low Risk**: Existing code already handles NULL correctly (`if last_sent_email_datetime else creation_datetime`)
- **Medium Risk**: Need to ensure timezone handling is correct
- **Low Risk**: Need to verify ORDER BY behavior with NULL values (NULLs typically sort first in ASC order)
- **Low Risk**: Backward compatible - existing campaigns that have sent emails are unaffected
- **Low Risk**: Environment variable override ensures dev/staging testing is practical

## Timeline Estimate
- **Database Migration**: 1-2 hours
- **Backend Implementation**: 2-4 hours
- **Testing**: 2-3 hours
- **UI Implementation**: 3-5 hours
- **Total**: 8-14 hours
