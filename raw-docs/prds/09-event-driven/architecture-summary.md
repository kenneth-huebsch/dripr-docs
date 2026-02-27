# Event-Driven Architecture - Implementation Summary

## Current Status: ✅ Implemented (Hybrid Architecture)

The dripr system has been successfully migrated from pure database polling to a **hybrid event-driven architecture** using AWS SNS/SQS for data fetching workflows.

## What Was Implemented

### Event-Driven Components (✅ Complete)
- **Local Market Data Fetching** - `SQS_LOCAL_MARKET_UPDATES_QUEUE_URL`
- **Active Listings Fetching** - `SQS_ACTIVE_LISTINGS_QUEUE_URL`
- **Recent Sales Fetching** - `SQS_RECENT_SALES_QUEUE_URL`
- **Property Valuation** - `SQS_PROPERTY_VALUATION_QUEUE_URL`
- **Intro Generation** - `SQS_INTRO_QUEUE_URL`
- **Home Report Analysis** - `SQS_HOME_REPORT_QUEUE_URL`
- **Welcome Emails** - `SQS_WELCOME_EMAILS_QUEUE_URL`

### Database Polling Components (Still Active)
- **Campaign Status Orchestration** - Manages transitions between campaign states
- **Email Creation** - Polls for campaigns ready to create emails
- **Email Sending** - Polls for emails ready to send

## Architecture Overview

### Event Flow
```
[Campaign Status Change] → [db_client.publish_campaign_status_change()]
                         → [SNS: dripr-campaign-events-topic]
                         → Fan-out to multiple SQS queues
                         → [data_fetcher event consumers]
                         → Process work independently
                         → Update campaign sub-status to READY
```

### Benefits Achieved
- ✅ **Decoupled Data Fetching**: Each data type (listings, sales, market data, etc.) processes independently
- ✅ **Automatic Retry**: SQS visibility timeout handles stuck tasks (no more FETCHING locks)
- ✅ **Better Fault Tolerance**: Failed messages return to queue after visibility timeout
- ✅ **Simplified Status Model**: Split into `CampaignStatus` (main workflow) and `SubStatus` (data operations)
- ✅ **Parallel Processing**: Multiple data operations can proceed simultaneously
- ✅ **No Deadlocks**: Event consumers don't compete for database locks

## Status Model Evolution

### New Enum Structure
- **CampaignStatus**: Main campaign lifecycle states (DORMANT, WAITING_FOR_DATA, WAITING_FOR_HOME_ANALYSIS, READY_TO_CREATE_EMAIL, etc.)
- **SubStatus**: Data fetching sub-statuses (DORMANT, WAITING_FOR_DATA, READY, FETCHING, ERROR)
- **Status** (Legacy): Kept for Email model until email_manager migration

### Status Fields
Campaigns now have separate status tracking for each data operation:
- `campaign_status` (CampaignStatus) - Main workflow state
- `property_status` (SubStatus) - Property valuation progress
- `active_listing_status` (SubStatus) - Active listings progress
- `recent_sale_status` (SubStatus) - Recent sales progress
- `local_market_data_status` (SubStatus) - Market data progress
- `intro_status` (SubStatus) - Intro generation progress
- `home_report_analysis_status` (SubStatus) - Home report progress

## Key Decisions

- **Queue Technology**: AWS SNS/SQS (Fan-out pattern for status changes)
- **Architecture Style**: Hybrid (event-driven data fetching + polling for orchestration)
- **Migration Approach**: Incremental, feature-by-feature
- **Rate Limiting**: Still handled per-process (not centralized)
- **Fault Recovery**: SQS visibility timeout (default 30 seconds)

## Future Work

### Email Manager Migration (Planned)
The email creation and sending workflows still use database polling. Future work includes:
1. Add `SQS_EMAIL_CREATION_QUEUE_URL` for email creation events
2. Add `SQS_EMAIL_SENDING_QUEUE_URL` for email sending events
3. Remove polling threads from email_manager
4. Remove `FETCHING` status (no longer needed with SQS visibility timeout)

### Observability Improvements
- CloudWatch metrics for queue depths
- Dead letter queues for failed messages
- Alerting on stuck campaigns


