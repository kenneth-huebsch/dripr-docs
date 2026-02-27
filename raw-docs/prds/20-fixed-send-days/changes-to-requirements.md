# First Email Sends Immediately If fixed_send_day = today
## FIRST_TIME_CAMPAIGN_DELAY_HOURS=0
As a user
When I create an email campaign
And I set the fixed Send Day to the current day
And FIRST_TIME_CAMPAIGN_DELAY_HOURS=0
And it is within business hours
Then I want the initial email to send out send out immediately
And I want subsequent emails to send out every_n_months from now on the same day

Ex:
Create email on 2/1/2026, fixed_send_day=1, FIRST_TIME_CAMPAIGN_DELAY_HOURS=0, every_n_months=1
- First email goes out immediately
- 2nd email goes out 3/1/2026

## FIRST_TIME_CAMPAIGN_DELAY_HOURS=24
As a user
When I create an email campaign
And I set the fixed Send Day to the current day
And FIRST_TIME_CAMPAIGN_DELAY_HOURS=24
And it is within business hours
Then I want the initial email to send out send out 24 hours from now
And I want subsequent emails to send out every_n_months from now on the same day

Ex:
Create email on 2/1/2026, fixed_send_day=1, FIRST_TIME_CAMPAIGN_DELAY_HOURS=24, every_n_months=1
- First email goes 2/2/2026
- 2nd email goes out 3/1/2026

# First Email Sends on fixed_send_day when fixed_send_day != today
## FIRST_TIME_CAMPAIGN_DELAY_HOURS=0
As a user
When I create an email campaign
And I set the fixed Send Day to some day other then today
And FIRST_TIME_CAMPAIGN_DELAY_HOURS=0
And it is within business hours
Then I want the initial email to send out at the next occurance of that business day
And I want subsequent emails to send out every_n_months after on the same day

Ex:
Create email on 2/1/2026, fixed_send_day=5, FIRST_TIME_CAMPAIGN_DELAY_HOURS=0, every_n_months=1
- First email goes on 2/5/2026
- 2nd email goes out 3/5/2026

## FIRST_TIME_CAMPAIGN_DELAY_HOURS=72
As a user
When I create an email campaign
And I set the fixed Send Day to to some day other then today
And FIRST_TIME_CAMPAIGN_DELAY_HOURS=72
And it is within business hours
Then I want the initial email to send out send out whichever comes later (72 hours from now OR the next occurance of fixed_send_day)
And I want subsequent emails to send out every_n_months after on the same day

Ex:
Create email on 2/1/2026, fixed_send_day=5, FIRST_TIME_CAMPAIGN_DELAY_HOURS=72, every_n_months=1
- First email goes 2/5/2026
- 2nd email goes out 3/5/2026

Ex:
Create email on 2/1/2026, fixed_send_day=2, FIRST_TIME_CAMPAIGN_DELAY_HOURS=72, every_n_months=1
- First email goes 2/4/2026
- 2nd email goes out 3/2/2026

# First Email Sends tomorrow during business hours when fixed_send_day = today, ONLY_SEND_EMAILS_DURING_WORKING_HOURS=true, we are after business hours
## FIRST_TIME_CAMPAIGN_DELAY_HOURS=0
As a user
When I create an email campaign
And I set the fixed Send Day to today
And FIRST_TIME_CAMPAIGN_DELAY_HOURS=0
And it is after business hours
Then I want the initial email to send out tomorrow during business hours.
And I want subsequent emails to send out every_n_months from now.

## FIRST_TIME_CAMPAIGN_DELAY_HOURS=72
As a user
When I create an email campaign
And I set the fixed Send Day to today
And FIRST_TIME_CAMPAIGN_DELAY_HOURS=72
And it is after business hours
Then I want the initial email to send out send out during the next business hours window after 72 hours
And I want subsequent emails to send out every_n_months from now.