---
name: Event-Driven Active Listings and Recent Sales
overview: Transition active listings and recent sales fetching from database polling to event-driven SQS queues, following the established pattern used for local market data updates. This involves creating 2 new SQS queues, modifying the event publisher, adding event consumers, and creating event handlers.
todos:
  - id: aws-queues
    content: Create SQS queues in AWS and subscribe to existing SNS topic
    status: completed
  - id: env-vars
    content: Add SQS queue URLs to local-dev.env and prod.env
    status: completed
  - id: event-handlers
    content: Add handle_active_listings_event and handle_recent_sales_event to event_handlers.py
    status: completed
  - id: event-consumers
    content: Add poll_active_listings_events and poll_recent_sales_events to data_fetcher.py
    status: completed
    dependencies:
      - env-vars
      - event-handlers
  - id: update-main
    content: Update main() to register new event polling threads
    status: completed
    dependencies:
      - event-consumers
  - id: remove-old-polling
    content: Remove old DB polling functions after validation
    status: completed
    dependencies:
      - update-main
---

# Event-Driven Active Listings and Recent Sales

## Current State

The system currently uses database polling for active listings and recent sales:

```mermaid
flowchart LR
    subgraph current [Current: Database Polling]
        DB[(Database)]
        DF[data_fetcher]
        DF -->|"poll every 5s"| DB
        DB -->|"WAITING_FOR_DATA campaigns"| DF
    end
```



- `poll_for_active_listings_that_need_updated()` in [data_fetcher.py](python/data_fetcher/data_fetcher.py) polls DB every 5 seconds
- `poll_for_recent_sales_that_need_updated()` polls similarly
- Both use `with_for_update(skip_locked=True)` locking which causes contention

## Target State

Event-driven processing using SNS/SQS:

```mermaid
flowchart LR
    subgraph target [Target: Event-Driven]
        DB[(Database)]
        DBC[db_client]
        SNS[SNS Topic]
        SQS1[SQS Active Listings Queue]
        SQS2[SQS Recent Sales Queue]
        DF[data_fetcher]
        
        DBC -->|"publish STATUS_CHANGE"| SNS
        SNS -->|"fan-out"| SQS1
        SNS -->|"fan-out"| SQS2
        DF -->|"consume"| SQS1
        DF -->|"consume"| SQS2
    end
```



## Implementation Plan

### 1. AWS Infrastructure Setup (Manual)

Create 2 new SQS queues in AWS and subscribe them to the existing `SNS_CAMPAIGN_EVENTS_TOPIC_ARN`:

- `dripr-active-listings-queue-dev` / `dripr-active-listings-queue-prod`
- `dripr-recent-sales-queue-dev` / `dripr-recent-sales-queue-prod`

### 2. Environment Variables

Add to [local-dev.env](local-dev.env) and [prod.env](prod.env):

```javascript
SQS_ACTIVE_LISTINGS_QUEUE_URL='https://sqs.us-east-1.amazonaws.com/...'
SQS_RECENT_SALES_QUEUE_URL='https://sqs.us-east-1.amazonaws.com/...'
```



### 3. Event Handlers

Add to [event_handlers.py](python/data_fetcher/event_handlers.py):

- `handle_active_listings_event(payload, ...)` - Extract logic from current polling function
- `handle_recent_sales_event(payload, ...)` - Extract logic from current polling function

Both handlers will:

1. Validate the payload contains `campaign_id` and `zip_code`
2. Fetch property data (or use zip code for no-address campaigns)
3. Delete existing listings/sales
4. Fetch new data from APIs
5. Update campaign status to `READY_TO_CREATE_EMAIL`
6. Handle errors by setting `ERROR` status

### 4. Event Consumers

Add to [data_fetcher.py](python/data_fetcher/data_fetcher.py):

- `poll_active_listings_events()` - New SQS consumer thread (similar to `poll_local_market_data_events`)
- `poll_recent_sales_events()` - New SQS consumer thread

### 5. Register New Threads

Update the `main()` function in [data_fetcher.py](python/data_fetcher/data_fetcher.py) to start the new event polling threads instead of the old DB polling threads.

### 6. Remove Old Polling Functions

Once validated, remove:

- `poll_for_active_listings_that_need_updated()`
- `poll_for_recent_sales_that_need_updated()`

### Key Files to Modify

| File | Changes ||------|---------|| [data_fetcher.py](python/data_fetcher/data_fetcher.py) | Add queue URL env vars, new event polling functions, update `main()` || [event_handlers.py](python/data_fetcher/event_handlers.py) | Add `handle_active_listings_event()` and `handle_recent_sales_event()` || [local-dev.env](local-dev.env) | Add `SQS_ACTIVE_LISTINGS_QUEUE_URL` and `SQS_RECENT_SALES_QUEUE_URL` || [prod.env](prod.env) | Add `SQS_ACTIVE_LISTINGS_QUEUE_URL` and `SQS_RECENT_SALES_QUEUE_URL` |

### Event Payload

The existing `STATUS_CHANGE` event published by `db_client.publish_campaign_status_change()` already contains all needed data:

```python
{
    "event_type": "STATUS_CHANGE",
    "payload": {
        "campaign_id": "...",
        "zip_code": "...",
        "from_status": "...",
        "to_status": "WAITING_FOR_DATA",
        "timestamp": "..."
    }
}

```