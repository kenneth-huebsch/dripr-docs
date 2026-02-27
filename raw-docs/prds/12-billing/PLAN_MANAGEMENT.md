# Plan Management Guide

This document explains how to add, modify, or remove subscription plans in Dripr.

## Overview

The billing system uses Stripe for payment processing and enforces campaign limits based on subscription plans. Plan configuration is split between **Stripe Dashboard**, **Environment Variables**, and **Code**.

---

## Table of Contents

1. [How Plans Work](#how-plans-work)
2. [Adding a New Standard Plan](#adding-a-new-standard-plan)
3. [Adding a Custom/Enterprise Plan](#adding-a-customenterprise-plan)
4. [Changing Campaign Limits](#changing-campaign-limits)
5. [Changing Prices](#changing-prices)
6. [Testing Plan Changes](#testing-plan-changes)

---

## How Plans Work

### Plan Types

1. **Standard Plans** (Starter, Pro)
   - Defined in environment variables
   - Hardcoded tier names in code
   - Require code changes to add new tiers

2. **Custom/Enterprise Plans**
   - Any Stripe Price ID can be used
   - Automatically categorized as `subscription_tier='undefined'`
   - No code changes needed

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **Stripe Price** | Defines price amount, billing interval | Stripe Dashboard |
| **Price Metadata** | Stores `campaign_limit` | Stripe Dashboard |
| **Environment Variables** | Maps plan names to Price IDs | `.env` file |
| **Tier Logic** | Determines tier name from Price ID | `stripe_routes.py` |

---

## Adding a New Standard Plan

### Example: Adding "Premium" Plan

#### Step 1: Create Price in Stripe

1. Go to [Stripe Dashboard → Products](https://dashboard.stripe.com/products)
2. Create a new Product: "Dripr Premium"
3. Add a Price:
   - Amount: e.g., $49/month
   - Billing: Recurring, monthly
4. **CRITICAL**: Add metadata to the Price:
   ```
   Key: campaign_limit
   Value: 50
   ```
5. Copy the Price ID (e.g., `price_abc123premium`)

#### Step 2: Add Environment Variable

Add to `.env`, `prod.env`, and `local-dev.env`:

```bash
STRIPE_PRICE_ID_PREMIUM_MONTHLY=price_abc123premium
```

#### Step 3: Update Code - `stripe_routes.py`

**Location:** `python/api_gateway/stripe_routes.py`

**A. Add to STRIPE_PRICE_IDS dictionary (line ~40):**

```python
STRIPE_PRICE_IDS = {
    'starter-monthly': os.getenv('STRIPE_PRICE_ID_STARTER_MONTHLY'),
    'pro-monthly': os.getenv('STRIPE_PRICE_ID_PRO_MONTHLY'),
    'premium-monthly': os.getenv('STRIPE_PRICE_ID_PREMIUM_MONTHLY'),  # NEW
}
```

**B. Add validation (line ~45):**

```python
if not STRIPE_PRICE_IDS['starter-monthly'] or not STRIPE_PRICE_IDS['pro-monthly'] or not STRIPE_PRICE_IDS['premium-monthly']:
    error_text = "STRIPE_PRICE_ID_STARTER_MONTHLY, STRIPE_PRICE_ID_PRO_MONTHLY, and STRIPE_PRICE_ID_PREMIUM_MONTHLY must be set"
    Logger.logger.error(error_text)
    raise Exception(error_text)
```

**C. Update `get_campaign_limit_and_tier_from_price()` function (line ~70):**

```python
# Determine subscription tier
if price_id in STRIPE_PRICE_IDS.values():
    # Standard plan - find which one
    if price_id == STRIPE_PRICE_IDS['starter-monthly']:
        subscription_tier = 'starter'
    elif price_id == STRIPE_PRICE_IDS['pro-monthly']:
        subscription_tier = 'pro'
    elif price_id == STRIPE_PRICE_IDS['premium-monthly']:  # NEW
        subscription_tier = 'premium'                        # NEW
    else:
        error_text = f"Invalid price ID {price_id}"
        Logger.logger.error(error_text)
        raise Exception(error_text)
else:
    # Custom/enterprise plan
    subscription_tier = 'undefined'
```

#### Step 4: Deploy

```bash
# Build and push to ECR
./build-and-push-to-aws.sh all release-YYYYMMDD-HHMM

# Deploy to Lightsail
./deploy-with-logging.sh release-YYYYMMDD-HHMM
```

#### Step 5: Update Frontend (Optional)

If you want the plan to appear in the UI, update:
- `ui/src/pages/Subscription.tsx` or equivalent pricing page
- Add plan card/button with the new plan ID `'premium-monthly'`

---

## Adding a Custom/Enterprise Plan

Custom plans are **much simpler** - no code changes needed!

### Steps:

1. **Create Price in Stripe Dashboard**
   - Create a Product (e.g., "Dripr Enterprise - Acme Corp")
   - Add a Price with any amount/interval
   - **CRITICAL**: Add metadata:
     ```
     Key: campaign_limit
     Value: 100
     ```
   - Copy the Price ID (e.g., `price_xyz789custom`)

2. **Share Price ID with Customer**
   - Customer enters this Price ID as an "access code" in the UI
   - System automatically:
     - Validates the Price ID exists
     - Extracts `campaign_limit` from metadata
     - Sets `subscription_tier='undefined'`

3. **Done!** No deployment needed.

---

## Changing Campaign Limits

### For Existing Subscriptions

#### Option A: Update Stripe Metadata (Recommended)

1. Go to [Stripe Dashboard → Products](https://dashboard.stripe.com/products)
2. Find the Product → Click the Price
3. Scroll to **Metadata**
4. Update `campaign_limit` value
5. **Important**: Changes take effect on the next webhook event:
   - When user upgrades/downgrades
   - When subscription renews
   - NOT immediately for active subscriptions

#### Option B: Update Database Directly (Immediate)

⚠️ **Use with caution - bypasses Stripe as source of truth**

```sql
-- Update specific user
UPDATE users 
SET campaign_limit = 100 
WHERE id = 'user_id_here';

-- Update all users on a specific tier
UPDATE users 
SET campaign_limit = 50 
WHERE subscription_tier = 'pro';
```

### For New Subscriptions

Just update the Stripe metadata - all new subscriptions will use the new limit.

---

## Changing Prices

### Stripe Best Practice: Create New Price

Stripe recommends creating a **new Price** rather than modifying existing ones:

1. **Create New Price** with updated amount
2. **Add metadata**: `campaign_limit` with the same value
3. **Update Environment Variable** to point to new Price ID:
   ```bash
   STRIPE_PRICE_ID_PRO_MONTHLY=price_NEW_ID_HERE
   ```
4. **Deploy**

### Migrating Existing Customers

Existing customers stay on their old price until they:
- Cancel and resubscribe
- Or, you manually migrate them in Stripe Dashboard

---

## Testing Plan Changes

### Test Checklist

#### 1. Test New Plan Creation
```bash
# Create a test mode price in Stripe
# Use Stripe test card: 4242 4242 4242 4242
```

- [ ] Metadata `campaign_limit` is present
- [ ] Checkout session creates successfully
- [ ] Webhook updates user's `campaign_limit` correctly
- [ ] `subscription_tier` is set correctly

#### 2. Test Campaign Enforcement
- [ ] Create campaign when at limit → Should fail with clear error
- [ ] Enable campaign when at limit → Should fail
- [ ] Create campaign when under limit → Should succeed

#### 3. Test Downgrade Check
```bash
curl -X POST https://api.dripr.ai/api/stripe/check-downgrade \
  -H "Authorization: Bearer YOUR_CLERK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"target_price_id": "price_test_123"}'
```

Expected response:
```json
{
  "allowed": false,
  "current_active_campaigns": 8,
  "target_campaign_limit": 5,
  "campaigns_to_disable": 3
}
```

#### 4. Test Webhook Events

Use [Stripe CLI](https://stripe.com/docs/stripe-cli) to trigger test webhooks:

```bash
# Test subscription created
stripe trigger checkout.session.completed

# Test subscription updated
stripe trigger customer.subscription.updated

# Test subscription canceled
stripe trigger customer.subscription.deleted
```

Verify in database:
```sql
SELECT id, email, campaign_limit, subscription_tier, subscription_status 
FROM users 
WHERE email = 'test@example.com';
```

---

## Configuration Reference

### Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `STRIPE_SECRET_KEY` | Stripe API authentication | `sk_live_...` |
| `STRIPE_WEBHOOK_SECRET` | Webhook signature verification | `whsec_...` |
| `STRIPE_PRICE_ID_STARTER_MONTHLY` | Maps 'starter-monthly' to Price ID | `price_abc123` |
| `STRIPE_PRICE_ID_PRO_MONTHLY` | Maps 'pro-monthly' to Price ID | `price_def456` |

### Database Fields

| Field | Type | Purpose |
|-------|------|---------|
| `users.campaign_limit` | Integer | Max enabled campaigns (enforced) |
| `users.subscription_tier` | String | Plan name (starter, pro, undefined, none) |
| `users.subscription_status` | String | Stripe status (active, canceled, etc.) |
| `users.subscription_plan` | String | Stripe Price ID |

### Stripe Price Metadata

**Required Metadata on EVERY Price:**

```
campaign_limit: <integer>
```

**Example Configurations:**

| Plan | Price/Month | campaign_limit |
|------|-------------|----------------|
| Starter | $19 | 5 |
| Pro | $49 | 20 |
| Enterprise | Custom | Custom (e.g., 100, 500, unlimited=9999) |

---

## Troubleshooting

### Error: "campaign_limit not found in Stripe metadata"

**Cause:** Price is missing required metadata.

**Fix:**
1. Go to Stripe Dashboard
2. Find the Price
3. Add metadata: `campaign_limit = <number>`

### Users Can Create More Campaigns Than Their Limit

**Possible Causes:**
1. Webhook didn't fire → Check Stripe webhook logs
2. Database not updated → Check `users.campaign_limit` in DB
3. Enforcement not deployed → Verify code is deployed

**Fix:**
```sql
-- Check current limit
SELECT email, campaign_limit, subscription_tier 
FROM users 
WHERE id = 'user_id';

-- Manually trigger limit update (temporary fix)
UPDATE users 
SET campaign_limit = 5 
WHERE id = 'user_id';
```

### New Plan Not Showing Up

**Checklist:**
- [ ] Environment variable set in `.env`
- [ ] Code updated in `stripe_routes.py`
- [ ] Code deployed to production
- [ ] Frontend updated (if needed)
- [ ] Stripe Price has `campaign_limit` metadata

---

## Migration Strategy

### Changing All Users from Plan A to Plan B

```sql
-- Step 1: Review users on old plan
SELECT id, email, subscription_tier, campaign_limit 
FROM users 
WHERE subscription_tier = 'starter';

-- Step 2: Update (if migrating limits)
UPDATE users 
SET campaign_limit = 10, subscription_tier = 'pro'
WHERE subscription_tier = 'starter';
```

⚠️ **Warning:** This doesn't change their Stripe subscription. They'll still be charged the old price until they manually change plans.

---

## Quick Reference

### Add Standard Plan
1. Create Stripe Price with metadata
2. Add env var: `STRIPE_PRICE_ID_X_MONTHLY`
3. Update `STRIPE_PRICE_IDS` dict
4. Update validation
5. Update `get_campaign_limit_and_tier_from_price()`
6. Deploy

### Add Custom Plan
1. Create Stripe Price with metadata
2. Share Price ID with customer
3. Done!

### Change Limit
1. Update Stripe metadata
2. Wait for next webhook OR update DB directly

### Change Price
1. Create new Price in Stripe
2. Update env var
3. Deploy

---

## Support

If you encounter issues:

1. Check CloudWatch logs: `/aws/lightsail/containers/dripr-container-service/api_gateway`
2. Check Stripe webhook logs: [Stripe Dashboard → Webhooks](https://dashboard.stripe.com/webhooks)
3. Verify database state:
   ```sql
   SELECT * FROM users WHERE id = 'user_id';
   ```

For questions, contact the development team.

