# Implementation Plan - Stripe Billing & Enforcement

## TODO - Manual Steps
> [!WARNING]
> **Database Migration Required:** Run the migration `b2c3d4e5f6a7_add_campaign_limit_and_subscription_tier.py` manually:
> ```bash
> cd python
> alembic upgrade head
> ```
> This will add `campaign_limit` and `subscription_tier` columns and set existing users to 9999 limit.

# Goal Description
Implement a robust billing system that enforces subscription limits (campaign counts) and handles custom enterprise plans. The system will prevent users from exceeding their plan limits and ensure that downgrades are blocked if usage exceeds the new plan's limits.

## User Review Required
> [!IMPORTANT]
> **Downgrade Logic:** We will implement a pre-check endpoint `/api/stripe/check-downgrade` that the frontend must call before allowing a user to select a lower tier plan. If the check fails, the frontend will show a modal requiring the user to disable campaigns.

> [!WARNING]
> **Database Migration:** We are adding `campaign_limit` to the `users` table. Existing users will need a default value (e.g., 0 or a "grandfathered" limit). I will set the default to 0 for now, assuming all current users should be on a plan.

## Proposed Changes

### Database Schema
#### [MODIFY] [models.py](file:///d:/Repositories/dripr/python/shared_resources/models.py)
- Add `campaign_limit` (Integer) to `User` model.
- Add `subscription_tier` (String) to `User` model (optional, but helpful for quick lookups).

### Database Migration Strategy
> [!IMPORTANT]
> **Existing Users:** To prevent service disruption, the migration script will:
> 1. Add the `campaign_limit` column with a default of `0`.
> 2. Execute an update statement to set `campaign_limit = 9999` for all *existing* users.
> 3. New users created after this migration will default to `0` until they subscribe.

### Shared Resources
#### [MODIFY] [db_client.py](file:///d:/Repositories/dripr/python/shared_resources/db_client.py)
- Update `create_user` to initialize `campaign_limit`.
- Update `update_user_subscription` to set `campaign_limit` based on the plan.
- Add method `get_active_campaign_count(user_id)` to efficiently count enabled campaigns.

### API Gateway (Enforcement)
#### [MODIFY] [api_gateway.py](file:///d:/Repositories/dripr/python/api_gateway/api_gateway.py)
- **`create_campaign`**: Add check: `if active_campaigns >= user.campaign_limit: raise Exception("Plan limit reached")`.
- **`edit_campaign`**: When `enabled` is being set to `True`, add the same check.

### Stripe Integration
#### [MODIFY] [stripe_routes.py](file:///d:/Repositories/dripr/python/api_gateway/stripe_routes.py)
- **`webhook`**: When `customer.subscription.updated` or `created` events occur, determine the `campaign_limit`:
    - **Stripe Metadata (Required):** Check the Stripe Price metadata for a key `campaign_limit`.
    - **Fail Fast:** If `campaign_limit` is missing from metadata, log a critical error `campaign_limit not found in Stripe metadata for price {price_id}` and do NOT update the user's limit (or set to 0/safe default and alert).
    - Update the user's `campaign_limit` in the database.
- **[NEW] Endpoint `/api/stripe/check-downgrade`**:
    - Input: `target_plan_id`
    - Logic: Get `target_limit`. Get `current_active_campaigns`. If `current > target`, return `{allowed: False, current: X, limit: Y}`.

### Managed Service / No-CC Support
- **Manual Override:** For users managed out-of-band (no credit card), you can manually set their `campaign_limit` in the database (e.g., via SQL or a future admin script).
- **Persistence:** Since these users will not have active Stripe subscriptions, the Stripe webhook will never fire for them, ensuring their manually set limit is never overwritten by the system.

## User Responsibilities
> [!IMPORTANT]
> **Action Required:** Before deploying these changes, you must update your Stripe configuration:
> 1.  **Update Stripe Prices:** Go to the Stripe Dashboard -> Product Catalog.
> 2.  **Add Metadata:** For *every* Price ID (Starter, Pro, Custom), add a metadata key `campaign_limit` with the integer value (e.g., `5`, `20`).
> 3.  **Verify:** Ensure all active prices have this metadata, otherwise subscription updates will fail/log errors.

## Verification Plan

### Automated Tests
- **Unit Tests (`tests/test_billing.py`)**:
    - Test `create_campaign` fails when limit is reached.
    - Test `edit_campaign` fails when enabling beyond limit.
    - Test `check_downgrade` logic.
    - Test webhook updates `campaign_limit` correctly.

### Manual Verification
1.  **New User Flow**: Sign up -> Try to create campaign -> Should fail (Limit 0).
2.  **Upgrade**: Subscribe to Starter -> Limit becomes 5 -> Create 5 campaigns -> Success.
3.  **Limit Hit**: Try to create 6th campaign -> Fail.
4.  **Downgrade Block**: Try to downgrade to a plan with limit 3 -> Should see Modal.
5.  **Downgrade Success**: Disable 3 campaigns -> Downgrade -> Success.
