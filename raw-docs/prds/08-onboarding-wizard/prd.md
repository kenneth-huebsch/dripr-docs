# Product Requirements Document: Onboarding Wizard

## Overview

Create a streamlined onboarding checklist that helps new users set up their Dripr account and send their first email campaign. The checklist appears as a collapsible section at the top of the Dashboard page and guides users through essential setup steps.

## Business Goals

1. **Improve user activation**: Guide new users to their first sent email faster
2. **Increase feature adoption**: Encourage users to set up signatures and Gmail integration
3. **Reduce friction**: Provide clear, actionable next steps for new users
4. **Build confidence**: Help users understand what needs to be done to succeed

## User Stories

### New User Journey
- As a new user, I want to see what steps I need to take to start sending emails
- As a new user, I want to easily navigate to setup pages from a checklist
- As a new user, I want to see my progress as I complete setup tasks

### Experienced User Journey
- As an experienced user, I want the onboarding checklist to get out of my way
- As an experienced user, I want to reference the checklist if I want to complete remaining tasks
- As an experienced user, I want to see which optional features I haven't set up yet

## Feature Requirements

### 1. Onboarding Checklist Component

**Location**: Dashboard page, above the "Leads" metrics section

**Visual Design**: 
- Minimal card/section design with clean checkmarks
- Collapsible/expandable banner
- Clear visual hierarchy between completed and incomplete tasks
- Optional tasks should be clearly marked as "(Optional)"

**Behavior**:
- Auto-collapsed if user has sent any emails (lifetime_emails_sent > 0)
- Auto-expanded if user has sent no emails (lifetime_emails_sent === 0)
- User can manually collapse/expand by clicking header
- Collapsed/expanded state does NOT persist across sessions - always determined by email count
- Each task is clickable and navigates to the relevant page

### 2. Task List

Tasks appear in this order:

1. **Set Up Your Signature: Upload a Profile Image** (Optional)
   - Links to: `/signature-settings`
   - Completed when: `profile_img_url` is not null in user's signature
   
2. **Set Up Your Signature: Upload Your Agency Logo** (Optional)
   - Links to: `/signature-settings`
   - Completed when: `agency_logo_url` is not null in user's signature
   
3. **Set Up Your Signature: Set Your Phone Number** (Optional)
   - Links to: `/signature-settings`
   - Completed when: `phone_number` is not null and not empty in user's signature
   
4. **Connect Gmail Account** (Optional)
   - Links to: `/gmail-integration`
   - Completed when: User has connected their Gmail account (OAuth token exists)
   - Description: "Send emails from your own email address to increase credibility and deliverability"
   
5. **Create Your First Campaign**
   - Links to: `/leads/new`
   - Completed when: User has at least one campaign created
   - Description: "Choose between Home Valuation campaigns (for homeowners) or Market Update newsletters (for prospects)"

### 3. Visual States

**Task States**:
- ✅ **Completed**: Green checkmark icon, slightly muted text color
- ⬜ **Incomplete**: Empty checkbox or gray checkmark, normal text color
- 🔗 **Clickable**: Entire task row is clickable, hover state shows it's interactive

**Section States**:
- **Expanded**: Full checklist visible with collapse arrow (▼)
- **Collapsed**: Header only visible with expand arrow (▶), showing something like "Getting Started"

### 4. Task Completion Detection

The frontend should check completion status by calling existing backend APIs:

**For Signature Tasks**:
- Call: `GET /api/signatures` (existing endpoint)
- Check: `profile_img_url`, `agency_logo_url`, `phone_number` fields

**For Gmail Integration**:
- Call: `GET /api/gmail/status` (existing endpoint)
- Check: `isConnected` boolean

**For Campaign Creation**:
- Use existing Dashboard data: `active_leads_count > 0`
- Or call: `GET /api/campaigns` and check if any campaigns exist

**For Auto-Collapse Logic**:
- Use existing Dashboard data: `lifetime_emails_sent > 0`

## User Experience Flow

### First Visit (No Emails Sent)
1. User logs in and navigates to Dashboard
2. Onboarding checklist is expanded by default at top of page
3. User sees all unchecked tasks
4. User clicks a task (e.g., "Set Up Your Signature: Upload a Profile Image")
5. User is navigated to Signature Settings page
6. User uploads profile image
7. User returns to Dashboard
8. Profile image task shows green checkmark ✅

### Subsequent Visits (No Emails Sent Yet)
1. User returns to Dashboard
2. Checklist is still expanded (because lifetime_emails_sent === 0)
3. Previously completed tasks show green checkmarks
4. User can continue with remaining tasks or manually collapse checklist

### After First Email Sent
1. User sends their first email
2. `lifetime_emails_sent` becomes > 0
3. On next Dashboard visit, checklist is collapsed by default
4. User can expand to see remaining optional tasks if desired
5. Checklist remains accessible forever for reference

## Technical Implementation Notes

### Frontend Changes Required

**1. Create New Component**: `OnboardingChecklist.tsx`
- Located in: `ui/src/components/`
- Fetches signature status, Gmail status, campaign count
- Determines auto-collapse based on `lifetime_emails_sent`
- Manages expand/collapse state (component-level, not persisted)
- Renders task list with completion status

**2. Modify Dashboard.tsx**:
- Import and render `OnboardingChecklist` component
- Place above existing metrics sections
- Pass `lifetime_emails_sent` from existing `DashboardStats`

**3. API Integration**:
- Use existing APIs - no backend changes needed
- `/api/signatures` - for signature completion status
- `/api/gmail/status` - for Gmail connection status  
- `/api/campaigns` or use `active_leads_count` from dashboard stats
- `/api/dashboard` - already provides `lifetime_emails_sent`

**4. TypeScript Types**:
- Add interface for checklist task state
- Extend or use existing signature/Gmail status types

### Backend Changes Required

**NONE** - All required data is already available via existing API endpoints.

## Open Questions & Future Enhancements

### Future Enhancements (Out of Scope for V1)
- Add celebration animation/modal when user sends first email
- Add tooltips with more detailed explanations for each task
- Add onboarding analytics to track which tasks users complete and when
- Add ability to permanently dismiss checklist
- Add more granular tracking (e.g., "Campaign created but not enabled")
- Add subscription/billing setup task when that becomes relevant

## Success Metrics

Track these metrics to measure onboarding success:

1. **Time to first email sent**: How long from signup to first sent email
2. **Signature completion rate**: % of users who upload profile image, logo, phone
3. **Gmail connection rate**: % of users who connect Gmail
4. **Campaign creation rate**: % of users who create at least one campaign
5. **Task completion correlation**: Which tasks correlate with long-term retention

## Design Specifications

### Visual Hierarchy
```
Dashboard Page
├── Page Header ("Dashboard Metrics")
├── 🆕 Onboarding Checklist (Collapsible Card)
│   ├── Header: "Getting Started" with expand/collapse icon
│   ├── Task List (when expanded):
│   │   ├── ✅/⬜ Set Up Your Signature: Upload a Profile Image
│   │   ├── ✅/⬜ Set Up Your Signature: Upload Your Agency Logo
│   │   ├── ✅/⬜ Set Up Your Signature: Set Your Phone Number
│   │   ├── ✅/⬜ Connect Gmail Account (Optional) + description
│   │   └── ✅/⬜ Create Your First Campaign + description
├── Leads Section (existing)
├── Lifetime Email Performance (existing)
└── This Month's Email Performance (existing)
```

### Example UI Layout (Expanded State)

```
┌─────────────────────────────────────────────────────────┐
│ Dashboard Metrics                                        │
│ Performance overview of your email campaigns and leads   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ ▼ Getting Started                                        │
├─────────────────────────────────────────────────────────┤
│ ⬜ Set Up Your Signature: Upload a Profile Image      → │
│ ✅ Set Up Your Signature: Upload Your Agency Logo     → │
│ ⬜ Set Up Your Signature: Set Your Phone Number       → │
│ ⬜ Connect Gmail Account (Optional)                   → │
│    Send emails from your own email address              │
│ ⬜ Create Your First Campaign                         → │
│    Choose between Home Valuation or Market Updates      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Leads                                                    │
│ [Total Leads: 5]                                        │
└─────────────────────────────────────────────────────────┘
```

### Example UI Layout (Collapsed State)

```
┌─────────────────────────────────────────────────────────┐
│ Dashboard Metrics                                        │
│ Performance overview of your email campaigns and leads   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ ▶ Getting Started                              4 of 5 ✅│
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Leads                                                    │
│ [Total Leads: 5]                                        │
└─────────────────────────────────────────────────────────┘
```

## Acceptance Criteria

### Must Have (V1)
- ✅ Onboarding checklist displays above metrics on Dashboard page
- ✅ Checklist auto-expands when user has 0 emails sent
- ✅ Checklist auto-collapses when user has >0 emails sent
- ✅ User can manually toggle expand/collapse state
- ✅ All 5 tasks display with correct completion status
- ✅ Clicking a task navigates to the correct page
- ✅ Completed tasks show green checkmark
- ✅ Optional tasks clearly marked as "(Optional)"
- ✅ Gmail task shows helpful description
- ✅ Campaign task shows helpful description
- ✅ No backend changes required (use existing APIs)

### Nice to Have (Future)
- Smooth expand/collapse animation
- Tooltip hover states with more details
- Progress indicator (e.g., "3 of 5 completed")
- Celebration when first email sent
- Analytics tracking for task completion

## Dependencies

- Existing `/api/signatures` endpoint
- Existing `/api/gmail/status` endpoint  
- Existing `/api/dashboard` endpoint (for `lifetime_emails_sent`)
- Existing `/api/campaigns` or dashboard `active_leads_count`

## Timeline Estimate

**Frontend Development**: 1-2 days
- Component creation: 4-6 hours
- API integration: 2-3 hours
- Styling and polish: 2-3 hours
- Testing: 2-3 hours

**Total Estimated Time**: 10-15 hours

## Notes

- Keep implementation simple - no localStorage, no backend changes
- Focus on clean, minimal UI that doesn't overwhelm users
- Ensure mobile responsive design
- All tasks are truly optional - users can send emails without completing any of them
- The checklist is a guide, not a blocker

