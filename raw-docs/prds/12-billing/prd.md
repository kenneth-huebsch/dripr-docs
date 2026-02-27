# Product Requirements Document: Stripe Billing Implementation

## 1. Introduction
**Objective:** Implement a robust billing system using Stripe to monetize the Dripr SaaS platform. The system must support standard subscription tiers, custom enterprise-style plans with metered usage, and strict feature enforcement based on subscription status.

**Status:** Draft
**Owner:** Antigravity (AI)

## 2. Problem Statement
Currently, the system allows unlimited usage (email campaigns) for free. While a Stripe integration (`python/api_gateway/stripe_routes.py`) exists, it is not enforcing limits or collecting revenue. We need to gate core features behind a paywall, enforce plan limits, and handle complex billing scenarios like upgrades, downgrades, and usage-based billing for custom plans.

## 3. Goals
-   **Monetization:** Successfully collect payments for standard and custom plans.
-   **Enforcement:** Prevent usage beyond plan limits (campaign count) and stop services for inactive/expired accounts without deleting user data.
-   **Flexibility:** Support fixed-price subscriptions and custom metered plans (per email/API call).
-   **User Experience:** Provide clear feedback on plan status, upgrade paths, and blocking actions when limits are reached.

## 4. User Stories & Requirements

### 4.1. Subscription Management & Onboarding
-   **New User Flow:** Upon logging in, users without an active plan must be redirected to the Plans/Pricing page.
-   **Navigation:** Users can navigate away from the Plans page to view the dashboard or settings, but core features (creating/editing campaigns) must be disabled or read-only.
-   **Dashboard Indicator:** A persistent visual indicator (e.g., banner or badge) must show "No Active Plan" or "Plan Expired" on the dashboard.
-   **Plan Selection:**
    -   **Standard Plans:** Users can select from defined tiers (e.g., $X/mo for Y campaigns).
    -   **Custom Plans:** Users can enter a provided "access code" string to unlock hidden, custom-configured plans.

### 4.2. Plan Enforcement & Limits
-   **Campaign Limits:**
    -   The system must check the number of *active* (enabled) campaigns against the user's plan limit.
    -   Users cannot enable more campaigns than their plan allows.
-   **Bulk Upload Limits:**
    -   When a user uploads a CSV/bulk file to create multiple campaigns, the system must validate that `(current active campaigns + number of rows in upload)` does not exceed their plan limit.
    -   **Rejection:** If the upload would exceed the limit, reject the entire upload (no partial processing).
    -   **UI Requirement:** Display a clear error message showing:
        -   Current active campaigns count
        -   Plan campaign limit
        -   Number of campaigns attempted in upload
        -   Remaining capacity (limit - active)
    -   **Example Message:** "Cannot upload 50 campaigns. You have 30/40 active campaigns (10 remaining capacity). Please disable campaigns or upgrade your plan."
-   **Downgrades:**
    -   Users cannot downgrade to a lower tier if their current active campaign count exceeds the new tier's limit.
    -   **UI Requirement:** A modal must appear explaining the conflict: "You have N active campaigns. Please disable M campaigns to downgrade to this plan."
-   **Subscription Cancellation:**
    -   **Automatic Campaign Disabling:** When a user cancels their subscription (either through the app or Stripe Customer Portal), the system must automatically disable all active campaigns.
    -   **UI Requirement:** Before cancellation, show a confirmation modal: "Canceling your subscription will disable X active campaign(s). This action cannot be undone. Continue?"
    -   **Webhook Handling:** The `customer.subscription.deleted` webhook must also disable all campaigns to handle portal cancellations.
    -   **Immediate Effect:** Campaign disabling happens immediately upon cancellation, not at period end.
-   **Cancellations & Expirations:**
    -   When a plan expires or is cancelled (at the end of the billing period), all active campaigns must effectively "pause."
    -   **Data Retention:** Campaigns are NOT deleted. Users can still view metrics, edit signatures, and access non-core features.
    -   **Sending:** No emails are sent for expired accounts.

### 4.3. Reactivation Logic
-   **Resuming Service:** When a user reactivates a plan:
    -   The system respects the originally scheduled `next_send_date` (calculated dynamically) for campaigns.
    -   **Catch-up:** If `next_send_date` is in the past, the system must trigger these sends immediately (or as soon as the next cron/worker runs).

### 4.4. Billing Models & Usage Reporting
-   **Standard Tier:** Fixed monthly price, fixed campaign quota.
-   **Custom Tier Capabilities:**
    -   **Base Price:** Different monthly fee.
    -   **Quotas:** Custom campaign limits.
    -   **Metered Billing (Usage-based):**
        -   Charge per Email Sent.
        -   Charge per API Call.
        -   Hybrid (Base + Email + API).
-   **Usage Reporting:** The system must asynchronously report usage (emails sent, API calls made) to Stripe Metered Billing endpoints.
    -   *Note:* `python/cron_jobs/usage_reporter.py` already exists and should be leveraged/updated for this.

## 5. Technical Constraints & Architecture
-   **Distributed System:** The system uses a database-driven orchestration pattern. Status checks must be implemented in the polling loops of independent services.
    -   **`data_fetcher`**: Must check subscription status before transitioning campaigns to `WAITING_FOR_DATA`.
    -   **`email_manager`**: Must check subscription status before sending emails.
    -   **`api_gateway`**: Must check limits before allowing campaign creation (`POST /campaigns`) or enabling (`PATCH /campaigns/{id}`).
-   **Database Client:** All database operations must use the `DatabaseClient` class with dependency injection as described in `CLAUDE.md`.
    -   We need to extend the `User` or `Subscription` model to store `plan_status`, `campaign_limit`, and `current_usage` to avoid hitting Stripe API on every poll.
-   **Stripe Integration:** Refactor existing `python/api_gateway/stripe_routes.py` to support the new requirements.

## 6. Open Questions
-   **Grace Periods:** Do we want to offer a grace period for failed payments before shutting off sending? (Assumed: No, strict enforcement for now).
-   **Proration:** How do we handle upgrades mid-cycle? (Assumed: Stripe default proration).
-   **Metered Billing Aggregation:** Do we report usage to Stripe in real-time or batch it? (Recommendation: Batch/Daily via `usage_reporter.py` to avoid rate limits).

## 7. Manual Test Scenarios

### 7.1. New User Onboarding
**Scenario 1: First-time user without subscription**
1. Create a new account and log in
2. Navigate to Dashboard
3. ✅ Verify "No Active Subscription" banner appears with "View Plans" button
4. Navigate to Leads page
5. ✅ Verify "No Active Subscription" banner appears
6. Try to create a new campaign
7. ✅ Verify you can access the form (not blocked)
8. Fill out campaign form and attempt to save
9. ✅ Verify error message appears: "Campaign limit reached"
10. ✅ Verify "Upgrade Plan" button appears and links to `/account`

**Scenario 2: User selects their first plan**
1. Navigate to Account/Subscription page
2. ✅ Verify "No Active Subscription" section shows
3. ✅ Verify all available plans display in pricing table
4. Click "Select Plan" on a paid plan
5. ✅ Verify redirected to Stripe Checkout
6. Complete payment in Stripe test mode
7. ✅ Verify redirected back to success page
8. Navigate to Dashboard
9. ✅ Verify "No Active Subscription" banner is GONE
10. ✅ Verify you can now create campaigns

### 7.2. Campaign Limit Enforcement
**Scenario 3: Creating campaigns within limit**
1. Log in with account that has a plan (e.g., 40 campaign limit)
2. Navigate to Subscription page
3. ✅ Verify "Campaign Usage: Active: X/40" displays correctly
4. Create campaigns until you have 39 active
5. ✅ Verify you can successfully create 1 more campaign
6. ✅ Verify usage updates to "40/40"
7. Try to create campaign #41
8. ✅ Verify error: "Campaign limit reached. You have 40/40 active campaigns."
9. ✅ Verify "Upgrade Plan" button appears

**Scenario 4: Enabling disabled campaigns at limit**
1. Have account at campaign limit (e.g., 40/40 active)
2. Navigate to Leads page
3. Disable 1 campaign
4. ✅ Verify subscription page shows "Active: 39/40 • Disabled: 1"
5. Create a new enabled campaign
6. ✅ Verify successful (now 40/40 active, 1 disabled)
7. Try to re-enable the disabled campaign
8. ✅ Verify error: "Campaign limit reached. You have 40/40 active campaigns."
9. ✅ Verify "Upgrade Plan" button appears

### 7.3. Bulk Upload Limits
**Scenario 5: Bulk upload within limit**
1. Have account with 30/40 active campaigns (10 remaining)
2. Navigate to Leads page → Bulk Upload
3. Upload CSV with 5 valid campaigns (all enabled)
4. ✅ Verify upload succeeds
5. ✅ Verify 5 campaigns created (now 35/40 active)

**Scenario 6: Bulk upload exceeding limit**
1. Have account with 35/40 active campaigns (5 remaining)
2. Navigate to Leads page → Bulk Upload
3. Upload CSV with 10 campaigns
4. ✅ Verify upload is REJECTED (no campaigns created)
5. ✅ Verify error message: "Cannot upload 10 campaigns. You have 35/40 active campaigns (5 remaining capacity). Please disable campaigns or upgrade your plan."
6. ✅ Verify all 35 original campaigns still exist (none were created)

**Scenario 7: Bulk upload exactly at limit**
1. Have account with 35/40 active campaigns (5 remaining)
2. Upload CSV with exactly 5 campaigns
3. ✅ Verify upload succeeds
4. ✅ Verify now at 40/40 active campaigns
5. Try to upload 1 more campaign
6. ✅ Verify rejected with appropriate error

### 7.4. Downgrade Prevention
**Scenario 9: Downgrade blocked by active campaigns**
1. Have account with "Growth" plan (40 campaigns) and 35 active campaigns
2. Navigate to Subscription page
3. Click "Select Plan" on "Starter" plan (10 campaigns)
4. ✅ Verify downgrade prevention modal appears
5. ✅ Verify modal shows: "You have 35 active campaigns but the Starter plan allows 10. Please disable 25 campaigns to downgrade."
6. ✅ Verify "Go to Campaigns" button navigates to Leads page
7. ✅ Verify "Cancel" button closes modal
8. ✅ Verify checkout does NOT proceed

**Scenario 10: Downgrade allowed when under limit**
1. Have account with "Growth" plan (40 campaigns) and 8 active campaigns
2. Click "Select Plan" on "Starter" plan (10 campaigns)
3. ✅ Verify NO modal appears
4. ✅ Verify redirected to Stripe Checkout
5. Complete downgrade
6. ✅ Verify subscription page shows new limit (10 campaigns)
7. ✅ Verify usage shows "Active: 8/10"

### 7.5. Subscription Status Display
**Scenario 11: Current subscription details**
1. Log in with active paid subscription
2. Navigate to Subscription page
3. ✅ Verify "Current Subscription" card shows:
   - Plan name (e.g., "Growth Plan")
   - Renewal date
   - Campaign usage (e.g., "Active: 30/40 • Disabled: 5")
4. ✅ Verify "Manage Subscription" button links to Stripe Customer Portal

**Scenario 12: Subscription after cancellation**
1. Navigate to Stripe Customer Portal (via "Manage Subscription")
2. Cancel subscription (set to cancel at period end)
3. Return to app
4. ✅ Verify subscription page shows "Cancels on [date]"
5. ✅ Verify campaigns are still active until period end
6. Wait for period end (or manually update in Stripe)
7. ✅ Verify "No Active Subscription" banner appears
8. ✅ Verify campaign limit = 0
9. ✅ Verify cannot create or enable campaigns

### 7.6. Plan Upgrades
**Scenario 13: Upgrade to higher tier**
1. Have account with "Starter" plan (10 campaigns) and 10 active campaigns
2. Try to create campaign #11
3. ✅ Verify error with "Upgrade Plan" button
4. Click "Upgrade Plan" → navigate to Subscription page
5. Select "Growth" plan (40 campaigns)
6. Complete checkout in Stripe
7. ✅ Verify subscription page updates to "Growth Plan"
8. ✅ Verify usage shows "Active: 10/40"
9. Create campaigns #11-15
10. ✅ Verify all succeed

### 7.7. Error Handling & Edge Cases
**Scenario 14: Stale Stripe data**
1. Have account with subscription canceled in Stripe (but not reflected in DB yet)
2. Navigate to Dashboard
3. ✅ Verify subscription status API call returns `active: false`
4. ✅ Verify "No Active Subscription" banner appears
5. ✅ Verify user can select new plan and checkout

**Scenario 15: Invalid Stripe customer ID**
1. Manually corrupt `stripe_customer_id` in database
2. Try to select a new plan
3. ✅ Verify checkout session creates successfully using customer email
4. Complete checkout
5. ✅ Verify subscription data updates correctly

**Scenario 16: User with zero campaigns**
1. Have account with paid plan but 0 campaigns
2. Navigate to Subscription page
3. ✅ Verify shows "Active: 0/40 • Disabled: 0"
4. Bulk upload 40 campaigns
5. ✅ Verify succeeds

**Scenario 17: Multiple users isolation**
1. Create 2 test accounts with different plans
2. Have User A at their campaign limit
3. Switch to User B
4. ✅ Verify User B can create campaigns (not affected by User A's limit)
5. ✅ Verify subscription pages show different usage for each user

### 7.8. Integration Points
**Scenario 18: Webhook handling**
1. Have active subscription
2. In Stripe Dashboard, manually trigger events:
   - `customer.subscription.updated` (change price)
   - `customer.subscription.deleted` (cancel immediately)
3. ✅ Verify app reflects changes within 30 seconds
4. ✅ Verify campaign limits update accordingly

**Scenario 19: Checkout session recovery**
1. Start checkout process but don't complete payment
2. Close browser tab
3. ✅ Verify can start new checkout session
4. Complete payment
5. ✅ Verify subscription activates correctly

## 8. Enterprise Plan Setup (Manual Process)

Enterprise plans require manual setup in Stripe and database synchronization. This process allows you to create custom-priced subscriptions without requiring customers to enter credit card information upfront.

### 8.1. Prerequisites

Before setting up an enterprise customer, ensure you have:
1. Created the custom price in Stripe Dashboard
2. Added required metadata to the price (see below)
3. Customer's email address and name

### 8.2. Required Stripe Metadata

**All enterprise prices MUST include the following metadata:**

| Key | Value | Example | Required |
|-----|-------|---------|----------|
| `campaign_limit` | Number of campaigns allowed | `2000` | ✅ Yes |

**How to add metadata to a Stripe Price:**
1. Go to [Stripe Dashboard → Products](https://dashboard.stripe.com/test/products)
2. Select your product
3. Click on the specific price
4. Scroll to **Metadata** section
5. Click **Add metadata**
6. Enter key: `campaign_limit`
7. Enter value: `2000` (or desired limit)
8. Click **Save**

**Why this is required:** The system extracts `campaign_limit` from Stripe metadata to enforce billing limits. Without this metadata, subscription creation will fail with error: `campaign_limit not found in Stripe metadata`.

### 8.3. Manual Subscription Creation Process

#### Step 1: Create Customer in Stripe (if needed)

1. Go to [Customers](https://dashboard.stripe.com/test/customers) → **Add customer**
2. Fill in:
   - **Email**: Customer's email address
   - **Name**: Customer's full name
   - **Description** (optional): Company name or notes
3. Click **Add customer**
4. **Copy the Customer ID** (format: `cus_xxxxxxxxxxxxx`)

#### Step 2: Create Subscription in Stripe

1. Open the customer's page in Stripe Dashboard
2. Click **Add subscription**
3. Select your enterprise price (ensure it has `campaign_limit` metadata)
4. Configure payment terms:
   - **Collection method**: Choose **Send invoice** (no card required)
   - **Days until due**: Set payment terms (e.g., `30` for Net 30)
   - **Trial period** (optional): Enter trial days if applicable
5. Click **Start subscription**
6. **Copy the Subscription ID** (format: `sub_xxxxxxxxxxxxx`)

#### Step 3: Update Database

You must manually sync the subscription data to your database. Connect to your database and run:

```sql
-- Replace these values with actual data
UPDATE users 
SET 
  stripe_customer_id = 'cus_xxxxxxxxxxxxx',      -- From Step 1 or 2
  stripe_subscription_id = 'sub_xxxxxxxxxxxxx',  -- From Step 2
  subscription_plan = 'price_1SWksi2epD6xa4z4m1MoQSKC',  -- Your enterprise price ID
  subscription_status = 'active',
  campaign_limit = 2000,                         -- Must match Stripe metadata
  subscription_tier = 'enterprise',
  current_period_end = '2025-12-23 23:59:59',   -- Based on billing cycle
  updated_at = NOW()
WHERE email = 'customer@example.com';            -- Customer's email
```

**Finding the values:**
- `stripe_customer_id`: From Step 1, or visible in subscription details
- `stripe_subscription_id`: From Step 2
- `subscription_plan`: The price ID (starts with `price_`)
- `campaign_limit`: Must match the `campaign_limit` in Stripe metadata
- `current_period_end`: Set to end of first billing period (subscription start date + 1 month)

#### Step 4: Verify Setup

1. Ask the customer to log in to the application
2. Navigate to **Account → Subscription**
3. Verify they see:
   - ✅ Current plan: "Enterprise" or custom name
   - ✅ Campaign usage: "0/2000" (or their limit)
   - ✅ No "No Active Subscription" banner
4. Test creating a campaign
5. ✅ Verify campaign creation succeeds

### 8.4. Common Issues & Troubleshooting

**Issue**: Customer gets error "campaign_limit not found in Stripe metadata"
- **Solution**: Add `campaign_limit` metadata to the Stripe price (see Section 8.2)

**Issue**: Customer sees "No Active Subscription" banner
- **Solution**: Verify database `subscription_status = 'active'` and `stripe_subscription_id` matches Stripe

**Issue**: Customer can't create campaigns
- **Solution**: Check `campaign_limit` in database is > 0 and matches Stripe metadata

**Issue**: Subscription doesn't appear in app after Stripe creation
- **Solution**: Database sync is manual - run the SQL UPDATE query from Step 3

### 8.5. Alternative: Invoice-Based Billing

For customers who will pay by invoice after service:

1. Create subscription with **Collection method: Send invoice**
2. Set **Days until due**: 30 (or your payment terms)
3. Stripe will:
   - Create an invoice automatically each billing cycle
   - Email invoice to customer
   - Wait for manual payment (bank transfer, check, etc.)
   - You mark invoice as paid in Stripe when received

**No credit card required** - perfect for enterprise contracts.

### 8.6. Webhook Sync

Once the subscription is created in Stripe, future updates will sync automatically via webhooks:
- ✅ Subscription renewals
- ✅ Invoice payments
- ✅ Cancellations
- ✅ Plan changes

You only need to manually update the database for the **initial subscription creation**.

## 9. Next Steps
1.  Review and approve this PRD.
2.  Create Technical Design Document (TDD) mapping these requirements to the `python/` services and database schema.
3.  Begin implementation.
