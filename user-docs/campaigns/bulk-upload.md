---
layout: page
title: Bulk Upload Leads (CSV)
---

# Bulk Upload Leads (CSV)

Bulk upload lets you add many leads in one shot.

## CSV Format

Your file must include these columns:
- `first_name`
- `last_name`
- `email`
- `zip_code`

Optional column:
- `formatted_address`

How campaign type is chosen:
- Address filled in -> Home Valuation Campaign
- Address blank/missing -> Market Update Campaign

## File Rules

- File type: `.csv`
- Max rows: `1000`
- Header names are not case-sensitive

## Upload Steps

1. Go to Leads and choose bulk upload.
2. Select your CSV file.
3. Confirm row count.
4. Start import.
5. Watch results as rows process.

## Why Rows Fail

Dripr checks your file before import and during import.

Common reasons:
- Email already exists
- Email is invalid/undeliverable
- Address data cannot be found (for address-based rows)
- Missing required fields

## Canceling an Upload

- You can cancel during processing.
- Already imported rows stay saved.
- Remaining rows stop.

## Plan Limits

If the upload would put you over your plan limit, it can be rejected.  
If this happens, reduce active campaigns or upgrade your plan, then try again.
