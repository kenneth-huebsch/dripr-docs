---
layout: page
title: Troubleshooting
---

# Troubleshooting

Quick fixes for the most common issues.

## Campaign Won't Create

Check these first:
- Required fields are present.
- Email looks correct.
- You are within your plan limit.
- Address or ZIP matches the campaign type.

Note: an unknown ZIP code no longer blocks creation. If your ZIP isn't in our database, we swap it for the numerically-closest ZIP we do have data for. See [Create Campaigns](campaigns/create-campaigns.md#unknown-zip-codes).

## Check Address Came Back Red

Two cases:

- **"We couldn't find this property on Zillow"** — switch the campaign to a **No-Address Newsletter** (toggle on the campaign form). Market content for the ZIP will still go out.
- **"Zillow's address doesn't match"** — click **Apply Zillow's format** to use their canonical version, or switch to a **No-Address Newsletter**.

You can also submit anyway — if Zillow still can't find the property after creation, the campaign auto-switches to a No-Address Newsletter on its own.

## Campaign Switched to No-Address Unexpectedly

If an address-newsletter campaign shows up as a no-address newsletter, it means our post-creation Zillow lookup couldn't produce a home-value section. The campaign self-recovered rather than going to **Error**. You'll see a log line indicating the auto-switch.

If you believe Zillow does have the property, double-check the address formatting, update the lead, and toggle it back to an Address Newsletter.

## Campaign Stuck or Slow

Try this:
1. Refresh the lead details page.
2. Check current campaign and email status.
3. Wait a little and refresh again.

If nothing changes after a while, contact support and include campaign ID.

## Email Not Sending

Common causes:
- Waiting for manual approval
- First-email delay still active
- Sending window not open yet (Tuesday-Thursday, `11:00 AM-6:00 PM ET`)
- Campaign disabled
- Lead unsubscribed/bounced/spam complaint

## Can't Delete a Campaign

If a campaign is currently building/in progress, deletion is blocked until that step finishes.

Try this:
- Refresh and check the campaign status.
- Wait for the building step to complete.
- Delete after the campaign is no longer in progress.

## Older Draft Marked Expired

This is normal if a newer cycle replaced an older unapproved draft.  
Expired drafts stay in history but cannot be sent.

## Bulk Upload Errors

Review:
- CSV headers and formatting
- Duplicate emails
- Undeliverable addresses
- Address lookup failures

Fix the source file and re-upload.

## Metrics Look Off

- Dashboard uses rolling 30-day and lifetime counters.
- Delivery and engagement events can arrive after initial send.
- Refresh to fetch latest aggregates.

## When to Contact Support

Share:
- Your account email
- Campaign ID(s)
- Approximate time issue started
- Screenshot of the error/status

This helps support fix things faster.
