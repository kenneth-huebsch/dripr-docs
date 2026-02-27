<!-- 3a4b9823-9a42-43dc-be9f-5afa303c4382 63c5384c-8af7-4f17-bcec-11171f3ed7e7 -->
# No-Address Newsletter Implementation Plan

## Overview

Add support for campaigns that only require client name, email, and zip code (no property address). These campaigns will show market data, recent sales, and active listings for the zip code area, but exclude the "Your Home" section.

## Database Changes

### 1. Create Migration for Campaign Table

**File**: New migration in `python/migrations/versions/`

Add two new columns to `campaigns` table:

- `no_address_newsletter` (Integer, default=0): 0 = with home valuation, 1 = no-address campaign
- `zip_code` (String(16), NOT NULL): Store zip code for all campaigns (provides flexibility to switch types in future)

Migration steps for campaigns table:

1. Add `no_address_newsletter` column (Integer, default=0)
2. Add `zip_code` column (String(16), nullable=True temporarily)
3. Backfill existing campaigns: Copy zip_code from associated property_data records
4. Make `zip_code` column NOT NULL after backfill

### 2. Add campaign_id to active_listings and recent_sales

**Files**: Same migration file

Add campaign_id column and backfill data:

For `active_listings` table:

1. Add `campaign_id` column (String(64), nullable=True temporarily)
2. Backfill: Copy campaign_id from property_data based on parent_property_id
3. Make `campaign_id` NOT NULL after backfill
4. Add index: `idx_active_listing_campaign_id`

For `recent_sales` table:

1. Add `campaign_id` column (String(64), nullable=True temporarily)
2. Backfill: Copy campaign_id from property_data based on parent_property_id
3. Make `campaign_id` NOT NULL after backfill
4. Add index: `idx_recent_sale_campaign_id`

Note: Keep `parent_property_id` columns for now (backward compatibility during rollout).

### 3. Update Models

**File**: `python/shared_resources/models.py`

Update `Campaign`, `ActiveListing`, and `RecentSale` model classes with new columns.

## Backend Changes

### 4. Update API Gateway - Campaign Creation

**File**: `python/api_gateway/api_gateway.py`

Modify `create_campaign()` function (line 217-248):

- Accept optional `no_address_newsletter` and `zip_code` parameters
- When `no_address_newsletter=1`, skip property address validation
- When `no_address_newsletter=0`, extract zip_code from formatted_address (for PropertyData) but also store directly on Campaign
- Pass these to `create_campaign_in_db()`

Modify `create_campaign_endpoint()` (line 250-297):

- Extract `no_address_newsletter` and `zip_code` from request body
- Update validation logic: 
- If `no_address_newsletter=1`, require zip_code instead of formatted_address
- If `no_address_newsletter=0` or not provided, require formatted_address (current behavior)

### 5. Update API Gateway - Campaign Editing

**File**: `python/api_gateway/api_gateway.py`

Modify `edit_campaign_endpoint()` (line 299-341):

- Do NOT allow changing `no_address_newsletter` (locked once created)
- Conditionally validate address vs zip_code based on campaign's existing `no_address_newsletter` value

### 6. Update Database Client - Campaign Creation

**File**: `python/shared_resources/db_client.py`

Modify `create_campaign_in_db()` (line 175-227):

- Add `no_address_newsletter` and `zip_code` parameters (zip_code required for both types)
- For `no_address_newsletter=0` (default): Create PropertyData as current behavior, store zip_code on Campaign
- For `no_address_newsletter=1`: Skip PropertyData creation, store zip_code on Campaign, set property_status to READY_TO_CREATE_EMAIL (skip property workflow, but keep intro workflow)

### 7. Update Database Client - Query Functions

**File**: `python/shared_resources/db_client.py`

Refactor all listing/sales query functions to use campaign_id instead of property_id:

- Rename `get_active_listings_by_property_id(property_id)` → `get_active_listings_by_campaign_id(campaign_id)` - query by campaign_id
- Rename `get_recent_sales_by_property_id(property_id)` → `get_recent_sales_by_campaign_id(campaign_id)` - query by campaign_id
- Rename `get_most_expensive_active_listing_by_property_id(property_id)` → `get_most_expensive_active_listing_by_campaign_id(campaign_id)` - query by campaign_id
- Rename `delete_active_listings_by_property_id(property_id)` → `delete_active_listings_by_campaign_id(campaign_id)` - delete by campaign_id
- Rename `delete_recent_sales_by_property_id(property_id)` → `delete_recent_sales_by_campaign_id(campaign_id)` - delete by campaign_id

Delete unused/broken function:

- Remove `delete_local_market_data_by_property_id()` - unused and broken (LocalMarketData is keyed by zip_code, not property)

Update all callers throughout the codebase to use new function names and pass campaign_id instead of property_id.

Update `campaign_to_campaign_details_data()` to handle campaigns without PropertyData (when `no_address_newsletter=1`).

### 8. Refactor RentCast API Functions

**File**: `python/shared_resources/rentcast_api_client.py`

Modify existing functions to accept lat/lng directly instead of PropertyData:

- `fetch_recent_sale_data_from_rentcast(lat, lng, radius)`: Change from accepting PropertyData to lat/lng/radius parameters
- `fetch_active_listing_data_from_rentcast(lat, lng, radius)`: Change from accepting PropertyData to lat/lng/radius parameters  
- `get_recent_sale_data(lat, lng, radius)`: Update signature to remove PropertyData dependency
- `get_active_listing_data(lat, lng, radius)`: Update signature to remove PropertyData dependency

### 9. Update API Client - Ordering Functions

**File**: `python/shared_resources/api_client.py`

Refactor ordering functions to accept individual data parameters instead of PropertyData:

- `order_active_listings(zip_code, houses_list, current_value=None, house_number=None)`:
- Accept zip_code (required) for radius calculation and zip matching
- Accept current_value (optional) for 10% price filtering
- Accept house_number (optional) to exclude recipient's house
- When current_value is None: Skip price filtering, sort by recency (newest first per PRD) then distance
- When house_number is None: Skip house_number exclusion

- `order_recent_sales(zip_code, houses_list, current_value=None, house_number=None)`: Apply same pattern

### 10. Update API Client - Listing Retrieval Functions

**File**: `python/shared_resources/api_client.py`

Refactor existing functions to accept individual data parameters:

- `get_active_listings(lat, lng, radius, campaign_id, zip_code, parent_property_id=None, current_value=None, house_number=None)`:
- Accept lat/lng coordinates directly
- Call refactored rentcast functions with lat/lng
- Pass individual params to ordering functions
- Set campaign_id on all returned ActiveListing objects
- Set parent_property_id if provided

- `get_recent_sales(lat, lng, radius, campaign_id, zip_code, parent_property_id=None, current_value=None, house_number=None)`: Apply same pattern

### 11. Update Data Fetcher - Active Listings

**File**: `python/data_fetcher/data_fetcher.py`

Modify `poll_for_active_listings_that_need_updated()` (line 59-101):

- Query campaign to check `no_address_newsletter` flag
- For `no_address_newsletter=0`: 
- Get PropertyData
- Extract: lat, lng from PropertyData; campaign_id from campaign; zip_code, parent_property_id, current_value, house_number from PropertyData
- Call `get_active_listings(lat, lng, radius, campaign_id, zip_code, parent_property_id, current_value, house_number)`
- Delete existing listings by campaign_id (using renamed function)
- For `no_address_newsletter=1`: 
- Look up lat/lng from ZipCode table using campaign.zip_code
- Call `get_active_listings(lat, lng, radius, campaign.id, campaign.zip_code, parent_property_id=None, current_value=None, house_number=None)`
- Delete existing listings by campaign_id
- Store listings with campaign_id set (no parent_property_id)

### 12. Update Data Fetcher - Recent Sales

**File**: `python/data_fetcher/data_fetcher.py`

Modify `poll_for_recent_sales_that_need_updated()` (line 104-147):

- Query campaign to check `no_address_newsletter` flag
- Apply same parameter extraction pattern as active_listings
- For `no_address_newsletter=0`: Extract all params from PropertyData
- For `no_address_newsletter=1`: Use campaign.zip_code, pass None for property-specific params

### 13. Update Data Fetcher - Status Management and Intro Generation

**File**: `python/data_fetcher/data_fetcher.py` and `python/shared_resources/db_client.py`

Modify status check functions:

- `get_campaign_ready_for_active_listings()`: Include `no_address_newsletter=1` campaigns, skip property_status check for them
- `get_campaign_ready_for_recent_sales()`: Include `no_address_newsletter=1` campaigns, skip property_status check for them
- `get_campaign_ready_for_home_report_analysis()`: Include `no_address_newsletter=1` campaigns (will generate intro only, not home_report_analysis)
- `edit_campaigns_status_that_are_ready_for_email_creation()`: For `no_address_newsletter=1`, check all statuses including intro_and_home_report_analysis_status

**File**: `python/data_fetcher/data_fetcher.py`

Modify `poll_for_home_report_analysis_and_intro()` (line 210-258):

- Query campaign to check `no_address_newsletter` flag
- For `no_address_newsletter=0`: Use existing flow with PropertyData
- For `no_address_newsletter=1`:
- Skip PropertyData retrieval
- Pass campaign to bedrock client for intro generation
- Only generate intro, set home_report_analysis to empty string

### 14. Update Bedrock Client for No-Address Campaigns

**File**: `python/shared_resources/bedrock_client.py`

Modify `get_data_from_bedrock()` (line 221-290):

- Accept campaign parameter and check `no_address_newsletter` flag
- For `no_address_newsletter=0`: Use existing logic (generate both intro and home_report_analysis with PropertyData)
- For `no_address_newsletter=1`:
- Use `1st-intro-no-address.txt` prompt instead of `1st-intro.txt`
- Skip home_report_analysis prompts entirely
- Don't require PropertyData
- Use campaign.zip_code and local_market_data for context
- Return dict with intro field only, set home_report_analysis to empty string

Modify `update_db_with_home_report_analysis_and_intro()` (line 293-302):

- Accept campaign parameter
- Pass campaign to `get_data_from_bedrock()`

### 15. Create New Intro Prompt

**File**: `python/shared_resources/prompts/1st-intro-no-address.txt`

Create file with placeholder text: "PLACEHOLDER: User will provide prompt for new lead intro (non-homeowner focus). LLM will return intro in same JSON format as current address-based newsletters."

### 16. Update Email Builder - Data Retrieval

**File**: `python/email_manager/email_builder.py`

Modify `get_data_from_db_to_populate_email_template()` (line 33-97):

- Check campaign's `no_address_newsletter` flag
- Make property retrieval conditional: only get PropertyData if `no_address_newsletter=0`
- For `no_address_newsletter=1`: 
- Set property to None
- Query listings/sales using renamed functions with campaign_id
- Get zip_code from campaign.zip_code for local_market_data lookup

Update `EmailTemplateData` TypedDict to make PropertyData optional.

### 17. Update Email Builder - Template Population

**File**: `python/email_manager/email_builder.py`

Modify `populate_json_struct_with_db_data()` (line 230-337):

- Add conditional checks for property being None
- Set subject line based on whether property exists:
- If property exists: "Home Report for: {property.formatted_address}!"
- If property is None: "Your Real Estate Market Update for {zip_code}!"
- Skip/omit "Your Home" section fields when property is None:
- formatted_address, current_value, img_url, value_change_percent, home_report_analysis, depreciation
- Get zip_code from campaign.zip_code when property is None

### 18. Update Email Template

**File**: `python/email_manager/html_generator.py` or template file

Ensure Handlebars template has conditional logic ({{#if property}}) or add it to skip rendering "Your Home" section when property data fields are absent.

## Frontend Changes

### 19. Update TypeScript Types

**File**: `ui/src/types.ts`

Add to campaign types:

- `no_address_newsletter?: number`
- `zip_code?: string`

### 20. Update Campaign Form Component

**File**: `ui/src/components/CampaignForm.tsx`

Add toggle switch for "Include Home Valuation" (default: OFF = `no_address_newsletter=0`):

- When toggle is OFF (`no_address_newsletter=0`): Show `formatted_address` field, hide `zip_code` field
- When toggle is ON (`no_address_newsletter=1`): Hide `formatted_address` field, show `zip_code` input field
- For editing mode: Disable the toggle (campaign type locked once created)
- Add validation for zip_code format (5 digits)

### 21. Update Create Campaign Page

**File**: `ui/src/pages/CreateCampaign.tsx`

- Add `no_address_newsletter` to initial state (default: 0)
- Add `zip_code` to initial state (default: '')
- Update validation logic:
- If `no_address_newsletter=0`: require formatted_address, optionally accept zip_code (will be extracted from address if not provided)
- If `no_address_newsletter=1`: require zip_code
- Include both fields in API request

### 22. Update Campaign Details Page

**File**: `ui/src/pages/CampaignDetails.tsx`

- Display campaign type indicator as read-only badge
- Conditionally show zip_code or formatted_address based on `no_address_newsletter` value
- Conditionally display property-related fields only for `no_address_newsletter=0` campaigns
- Ensure toggle is disabled in edit mode

## Testing Considerations

- Test campaign creation for both types via UI
- Test that `no_address_newsletter=1` campaigns skip PropertyData creation
- Test data fetcher polling for both campaign types with updated function signatures
- Verify intro generation works for no-address campaigns using new prompt
- Verify email generation excludes "Your Home" section for no-address campaigns
- Test that campaign type cannot be changed after creation
- Verify proper zip code validation
- Test edge cases: invalid zip codes, zip codes not in ZipCode table
- Test ordering functions with and without property-specific params
- Verify listings are sorted by recency first for no-address campaigns
- Verify migration properly backfills campaign_id on existing listings/sales

## Key Files Modified

**Backend**:

- Migration file (new)
- `python/shared_resources/models.py`
- `python/api_gateway/api_gateway.py`
- `python/shared_resources/db_client.py`
- `python/data_fetcher/data_fetcher.py`
- `python/shared_resources/api_client.py`
- `python/shared_resources/rentcast_api_client.py`
- `python/shared_resources/bedrock_client.py`
- `python/email_manager/email_builder.py`
- `python/shared_resources/prompts/1st-intro-no-address.txt` (new)

**Frontend**:

- `ui/src/types.ts`
- `ui/src/components/CampaignForm.tsx`
- `ui/src/pages/CreateCampaign.tsx`
- `ui/src/pages/CampaignDetails.tsx`

### To-dos

- [ ] Create database migration for campaign.no_address_newsletter, campaign.zip_code, and campaign_id columns on active_listings/recent_sales
- [ ] Update Campaign, ActiveListing, and RecentSale models with new columns
- [ ] Update db_client.py create_campaign_in_db() and add query functions for campaign_id-based listing retrieval
- [ ] Update API gateway create and edit campaign endpoints to handle no_address_newsletter and zip_code
- [ ] Refactor rentcast_api_client.py functions to accept lat/lng instead of PropertyData
- [ ] Create order_active_listings_by_zip() and order_recent_sales_by_zip() without home value filtering
- [ ] Create get_active_listings_for_campaign() and get_recent_sales_for_campaign() wrapper functions
- [ ] Update data_fetcher.py polling functions to handle no-address campaigns with zip code lookups
- [ ] Update email_builder.py to handle optional PropertyData and no-address email generation
- [ ] Create 1st-intro-no-address.txt prompt file placeholder
- [ ] Update TypeScript types with no_address_newsletter and zip_code fields
- [ ] Update CampaignForm.tsx with toggle and conditional field display
- [ ] Update CreateCampaign.tsx with new state and validation
- [ ] Update CampaignDetails.tsx to display campaign type and conditional fields