# Product Requirements Document: Lead Search Feature

## Overview
Add a search capability to the Leads page to help users quickly locate specific leads by name, addressing the usability challenge when managing large numbers of campaigns (700+).

## Problem Statement
Users with hundreds of campaigns face difficulty locating specific leads because:
- Initial page load shows only 25 campaigns
- Users must manually load additional campaigns in batches of 100
- No search or filter functionality currently exists
- Manually scrolling through hundreds of rows is time-consuming and frustrating

## Solution
Implement a server-side search feature that allows users to search for leads by first name or last name with partial string matching.

## User Stories
1. As a real estate agent with 700+ leads, I want to search for a client by name so that I can quickly find their campaign without scrolling through hundreds of entries.
2. As a user, I want to search by partial names (e.g., "John" or "son") so that I don't need to remember the exact spelling.
3. As a user, I want to clear my search and return to the normal view so that I can browse all campaigns again.

## Functional Requirements

### Search UI Components
1. **Search Input Field**
   - Display a search text input in the Leads page header area
   - Placeholder text: "Search by client name..."
   - Located near the "Refresh" and "New Lead" buttons

2. **Search Button**
   - Button labeled "Search" adjacent to the search input
   - Triggers the search query when clicked
   - Only enabled when the search input contains text

3. **Clear Search Button (X)**
   - Display an X icon button within or next to the search input
   - Only visible when a search is active
   - Clicking clears the search and reloads the original paginated campaign list
   - Returns user to the initial state (first 25 campaigns)

### Search Behavior
1. **Search Criteria**
   - Search against `client_first_name` field
   - Search against `client_last_name` field
   - Use partial string matching (substring match)
   - Case-insensitive matching
   - Match search term anywhere within the name fields

2. **Search Execution**
   - Triggered by clicking the Search button (not real-time/as-you-type)
   - Send search query to backend API endpoint
   - Server performs database query with search filters

3. **Search Results**
   - Display results in the existing `CampaignTable` component
   - Results are paginated (same as normal campaign list)
   - Initial search returns 25 results
   - "Load More" button loads 100 additional results
   - Show total count: "Showing X of Y results"

4. **Empty Results**
   - Display "No results found" message when search returns zero campaigns
   - Provide clear indication that the search term didn't match any leads
   - Maintain the search input value so user can modify and retry

5. **Clear Search**
   - Clicking the X button clears the search
   - Resets to initial page state (loads first 25 campaigns with offset=0)
   - Removes search term from input field
   - Calls the same API endpoint used on initial page load

### Performance Expectations
- Search response time: < 1 second (no loading indicator required)
- Search should work efficiently with thousands of campaigns
- Pagination should work identically for search results and normal lists

## Technical Requirements

### Backend API
1. **New or Modified Endpoint**
   - Extend existing `/api/campaigns` endpoint to accept search parameter
   - Add optional query parameter: `search` (string)
   - When `search` is present, filter results by first_name and last_name
   - Continue to support existing `limit` and `offset` parameters
   - Return same `PaginatedCampaignsResponse` format

2. **Database Query**
   - Use SQL LIKE or equivalent for partial matching
   - Search pattern: `%{search_term}%` (matches anywhere in string)
   - Case-insensitive comparison
   - Search condition: `client_first_name LIKE %term% OR client_last_name LIKE %term%`

3. **Pagination Logic Reusability**
   - Current pagination implementation should work for both:
     - Normal campaign listing (no search filter)
     - Search results (with search filter applied)
   - Reuse existing pagination counting and limiting logic
   - The `total` count in response should reflect filtered results when searching

### Frontend Implementation
1. **State Management**
   - Add `searchTerm` state to track current search query
   - Add `isSearchActive` state to determine if search is active
   - Maintain existing pagination state (offset, hasMore, total)

2. **API Integration**
   - Modify `fetchCampaigns` to accept optional search parameter
   - Include search term in API call when searching
   - Handle search + pagination combination

3. **UI Updates**
   - Add search input and button to Leads page header
   - Show/hide X button based on search state
   - Update status text to show "results" vs "campaigns" when searching
   - Reuse existing `CampaignTable` component without modifications

## User Flow

### Search Flow
1. User navigates to Leads page → Sees first 25 campaigns
2. User enters "John" in search box
3. User clicks Search button
4. System queries database for campaigns matching "John" in first or last name
5. Table displays matching results with pagination
6. User can click "Load More" to see additional matching campaigns

### Clear Search Flow
1. User has active search with results displayed
2. User clicks X button
3. Search input clears
4. System fetches initial 25 campaigns (same as page load)
5. User returns to normal browsing mode

## Edge Cases
1. **Empty search term**: Disable Search button when input is empty
2. **Search with no results**: Display "No results found" message
3. **Search while loading**: Disable search button during any loading operation
4. **Special characters**: Handle special characters in search terms safely (SQL injection prevention)
5. **Very long search terms**: Consider reasonable max length for search input (e.g., 100 characters)
6. **Search with pagination**: Ensure offset/limit work correctly with filtered results

## Out of Scope
- Email address search (explicitly excluded)
- Property address search
- Advanced filters (status, date ranges, etc.)
- Search history or saved searches
- Export of search results
- Multi-field search with boolean operators (AND/OR)
- Real-time/as-you-type search

## Success Metrics
- Users can find a specific lead in < 5 seconds
- Search response time < 1 second for databases with 1000+ campaigns
- Reduced time-to-find compared to manual scrolling (baseline measurement)

## Future Enhancements (Not in Initial Release)
- Search by email address
- Search by property address
- Advanced filters (campaign status, date ranges)
- Search suggestions/autocomplete
- Recent searches
- Combined search with sorting functionality

## Technical Notes
- Pagination logic should be abstracted/reusable for both search and non-search queries
- Backend should use database indexes on first_name and last_name columns for performance
- Consider adding FULLTEXT index for better search performance at scale
- Frontend should maintain search state separate from pagination state for cleaner code

