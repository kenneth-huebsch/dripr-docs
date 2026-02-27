# Pagination Technical Implementation Plan

## Overview
This document provides a detailed technical implementation plan for adding pagination to the Leads page, based on the [PRD](./prd.md).

## Implementation Order

### Phase 1: Backend Implementation (4-6 hours)
1. Update database query function with pagination
2. Modify API endpoint to accept pagination parameters
3. Add response metadata structure
4. Write backend tests
5. Test backward compatibility

### Phase 2: Frontend Implementation (6-8 hours)
1. Update state management in Leads.tsx
2. Implement incremental loading logic
3. Add Load More button UI
4. Update refresh functionality
5. Add campaign count indicator
6. Write frontend tests

### Phase 3: Integration Testing (4-6 hours)
1. End-to-end testing
2. Performance testing with large datasets
3. Bug fixes and polish

## Detailed Implementation Steps

## Backend Implementation

### Step 1: Update db_client.py

**File:** `python/shared_resources/db_client.py`

#### 1.1 Modify get_lead_table_datas_by_user_id function

```python
from typing import Dict, Any

def get_lead_table_datas_by_user_id(
    user_id: str,
    limit: int = None,
    offset: int = 0
) -> Dict[str, Any]:
    """
    Retrieve paginated campaign lead table data for a user.

    Args:
        user_id: The user's ID
        limit: Maximum number of campaigns to return (None = all)
        offset: Number of campaigns to skip

    Returns:
        Dictionary with campaigns array and pagination metadata
    """
    Logger.logger.info(f"Retrieving campaign lead table for owner {user_id}, limit={limit}, offset={offset}")
    session = Session()
    lead_table_datas = []

    try:
        # Build base query
        query = session.query(Campaign).filter_by(user_id=user_id)

        # Get total count before pagination
        total_count = query.count()

        # Apply ordering by next_send_datetime (soonest first)
        # Use COALESCE to handle NULL values (put them at the end)
        query = query.order_by(
            func.coalesce(Campaign.next_send_datetime, datetime.max).asc()
        )

        # Apply pagination if limit is specified
        if limit is not None:
            query = query.limit(limit).offset(offset)
            campaigns = query.all()
        else:
            # Backward compatibility: return all if no limit
            campaigns = query.all()

        # Convert campaigns to lead table data
        for campaign in campaigns:
            property_data = session.query(PropertyData).filter_by(campaign_id=campaign.id).first()
            lead_table_data = campaign_to_lead_table_data(campaign, property_data)
            lead_table_datas.append(lead_table_data)

        # Calculate pagination metadata
        current_count = len(campaigns)
        has_more = (offset + current_count) < total_count if limit else False

        result = {
            "campaigns": lead_table_datas,
            "total": total_count,
            "limit": limit if limit is not None else total_count,
            "offset": offset,
            "has_more": has_more
        }

        Logger.logger.info(f"Retrieved {current_count} of {total_count} campaigns")
        return result

    except Exception as e:
        session.rollback()
        error_text = f"Error retrieving lead table data for owner {user_id}: {e}"
        Logger.logger.error(error_text)
        raise Exception(error_text)
    finally:
        session.close()
```

#### 1.2 Add necessary imports

```python
from datetime import datetime
from sqlalchemy import func
```

### Step 2: Update api_gateway.py

**File:** `python/api_gateway/api_gateway.py`

#### 2.1 Modify get_lead_table_endpoint

```python
@app.route("/api/campaigns", methods=['GET'])
@require_clerk_auth
def get_lead_table_endpoint():
    Logger.logger.info(f"Getting lead table data. Query params: {request.args}")
    clerk_id = request.auth.get('sub')
    if not clerk_id:
        Logger.logger.info("Missing required parameter 'clerk_id'")
        return jsonify({"error": "Missing required parameter 'clerk_id'"}), 400

    user = get_user_by_clerk_id(clerk_id)
    if not user:
        Logger.logger.info("User not found")
        return jsonify({"error": "User not found"}), 404

    # Extract and validate pagination parameters
    try:
        # Get limit parameter (default: 25 for initial implementation)
        limit_str = request.args.get('limit', '25')
        limit = int(limit_str) if limit_str else None

        # Validate limit
        if limit is not None:
            if limit < 1:
                return jsonify({"error": "Limit must be greater than 0"}), 400
            if limit > 1000:
                return jsonify({"error": "Limit cannot exceed 1000"}), 400

        # Get offset parameter (default: 0)
        offset = int(request.args.get('offset', '0'))

        # Validate offset
        if offset < 0:
            return jsonify({"error": "Offset cannot be negative"}), 400

    except ValueError:
        return jsonify({"error": "Invalid pagination parameters"}), 400

    try:
        # Check for backward compatibility mode
        # If neither limit nor offset is provided, return all (old behavior)
        if 'limit' not in request.args and 'offset' not in request.args:
            Logger.logger.info("No pagination params - using backward compatible mode")
            result = get_lead_table_datas_by_user_id(user.id, limit=None, offset=0)
            # For backward compatibility, return just the campaigns array
            return jsonify(result["campaigns"]), 200

        # New paginated response
        result = get_lead_table_datas_by_user_id(user.id, limit=limit, offset=offset)
        return jsonify(result), 200

    except Exception as e:
        Logger.logger.error(f"Error getting lead table data: {e}")
        return jsonify({"error": str(e)}), 500
```

### Step 3: Database Index (Optional Performance Optimization)

Create a migration to add a composite index for better query performance:

```bash
cd python/migrations
alembic revision --autogenerate -m "add_campaign_user_nextsend_index"
```

Edit the generated migration file:

```python
def upgrade():
    # Add composite index for pagination queries
    op.create_index(
        'idx_campaign_user_nextsend',
        'campaigns',
        ['user_id', 'next_send_datetime'],
        unique=False
    )

def downgrade():
    op.drop_index('idx_campaign_user_nextsend', table_name='campaigns')
```

## Frontend Implementation

### Step 4: Update Types

**File:** `ui/src/types/index.ts`

Add pagination response type:

```typescript
export interface PaginatedCampaignsResponse {
  campaigns: LeadTableData[];
  total: number;
  limit: number;
  offset: number;
  has_more: boolean;
}
```

### Step 5: Update Leads.tsx

**File:** `ui/src/pages/Leads.tsx`

Complete implementation:

```typescript
import { Link } from 'react-router-dom';
import { Plus, Loader, RefreshCcw, ChevronDown } from 'lucide-react';
import { CampaignTable } from '../components/CampaignTable';
import type { LeadTableData, PaginatedCampaignsResponse } from '../types';
import { useEffect, useState, useCallback } from 'react';
import { useUser } from '@clerk/clerk-react';
import { useApiClient } from '../services/apiClient';

const INITIAL_LIMIT = 25;
const LOAD_MORE_LIMIT = 100;

export function Leads() {
  const { user } = useUser();
  const apiClient = useApiClient();

  // State management
  const [campaigns, setCampaigns] = useState<LeadTableData[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const fetchCampaigns = useCallback(async (
    limit: number,
    currentOffset: number,
    append: boolean = false
  ) => {
    // Set appropriate loading state
    if (append) {
      setIsLoadingMore(true);
    } else {
      setIsLoading(true);
      setError(null);
    }

    try {
      // Check if we should use paginated response
      const response = await apiClient(`/api/campaigns?limit=${limit}&offset=${currentOffset}`);

      // Handle both old and new response formats
      if (Array.isArray(response)) {
        // Old format (backward compatibility)
        setCampaigns(response);
        setHasMore(false);
        setTotal(response.length);
      } else {
        // New paginated format
        const data = response as PaginatedCampaignsResponse;

        if (append) {
          // Append new campaigns to existing ones
          setCampaigns(prev => [...prev, ...data.campaigns]);
        } else {
          // Replace campaigns (initial load or refresh)
          setCampaigns(data.campaigns);
        }

        setHasMore(data.has_more);
        setTotal(data.total);
        setOffset(currentOffset + data.campaigns.length);
      }
    } catch (error) {
      console.error('Error fetching campaigns:', error);
      const errorMessage = error instanceof Error ? error.message : 'Failed to load campaigns';
      setError(errorMessage);

      // On error, show empty state if no campaigns loaded
      if (!append && campaigns.length === 0) {
        setCampaigns([]);
      }
    } finally {
      setIsLoading(false);
      setIsLoadingMore(false);
    }
  }, [apiClient, campaigns.length]);

  // Initial load
  useEffect(() => {
    if (user?.id) {
      fetchCampaigns(INITIAL_LIMIT, 0, false);
    }
  }, [user?.id]);

  // Refresh handler
  const handleRefresh = useCallback(() => {
    setOffset(0);
    fetchCampaigns(INITIAL_LIMIT, 0, false);
  }, [fetchCampaigns]);

  // Load more handler
  const handleLoadMore = useCallback(() => {
    if (!isLoadingMore && hasMore) {
      fetchCampaigns(LOAD_MORE_LIMIT, offset, true);
    }
  }, [fetchCampaigns, offset, isLoadingMore, hasMore]);

  // Calculate remaining campaigns
  const remainingCount = Math.max(0, total - campaigns.length);
  const nextLoadCount = Math.min(LOAD_MORE_LIMIT, remainingCount);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="sm:flex sm:items-center justify-between">
        <div className="sm:flex-auto">
          <h1 className="text-2xl font-semibold text-gray-900">Leads</h1>
          <p className="mt-2 text-sm text-gray-700">
            A list of all your email marketing campaigns
            {total > 0 && (
              <span className="ml-2 text-gray-500">
                (Showing {campaigns.length} of {total} campaigns)
              </span>
            )}
          </p>
        </div>
        <div className="mt-4 sm:mt-0 sm:flex-none flex items-center space-x-4">
          {/* Refresh Button */}
          <button
            onClick={handleRefresh}
            className="inline-flex items-center justify-center rounded-md border border-transparent bg-gray-200 px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={isLoading || isLoadingMore}
          >
            <RefreshCcw className={`w-4 h-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
          <Link
            to="/leads/new"
            className="inline-flex items-center justify-center rounded-md border border-transparent bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            <Plus className="w-4 h-4 mr-2" />
            New Lead
          </Link>
        </div>
      </div>

      {/* Error state */}
      {error && !isLoading && (
        <div className="mt-4 rounded-md bg-red-50 p-4">
          <div className="flex">
            <div className="ml-3">
              <h3 className="text-sm font-medium text-red-800">Error loading campaigns</h3>
              <div className="mt-2 text-sm text-red-700">{error}</div>
              <button
                onClick={handleRefresh}
                className="mt-2 text-sm font-medium text-red-600 hover:text-red-500"
              >
                Try again
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="mt-8">
        {isLoading ? (
          <div className="flex justify-center items-center py-12">
            <Loader className="w-8 h-8 text-blue-500 animate-spin" />
            <span className="ml-2 text-gray-600">Loading campaigns...</span>
          </div>
        ) : (
          <>
            <CampaignTable campaigns={campaigns} />

            {/* Load More Button */}
            {hasMore && (
              <div className="mt-6 flex justify-center">
                <button
                  onClick={handleLoadMore}
                  disabled={isLoadingMore}
                  className="inline-flex items-center px-6 py-3 border border-gray-300 shadow-sm text-base font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isLoadingMore ? (
                    <>
                      <Loader className="w-5 h-5 mr-2 animate-spin" />
                      Loading...
                    </>
                  ) : (
                    <>
                      <ChevronDown className="w-5 h-5 mr-2" />
                      Load {nextLoadCount} More {nextLoadCount === 1 ? 'Campaign' : 'Campaigns'}
                      {remainingCount > LOAD_MORE_LIMIT && (
                        <span className="ml-1 text-gray-500">
                          ({remainingCount} remaining)
                        </span>
                      )}
                    </>
                  )}
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
```

## Testing Plan

### Backend Testing

**File:** `python/tests/test_pagination.py`

```python
import pytest
from shared_resources.db_client import get_lead_table_datas_by_user_id
from shared_resources.models import Campaign, User

@pytest.fixture
def test_user_with_campaigns(db_session):
    """Create test user with multiple campaigns"""
    user = User(clerk_id="test_clerk_123", email="test@example.com")
    db_session.add(user)
    db_session.commit()

    # Create 150 test campaigns with varying next_send_datetime
    for i in range(150):
        campaign = Campaign(
            user_id=user.id,
            client_first_name=f"Client{i}",
            client_last_name=f"Test{i}",
            formatted_address=f"{i} Test St",
            next_send_datetime=datetime.now() + timedelta(days=i),
            enabled=1
        )
        db_session.add(campaign)

    db_session.commit()
    return user

def test_pagination_first_page(test_user_with_campaigns):
    """Test fetching first page of results"""
    result = get_lead_table_datas_by_user_id(
        test_user_with_campaigns.id,
        limit=25,
        offset=0
    )

    assert len(result["campaigns"]) == 25
    assert result["total"] == 150
    assert result["has_more"] == True
    assert result["offset"] == 0
    assert result["limit"] == 25

def test_pagination_middle_page(test_user_with_campaigns):
    """Test fetching middle page of results"""
    result = get_lead_table_datas_by_user_id(
        test_user_with_campaigns.id,
        limit=100,
        offset=25
    )

    assert len(result["campaigns"]) == 100
    assert result["total"] == 150
    assert result["has_more"] == True
    assert result["offset"] == 25

def test_pagination_last_page(test_user_with_campaigns):
    """Test fetching last page with partial results"""
    result = get_lead_table_datas_by_user_id(
        test_user_with_campaigns.id,
        limit=100,
        offset=125
    )

    assert len(result["campaigns"]) == 25  # Only 25 remaining
    assert result["total"] == 150
    assert result["has_more"] == False
    assert result["offset"] == 125

def test_ordering_by_next_send_datetime(test_user_with_campaigns):
    """Test that results are ordered by next_send_datetime"""
    result = get_lead_table_datas_by_user_id(
        test_user_with_campaigns.id,
        limit=10,
        offset=0
    )

    campaigns = result["campaigns"]
    for i in range(1, len(campaigns)):
        prev_date = campaigns[i-1]["next_send_datetime"]
        curr_date = campaigns[i]["next_send_datetime"]
        assert prev_date <= curr_date  # Should be ascending order

def test_backward_compatibility(test_user_with_campaigns):
    """Test that function works without pagination params"""
    result = get_lead_table_datas_by_user_id(
        test_user_with_campaigns.id
    )

    # Should return all campaigns in old format
    assert result["campaigns"]
    assert result["total"] == 150
    assert result["has_more"] == False
```

### Frontend Testing

**File:** `ui/src/pages/__tests__/Leads.test.tsx`

```typescript
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { Leads } from '../Leads';
import { useApiClient } from '../../services/apiClient';

jest.mock('../../services/apiClient');

describe('Leads Pagination', () => {
  const mockApiClient = jest.fn();

  beforeEach(() => {
    (useApiClient as jest.Mock).mockReturnValue(mockApiClient);
  });

  test('loads initial 25 campaigns', async () => {
    const mockResponse = {
      campaigns: Array(25).fill(null).map((_, i) => ({
        campaign_id: `id-${i}`,
        client_first_name: `Client${i}`,
        // ... other fields
      })),
      total: 150,
      has_more: true,
      limit: 25,
      offset: 0
    };

    mockApiClient.mockResolvedValueOnce(mockResponse);

    render(<Leads />);

    await waitFor(() => {
      expect(screen.getByText('Showing 25 of 150 campaigns')).toBeInTheDocument();
    });

    expect(mockApiClient).toHaveBeenCalledWith('/api/campaigns?limit=25&offset=0');
  });

  test('loads more campaigns when button clicked', async () => {
    const initialResponse = {
      campaigns: Array(25).fill(null).map((_, i) => ({
        campaign_id: `id-${i}`,
        client_first_name: `Client${i}`,
      })),
      total: 150,
      has_more: true,
      limit: 25,
      offset: 0
    };

    const moreResponse = {
      campaigns: Array(100).fill(null).map((_, i) => ({
        campaign_id: `id-${i + 25}`,
        client_first_name: `Client${i + 25}`,
      })),
      total: 150,
      has_more: true,
      limit: 100,
      offset: 25
    };

    mockApiClient
      .mockResolvedValueOnce(initialResponse)
      .mockResolvedValueOnce(moreResponse);

    render(<Leads />);

    await waitFor(() => {
      expect(screen.getByText('Load 100 More Campaigns')).toBeInTheDocument();
    });

    fireEvent.click(screen.getByText(/Load 100 More Campaigns/));

    await waitFor(() => {
      expect(screen.getByText('Showing 125 of 150 campaigns')).toBeInTheDocument();
    });

    expect(mockApiClient).toHaveBeenCalledWith('/api/campaigns?limit=100&offset=25');
  });

  test('refresh resets to first page', async () => {
    // ... test implementation
  });

  test('handles error gracefully', async () => {
    mockApiClient.mockRejectedValueOnce(new Error('Network error'));

    render(<Leads />);

    await waitFor(() => {
      expect(screen.getByText('Error loading campaigns')).toBeInTheDocument();
      expect(screen.getByText('Try again')).toBeInTheDocument();
    });
  });
});
```

## Performance Testing Script

**File:** `python/scripts/test_pagination_performance.py`

```python
import time
import requests
from statistics import mean, stdev

def test_pagination_performance(api_url, auth_token):
    """Test pagination performance with various offsets"""

    test_cases = [
        {"limit": 25, "offset": 0, "name": "First page"},
        {"limit": 100, "offset": 25, "name": "Second page (100 items)"},
        {"limit": 100, "offset": 500, "name": "Deep pagination"},
        {"limit": 100, "offset": 5000, "name": "Very deep pagination"},
    ]

    results = []

    for test_case in test_cases:
        times = []

        # Run each test 5 times
        for _ in range(5):
            start = time.time()
            response = requests.get(
                f"{api_url}/api/campaigns",
                params={"limit": test_case["limit"], "offset": test_case["offset"]},
                headers={"Authorization": f"Bearer {auth_token}"}
            )
            elapsed = time.time() - start
            times.append(elapsed)

            if response.status_code != 200:
                print(f"Error in {test_case['name']}: {response.status_code}")
                break

        if times:
            avg_time = mean(times)
            std_time = stdev(times) if len(times) > 1 else 0

            results.append({
                "test": test_case["name"],
                "avg_time": avg_time,
                "std_dev": std_time,
                "params": test_case
            })

            print(f"{test_case['name']}:")
            print(f"  Average: {avg_time:.3f}s")
            print(f"  Std Dev: {std_time:.3f}s")
            print(f"  Payload size: {len(response.content) / 1024:.1f}KB")

    return results

if __name__ == "__main__":
    # Run performance tests
    results = test_pagination_performance(
        "http://localhost:5000",
        "your-test-token"
    )

    # Check if any test exceeds acceptable threshold
    for result in results:
        if result["avg_time"] > 2.0:
            print(f"WARNING: {result['test']} exceeds 2 second threshold!")
```

## Deployment Checklist

### Pre-deployment
- [ ] All tests passing
- [ ] Performance tested with realistic data volumes
- [ ] Backward compatibility verified
- [ ] Database migration created and tested
- [ ] Error handling tested (network failures, invalid params)

### Backend Deployment
1. [ ] Apply database migration (add index if needed)
2. [ ] Deploy updated `db_client.py`
3. [ ] Deploy updated `api_gateway.py`
4. [ ] Verify backward compatibility with existing frontend
5. [ ] Monitor error logs

### Frontend Deployment
1. [ ] Deploy updated `Leads.tsx`
2. [ ] Deploy updated types
3. [ ] Verify initial page load performance
4. [ ] Test Load More functionality
5. [ ] Check error states

### Post-deployment Monitoring
- [ ] Monitor API response times in CloudWatch
- [ ] Check for database slow queries
- [ ] Monitor error rates
- [ ] Collect user feedback
- [ ] Verify memory usage is stable

## Rollback Plan

If issues are encountered:

### Backend Rollback
1. Revert `db_client.py` to return all campaigns
2. Revert `api_gateway.py` endpoint changes
3. Keep database index (no harm)

### Frontend Rollback
1. Revert `Leads.tsx` to previous version
2. Frontend will automatically use non-paginated response

## Future Optimizations

### 1. Cursor-based Pagination (if offset performance degrades)
```python
# Use last campaign's next_send_datetime and id as cursor
def get_campaigns_cursor(user_id, cursor=None, limit=25):
    query = session.query(Campaign).filter_by(user_id=user_id)

    if cursor:
        last_datetime, last_id = cursor.split('_')
        query = query.filter(
            (Campaign.next_send_datetime > last_datetime) |
            ((Campaign.next_send_datetime == last_datetime) & (Campaign.id > last_id))
        )

    campaigns = query.order_by(
        Campaign.next_send_datetime.asc(),
        Campaign.id.asc()
    ).limit(limit).all()

    # Generate next cursor
    if campaigns:
        last = campaigns[-1]
        next_cursor = f"{last.next_send_datetime}_{last.id}"

    return campaigns, next_cursor
```

### 2. React Query Integration
```typescript
// Use React Query for caching and automatic refetching
import { useInfiniteQuery } from '@tanstack/react-query';

const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
  queryKey: ['campaigns'],
  queryFn: ({ pageParam = 0 }) => fetchCampaigns(100, pageParam),
  getNextPageParam: (lastPage) =>
    lastPage.has_more ? lastPage.offset + lastPage.limit : undefined,
});
```

### 3. Virtual Scrolling (for very large lists)
```typescript
// Use react-window for virtualized rendering
import { FixedSizeList } from 'react-window';

<FixedSizeList
  height={600}
  itemCount={campaigns.length}
  itemSize={60}
  width="100%"
>
  {({ index, style }) => (
    <div style={style}>
      <CampaignRow campaign={campaigns[index]} />
    </div>
  )}
</FixedSizeList>
```

## Success Metrics

Track these metrics to measure success:

1. **Performance Metrics**
   - Initial page load time < 2 seconds (P95)
   - Load More response time < 2 seconds (P95)
   - API payload size < 100KB for 25 campaigns

2. **User Experience Metrics**
   - Reduced bounce rate on Leads page
   - Increased engagement (more campaigns viewed)
   - Reduced support tickets about slow loading

3. **System Metrics**
   - Reduced database query time
   - Lower memory usage on backend
   - Reduced network bandwidth usage

## Questions/Decisions Log

### Resolved
- **Q:** Should limit be 25 or configurable?
  - **A:** Fixed at 25 for initial load, 100 for subsequent loads
- **Q:** Use offset or cursor pagination?
  - **A:** Offset for simplicity, cursor if performance issues

### Open
- **Q:** Should sorting trigger server-side re-query?
  - **Current:** Client-side only on loaded data
- **Q:** Add "Jump to page" functionality?
  - **Current:** Not in initial release

## References

- [PRD Document](./prd.md)
- [MySQL LIMIT/OFFSET Performance](https://dev.mysql.com/doc/refman/8.0/en/limit-optimization.html)
- [React Query Pagination](https://tanstack.com/query/latest/docs/react/guides/paginated-queries)
- [SQLAlchemy Pagination](https://docs.sqlalchemy.org/en/14/orm/query.html#sqlalchemy.orm.Query.limit)