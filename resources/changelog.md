# Changelog

Automated release notes generated from merged commits.

## 2026-02-28 - `3a88790`

- Restricted sends to Tuesday-Thursday, `11:00 AM-6:00 PM ET`.
- Updated user-facing UI terminology to Address Newsletter and No-Address Newsletter.
- Blocked campaign deletion while a campaign is in building/in-progress status.

[View commit](https://github.com/kenneth-huebsch/dripr/commit/3a88790)

## 2026-02-27 - `bf82543`

- initial publish for testing

[View commit](https://github.com/kenneth-huebsch/dripr/commit/bf825431486e29130728528400b0bf695944cd6b)

## 2026-02-28 - `7bcd431`

- working hours and zillow client fixes
- address zip toggle and new google api keys
- prevent deletion of campaigns being updated and docs updates
- [release-20260228-1749] tue-thurs working hours

[View commit](https://github.com/kenneth-huebsch/dripr/commit/7bcd431df4fc1c6257a8171b2f75fab30705b5df)

## 2026-03-05 - `b984ec2`

- get metrics into issue_auditor
- [release-20260305-1208] montonicity in last_scheduled_send_date
- [release-20260305-1208] cloudwatch metrics and last_schedule_send_date bugfix

[View commit](https://github.com/kenneth-huebsch/dripr/commit/b984ec2969f9d163a818c7e789fc68e174fce282)

## 2026-03-06 - `55432cf`

- created an env var validation helper function
- [release-20260305-2050] created an env var validation helper function

[View commit](https://github.com/kenneth-huebsch/dripr/commit/55432cf6518d2d81d91a98a67820118c3667d1cd)

## 2026-03-07 - `93e04ad`

- send metrics to cloudwatch to display in dashboard
- moved zillowclientprotocol to its own file
- zillow client refactoring
- [release-20260307-1506] zillow refactor and cloudwatch metrics

[View commit](https://github.com/kenneth-huebsch/dripr/commit/93e04ad3c169e2400dd38589ce5899d067be561a)

## 2026-03-07 - `8aae79c`

- check whole word business patterns
- [release-20260307-1617] bug_fix on business exclusion matching

[View commit](https://github.com/kenneth-huebsch/dripr/commit/8aae79c79dc42a8f5f645148b5406d1ec94b248e)

## 2026-03-10 - `3fd80ca`

- bugfix to get cron_jobs logs to show in cloudwatch
- [release-20260309-2320] cron_jobs metrics bugfix

[View commit](https://github.com/kenneth-huebsch/dripr/commit/3fd80cac3cd409450baada4e752ed0f1f188447c)

## 2026-03-15 - `4c94e82`

- Create n8n README.md

[View commit](https://github.com/kenneth-huebsch/dripr/commit/4c94e82277567517c748725501786a9580e8986d)

## 2026-03-15 - `8913b0f`

- added n8n creds to accounts.md

[View commit](https://github.com/kenneth-huebsch/dripr/commit/8913b0f61b788bbdb314a0b0ad6c149e16fc7be4)

## 2026-03-23 - `2aae97b`

- working date awareness
- [release-20260323-1702] date awareness in intros

[View commit](https://github.com/kenneth-huebsch/dripr/commit/2aae97bed7b8f3bc5fecfc9f0656907741ee6aa4)

## 2026-04-02 - `fb863f9`

- [data_fetcher-release-20260401-1728] hotfix to raise polling limit to 2000
- [data_fetcher-release-20260401-1728] hotfix to raise polling limit to 2k

[View commit](https://github.com/kenneth-huebsch/dripr/commit/fb863f92524cae6d4f16b5a88d3fc236dc8d3a28)

## 2026-04-10 - `eb59539`

- plane edits
- refactor complete. no testing done yet.
- unit tests passing
- added integration tests, but not tested yet
- implemented multi-source-client-manager
- created email manager package
- added helpers for datetime conversions
- from datetime import updates
- refactored models.py into smaller files.
- integration tests passing
- requirements refactoring port update, e2e tests passing
- todos added to backlog
- back to port 5000
- [release-20260409-2021] zerobounce client and package refactors
- @kenneth-huebsch [release-20260409-2021] zerobounce client and package refactors

[View commit](https://github.com/kenneth-huebsch/dripr/commit/eb595390045c5a0628af3f83ebf69b05c9231c8e)

## 2026-04-18 - `c0fcb4c`

- fixed cron_jobs dockerfile

[View commit](https://github.com/kenneth-huebsch/dripr/commit/c0fcb4c1cfa457d1b95bf6565e944f3bf9fc7919)

## 2026-04-20 - `5d2c84f`

- tests passing
- context cleanup
- integration tests passing after main merge
- unit and int tests passing after bugfix
- plan options
- cadance recovery fix implemented
- backlog update
- [release-20260419-2047] anchor campaign create times to 3am EST
- [release-20260419-2047] anchor campaign create times to 3am EST

[View commit](https://github.com/kenneth-huebsch/dripr/commit/5d2c84f6b6365dc97bb965bf6577b77273619538)
