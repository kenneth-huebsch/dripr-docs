---
layout: page
title: Create and Manage Campaigns
---

# Create and Manage Campaigns

Each lead you add becomes a recurring monthly email campaign.

## Newsletter Types

### Address Newsletter
Use this when you have the lead's property address.

Usually includes:
- Their home value section
- Local market trends
- Nearby listings and recent sales

### No-Address Newsletter
Use this when you do not have a property address, but do have a ZIP code.

This version skips the home-value section and focuses on local market content.

## Required Contact Fields

For every lead:
- `first_name`
- `last_name`
- `email`

Then add one:
- `formatted_address` (address newsletter)
- `zip_code` (no-address newsletter)

## Check Address (Address Newsletters)

When you enter an address, click **Check Address** to pre-verify it against Zillow before saving the campaign.

You'll see one of three results:

- **Green — Address verified.** The address was found on Zillow and matches what you typed.
- **Red — Zillow doesn't have this property.** We couldn't build a home-value section for this address. Switch the campaign to a **No-Address Newsletter** (toggle at the top of the form) so we send market updates for the ZIP instead.
- **Red — Zillow's address doesn't match.** We show you Zillow's canonical version (e.g. `1828 N Karlov Ave #2` vs `1828 N Karlov Ave`). You can either click **Apply Zillow's format** to use theirs, or switch to a **No-Address Newsletter**.

Check Address is a pre-flight check, not a blocker — you can still submit the campaign even if it comes back red.

## What Happens If Address Lookup Fails Later

If you skip Check Address (or it passes but Zillow later can't produce the data we need for the home-value section), we **automatically switch the campaign to a No-Address Newsletter** instead of marking it as errored. The lead will appear in your dashboard as a working no-address campaign, and you'll see a log entry noting the switch.

This means you rarely need to manually fix campaigns that fail property lookup — they self-recover to the no-address flow.

## Unknown ZIP Codes

If you enter a ZIP code we don't have market data for, we **automatically swap it to the numerically-closest ZIP in our database** at campaign creation. The campaign will send market data for that nearby ZIP. The swap is silent in the UI — no error, no prompt.

This usually only matters for very new ZIPs or unusual entries. For normal US ZIPs, you won't notice a difference.

## Monthly Send Day

Choose the day each monthly email should go out.

- Select a day from `1-28`.
- This keeps sends consistent month to month.
- Sends only go out Tuesday-Thursday, `11:00 AM-6:00 PM ET`.
- The first email can follow separate first-send timing rules.

## Editing Campaigns

You can edit lead details later, including monthly send day.

Good to know:
- Changing send day updates future sends.
- Edits should not trigger instant sends.
- Disabled campaigns stay paused until re-enabled.
- Campaigns in a building/in-progress state cannot be deleted.

## Statuses You Might See

Common statuses:
- Waiting for data
- Waiting for home analysis
- Ready to create email
- Ready to send
- Unsubscribed
- Error

If something looks stuck, refresh the page first, then use the troubleshooting guide.
