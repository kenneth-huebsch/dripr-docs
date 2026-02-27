### PRD: Monthly Agent Statistics CSV via SQL

### Summary
Generate a CSV where each row contains “last 30 days” and lifetime statistics for each user. The deliverable is one or more MySQL files that can be executed by external automation to produce the CSV output monthly. No application code is required in this feature; the SQL alone must produce the desired flat result set.

### Scope
- Compute per-user metrics from existing tables in the database described in `docs/system-description.md` and `python/shared_resources/models.py`.
- “Monthly” is defined as the last 30 full days relative to execution time.
- Provide a single primary MySQL query that returns one row per agent with all required columns.
- Aggregates already exist: `usage_summary` exists but is per-billing-period; prefer event/timestamp tables for last-30-day metrics.

### Out of Scope
- Scheduling/execution. External automation will run the SQL and export to CSV.
- UI changes.

### Key Definitions
- Time window
  - window_end: execution time in UTC (use NOW()).
  - window_start: NOW() - INTERVAL 30 DAY (UTC).
- User set
  - Include any user present in `users`.
- Active lead (point-in-time, not windowed)
  - A campaign with `enabled = 1`
- Email event counting (within the last 30 days)
  - sent: emails with non-minimum `sent_datetime` in window.
  - opened: `opened_at` in window.
  - spam complaints: `spam_complaint_at` in window.
  - unsubscribes: `unsubscribed_at` in window.
- Recipient uniqueness
  - Unique recipients are counted by distinct `emails.to_email` scoped per-user within the window.

### Required Output Columns (per agent row)
- Identification
  - `user_email`
- Lead/Campaign snapshot
  - `active_leads_count_now` (as of query time)
  - `new_leads_last_30d` (campaigns with `creation_datetime` in window)
- Email volume and outcomes (last 30 days)
  - `emails_sent_last_30d`
  - `emails_opened_last_30d`
  - `spam_complaints_last_30d`
  - `unsubscribes_last_30d`
- Lifetime counters (since inception)
  - `lifetime_emails_sent`
  - `lifetime_spam_complaints`
  - `lifetime_unsubscribes`

### Output Format and Ordering
- The primary SQL must produce a single result set suitable for CSV export, one row per user.
- Recommended ordering: `ORDER BY agent_email ASC`.

### SQL Deliverables
1) Primary per-agent metrics query (MySQL 8.0+ recommended)
   - Use CTEs to compute window bounds and sub-aggregates for readability.
   - Treat NOW() as UTC; do not apply timezone conversions in-SQL.
   - Avoid scanning entire large tables without filters; leverage indexes (`idx_email_user_id`, etc.).

### Calculation Details (SQL-friendly)
- Window
  - `WITH params AS (SELECT NOW() AS window_end, NOW() - INTERVAL 30 DAY AS window_start)`

- Active leads now
  - Count in `campaigns` where `user_id = users.id AND enabled = 1 AND campaign_status NOT IN ('ERROR')`.

- New leads last 30 days
  - Count campaigns where `creation_datetime >= window_start AND creation_datetime < window_end`.

- Emails prepared last 30 days
  - Count `emails` by `creation_datetime` in window.

- Emails sent last 30 days
  - Count `emails` where `sent_datetime >= window_start AND sent_datetime < window_end`.

- Opened last 30 days
  - Count `emails` where `opened_at >= window_start AND opened_at < window_end`.

- Spam complaints last 30 days
  - Count emails where `spam_complaint_at >= window_start AND spam_complaint_at < window_end`.

- Unsubscribes last 30 days
  - Count emails where `unsubscribed_at >= window_start AND unsubscribed_at < window_end`.

- Lifetime metrics
  - Sent: `sent_datetime > '1970-01-01'` (no window).
  - Spam complaints: `delivery_status = 'SPAM_COMPLAINT'`.
  - Unsubscribes: `unsubscribed_at > '1970-01-01'` (no window).

### Acceptance Criteria
- Running the primary SQL on a production-like snapshot returns one row per user with all columns listed above, correct data types, and non-null window bounds.
- Metrics limited to the last 30 days reflect event timestamps where available; bounce/unsubscribe approximations are documented if timestamps are missing.
- The SQL executes under MySQL 8.0+ and finishes within reasonable time using existing indexes.
- The output sorts by `agent_email` and is CSV-exportable by the automation system without further transformation.

### Implementation Notes
- Use CTEs for readability (e.g., `params`, `emails_in_window`, `sent_in_window`, `delivered_in_window`, `opens_in_window`, `bounces_in_window`, `unsubs_in_window`, `spam_in_window`, `zip_usage_in_window`).
- Join aggregates back to `users` on `users.id = emails.user_id` using LEFT JOINs so agents with zero activity still appear.
- Guard all rate calculations with `NULLIF(denominator, 0)` to avoid division-by-zero.
- Consider making the subscriber filter configurable via a commented WHERE clause block.