### PRD: Campaign List Pagination

### Summary
Implement server-side pagination for the Leads page to handle thousands of campaigns efficiently. The UI should initially load 25 campaigns, allow users to load 100 more at a time via a "Load More" button, and maintain client-side sorting functionality on currently loaded data.

### Background
Currently, the `/api/campaigns` endpoint returns all campaigns for a user without pagination. As users accumulate hundreds or thousands of campaigns, this causes:
- Slow page load times
- Large API response payloads
- Poor user experience
- Unnecessary database and network overhead

### Scope
- Add pagination support to the `GET /api/campaigns` endpoint
- Update the frontend Leads page to implement incremental loading
- Prioritize campaigns by soonest `next_send_datetime` (ascending)
- Preserve existing client-side sorting functionality for loaded campaigns
- Maintain backward compatibility during transition

### Out of Scope
- Search/filter functionality (future feature)
- Server-side sorting beyond the default ordering
- Virtual scrolling or infinite scroll (using explicit "Load More" button instead)
- Pagination for other endpoints (campaigns details, emails, etc.)

### Key Definitions
- **Page size**: Number of campaigns returned per API request
  - Initial load: 25 campaigns
  - Subsequent loads: 100 campaigns per click
- **Default ordering**: Campaigns ordered by `next_send_datetime` ASC (soonest first) in the database query
- **Client-side sorting**: User-initiated sorting (enabled, status, client, address, next_send_datetime) applies only to currently loaded campaigns
- **Cursor-based pagination**: Use offset-based pagination for simplicity (limit/offset pattern)

### User Stories

**As a real estate agent with many campaigns:**
1. I want the Leads page to load quickly so I don't have to wait for thousands of campaigns
2. I want to see my most urgent campaigns first (soonest next send date)
3. I want to load more campaigns when needed without reloading the page
4. I want to sort my currently loaded campaigns by different columns
5. I want previously loaded campaigns to remain visible when loading more

### API Changes

#### GET /api/campaigns

**New Query Parameters:**
- `limit` (optional, integer): Number of campaigns to return. Defaults to 25.
- `offset` (optional, integer): Number of campaigns to skip. Defaults to 0.

**Request Examples:**
```
GET /api/campaigns                    # Returns first 25 campaigns
GET /api/campaigns?limit=25&offset=0  # Same as above (explicit)
GET /api/campaigns?limit=100&offset=25 # Returns campaigns 26-125
```

**Response Format:**
```json
{
  "campaigns": [ /* array of LeadTableData objects */ ],
  "total": 1523,           // Total number of campaigns for this user
  "limit": 25,             // Number of campaigns returned in this response
  "offset": 0,             // Starting position for this page
  "has_more": true         // Whether more campaigns are available
}
```

**Backend Changes Required:**
1. Update `get_lead_table_datas_by_user_id()` in `db_client.py`:
   - Accept `limit` and `offset` parameters
   - Add `.limit()` and `.offset()` to SQLAlchemy query
   - Change default ordering to `order_by(Campaign.next_send_datetime.asc())`
   - Return pagination metadata (total count, has_more)

2. Update `get_lead_table_endpoint()` in `api_gateway.py`:
   - Extract `limit` and `offset` from query parameters
   - Validate parameters (limit max: 1000, offset min: 0)
   - Pass parameters to database function
   - Return paginated response with metadata

**Default Ordering:**
```python
# In db_client.py - get_lead_table_datas_by_user_id()
campaigns = session.query(Campaign)\
    .filter_by(user_id=user_id)\
    .order_by(Campaign.next_send_datetime.asc())\
    .limit(limit)\
    .offset(offset)\
    .all()
```

### Frontend Changes

#### Leads.tsx Component Updates

**State Management:**
```typescript
const [campaigns, setCampaigns] = useState<LeadTableData[]>([]);
const [isLoading, setIsLoading] = useState(true);
const [isLoadingMore, setIsLoadingMore] = useState(false);
const [hasMore, setHasMore] = useState(false);
const [total, setTotal] = useState(0);
const [offset, setOffset] = useState(0);
```

**Initial Load:**
- Fetch first 25 campaigns on component mount
- Display loading spinner while fetching

**Load More Functionality:**
- Button appears at bottom of campaign table when `hasMore === true`
- Button text: "Load 100 More Campaigns" (or "Load More (X remaining)" showing count)
- On click: fetch next 100 campaigns with current offset
- Append new campaigns to existing array (cumulative)
- Update offset by adding 100
- Show loading indicator on button while fetching
- Disable button while loading to prevent duplicate requests

**API Integration:**
```typescript
async function fetchCampaigns(limit: number, currentOffset: number, append: boolean = false) {
  append ? setIsLoadingMore(true) : setIsLoading(true);
  try {
    const response = await apiClient(`/api/campaigns?limit=${limit}&offset=${currentOffset}`);
    const newCampaigns = response.campaigns;

    setCampaigns(prev => append ? [...prev, ...newCampaigns] : newCampaigns);
    setHasMore(response.has_more);
    setTotal(response.total);
    setOffset(currentOffset + newCampaigns.length);
  } catch (error) {
    console.error('Error fetching campaigns:', error);
  } finally {
    append ? setIsLoadingMore(false) : setIsLoading(false);
  }
}

// Initial load
useEffect(() => {
  fetchCampaigns(25, 0, false);
}, [user?.id]);

// Load more handler
function handleLoadMore() {
  fetchCampaigns(100, offset, true);
}
```

**Refresh Button Behavior:**
- Reset to initial state (first 25 campaigns)
- Clear existing campaigns array
- Reset offset to 0

#### CampaignTable.tsx Updates

**No Changes Required:**
- Client-side sorting continues to work on the `campaigns` prop
- Sorting applies only to currently loaded campaigns
- `useMemo` hook efficiently re-sorts when campaigns array changes

**UI Enhancement (Optional):**
- Show campaign count indicator: "Showing 125 of 1,523 campaigns"

### Technical Considerations

**Database Performance:**
- Existing index on `user_id` in `campaigns` table should be sufficient
- Consider adding composite index: `(user_id, next_send_datetime)` for optimal performance
- Monitor query performance with EXPLAIN for queries with large offsets

**Offset Limitations:**
- Large offsets (e.g., `OFFSET 50000`) can be slow in MySQL
- For initial implementation, offset-based pagination is acceptable
- Future optimization: cursor-based pagination using `next_send_datetime` + `id` if needed

**Backward Compatibility:**
- If `limit` and `offset` are not provided, default to current behavior (return all campaigns)
- This allows gradual rollout and testing

**Error Handling:**
- Handle network errors gracefully (show error message, allow retry)
- Validate query parameters on backend (400 Bad Request for invalid values)
- Handle edge cases: no campaigns, all campaigns loaded, deleted campaigns while paginating

**Client-Side Sorting Behavior:**
- User expectations: sorting should apply to all campaigns, not just loaded ones
- Actual behavior: sorting applies only to loaded campaigns
- Consider adding UI indicator: "Sorting X of Y campaigns" or tooltip explaining behavior
- Future enhancement: server-side sorting with pagination

### Acceptance Criteria

**Backend:**
1. `/api/campaigns` endpoint accepts `limit` and `offset` query parameters
2. Endpoint returns paginated response with `campaigns`, `total`, `limit`, `offset`, `has_more` fields
3. Default ordering is by `next_send_datetime` ASC
4. Query includes proper SQL LIMIT and OFFSET clauses
5. Total count is accurate for the user's campaigns
6. `has_more` correctly indicates if additional campaigns exist
7. Invalid parameters return 400 Bad Request with clear error message
8. Endpoint works without pagination parameters (backward compatibility)

**Frontend:**
1. Leads page initially loads 25 campaigns ordered by soonest next send date
2. "Load More" button appears when more campaigns are available
3. Clicking "Load More" fetches 100 additional campaigns and appends to list
4. Previously loaded campaigns remain visible after loading more
5. Loading indicators show during initial load and incremental loads
6. Refresh button resets to first 25 campaigns
7. Client-side sorting continues to work on currently loaded campaigns
8. Campaign count indicator shows "Showing X of Y campaigns"
9. No campaigns message displays when user has zero campaigns
10. Error states are handled gracefully (network errors, empty responses)

**Performance:**
1. Initial page load completes in < 2 seconds for users with thousands of campaigns
2. API response payload size is reasonable (< 100KB for 25 campaigns)
3. Database query executes in < 500ms for first page (with proper indexing)
4. Subsequent "Load More" operations complete in < 2 seconds

### Testing Requirements

**Backend Tests:**
1. Test pagination with various `limit` and `offset` combinations
2. Test total count accuracy
3. Test `has_more` flag with different dataset sizes
4. Test default ordering by `next_send_datetime`
5. Test backward compatibility (no pagination params)
6. Test parameter validation (negative offset, excessive limit, etc.)
7. Test with user having 0, 1, 24, 25, 26, 1000+ campaigns

**Frontend Tests:**
1. Test initial load displays first 25 campaigns
2. Test "Load More" button appears/disappears appropriately
3. Test campaigns are appended correctly
4. Test sorting works on loaded campaigns
5. Test refresh button resets state
6. Test loading indicators display correctly
7. Test error handling for failed API calls

**Integration Tests:**
1. Test complete user flow: load page → load more → sort → refresh
2. Test with realistic data volumes (1000+ campaigns)
3. Test concurrent requests (user clicks Load More multiple times)

### Migration Strategy

**Phase 1: Backend Implementation**
1. Add pagination parameters to database function (with defaults for backward compatibility)
2. Update API endpoint to accept and return pagination metadata
3. Deploy backend changes
4. Verify existing frontend continues to work (no pagination params = all results)

**Phase 2: Frontend Implementation**
1. Update Leads page with pagination logic
2. Add "Load More" button UI
3. Test thoroughly in staging environment
4. Deploy frontend changes

**Phase 3: Monitoring & Optimization**
1. Monitor API response times and payload sizes
2. Collect user feedback on UX
3. Add database index if query performance degrades with large offsets
4. Consider cursor-based pagination if offset performance becomes problematic

### Future Enhancements

**Not in Scope for Initial Release:**
1. Search/filter functionality with pagination
2. Server-side sorting (allow sorting entire dataset, not just loaded campaigns)
3. Virtual scrolling or infinite scroll (automatically load more on scroll)
4. "Jump to page" functionality
5. Configurable page size (allow users to choose 25, 50, 100, etc.)
6. Cursor-based pagination for better performance with large offsets
7. Pagination for campaign emails and other list views

### Open Questions

1. Should the "Load More" button always load 100, or should it adapt based on remaining campaigns?
   - Recommendation: Always load 100 until fewer than 100 remain

2. Should we add a "Load All" button for users who want to see everything?
   - Recommendation: No, to prevent performance issues. Users can keep clicking "Load More"

3. Should sorting trigger a new API request to sort the entire dataset?
   - Recommendation: Not in initial release. Document as known limitation.

4. Should we remember the user's scroll position and loaded campaigns when navigating away and back?
   - Recommendation: Not in initial release. Can use React Query cache in future.

### Implementation Notes

**Estimated Effort:**
- Backend changes: 4-6 hours (including tests)
- Frontend changes: 6-8 hours (including tests and UI polish)
- Testing & bug fixes: 4-6 hours
- **Total: 14-20 hours**

**Dependencies:**
- No external dependencies required
- Uses existing SQLAlchemy, Flask, React, TypeScript stack

**Risks:**
- Users may be confused that sorting only applies to loaded campaigns
  - Mitigation: Add tooltip or indicator explaining behavior
- Large offsets may cause slow queries in MySQL
  - Mitigation: Monitor performance, add composite index if needed
