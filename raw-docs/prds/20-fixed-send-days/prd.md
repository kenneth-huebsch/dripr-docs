# Fixed Monthly Send Day Feature - Product Requirements Document

**Status:** ✅ Implemented (January 2026)

**Migration File:** `python/migrations/versions/h1i2j3k4l5m6_add_fixed_send_day_columns.py`

## Overview

This feature allows users to specify a fixed day of the month for all subsequent campaign emails to be sent, enabling customers who want predictable monthly email schedules (e.g., "all my emails go out on the 15th of each month").

## Problem Statement

Currently, campaign emails are sent based on `last_sent_email_datetime + every_n_months`, which means the send day varies based on when emails were actually sent. If an email is approved late, the schedule shifts. Some users want all their campaign emails to go out on a consistent day each month (e.g., the 1st, 15th, or last day) for better predictability and alignment with their business processes.

## Key Concepts

### New Fields Introduced
- **`fixed_send_day`** (Campaign): The day of the month (1-31) when subsequent emails should be sent
- **`last_scheduled_send_date`** (Campaign): The date when the last email WAS SUPPOSED to send (not when it actually sent). Used for calculating next send date to ensure late approvals don't shift the schedule.
- **`EXPIRED`** (DeliveryStatus): New enum value for emails that were not approved before the next email was created

### Environment Variables (Existing - No Changes)
- **`FIRST_TIME_CAMPAIGN_DELAY_HOURS`**: Existing delay for first-time campaign emails
- **`ONLY_SEND_EMAILS_DURING_WORKING_HOURS`**: Existing flag for working hours restriction

### Constants (Existing - No Changes)
- **`EMAIL_SEND_START_HOUR_UTC`**: Existing constant (16:00 UTC = 11:00 AM EST) in email_manager - used by working hours logic

---

## User Stories

### Story 1: Default Behavior - Set Send Day to Creation Day
**As a** real estate agent creating a new campaign  
**I want** the system to default the send day to the day of the month I'm creating the campaign  
**So that** future emails will be sent on that same day each month without manual configuration

**Acceptance Criteria:**
- When creating a campaign on June 15th, the system defaults `fixed_send_day` to 15
- When creating a campaign on January 3rd, the system defaults `fixed_send_day` to 3
- If the campaign is being created on day 29-31, the UI shows the field as empty (NULL) and requires the user to select a value 1-28
- This default is set automatically but can be changed before saving

---

### Story 2: Customize Send Day During Creation
**As a** real estate agent creating a new campaign  
**I want** to open the "Campaign Information" dropdown and change the monthly send day  
**So that** I can align all my campaigns to send on my preferred day of the month

**Acceptance Criteria:**
- Campaign Information dropdown includes a "Monthly Send Day" field
- Field shows values 1-28 (dropdown or number input)
- The default value is the day of the month the campaign is being created (or empty if 29-31)
- User can change this to any value between 1-28
- UI does not allow the campaign to be saved with a NULL value in `fixed_send_day`
- This setting is saved with the campaign
- If a campaign was grandfathered in with a (29-31) fixed_start date it is displayed correctly, but when you click edit it goes to NULL and wont save until you update it to a valid value 
---

### Story 3: Edit Send Day After Campaign Creation
**As a** real estate agent managing existing campaigns  
**I want** to edit the monthly send day on an existing campaign  
**So that** I can adjust my schedule without recreating the campaign

**Acceptance Criteria:**
- When viewing/editing campaign details, the "Campaign Information" section shows the current "Monthly Send Day" setting
- User can change this value (1-28)
- Changes apply to the next calculated send date
- The change does not retroactively affect `last_scheduled_send_date` or trigger immediate sends
- The same conditions remain in place for when to allow a campaign edit (existing edit restrictions still apply)
- There should never be an immediate send from editing the `fixed_send_day`

**Next Send Date Calculation After Edit:**
The next send date is calculated as: the next occurrence of the **new** `fixed_send_day` after (`last_scheduled_send_date` + `every_n_months`)

**Examples:**

| Today | every_n_months | Last Scheduled Send | New fixed_send_day | Next Send Date |
|-------|----------------|---------------------|-------------------|----------------|
| 2/14/2026 | 1 | 1/13/2026 | 15 | 2/15/2026 |
| 2/14/2026 | 1 | 1/16/2026 | 15 | 3/15/2026 |

---

### Story 4: First Email Uses Normal Logic
**As a** real estate agent creating a new campaign  
**I want** the first email to use the existing `FIRST_TIME_CAMPAIGN_DELAY_HOURS` delay and approval logic  
**So that** I have time to review before the first send, and subsequent emails follow my fixed schedule

**Acceptance Criteria:**
- First email follows existing logic:
  - `FIRST_TIME_CAMPAIGN_DELAY_HOURS` delay from campaign creation
  - Subject to approval if `check_before_sending == 1`
  - Working hours restriction handled by existing `ONLY_SEND_EMAILS_DURING_WORKING_HOURS` logic (no new code needed)
- When the first email is **created** (not sent):
  - `Campaign.last_scheduled_send_date` is set to the scheduled send datetime
  - `Email.scheduled_send_datetime` is set to the scheduled send datetime
- When the first email is **sent**:
  - `Campaign.last_sent_email_datetime` is updated to the actual send time
- All subsequent emails use the fixed send day logic
- The first email timing does NOT cause an extra month to be skipped for subsequent sends

---

### Story 5: Subsequent Emails Follow Fixed Schedule
**As a** real estate agent with active campaigns  
**I want** subsequent emails to be sent on my specified day of the month  
**So that** my email schedule is predictable and consistent

**Acceptance Criteria:**

**Send Date Calculation Logic (Simplified to 2 Cases):**

| Condition | Calculation |
|-----------|-------------|
| `last_scheduled_send_date` is NULL | `creation_datetime` + `FIRST_TIME_CAMPAIGN_DELAY_HOURS` |
| `last_scheduled_send_date` is NOT NULL | Next occurrence of `fixed_send_day` after (`last_scheduled_send_date` + `every_n_months`), preserving time |

**Implementation Note:** By setting `last_scheduled_send_date` when the first email is **created** (not sent), we eliminate the need for a separate "2nd email" case. The logic simplifies to just 2 branches.

**Key Behaviors:**
- If the calculated month doesn't have the specified day (e.g., Feb 30), use the last valid day of that month
- The schedule is based on `last_scheduled_send_date`, NOT `last_sent_email_datetime`
- Late approvals do not shift the schedule - the next send date remains anchored to when it was SUPPOSED to send
- Subsequent emails preserve the time from previous scheduled send; working hours logic handles actual send timing

---

### Story 6: Emails Sent at Configured Time of Day
**As a** real estate agent with active campaigns  
**I want** emails to be sent at a consistent time of day  
**So that** my email schedule is predictable

**Acceptance Criteria:**

**First Email:**
```
scheduled_time = creation_datetime + FIRST_TIME_CAMPAIGN_DELAY_HOURS
```
The existing `ONLY_SEND_EMAILS_DURING_WORKING_HOURS` logic handles working hours restrictions - no new code needed for first emails.

**Subsequent Emails (2nd+):**
- Scheduled on the calculated `fixed_send_day`, preserving the time from the previous scheduled send
- The existing `ONLY_SEND_EMAILS_DURING_WORKING_HOURS` logic handles working hours restrictions
- Email sending poller ensures emails are sent during working hours (11:00 AM - 6:00 PM EST) when flag is enabled

---

### Story 7: Expiring Old "Waiting for Approval" Emails
**As a** real estate agent with an active campaign that still has an email waiting for approval when the next email should be created  
**I want** the old email to be marked as "EXPIRED"  
**So that** my email schedule remains predictable and I don't have stale emails lingering

**Acceptance Criteria:**
- When the system attempts to create the next email for a campaign, it first checks for any existing emails that are:
  - `Email.status` = `READY` (created but not sent)
  - `Email.delivery_status` = `READY_TO_SEND`
  - `Email.approved` = `0` (waiting for manual approval)
- If found, those emails are marked as:
  - `Email.status` = `DORMANT`
  - `Email.delivery_status` = `EXPIRED` (new enum value)
- I can see the EXPIRED status in the UI with meaningful tooltip text explaining why it expired
- I am unable to approve or send expired emails
- I can still view expired emails in the UI and see their content

---

### Story 8: Late Approvals Do Not Impact Next Send Date
**As a** real estate agent with an active campaign  
**I want** emails to send on `fixed_send_day` regardless of when the previous email was actually sent  
**So that** my email schedule is predictable and consistent

**Acceptance Criteria:**

**Example Scenario:**
- Campaign sends every month on the 15th (`fixed_send_day` = 15, `every_n_months` = 1)
- It is February 14th and the January email is still waiting for approval
- User approves the January email on Feb 14th → it sends
- `last_sent_email_datetime` = Feb 14th
- `last_scheduled_send_date` = Jan 15th (the original scheduled date)
- When Feb 15th comes, another email is generated (based on `last_scheduled_send_date`, not `last_sent_email_datetime`)

---

### Story 9: Editing Fixed Send Day After Previous Sends
**As a** real estate agent with an active campaign where I just changed the `fixed_send_day`  
**I want** the next send date to respect the new schedule without causing emails to send immediately  
**So that** I don't have emails sending out right after each other

**Acceptance Criteria:**
- Next send date = next occurrence of the **new** `fixed_send_day` after (`last_scheduled_send_date` + `every_n_months`)
- There should never be an immediate send from editing `fixed_send_day`
- If the new `fixed_send_day` has already passed in the current period, the send moves to the next period

**Examples:**

**Example 1:**
- Today: 2/14/2026
- `every_n_months`: 1
- `last_scheduled_send_date`: 1/13/2026
- User updates `fixed_send_day` to: 15
- Calculation: next 15 after (1/13 + 1 month = 2/13) → **2/15/2026**

**Example 2:**
- Today: 2/14/2026
- `every_n_months`: 1
- `last_scheduled_send_date`: 1/16/2026
- User updates `fixed_send_day` to: 15
- Calculation: next 15 after (1/16 + 1 month = 2/16) → **3/15/2026**

---

## Functional Requirements

### FR1: Database Schema Changes

**New Column: `fixed_send_day`**
- Table: `campaigns`
- Type: `INTEGER`
- Nullable: `NOT NULL`
- Valid range: 1-31 (API validates 1-31, UI restricts to 1-28)

**New Column: `last_scheduled_send_date`**
- Table: `campaigns`
- Type: `DATETIME`
- Nullable: Yes (NULL until first email is created)
- Purpose: Tracks when the last email WAS SUPPOSED to send, used for next send date calculation
- Updated: When each email is **created** (not when sent)

**New Column: `scheduled_send_datetime`**
- Table: `emails`
- Type: `DATETIME`
- Nullable: Yes (NULL for legacy emails)
- Purpose: Tracks when this specific email was scheduled to send (audit trail)
- Set: When the email is created

**New Enum Value: `EXPIRED`**
- Enum: `DeliveryStatus`
- Purpose: Indicates an email was not approved before the next email was created

**New Enum Value: `COMPLETE`**
- Enum: `SubStatus`
- Purpose: Indicates an email has reached a terminal state (sent, delivered, opened, expired, etc.) with no future actions needed
- Usage: Set on `Email.status` when email reaches any terminal delivery status

**Migration Strategy:**
- For existing campaigns with `last_sent_email_datetime IS NOT NULL`: 
  - Set `fixed_send_day` to the day of `last_sent_email_datetime`
  - Set `last_scheduled_send_date` to `last_sent_email_datetime`
- For existing campaigns with `last_sent_email_datetime IS NULL`:
  - Set `fixed_send_day` to the day of `creation_datetime`
  - Set `last_scheduled_send_date` to NULL
- Values of 29-31 are allowed for migrated campaigns (grandfathered in)

---

### FR2: UI Changes - Campaign Information Dropdown

**Requirement:** Add "Monthly Send Day" field to Campaign Information section

**Field Specifications:**
- **Label:** "Monthly Send Day"
- **Field Type:** Number input or Dropdown
- **Location:** Inside the "Campaign Information" collapsible section in:
  - Campaign creation form (`CreateCampaign.tsx`)
  - Campaign details/edit form (`CampaignDetails.tsx`)
- **Help Text:** "The day of the month (1-28) when future emails will be sent. The first email follows normal scheduling."
- **Validation:**
  - Minimum: 1
  - Maximum: 28
  - Integer only
  - Required field (cannot be empty/NULL)
- **Default Value:** 
  - When creating: Current day of the month (or empty if 29-31)
  - When editing: Existing value

---

### FR3: API Validation

**Create Campaign (`POST /api/campaigns`):**
- Accept `fixed_send_day` from request body
- If not provided, default to day of `creation_datetime`
- Validate range: 1-31 (backend supports full range for future flexibility)
- Return error if value is outside 1-31

**Edit Campaign (`PUT /api/campaigns/{id}`):**
- Accept `fixed_send_day` from request body
- Validate range: 1-31
- Update database
- Do not trigger immediate email creation

**Get Campaign / List Campaigns:**
- Include `fixed_send_day` in response
- Include `last_scheduled_send_date` in response
- Include `next_send_datetime` (calculated) in response

---

### FR4: Expired Email UI

**Requirements:**
- Display "EXPIRED" status with distinctive styling (e.g., gray/muted)
- Show tooltip: "This email expired because it was not approved before the next email was scheduled to be created."
- Hide "Approve" and "Send" buttons for expired emails
- Keep "View" functionality available
- Include in email history list

---

## Non-Functional Requirements

### NFR1: Data Integrity
- `fixed_send_day` values must be validated at API layer (1-31)
- `fixed_send_day` values must be validated at UI layer (1-28)
- Invalid values should be rejected with clear error messages
- Database constraint ensures `fixed_send_day` is always NOT NULL

### NFR2: Schedule Predictability
- Next send date calculation must use `last_scheduled_send_date`, never `last_sent_email_datetime`
- Late approvals must not shift the schedule
- Editing `fixed_send_day` must never cause an immediate send

### NFR3: Testability
- Unit tests for `calculate_next_send_datetime()` with various `fixed_send_day` values
- Unit tests for expiration logic
- Integration tests for API endpoints with `fixed_send_day` parameter
- Edge case tests for month boundary conditions

---

## Edge Cases & Special Scenarios

### EC1: Day Doesn't Exist in Target Month
**Scenario:** `fixed_send_day = 31`, next send month is February (28/29 days)

**Handling:** Use last valid day of month
- February 2026 (non-leap): Use day 28
- February 2024 (leap): Use day 29
- April (30 days): Use day 30

**Implementation:** `actual_day = min(fixed_send_day, last_day_of_month)`

---

### EC2: Campaign Created on Day 29, 30, or 31
**Scenario:** Campaign created on January 31st

**Handling:**
- Frontend defaults to empty (NULL) since 31 > 28
- UI restricts input to max 28
- UI does not allow the campaign to be saved with a NULL value
- User must explicitly select a value 1-28 before saving
- Backend still supports 29-31 for migrated campaigns and future flexibility

**UX Flow:** User creating on Jan 31 sees an empty field and must choose a value 1-28 before saving.

---

### EC3: Missing Fixed Send Day
**Scenario:** Campaign somehow has `fixed_send_day = NULL` in database

**Handling:** System throws an error - this is an invalid state

**Prevention:** 
- Database constraint ensures NOT NULL
- API validation rejects NULL values
- UI validation prevents saving with NULL

---

### EC4: Leap Year Handling
**Scenario:** `fixed_send_day = 29`, target month is February

**Handling:**
- Leap year (e.g., 2024): Use Feb 29
- Non-leap year (e.g., 2026): Use Feb 28
- Implementation: `calendar.monthrange()` handles leap year detection

---

### EC5: Timezone Considerations
**Scenario:** User in US creates campaign, but system stores datetimes in UTC

**Handling:**
- `creation_datetime` and `last_scheduled_send_date` are stored in UTC
- `fixed_send_day` is a calendar day, not timezone-specific
- `EMAIL_SEND_START_HOUR_UTC` is 16:00 UTC (11:00 AM EST)
- Calculation uses UTC dates consistently

---

### EC6: Email Approved Just Before Next Creation
**Scenario:** User approves an email moments before the system tries to create the next one

**Handling:**
- If user approves first → email sends normally, `last_sent_email_datetime` and `last_scheduled_send_date` are updated
- If system runs first → old email is expired, new email is created
- No race condition because expiration check happens at the start of the next email creation process, not at a specific clock time

---

### EC7: Multiple Pending Emails (Edge Case)
**Scenario:** Somehow multiple emails are pending approval for the same campaign

**Handling:** When creating the next email, expire ALL emails that are pending approval (status=READY, delivery_status=READY_TO_SEND, approved=0) for that campaign

---

## Summary: Next Send Date Calculation

```
function calculate_next_send_datetime(campaign):
    
    if campaign.last_scheduled_send_date is NULL:
        # First email - use existing delay logic
        # Working hours handled by existing ONLY_SEND_EMAILS_DURING_WORKING_HOURS logic
        return campaign.creation_datetime + FIRST_TIME_CAMPAIGN_DELAY_HOURS
    
    else:
        # All subsequent emails - use fixed send day logic
        target_date = campaign.last_scheduled_send_date + every_n_months
        return next_occurrence_of_day(campaign.fixed_send_day, after=target_date)


function next_occurrence_of_day(day, after):
    # Find the next occurrence of 'day' that is strictly after 'after'
    # Handle months with fewer days by using min(day, last_day_of_month)
    # Preserve the time component from 'after'
    ...
```

**Note:** By setting `last_scheduled_send_date` when each email is **created**, we eliminate the need for a separate "2nd email" case. The first email's scheduled time becomes the anchor for calculating subsequent sends.

---

## Resolved Questions (from Technical Planning)

1. **Email Creation Trigger:** Uses existing poller in `data_fetcher` that checks `next_send_datetime`. The `calculate_next_send_datetime()` function will be updated to use the new logic.

2. **How to detect "exactly 1 email sent":** Not needed. By setting `last_scheduled_send_date` when the first email is **created**, the logic simplifies to just 2 cases: NULL (first email) vs NOT NULL (subsequent emails).

3. **Backfill `last_scheduled_send_date`:** Set to `last_sent_email_datetime` for existing campaigns. This is acceptable as it maintains the current behavior for migrated campaigns.

4. **Environment Variables:** No new environment variables needed. Use existing `EMAIL_SEND_START_HOUR_UTC` constant (16:00 UTC = 11:00 AM EST).

5. **Working Hours for First Email:** No new code needed. Existing `ONLY_SEND_EMAILS_DURING_WORKING_HOURS` logic handles working hours restrictions for first emails.

---

**Document Version:** 2.1  
**Last Updated:** 2026-01-17  
**Status:** Ready for Implementation
