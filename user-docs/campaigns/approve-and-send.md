---
layout: page
title: Approve and Send Workflow
---

# Approve and Send Workflow

This is the simple version of how emails move from draft to sent.

## What Happens in Order

1. Campaign is created and scheduled.
2. Dripr gathers the needed data.
3. Draft email is created.
4. You approve it (if approval is turned on).
5. Email sends when timing rules are met.

## If Approval Is Turned On

- Draft email requires manual approval.
- After approval, it sends when eligible.

## If Approval Is Turned Off

- Dripr can auto-send when timing rules are met.

## First Email Delay

Your first email may wait before sending.  
This gives you time to review your message.

## Send Window

Emails only send during this window:
- Tuesday through Thursday
- `11:00 AM-6:00 PM ET`

If an email is approved outside that window, it waits for the next eligible time.

## Monthly Schedule

After the first send, future emails follow your selected monthly send day.

## Expired Draft Emails

If a draft sits too long, it may be marked `EXPIRED`.

That means:
- It stays in history.
- It can no longer be approved/sent.
- A newer draft can move forward.

## Delivery Results You May See

Statuses include:
- Sent
- Delivered
- Opened
- Bounced
- Spam complaint
- Unsubscribed

Bounces, spam complaints, or unsubscribes can stop future sends for that lead.
