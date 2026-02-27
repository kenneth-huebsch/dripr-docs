# Fix Race Condition: User Creation Webhook Delay (Dashboard Only)

## Problem
When a new user signs up, they're redirected to the UI which immediately tries to fetch data. However, the user record isn't created in the database until the Clerk webhook is processed, causing API calls to fail with "User not found" (404) errors.

## Solution
Implement retry/polling logic **only on the Dashboard page** that:
1. Detects "User not found" (404) errors from the dashboard API call
2. Automatically retries with exponential backoff
3. Shows a spinner during retries
4. Shows a technical error message after max retries

## Implementation Plan

### 1. Update API Client (Minimal Change)
- **File**: `ui/src/services/apiClient.ts`
- Enhance error handling to preserve error details (status code and error message from response body)
- Throw structured errors that include status code and message so Dashboard can detect "User not found" condition
- This is a minimal change necessary for error detection

### 2. Update Dashboard Page
- **File**: `ui/src/pages/Dashboard.tsx`
- Implement inline retry logic in `fetchDashboardData` function
- Detect 404 errors with "User not found" message
- Implement exponential backoff: 1s, 2s, 4s, 8s, 16s (5 retries total, ~30 seconds max)
- Show spinner during retries (reuse existing loading state)
- After max retries, show error message: "Unable to find data for this clerk user"
- No manual refresh button needed

## Technical Details

### Retry Logic Parameters
- Initial delay: 1 second
- Max delay: 16 seconds
- Exponential multiplier: 2x
- Max retries: 5 attempts
- Total max wait time: ~30 seconds

### Error Detection
- Check for HTTP 404 status code
- Check error message contains "User not found"
- Only retry on this specific error condition

### User Experience
- During retries: Show existing loading spinner (no additional message needed)
- After max retries: Show error message "Unable to find data for this clerk user"
- No manual refresh button

## Files to Modify
1. `ui/src/services/apiClient.ts` - Preserve error details (status code, message)
2. `ui/src/pages/Dashboard.tsx` - Add retry logic to `fetchDashboardData`

## Status

✅ All changes have been implemented and completed.

