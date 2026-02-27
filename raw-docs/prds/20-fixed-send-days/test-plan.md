# Fixed Send Day Feature - Manual Test Plan

## 0. General
1. Create a campaign with the current fixed_send_date, 24 hour delay, during business hours... 
1. Create a campaign with a future fixed_send_date
1. Create a campaign with a fixed_send_date
1. Create a campaign, then edit the fixed send date to be future
1. Create a campaign, then edit the fixed send date to be past

---

## 1. End of Month Creation & Approval Timing

### 1.1 Created during EST business hours while still Jan 31 UTC

**Step 1:** Create a campaign on Jan 31st within EST business hours while its still Jan 31 UTC

**Verify:**
- ✅fixed_send_day field automatically selects the first of the next month
- ✅Attempt to change fixed_send_day to 'x', '28', '31', '0'


**Step 2:** Save

**Verify:**
- ✅Campaign saves successfully
- ✅next_send_datetime = 5/1/2026 (includes 24-hour first-time delay)

**Step 3:** Approve on Jan 31 within EST business hours while its still Jan 31 UTC

**Verify:**
- ✅Email sends immediately
- ✅Campaign.last_scheduled_send_date is set
- ✅Campaign.last_sent_email_datetime is set
- ✅Next scheduled send = 5/1/2026

---

### 1.2 Created outside of EST business hours while still Jan 31 UTC

**Step 1:** Create a campaign on Jan 31st outside of EST business hours while its still Jan 31 UTC (ex: 6:30pm EST)

**Verify:**
- ✅next_send_datetime = 5/1/2026

**Step 3:** Approve on Jan 31 outside of EST business hours while its still Jan 31 UTC (ex: 6:35pm EST)

**Verify:**
- Email queued to send on 2/1/2026 during working hours (11am-6pm EST)
- next_send_datetime = 5/1/2026

---

### 1.3 Created outside of EST business hours while Feb 1 UTC

**Step 1:** Create a campaign on Jan 31st outside of EST business hours while Feb 1 UTC (ex: 7:05pm EST)

**Verify:**
- fixed_send_day field is empty (NULL) in UI
- Must select value 1-28 to save

**Step 2:** Set fixed_send_day = 1 and save

**Verify:**
- next_send_datetime = 5/1/2026

**Step 3:** Approve on Jan 31 outside of EST business hours while Feb 1 UTC (ex: 7:35pm EST)

**Verify:**
- Email queued to send on 2/1/2026 during working hours
- next_send_datetime = 5/1/2026

### 1.4 Created outside of EST business hours while Feb 1 UTC, with SEND_DURING_BUSINESS_HOURS = True
**Step 1:** Create a campaign on Jan 31st outside of EST business hours while Feb 1 UTC (ex: 7:05pm EST)

**Step 2:** Edit fixed_send_day to 15

**Step 1:** Approve it

**Verify:**
- Sends on Feb 1st
- next_send_day is 5/15
- ⚠️ Prior to email being sent, the UI shows the next_send_day as 5/15. I would expect it to be 2/1 until it sends, and then become 5/15




## 2. Fixed Send Day Validation at Month Boundaries

### 2.1 Creating on day 29

**Step 1:** Create campaign on Jan 29

**Verify:**
- fixed_send_day field is empty (NULL)
- Must manually select 1-28
- Cannot save with empty value

**Step 2:** Select fixed_send_day = 28, save, and approve immediately

**Verify:**
- Next send calculates to April 28 (Feb doesn't have 29 in 2026, so skip to April based on every_n_months=1)

---

### 2.2 Creating on day 30

**Step 1:** Create campaign on Jan 30

**Verify:**
- Same validation as day 29

**Step 2:** Select fixed_send_day = 15, save

**Verify:**
- Next send calculates correctly to April 15

---

### 2.3 Selecting fixed_send_day = 28 (February edge)

**Step 1:** Create campaign on Jan 15, set fixed_send_day = 28

**Verify:**
- First email scheduled for Jan 18 (72-hour delay)
- After first email sends, next email scheduled for Feb 28 (2026 is not a leap year)
- After Feb email sends, next email scheduled for March 28

---

### 2.4 Editing grandfathered campaign with day 29-31

**Step 1:** Use SQL to manually set a campaign to fixed_send_day = 31

**Verify:**
- Campaign displays day 31 in view mode

**Step 2:** Click edit

**Verify:**
- Field shows NULL/empty
- Cannot save without selecting new value 1-28

---

## 3. Invalid Month Day Handling

### 3.1 Fixed send day 31 crossing into 30-day months

**Step 1:** Create campaign on Jan 15 with fixed_send_day = 28 (we'll edit this after)

**Step 2:** Use SQL to update fixed_send_day = 31 (simulating grandfathered data)

**Verify:**
- Next send in February calculates to Feb 28 (last day of month)
- Next send in March calculates to March 31
- Next send in April calculates to April 30 (last day of month)
- Next send in May calculates to May 31

---

### 3.2 Leap year handling (test in 2028 or manually set dates)

**Step 1:** If possible, create test with fixed_send_day = 29 for February in leap year (2028)

**Verify:**
- Feb 2028 send uses Feb 29
- Feb 2029 send uses Feb 28

---

## 4. Late Approval & Schedule Preservation

### 4.1 Approve email after next scheduled date passes

**Step 1:** Create campaign on Jan 15 with fixed_send_day = 20

**Step 2:** Wait until Jan 23 (after scheduled send Jan 20) before approving

**Verify:**
- Email sends immediately upon approval
- Campaign.last_scheduled_send_date = Jan 20 (original schedule)
- Campaign.last_sent_email_datetime = Jan 23 (actual send)
- Next email still calculates to Feb 20 (schedule not shifted by late approval)

---

### 4.2 Multiple late approvals

**Step 1:** Create campaign, let 2 emails expire (don't approve for 2+ months)

**Verify:**
- Each unapproved email is marked EXPIRED when next one is created
- Old emails show EXPIRED status in UI with tooltip
- Cannot approve EXPIRED emails
- Approve button hidden for EXPIRED emails
- Can still view content of EXPIRED emails

---

## 5. Editing fixed_send_day After Campaign Active

### 5.1 Edit to earlier day in same month

**Step 1:** Create campaign on Jan 5 with fixed_send_day = 20, let first email send

**Step 2:** On Jan 10, edit fixed_send_day to 15

**Verify:**
- next_send_datetime = Feb 15 (not Jan 15, since 15 hasn't occurred after last_scheduled + every_n_months)
- No immediate email creation

---

### 5.2 Edit to later day in same month

**Step 1:** Create campaign on Jan 5 with fixed_send_day = 10, let first email send on Jan 8

**Step 2:** On Jan 12, edit fixed_send_day to 25

**Verify:**
- next_send_datetime = Feb 25
- No immediate email creation

---

### 5.3 Edit on last day of month

**Step 1:** Create campaign on Jan 1 with fixed_send_day = 1, let first email send

**Step 2:** On Jan 31, edit fixed_send_day to 15

**Verify:**
- next_send_datetime = Feb 15
- No immediate email creation
- Calculation: next 15 after (Jan 1 + 1 month = Feb 1) = Feb 15

---

## 6. Email Expiration Scenarios

### 6.1 Email expires exactly at month boundary

**Step 1:** Create campaign with fixed_send_day = 1, let first email send

**Step 2:** Don't approve the Feb 1 email

**Verify:**
- When March 1 calculation triggers, Feb 1 email is marked EXPIRED
- New email created for March 1
- Campaign has 2 emails in history: one EXPIRED, one READY

---

### 6.2 Approve just before expiration

**Step 1:** Create campaign with fixed_send_day = 1, let first email send

**Step 2:** On the day the next email is about to be created, approve the current one just before the poller runs

**Verify:**
- Email sends successfully
- No EXPIRED emails
- Next email created normally

---

### 6.3 Multiple pending emails (edge case - shouldn't happen but test defensive code)

**Step 1:** Use test/staging DB to create 2 READY emails for same campaign

**Verify:**
- When next email creation triggers, both are marked EXPIRED
- Only one new email is created

---

## 7. Different every_n_months Values

### 7.1 Every 2 months

**Step 1:** Create campaign on Jan 15 with fixed_send_day = 15, every_n_months = 2

**Verify:**
- First email: Jan 18 (72-hour delay)
- Second email: March 15 (2 months after Jan 15)
- Third email: May 15

---

### 7.2 Every 3 months (quarterly)

**Step 1:** Create campaign on Jan 10 with fixed_send_day = 10, every_n_months = 3

**Verify:**
- First email: Jan 13
- Second email: April 10
- Third email: July 10

---

### 7.3 Every 6 months (semi-annual)

**Step 1:** Create campaign on Jan 31

**Verify:**
- Must select fixed_send_day 1-28

**Step 2:** Select fixed_send_day = 28, every_n_months = 6

**Verify:**
- First email: Feb 3
- Second email: July 28
- Third email: Jan 28 (next year)

---

## 8. Working Hours Edge Cases

### 8.1 First email scheduled outside working hours

**Step 1:** Create campaign at 8pm EST on Jan 15 (Jan 16 UTC)

**Step 2:** Approve when first email is ready

**Verify:**
- If ONLY_SEND_EMAILS_DURING_WORKING_HOURS is enabled:
  - Email waits until next working day 11am EST
- Time from first email is preserved for subsequent emails

---

### 8.2 Fixed send day falls on weekend (if working hours includes weekend logic)

**Step 1:** Create campaign with fixed_send_day = 1, where Feb 1 is a Saturday

**Verify:**
- Email sends according to weekend handling rules (if implemented)

---

## 9. Time Preservation Across Sends

### 9.1 Verify time component carries forward

**Step 1:** Create campaign on Jan 15 at 2:30pm EST, set fixed_send_day = 15

**Step 2:** Let first email send

**Verify:**
- First email scheduled_send_datetime includes time: Jan 18, 2:30pm EST
- Second email preserves time: Feb 15, 2:30pm EST
- Third email preserves time: March 15, 2:30pm EST

---

### 9.2 Time preservation with working hours override

**Step 1:** Create campaign at 8pm EST (outside working hours)

**Verify:**
- First email adjusted to next working day 11am
- Subsequent emails use that adjusted time (11am), not original creation time

---

## 10. API & Database Validation

### 10.1 API rejects invalid fixed_send_day

**Test 1:** POST /api/campaigns with fixed_send_day = 0

**Verify:** 400 error

**Test 2:** POST /api/campaigns with fixed_send_day = 32

**Verify:** 400 error

**Test 3:** POST /api/campaigns with fixed_send_day = -5

**Verify:** 400 error

---

### 10.2 API accepts valid range

**Test 1:** POST /api/campaigns with fixed_send_day = 1

**Verify:** 201 success

**Test 2:** POST /api/campaigns with fixed_send_day = 28

**Verify:** 201 success

**Test 3:** POST /api/campaigns with fixed_send_day = 15

**Verify:** 201 success

---

### 10.3 Database constraint prevents NULL

**Test 1:** Attempt SQL INSERT with fixed_send_day = NULL

**Verify:** Database constraint violation

---

## 11. UI/UX Validation

### 11.1 Monthly Send Day field displays correctly

**Step 1:** View campaign creation form

**Verify:**
- "Monthly Send Day" field visible in "Campaign Information" dropdown
- Help text: "The day of the month (1-28) when future emails will be sent. The first email follows normal scheduling."
- Min/max validation shows (1-28)
- Field is required (cannot submit empty)

---

### 11.2 Default value behavior

**Test 1:** Open campaign form on Jan 15

**Verify:** Default value = 15

**Test 2:** Open campaign form on Jan 5

**Verify:** Default value = 5

**Test 3:** Open campaign form on Jan 31

**Verify:** Default value = empty (NULL), requires selection

---

### 11.3 Edit campaign displays current value

**Step 1:** Edit existing campaign with fixed_send_day = 10

**Verify:**
- Field shows "10"
- Can change to different value 1-28
- Changes save correctly

---

### 11.4 EXPIRED email UI

**Step 1:** Create EXPIRED email (by not approving before next send)

**Verify:**
- Badge shows "Expired" with clock icon
- Badge is gray/muted styling
- Tooltip: "This email expired because it was not approved before the next email was scheduled to be created."
- "Approve" button hidden or disabled
- "Send" button hidden or disabled
- "View" button still available
- Email appears in email history list

---

## 12. Data Migration Validation

### 12.1 Existing campaign with sent emails

**Step 1:** Check campaign created before feature deployment that HAS sent emails

**Verify:**
- fixed_send_day = day of last_sent_email_datetime
- last_scheduled_send_date = last_sent_email_datetime
- next_send_datetime calculates correctly

---

### 12.2 Existing campaign without sent emails

**Step 1:** Check campaign created before feature deployment that HAS NOT sent emails

**Verify:**
- fixed_send_day = day of creation_datetime
- last_scheduled_send_date = NULL
- First email uses 72-hour delay from creation

---

## 13. Edge Case: Day 28 in February

### 13.1 Non-leap year February with fixed_send_day = 28

**Step 1:** Create campaign on Jan 1 with fixed_send_day = 28

**Verify:**
- First email: Jan 4
- Second email: Feb 28, 2026 (not leap year)
- Third email: March 28

---

### 13.2 Transition from January 31 context to February sends

**Step 1:** Create campaign on Jan 31, select fixed_send_day = 15

**Verify:**
- First email: Feb 3
- Second email: Feb 15
- Math: next 15 after (Jan 31 + 72 hours + 1 month) = Feb 15

---

## Test Environment Notes

- Test with `FIRST_TIME_CAMPAIGN_DELAY_HOURS` set to 72 (default)
- Test with `ONLY_SEND_EMAILS_DURING_WORKING_HOURS` both enabled and disabled
- Test with `EMAIL_SEND_START_HOUR_UTC` = 16 (11am EST)
- Verify all datetime storage is in UTC
- Use staging/test database for destructive tests
- Consider using manual SQL updates to simulate grandfathered data (days 29-31)