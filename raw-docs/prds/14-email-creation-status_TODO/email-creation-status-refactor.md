# Email Creation Status Refactor

## Problem Statement

Currently, when the email manager picks up a campaign ready for email creation, it sets `campaign_status = FETCHING` as a lock mechanism to prevent duplicate processing by concurrent workers.

**Location:** `python/shared_resources/db_client.py`, line ~878 in `get_campaign_ready_to_create_email()`

```python
campaign.campaign_status = Status.FETCHING  # Mark as fetching to lock it for this transaction
```

### Why This Is Problematic

1. **Semantic confusion**: `FETCHING` implies data is being fetched from external APIs, not that an email is being built
2. **Inconsistent with documented state machine**: CLAUDE.md documents `FETCHING` as part of the data fetching phase (step 3), not email creation
3. **Misleading**: When debugging, seeing `campaign_status = FETCHING` suggests data fetching is in progress, not email building

### Why The Lock Is Necessary

The `FETCHING` status (or any equivalent) **is required** for concurrency control:

1. `with_for_update(skip_locked=True)` provides a short-term row lock during the SELECT
2. After `session.commit()`, the row lock is released
3. `build_email(campaign)` executes AFTER the session is closed (takes seconds/minutes)
4. Without an application-level lock status, another worker could pick up the same campaign and create duplicate emails

**Race condition without lock status:**
```
1. Worker A: Gets campaign (READY_TO_CREATE_EMAIL), row locked
2. Worker A: session.commit() → row lock RELEASED
3. Worker A: Starts build_email()
4. Worker B: Gets SAME campaign (still READY_TO_CREATE_EMAIL)  ← RACE!
5. Both workers create duplicate emails
```

---

## Proposed Solution

Add a new `CREATING_EMAIL` status value to the `Status` enum instead of reusing `FETCHING`.

### Changes Required

#### 1. Update Status Enum (`python/shared_resources/models.py`)

```python
class Status(Enum):
    DORMANT = 'DORMANT'
    WAITING_FOR_DATA = 'WAITING_FOR_DATA'
    FETCHING = 'FETCHING'  # currently fetching data from external APIs
    READY_TO_CREATE_EMAIL = 'READY_TO_CREATE_EMAIL'
    CREATING_EMAIL = 'CREATING_EMAIL'  # NEW - building email content, acts as lock
    WAITING_FOR_MANUAL_APPROVAL = 'WAITING_FOR_MANUAL_APPROVAL'
    READY_TO_SEND_EMAIL = 'READY_TO_SEND'
    SENT = 'SENT'
    UNSUBSCRIBED = 'UNSUBSCRIBED'
    ERROR = 'ERROR'
```

#### 2. Update db_client.py (`get_campaign_ready_to_create_email`)

Change line ~878 from:
```python
campaign.campaign_status = Status.FETCHING
```

To:
```python
campaign.campaign_status = Status.CREATING_EMAIL
```

#### 3. Update CLAUDE.md State Machine Documentation

Add `CREATING_EMAIL` to the documented campaign state flow:
```
READY_TO_CREATE_EMAIL → CREATING_EMAIL → WAITING_FOR_MANUAL_APPROVAL / READY_TO_SEND_EMAIL
```

#### 4. Update edit_campaign Validation (`db_client.py`, line ~1880)

The validation that prevents editing campaigns in progress should include the new status:
```python
if (
    campaign.campaign_status == Status.WAITING_FOR_DATA
    or campaign.campaign_status == Status.FETCHING
    or campaign.campaign_status == Status.CREATING_EMAIL  # ADD THIS
    or campaign.campaign_status == Status.READY_TO_CREATE_EMAIL
    or campaign.campaign_status == Status.WAITING_FOR_MANUAL_APPROVAL
):
```

---

## Alternative Considered (Not Recommended)

**Option: Add new `email_building_status` field**

This was considered to match the sub-status pattern (`property_status`, `active_listing_status`, etc.) but rejected because:

1. Sub-statuses exist for **parallel** data fetching operations
2. Email building is **sequential**, not parallel
3. Would require a database migration
4. Adds unnecessary complexity for a single lock state
5. Would require updating two fields instead of one

---

## Impact Assessment

- **Risk**: Low - new enum value, minimal code changes
- **Migration**: None required - MySQL stores enum as string, new value just works
- **Testing**: Verify email_manager correctly transitions through new status
- **Backward compatibility**: Existing campaigns won't have `CREATING_EMAIL` status, no impact

---

## Files to Modify

1. `python/shared_resources/models.py` - Add `CREATING_EMAIL` to Status enum
2. `python/shared_resources/db_client.py` - Use new status in `get_campaign_ready_to_create_email()` and edit validation
3. `CLAUDE.md` - Update state machine documentation

