# Lead Details Page Fixes - Technical Plan

## Overview
Fix four UI issues on the Lead Details Page (`CampaignDetails.tsx` component) to improve consistency and usability.

## Changes Required

### 1. Add Refresh Button
**File**: `ui/src/pages/CampaignDetails.tsx`

- Import `RefreshCcw` icon from `lucide-react` (already imported in Leads.tsx)
- Add refresh button to the left of the Edit button in the header section (lines 251-284)
- Create `handleRefresh` function that calls the existing `fetchCampaign` logic
- Use the same styling as the refresh button in `Leads.tsx` (lines 119-126)
- Button should be disabled when `isLoading` is true
- Icon should animate when loading

### 2. Add Status Icon to Campaign Information Section
**File**: `ui/src/components/CampaignForm.tsx`

- Import status icon functions/logic from `CampaignTable.tsx` or create a shared utility
- The status row is at lines 390-399
- Use the same `getCampaignStatusIcon` logic from `CampaignTable.tsx` (lines 95-148)
- Display icon alongside the status text (currently just shows capitalized text)
- Import required icons: `CalendarSearch`, `Hourglass`, `Search`, `NotebookPen`, `Clock`, `Mail`, `Send`, `RefreshCwOff`, `AlertCircle` from `lucide-react`

### 3. Fix Row Background Colors
**File**: `ui/src/components/CampaignForm.tsx`

- Remove all `bg-gray-50` classes from information rows
- Change all rows to have white background (default, no background class needed)
- Affected rows:
  - Line 220: Lead Information section - First Name row
  - Line 298: Property Address section
  - Line 340: Zip Code section  
  - Line 381: Campaign Information - Lead ID row
  - Line 403: Campaign Information - Error Details row
  - Line 421: Campaign Information - Enabled row
  - Line 478: Campaign Information - BCC row
  - Line 557: Campaign Information - Notes row

### 4. Make Email History Always Visible
**File**: `ui/src/components/EmailTable.tsx`

- Remove collapsible functionality:
  - Remove `expanded` state (line 15)
  - Remove `handleToggleExpanded` function (lines 21-28)
  - Remove the clickable header with chevron icon (lines 162-173)
- Always display the table content:
  - Remove conditional rendering `{expanded && ...}` (line 175)
  - Call `fetchEmails()` on component mount using `useEffect`
  - Keep the table structure and all existing functionality (approval, viewing, etc.)

## Implementation Notes

- The refresh button should reuse the existing `fetchCampaign` function from `useEffect` (lines 98-125 in CampaignDetails.tsx)
- Status icons should match exactly what's shown in the Leads page table
- All row backgrounds should be consistent white (no alternating colors)
- Email History should load automatically when the component mounts

## Status

✅ All changes have been implemented and completed.

