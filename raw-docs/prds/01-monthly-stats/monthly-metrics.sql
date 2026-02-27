-- Monthly Agent Statistics Query
-- Purpose: Generate per-user statistics for the last 30 days and lifetime metrics
-- Output: One row per user with email activity, lead counts, and spam metrics
-- Usage: Execute monthly via external automation and export to CSV
-- Compatible with: MySQL 5.7+ and MySQL 8.0+

USE `dripr-prod`;

SELECT 
    u.email AS user_email,
    COALESCE(aln.count_active_leads, 0) AS active_leads_count_now,
    COALESCE(nll.count_new_leads, 0) AS new_leads_last_30d,
    COALESCE(esl.count_sent, 0) AS emails_sent_last_30d,
    COALESCE(eol.count_opened, 0) AS emails_opened_last_30d,
    COALESCE(scl.count_spam, 0) AS spam_complaints_last_30d,
    COALESCE(usl.count_unsubscribes, 0) AS unsubscribes_last_30d,
    COALESCE(les.count_lifetime_sent, 0) AS lifetime_emails_sent,
    COALESCE(bls.count_lifetime_opened, 0) AS lifetime_emails_opened,
    COALESCE(lsc.count_lifetime_spam, 0) AS lifetime_spam_complaints,
    COALESCE(lus.count_lifetime_unsubscribes, 0) AS lifetime_unsubscribes
FROM users u
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_active_leads
    FROM campaigns
    WHERE enabled = 1
    GROUP BY user_id
) aln ON u.id = aln.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_new_leads
    FROM campaigns
    WHERE creation_datetime >= NOW() - INTERVAL 30 DAY
      AND creation_datetime < NOW()
      AND enabled = 1
    GROUP BY user_id
) nll ON u.id = nll.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_sent
    FROM emails
    WHERE sent_datetime >= NOW() - INTERVAL 30 DAY
      AND sent_datetime < NOW()
    GROUP BY user_id
) esl ON u.id = esl.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_opened
    FROM emails
    WHERE opened_at >= NOW() - INTERVAL 30 DAY
      AND opened_at < NOW()
    GROUP BY user_id
) eol ON u.id = eol.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_spam
    FROM emails
    WHERE spam_complaint_at >= NOW() - INTERVAL 30 DAY
      AND spam_complaint_at < NOW()
    GROUP BY user_id
) scl ON u.id = scl.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_unsubscribes
    FROM emails
    WHERE unsubscribed_at >= NOW() - INTERVAL 30 DAY
      AND unsubscribed_at < NOW()
    GROUP BY user_id
) usl ON u.id = usl.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_lifetime_sent
    FROM emails
    WHERE sent_datetime > '1970-01-01'
    GROUP BY user_id
) les ON u.id = les.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_lifetime_opened
    FROM emails
    WHERE opened_at > '1970-01-01'
    GROUP BY user_id
) bls ON u.id = bls.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_lifetime_spam
    FROM emails
    WHERE delivery_status = 'SPAM_COMPLAINT'
    GROUP BY user_id
) lsc ON u.id = lsc.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS count_lifetime_unsubscribes
    FROM emails
    WHERE unsubscribed_at > '1970-01-01'
    GROUP BY user_id
) lus ON u.id = lus.user_id
WHERE aln.count_active_leads > 0
  AND u.email NOT IN ('kenneth.huebsch@gmail.com', 'kenny@puffin.dev', 'kenny@dripr.ai', 'kenny@getdripr.com')
ORDER BY u.email ASC;
