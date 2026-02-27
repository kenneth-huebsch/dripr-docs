# Intro and Home Report Queues - Implementation Summary

## Overview

Successfully migrated intro generation and home report analysis from database polling to event-driven architecture using AWS SNS/SQS, completing the event-driven transformation of all data fetching workflows in the data_fetcher service.

## What Was Implemented

### New SQS Queues
- **`SQS_INTRO_QUEUE_URL`**: Processes intro text generation via AWS Bedrock
- **`SQS_HOME_REPORT_QUEUE_URL`**: Processes home report analysis via AWS Bedrock

### Event Handlers
- **`handle_intro_event()`**: Generates personalized intro text for campaigns
  - Uses `1st-intro.txt` for first property-based campaign
  - Uses `1st-intro-no-address.txt` for first no-address campaign
  - Uses `recurring-intro.txt` for subsequent emails (both types)
  - No longer requires market data or mortgage rate parameters
- **`handle_home_report_event()`**: Generates home report analysis
  - Skips processing for no-address campaigns (sets status to READY immediately)
  - Requires property data (formatted_address, current_value, purchase_price, purchase_date)
  - Returns unformatted plain text

### Event Consumers
- **`poll_intro_events()`**: Long-polls SQS intro queue (20s wait, 10 messages max)
- **`poll_home_report_events()`**: Long-polls SQS home report queue (20s wait, 10 messages max)

### Database Changes

#### New Enum Structure
**Created three separate enums:**
- **`CampaignStatus`**: Main campaign lifecycle states
  - `DORMANT`, `WAITING_FOR_DATA`, `WAITING_FOR_HOME_ANALYSIS`, `READY_TO_CREATE_EMAIL`, `FETCHING`, `WAITING_FOR_MANUAL_APPROVAL`, `READY_TO_SEND_EMAIL`, `UNSUBSCRIBED`, `ERROR`
- **`SubStatus`**: Data fetching sub-statuses
  - `DORMANT`, `WAITING_FOR_DATA`, `READY`, `FETCHING`, `ERROR`
- **`Status`** (Legacy): Retained for Email model until email_manager migration
  - All old values kept for backward compatibility

#### Schema Changes
- **Split `intro_and_home_report_analysis_status`** into:
  - `intro_status` (SubStatus) - Tracks intro generation progress
  - `home_report_analysis_status` (SubStatus) - Tracks home report analysis progress
- **Added `WAITING_FOR_HOME_ANALYSIS`** to CampaignStatus enum
- **Updated all SubStatus columns** to use the new SubStatus enum
- **Updated Email.status** to use SubStatus enum

#### Migration File
- `f1a2b3c4d5e6_split_status_enum_and_rename_intro_column.py`
- Handles enum expansion, data migration, column creation/deletion
- Full downgrade support

### Code Changes

#### db_client.py
- Added `edit_intro_on_campaign(campaign_id, intro)` - Updates intro text
- Added `edit_home_report_analysis_on_campaign(campaign_id, home_report_analysis)` - Updates home report text
- Replaced `edit_intro_and_home_report_analysis_status_on_campaign()` with:
  - `edit_intro_status_on_campaign(campaign_id, status)`
  - `edit_home_report_analysis_status_on_campaign(campaign_id, status)`
- Updated all Status references to use CampaignStatus or SubStatus appropriately
- Removed unused imports (LocalMarketData, MortgageRate from various functions)

#### bedrock_campaign_client.py
- **Removed `generate_intro_and_analysis()`** - No longer needed
- **Split into separate methods:**
  - `generate_intro(campaign_id, no_address_newsletter)` - Returns plain text
  - `generate_home_report_analysis(formatted_address, current_value, purchase_price, purchase_date)` - Returns plain text
- **Consolidated prompts:**
  - All prompts now prepend `context.txt` for unified context
  - Removed `context-no-address.txt` (consolidated into main context)
  - Removed market data context from intro prompts
  - Updated logic so recurring campaigns use `recurring-intro.txt` regardless of type
- Removed `update_db_with_home_report_analysis_and_intro()` helper function

#### data_fetcher.py
- Added environment variable validation for new queue URLs
- Imported new event handlers (`handle_intro_event`, `handle_home_report_event`)
- Added two new event consumer threads:
  - `IntroEventPoller` - Runs `poll_intro_events()`
  - `HomeReportEventPoller` - Runs `poll_home_report_events()`
- **Removed `poll_for_home_report_analysis_and_intro()`** - Replaced by event consumers
- Updated thread configuration in `main()`

#### Tests
- Updated `test_email_generation.py` to reflect new architecture:
  - `test_home_valuation_uses_standard_prompts` - Tests `generate_intro()` with property campaigns
  - `test_no_address_uses_custom_prompts` - Tests `generate_intro()` with no-address campaigns
  - `test_home_valuation_includes_property_data` - Tests `generate_home_report_analysis()` with property data
  - `test_home_valuation_generates_home_report` - Verifies plain text return
  - Removed obsolete tests for combined generation

## Campaign Status Flow

### Updated State Machine

**1. DORMANT → WAITING_FOR_DATA**
- Campaign becomes ready for data updates
- `STATUS_CHANGE` event published to SNS
- Fan-out to all data queues including intro queue

**2. WAITING_FOR_DATA (Parallel Processing)**
- All data operations proceed independently:
  - Property valuation
  - Active listings
  - Recent sales
  - Local market data
  - **Intro generation** ← NEW
- Each updates its respective sub-status to `READY`

**3. WAITING_FOR_DATA → WAITING_FOR_HOME_ANALYSIS**
- Triggered when all data sub-statuses reach `READY`
- `STATUS_CHANGE` event published to home report queue

**4. WAITING_FOR_HOME_ANALYSIS**
- Home report analysis generated (or skipped for no-address)
- `home_report_analysis_status` updated to `READY`

**5. WAITING_FOR_HOME_ANALYSIS → READY_TO_CREATE_EMAIL**
- All sub-statuses (including intro and home_report_analysis) are `READY`
- Campaign ready for email creation

## Key Improvements

### Decoupling
- ✅ Intro no longer waits for property data
- ✅ Intro and home report are independent operations
- ✅ No artificial coupling between unrelated operations

### Fault Tolerance
- ✅ SQS visibility timeout handles stuck tasks (30s default)
- ✅ Automatic retry for transient failures
- ✅ Messages return to queue if processing fails

### Simplified Prompts
- ✅ Single `context.txt` for all prompts (DRY principle)
- ✅ Task-specific prompts focus only on their specific requirements
- ✅ Removed unnecessary market data from intro generation
- ✅ Plain text output (no JSON parsing needed)

### Better Semantics
- ✅ Clear separation between campaign lifecycle (CampaignStatus) and data operations (SubStatus)
- ✅ Separate tracking for intro vs home report (no more combined status)
- ✅ New `WAITING_FOR_HOME_ANALYSIS` state makes workflow explicit

## Environment Variables

Added to both `local-dev.env` and `prod.env`:
```bash
SQS_INTRO_QUEUE_URL='https://sqs.us-east-1.amazonaws.com/930028135507/dripr-intro-queue-{dev|prod}'
SQS_HOME_REPORT_QUEUE_URL='https://sqs.us-east-1.amazonaws.com/930028135507/dripr-home-report-queue-{dev|prod}'
```

## Documentation Updates

- ✅ `docs/campaign-state-machine.md` - Updated state flow with new statuses
- ✅ `docs/system-design.md` - Updated architecture diagram and component descriptions
- ✅ `docs/09-event-driven/architecture-summary.md` - Updated to reflect implemented architecture
- ✅ `docs/development-guide.md` - Updated multi-threading section
- ✅ `README.md` - Updated architecture overview and completed TODOs

## Testing

Tested in integrated environment:
- ✅ Intro generation via SQS events
- ✅ Home report analysis via SQS events
- ✅ Database methods for updating intro and home report text
- ✅ Proper status transitions through state machine
- ✅ No-address campaigns skip home report correctly

## Future Work

### Email Manager Migration (Next Priority)
The last remaining polling-based workflows are in email_manager:
1. Email creation polling
2. Email sending polling

Migrating these to events will:
- ✅ Eliminate the `FETCHING` lock entirely
- ✅ Remove race conditions in email creation/sending
- ✅ Complete the event-driven transformation

### Potential Enhancements
- CloudWatch metrics for queue depths and processing times
- Dead letter queues for failed messages
- Enhanced error handling and alerting
- Retry policies with exponential backoff

## Conclusion

The intro and home report queue implementation completes the event-driven transformation of the data_fetcher service. All data fetching operations now use SQS queues, providing better fault tolerance, parallelism, and scalability. Only campaign status orchestration and email operations remain as polling-based workflows.

