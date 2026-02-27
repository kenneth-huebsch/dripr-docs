# Hybrid Polling & Event-Driven System

The system uses a **hybrid orchestration pattern** combining database polling with event-driven queues:

- **api_gateway**: REST API exposed to frontend (Flask + Gunicorn with 3 workers)
- **data_fetcher**: Background service that fetches real estate data from multiple APIs (hybrid: one polling thread for status orchestration, multiple event consumers for data fetching)
- **email_manager**: Background service that creates and sends emails (fully event-driven: three event consumers)
- **cron_jobs**: Scheduled maintenance tasks (cleanup, stuck campaign restarts, usage reporting)
- **ui**: React frontend (Vite + TypeScript + TailwindCSS)

Services coordinate through:
1. **Database status polling** - Single polling thread in data_fetcher orchestrates campaign status transitions
2. **SNS/SQS event queues** - Event-driven processing for all data fetching, email creation, email sending, and welcome emails

# Campaign State Machine

Campaigns flow through these states with detailed field values at each step:

## 1. Campaign Created

When a user creates a campaign via the API:

- `Campaign.campaign_status` = `DORMANT` (CampaignStatus enum)
- `Campaign.property_status` = `DORMANT` (SubStatus enum)
- `Campaign.active_listing_status` = `DORMANT` (SubStatus enum)
- `Campaign.recent_sale_status` = `DORMANT` (SubStatus enum)
- `Campaign.local_market_data_status` = `DORMANT` (SubStatus enum)
- `Campaign.intro_status` = `DORMANT` (SubStatus enum)
- `Campaign.home_report_analysis_status` = `DORMANT` (SubStatus enum)
- `Campaign.email_creation_status` = `DORMANT` (SubStatus enum)
- `Campaign.intro` = `NULL`
- `Campaign.home_report_analysis` = `NULL`
- `Campaign.last_sent_email_datetime` = `NULL` (default, meaning no email has been sent)
- `Campaign.last_scheduled_send_date` = `NULL` (set when first email is created)
- `Campaign.fixed_send_day` = 1-28 (day of month for subsequent emails, required field)
- `Campaign.enabled` = 0 or 1 (based on user input)

**Note**: For no-address newsletters (`no_address_newsletter=1`), `property_status` and `home_report_analysis_status` are set to `READY` immediately since property data and home report analysis are not needed.

## 2. Campaign Ready for Data Fetching

When `next_send_datetime` arrives (calculated dynamically using `calculate_next_send_datetime()`), `data_fetcher` updates campaigns:

- `Campaign.campaign_status` = `WAITING_FOR_DATA`
- `Campaign.property_status` = `WAITING_FOR_DATA` (or `READY` if `no_address_newsletter=1`)
- `Campaign.active_listing_status` = `WAITING_FOR_DATA`
- `Campaign.recent_sale_status` = `WAITING_FOR_DATA`
- `Campaign.local_market_data_status` = `WAITING_FOR_DATA`
- `Campaign.intro_status` = `WAITING_FOR_DATA`
- `Campaign.home_report_analysis_status` = `WAITING_FOR_DATA` (or `READY` if `no_address_newsletter=1`)

**Email Placeholder Creation**: At this point, an `Email` record is created as a placeholder:
- `Email.campaign_id` = campaign ID
- `Email.user_id` = campaign user ID
- `Email.to_email` = campaign client email
- `Email.data` = `{}` (empty, will be populated later)
- `Email.html_content` = `""` (empty, will be populated later)
- `Email.status` = `WAITING_FOR_DATA` (SubStatus enum; will be set to `READY` after content is populated)
- `Email.delivery_status` = `NULL` (will be set to `READY_TO_SEND` after content is populated)
- `Email.approved` = 0 (will be set based on `check_before_sending` after content is populated)
- `Email.local_footer_content_type` = `NULL` (will be set during data fetching)

**Note**: `next_send_datetime` is not a database field - it's dynamically calculated using the `calculate_next_send_datetime()` function:
- **First email** (`last_scheduled_send_date` is `NULL`):
  - If `fixed_send_day` equals current day (EST): Uses `creation_datetime` + `FIRST_TIME_CAMPAIGN_DELAY_HOURS`
  - If `fixed_send_day` differs from current day: Uses max(`creation_datetime` + `FIRST_TIME_CAMPAIGN_DELAY_HOURS`, next occurrence of `fixed_send_day`)
  - Working hours enforcement: When `ONLY_SEND_EMAILS_DURING_WORKING_HOURS='true'`, the calculated send time is adjusted forward to the next working hours window (11am-6pm EST) if needed
- **Subsequent emails** (`last_scheduled_send_date` is NOT `NULL`): Uses `last_scheduled_send_date` + `every_n_months`, adjusted to the `fixed_send_day` of that month

At this point, a `STATUS_CHANGE` event is published to SNS, which fans out to all relevant SQS queues (local market, active listings, recent sales, property valuation, intro). Each queue's consumer will process the event independently.

## 3. Data Fetching (Parallel Processing)

`data_fetcher` processes each sub-status independently using event-driven queues:

**Event-Driven (SQS Queues):**
- `local_market_data_status` - Consumes from `SQS_LOCAL_MARKET_UPDATES_QUEUE_URL`
- `active_listing_status` - Consumes from `SQS_ACTIVE_LISTINGS_QUEUE_URL`
- `recent_sale_status` - Consumes from `SQS_RECENT_SALES_QUEUE_URL`
- `property_status` - Consumes from `SQS_PROPERTY_VALUATION_QUEUE_URL`
- `intro_status` - Consumes from `SQS_INTRO_QUEUE_URL`

Each sub-status transitions:
1. `WAITING_FOR_DATA` → `READY` (when data fetch completes successfully)
2. `WAITING_FOR_DATA` → `ERROR` (if fetch fails)

During this phase:
- `Campaign.campaign_status` = `WAITING_FOR_DATA` (remains until intro generation and all data sub-statuses complete)
- Individual sub-statuses (`property_status`, `active_listing_status`, etc.) transition independently
- `Campaign.intro` is populated by AWS Bedrock when `intro_status` is processed

**Local Footer Content Generation**: When `local_market_data_status` is processed, the system also determines and generates the email footer content using `generate_local_footer_content()`:
- **Odd months (1, 3, 5, 7, 9, 11)**: Attempts to generate local business content. If successful, sets `Email.local_footer_content_type` = `LOCAL_BUSINESS`. If generation fails, falls back to `EDUCATION_TOPIC`.
- **Even months (2, 4, 6, 8, 10, 12)**: Always uses education topic. Sets `Email.local_footer_content_type` = `EDUCATION_TOPIC`.
- This month-based strategy provides recipients with diverse content each cycle (local business highlights alternating with expert tips).

**Note:** All sub-statuses skip the `FETCHING` intermediate state since SQS visibility timeout handles duplicate processing prevention.

## 4. Campaign Ready for Home Report Analysis

When property data and local market data are ready:

- `Campaign.campaign_status` = `WAITING_FOR_HOME_ANALYSIS`
- `Campaign.property_status` = `READY`
- `Campaign.active_listing_status` = `READY`
- `Campaign.recent_sale_status` = `READY`
- `Campaign.local_market_data_status` = `READY`
- `Campaign.intro_status` = `READY`
- `Campaign.home_report_analysis_status` = `WAITING_FOR_DATA`
- `Campaign.intro` = populated (generated by AWS Bedrock)
- `Campaign.home_report_analysis` = `NULL` (not yet generated)

At this point, a `STATUS_CHANGE` event is published to the `SQS_HOME_REPORT_QUEUE_URL` queue.

**Note**: For no-address campaigns, `home_report_analysis_status` is set directly to `READY` without LLM processing, skipping this state entirely.

## 5. Home Report Analysis Generated

`data_fetcher` consumes the home report event from `SQS_HOME_REPORT_QUEUE_URL`:

- `Campaign.home_report_analysis_status` = `READY`
- `Campaign.home_report_analysis` = populated (generated by AWS Bedrock, or `NULL` for no-address campaigns)

## 6. Campaign Ready for Email Creation

When all sub-statuses reach `READY`:

- `Campaign.campaign_status` = `READY_TO_CREATE_EMAIL`
- `Campaign.email_creation_status` = `WAITING_FOR_DATA` (set by poller when transitioning to `READY_TO_CREATE_EMAIL`)
- `Campaign.property_status` = `READY`
- `Campaign.active_listing_status` = `READY`
- `Campaign.recent_sale_status` = `READY`
- `Campaign.local_market_data_status` = `READY`
- `Campaign.intro_status` = `READY`
- `Campaign.home_report_analysis_status` = `READY`
- `Campaign.intro` = populated (generated by AWS Bedrock)
- `Campaign.home_report_analysis` = populated (generated by AWS Bedrock, or `NULL` for no-address campaigns)

At this point, a `STATUS_CHANGE` event is published to the `SQS_EMAIL_CREATION_QUEUE_URL` queue.

## 7. Email Content Populated

`email_manager` email creation consumer processes `STATUS_CHANGE` event (to `READY_TO_CREATE_EMAIL`), builds the email content, and updates the existing `Email` record (created as a placeholder in step 2):

**Email Builder Process**:
1. Fetches all campaign data (property, listings, sales, local market data, signature, etc.)
2. Reads `Email.local_footer_content_type` (set during data fetching) to determine footer content:
   - If `LOCAL_BUSINESS`: Includes local business highlight with education topic as fallback
   - If `EDUCATION_TOPIC`: Includes only education topic
3. Compiles Handlebars template with all data
4. Updates the email record with content

**Updated Email Fields**:
- `Email.data` = populated with all template data (JSON)
- `Email.html_content` = rendered HTML content
- `Email.delivery_status` = `READY_TO_SEND` (DeliveryStatus enum)
- `Email.approved` = 0 (if `Campaign.check_before_sending=1`) or 1 (if `Campaign.check_before_sending=0`)
- `Email.status` = `READY` (SubStatus enum)
- `Email.scheduled_send_datetime` = calculated using `calculate_next_send_datetime()` (when this email should be sent, see note above for first email logic)
- `Campaign.campaign_status` = `READY_TO_CREATE_EMAIL` (unchanged - stays in this state)
- `Campaign.email_creation_status` = `READY` (indicates email is created and ready)
- `Campaign.last_scheduled_send_date` = set to `Email.scheduled_send_datetime` (for calculating next email's send date)

Before creating the new email, any old unapproved emails are expired:
- Old unapproved emails (`status=READY`, `delivery_status=READY_TO_SEND`, `approved=0`) that are older than `every_n_months` AND created before `last_sent_email_datetime` are marked as:
  - `Email.delivery_status` = `EXPIRED`
  - `Email.status` = `COMPLETE`

**Campaign Status**:
- `Campaign.campaign_status` = `READY_TO_CREATE_EMAIL` (unchanged - stays in this state)
- `Campaign.email_creation_status` = `READY` (indicates email content is populated and ready)

**Note**: The campaign remains in `READY_TO_CREATE_EMAIL` status. A poller in `data_fetcher` will check approval status and first-time delays before transitioning to `READY_TO_SEND_EMAIL`.

## 8. Campaign Ready for Email Sending

`data_fetcher` poller (`edit_campaigns_status_that_are_ready_for_email_sending()`) checks campaigns in `READY_TO_CREATE_EMAIL` with `email_creation_status=READY` and transitions them when:
- Email is approved (either `check_before_sending=0` OR `Email.approved=1`)
- First-time campaign delay has passed (if `last_sent_email_datetime is NULL`, campaign must be at least `FIRST_TIME_CAMPAIGN_DELAY_HOURS` old)
- Campaign is enabled

When these conditions are met:
- `Campaign.campaign_status` = `READY_TO_SEND_EMAIL`
- A `STATUS_CHANGE` event is published to the `SQS_EMAIL_SENDING_QUEUE_URL` queue

## 9. Email Sent

`email_manager` email sending consumer processes `STATUS_CHANGE` event (to `READY_TO_SEND_EMAIL`) and sends the email (via Gmail API or Postmark):

- `Email.delivery_status` = `SENT`
- `Email.status` = `COMPLETE` (terminal state - no more processing needed)
- `Email.sent_datetime` = current UTC timestamp
- `Email.message_id` = Postmark MessageID (if sent via Postmark)
- `Campaign.last_sent_email_datetime` = current UTC timestamp
- Then immediately: `Campaign.campaign_status` = `DORMANT`
- All sub-statuses reset to `DORMANT`:
  - `Campaign.property_status` = `DORMANT`
  - `Campaign.active_listing_status` = `DORMANT`
  - `Campaign.recent_sale_status` = `DORMANT`
  - `Campaign.local_market_data_status` = `DORMANT`
  - `Campaign.intro_status` = `DORMANT`
  - `Campaign.home_report_analysis_status` = `DORMANT`
  - `Campaign.email_creation_status` = `DORMANT`

**Note**: 
- Email sending consumer checks working hours (11am-6pm EST) and calculates sleep duration until next window if `ONLY_SEND_EMAILS_DURING_WORKING_HOURS=true`
- Approval and first-time delay checks are handled by the poller before the event is published, so the consumer can send immediately

## 10. Email Delivered

When Postmark webhook confirms delivery:

- `Email.delivery_status` = `DELIVERED` (only if current status priority allows)
- `Email.status` = `COMPLETE` (terminal state)
- `Email.delivered_at` = delivery timestamp
- `Email.delivery_details` = delivery information
- `Campaign.campaign_status` = `DORMANT` (unchanged)

## 11. Email Opened

When Postmark webhook confirms email open:

- `Email.delivery_status` = `OPENED` (only if current status priority allows - higher priority than DELIVERED)
- `Email.status` = `COMPLETE` (terminal state)
- `Email.opened_at` = open timestamp
- `Campaign.campaign_status` = `DORMANT` (unchanged)

## 12. Email Bounced

When Postmark webhook reports bounce:

- `Email.delivery_status` = `BOUNCED` (only if current status priority allows)
- `Email.status` = `COMPLETE` (terminal state)
- `Email.bounced_at` = bounce timestamp
- `Email.bounced_details` = bounce details (includes bounce type if available)
- `Campaign.campaign_status` = `UNSUBSCRIBED`
- `Campaign.enabled` = 0

**Note**: Postmark sends both a `Bounce` event and a `SubscriptionChange` event for hard bounces. The priority system ensures BOUNCED (priority 4) cannot be overwritten by UNSUBSCRIBED (priority 3) from the subsequent SubscriptionChange webhook.

## 13. Spam Complaint

When Postmark webhook reports spam complaint:

- `Email.delivery_status` = `SPAM_COMPLAINT` (only if current status priority allows)
- `Email.status` = `COMPLETE` (terminal state)
- `Email.spam_complaint_at` = complaint timestamp
- `Email.spam_complaint_details` = complaint details
- `Campaign.campaign_status` = `UNSUBSCRIBED`
- `Campaign.enabled` = 0

## 14. Unsubscribed

When recipient unsubscribes (via Postmark webhook or manual action):

- `Email.delivery_status` = `UNSUBSCRIBED` (only if current status priority allows)
- `Email.status` = `COMPLETE` (terminal state)
- `Email.unsubscribed_at` = unsubscribe timestamp
- `Email.unsubscribed_details` = unsubscribe details
- `Campaign.campaign_status` = `UNSUBSCRIBED`
- `Campaign.enabled` = 0

**Note**: UNSUBSCRIBED (priority 3) cannot overwrite BOUNCED (priority 4) or SPAM_COMPLAINT (priority 5) statuses. This prevents SubscriptionChange webhooks (sent after bounces/spam complaints) from overwriting the more critical bounce/spam status information.

## 15. Email Expired

When an email is too old and a new email is created before it was approved:

- `Email.delivery_status` = `EXPIRED`
- `Email.status` = `COMPLETE` (terminal state)

This occurs when:
- Email was awaiting approval (`approved=0`)
- Campaign has sent other emails since this one was created
- Email is older than the campaign's `every_n_months` period

Expired emails are marked automatically when a new email is created via the `expire_pending_emails()` function.

**Email Delivery Status Priority**: The system uses a priority system to prevent lower-priority statuses from overwriting higher-priority ones. Priority order (highest to lowest): `SPAM_COMPLAINT` (5) > `BOUNCED` (4) > `UNSUBSCRIBED` (3) > `OPENED` (2) > `DELIVERED` (1) > `SENT` (0) > `EXPIRED` (0) > `READY_TO_SEND` (0)

**Email SubStatus (`status` field)**: Emails transition through processing states (`WAITING_FOR_DATA` → `READY`) and reach `COMPLETE` when they enter any terminal delivery status (`SENT`, `DELIVERED`, `OPENED`, `BOUNCED`, `SPAM_COMPLAINT`, `UNSUBSCRIBED`, `EXPIRED`). On send failure, emails may transition to `ERROR` instead. The `COMPLETE` status indicates no further processing is needed for this email. Note: `DORMANT` is not used for emails—it applies only to Campaign sub-statuses.
