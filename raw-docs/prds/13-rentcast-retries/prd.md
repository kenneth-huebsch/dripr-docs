# PRD: Rentcast Recent Sales - Allow Properties Without Disclosed Prices

## Overview
Modify the Recent Sales API filtering logic to handle markets where property sale prices are not publicly disclosed, preventing unnecessary campaign failures.

## Background
The system currently fetches "Recent Sales" data from the Rentcast API to populate emails with comparable properties sold in the past 90 days. The filtering uses 5 priority tiers with progressively wider search radiuses and different price matching criteria. If no tier yields 10+ properties after 3 retries with expanded radius, the campaign enters ERROR status.

In some regions of the country, property sale prices are not required to be made public, causing campaigns to fail even though suitable properties exist - they just lack pricing data.

## Problem Statement
Campaigns are failing unnecessarily in markets where property sale prices are not publicly disclosed, even though the properties themselves are valid recent sales that could provide value to the lead.

## Goals
- Reduce campaign failures in markets with undisclosed sale prices
- Maintain data quality by preferring properties with prices when available
- Provide visibility into when fallback behavior is used
- Improve property selection logic by replacing discrete tiers with a flexible scoring system
- Eliminate code duplication between active listings and recent sales ordering

## Non-Goals
- Changing the retry logic or radius expansion behavior
- Changing the minimum property count threshold (stays at 10)
- Changing the fundamental prioritization logic (distance, price similarity, etc.)

## Functional Requirements

### FR-1: Allow Properties Without Disclosed Prices
**Current Behavior:** The system rejects properties with `None` or empty price values at all filtering stages, causing campaigns to fail in markets without public pricing.

**New Behavior:** Properties without disclosed prices should be included in results but with lower priority/scores than properties with prices.

**Acceptance Criteria:**
- Properties with `None` or empty price values are accepted and scored
- Properties with valid prices receive scoring bonuses and are prioritized
- Campaigns do not fail solely due to lack of price data when sufficient properties exist

### FR-2: Maintain Retry Logic
**Requirement:** Keep the existing retry behavior unchanged.

**Acceptance Criteria:**
- System still retries up to 3 times with progressively wider radius if insufficient properties found
- Radius expansion logic remains the same
- Scoring system is re-applied on each retry attempt with the new radius

### FR-3: Campaign Success with Sufficient Properties
**Requirement:** If the scoring system finds 10+ properties (with or without prices), the campaign should proceed successfully instead of entering ERROR status.

**Acceptance Criteria:**
- Campaigns do not enter ERROR status when sufficient scored properties are found
- Campaigns proceed to email generation phase
- Normal workflow continues after successful property retrieval

### FR-4: Email Display Logic
**Requirement:** For properties without disclosed prices, omit the price field from the email while still displaying other property information.

**Email Fields to Display:**
- Address
- Sale date
- Any other existing fields (beds, baths, sqft, etc.)

**Email Fields to Omit:**
- Price/sale price field (when `None` or empty)

**Acceptance Criteria:**
- Email template gracefully handles missing price data
- Properties without prices are visually consistent with properties that have prices
- No "null", "None", "$0", or similar placeholder values displayed for price

### FR-5: Logging and Monitoring
**Requirement:** Log when properties without prices are included in results to provide visibility into which markets/campaigns use this fallback behavior.

**Acceptance Criteria:**
- Log message includes campaign/lead identifier
- Log indicates number of properties without prices included
- Log level is appropriate (INFO or WARNING)
- Logs enable future analysis of markets with undisclosed pricing
- Log individual property scores during ranking process (at DEBUG level)

### FR-6: Refactor from Tier-Based to Score-Based Property Ranking
**Current Behavior:** Properties are filtered through 5 discrete tiers with hard cutoffs (25%, 50%, 75%, 100% radius). Properties that don't match any tier criteria are excluded. This creates:
- Artificial boundaries (property at 24.9% radius vs 25.1% radius treated very differently)
- Code duplication between `order_active_listings` and `order_recent_sales` (~85% identical)
- Rigid filtering that rejects properties with missing prices even when price checking is disabled

**New Behavior:** Replace tier-based filtering with a continuous scoring system that ranks properties by overall quality.

**Scoring Factors:**
1. **Distance Score** - Closer properties score higher (continuous, not discrete tiers)
2. **Price Availability** - Properties with prices get bonus points
3. **Price Similarity** - When `current_value` provided, properties with similar prices score higher
4. **Zip Code Match** - Properties in same zip code get bonus points
5. **Recency/Freshness** - Recent sales: newer sales score higher; Active listings: lower days on market scores higher

**Acceptance Criteria:**
- Single generic `PropertyScorer` class that works for both recent sales and active listings
- Configurable `ScoringWeights` class to allow different weight configurations
- Properties ranked by composite score (highest to lowest)
- No artificial tier boundaries - scoring is continuous
- Properties without prices receive score penalty but remain viable candidates
- Maintains existing prioritization logic (close + similar price = highest score)
- All existing tests pass with equivalent or better property selection
- Code duplication eliminated between active listings and recent sales ordering

**Implementation Requirements:**
- Create `PropertyScorer[T]` generic class for scoring logic
- Create `ScoringWeights` dataclass for configurable weight tuning
- Replace `order_recent_sales()` implementation with scoring system
- Replace `order_active_listings()` implementation with scoring system
- Maintain backward compatibility - function signatures remain unchanged
- Add comprehensive logging of scores for debugging and tuning

## Technical Notes

### Current Filter Tier Structure (To Be Replaced)
```python
filter_tiers = [
    (0.25 * radius, True),  # Tier 1: Within 25% radius, similar price
    (0.5 * radius, True),   # Tier 2: Within 50% radius, similar price
    (0.75 * radius, True),  # Tier 3: Within 75% radius, similar price
    (radius, True),         # Tier 4: Within full radius, similar price
    (radius, False),        # Tier 5: Within full radius, any price
]
```

**Critical Bug:** In `order_recent_sales()` line 357, the function checks `if not is_valid_string(house["price"])` and returns `False` before checking the `check_price` parameter. This means Tier 5 (where `check_price=False`) still rejects properties without prices, defeating the purpose of Tier 5.

### Proposed Scoring System Architecture

**Core Classes:**
```python
@dataclass
class ScoringWeights:
    distance_weight: float = 1.0
    price_similarity_weight: float = 0.8
    same_zip_bonus: float = 50.0
    has_price_bonus: float = 30.0
    no_price_penalty: float = 25.0
    # ... other weights

class PropertyScorer[T]:
    def __init__(self, zip_code, radius, current_value, house_number, weights)
    def _is_valid_for_inclusion(self, prop: T) -> tuple[bool, str]  # Hard filters only
    def calculate_score(self, prop: T) -> float  # Quality scoring
    def rank_properties(self, properties: list[T]) -> list[tuple[T, float]]
    def order_properties(self, properties: list[T]) -> list[T]
```

**Score Calculation Example:**
- Property with price, 0.5mi away, same zip, price within 10%: **~215 points**
- Property without price, 3mi away, different zip: **~55 points**

Both are viable, but property with price is strongly preferred.

### Code Locations
- Primary implementation: `python/shared_resources/api_client.py`
  - `order_recent_sales()` - Lines 318-407
  - `order_active_listings()` - Lines 241-315
- Email template updates needed for conditional price display

## Success Metrics

### Business Metrics
- Reduction in campaign ERROR status rate due to missing recent sales data
- Number of campaigns that succeed with properties lacking prices
- Markets/regions where fallback behavior is most common
- Overall campaign success rate improvement

### Technical Metrics
- Lines of code reduction (eliminate ~85% duplication between order functions)
- Property selection quality (compare scores of selected properties before/after)
- Test coverage maintained or improved
- No regression in existing campaign success rates

## Dependencies
- Rentcast API (no changes required)
- Email generation system (requires template update for conditional price display)
- Existing test suite must be updated to work with scoring system

## Implementation Phases

### Phase 1: Core Scoring Infrastructure
1. Create `ScoringWeights` dataclass with configurable weights
2. Create `PropertyScorer[T]` generic class with scoring logic
3. Implement `calculate_score()` method with all scoring factors
4. Add comprehensive unit tests for scoring logic

### Phase 2: Integration
1. Replace `order_recent_sales()` implementation with `PropertyScorer`
2. Replace `order_active_listings()` implementation with `PropertyScorer`
3. Maintain backward-compatible function signatures
4. Add logging for score debugging

### Phase 3: Email Template Updates
1. Update email templates to conditionally display price
2. Handle `None` or empty price values gracefully
3. Ensure visual consistency between priced and non-priced properties

### Phase 4: Testing & Validation
1. Update existing tests to work with scoring system
2. Verify no regression in campaign success rates
3. Test with known markets that lack public pricing data
4. Validate that properties without prices now succeed

## Testing Strategy

### Unit Tests
- Score calculation for various property configurations
- Hard filter validation logic
- Weight configuration impact on rankings
- Edge cases (no prices, extreme distances, etc.)

### Integration Tests
- End-to-end recent sales retrieval with scoring
- End-to-end active listings retrieval with scoring
- Campaigns in markets without public pricing
- Verify retry logic still functions correctly

### Regression Tests
- Existing campaign test cases should pass
- Property selection quality should be equivalent or better
- No increase in ERROR status rate for existing markets

## Open Questions
None - all requirements clarified.

## Revision History
- v1.0 - Initial PRD created (2025-11-26)
- v2.0 - Added scoring system refactoring to scope (2025-11-26)

