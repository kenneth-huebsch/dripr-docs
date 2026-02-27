# Localized Neighborhood Content Block
## Product Requirements Document

## Overview

This document defines the requirements for replacing the existing "Expert Tip" section in Dripr emails with a localized content block that signals community awareness using only a recipient's ZIP code.

This feature is **always on**, requires **no agent configuration**, and is designed to be **computed once per ZIP code per month**, then reused across all emails sent to that ZIP during the same month.

## Project Scope

**⚠️ Important: This PRD describes a complete vision for localized neighborhood content, but the current project scope is limited to:**

- **Priority 1: Local Business Highlight** (primary content type)
- **Priority 4: Expert Tip** (fallback when business highlight cannot be generated)

The remaining content types (Local News/Development Theme and Local Market Micro-Insight) are documented below for future reference but are **out of scope** for this project.

## Problem Statement

The current “Expert Tip” section feels generic and non-local. User feedback indicates agents want content that feels specific to where their clients live and reinforces the agent’s local expertise.

The goal is to introduce localized content that feels human, relevant, and intentional, without increasing agent workload or introducing operational fragility.

## Goals

- Replace "Expert Tip" with a localized neighborhood-focused content block
- Use ZIP code as the only required input
- Ensure content feels local and authentic
- Precompute content once per ZIP code per month
- Reuse precomputed content for all emails sent to that ZIP during the month
- Ensure recipients never receive the same content twice
- Fall back to expert tip if unable to generate local content
## Non-Goals

- Real-time or breaking news delivery
- Manual curation by agents
- Opinionated or predictive commentary
- Personalization beyond ZIP-level locality

## Feature Summary

### Feature Name

**Around Your Neighborhood**

### Placement

Replaces the existing “Expert Tip” section in all Dripr emails.

### Behavior

- Always included in emails
- Content is generated automatically
- Content updates at most once per ZIP code per calendar month

## Inputs and Derived Data

### Required Input

- Recipient ZIP code

### Derived Data

- Latitude and longitude

## Content Generation Strategy

Content is generated using a **tiered priority system**. The system attempts to generate the highest-priority content first and falls back as needed.

### Priority Order (Current Project Scope)

**In Scope:**
1. Local Business Highlight (Primary)
4. Expert Tip (Fallback)

**Future Work (Out of Scope for This Project):**
2. Local News or Development Theme
3. Local Market Micro-Insight

Only one content type is rendered per email. For this project, the system will attempt to generate a Local Business Highlight and fall back to the Expert Tip if no suitable business can be found.

## Content Types

### 1. Local Business Highlight (Primary)

**Description**  
Highlights a nearby, well-rated local business.

**Example Output**  
> Local favorite nearby. Oak Street Coffee is a highly rated spot known for its weekend crowds and welcoming atmosphere.

**Data Source**

- Google Places API

**Selection Rules**

- Distance: use the same radius logic as selecting active listings and recent sales
- Minimum rating threshold
- Review count: `user_ratings_total >= 30` and `user_ratings_total <= 1500` (use review volume as a proxy for local businesses)
- Randomized selection with quality bias
- Category rotation to avoid repetition

**Chain Exclusion**

- Exclude known chains by name using a chain exclusion list
- The exclusion list must include company names such as: Home Depot, Lowe's, Starbucks, Target, Walmart, CVS, Walgreens, Planet Fitness, Anytime Fitness, McDonald's, Subway
- This list should be maintained and expanded as needed to avoid national/regional chains

**Category Preferences**

- **Prefer local-friendly categories** where chains are rarer:
  - bakery
  - cafe
  - coffee_shop
  - restaurant (non-fast-food)
  - florist
  - pet_store
  - yoga_studio
  - hair_salon
  - nail_salon
  - bookstore

- **Avoid categories** that are typically dominated by chains:
  - big_box_store
  - department_store
  - home_improvement_store
  - hardware_store
  - home_improvement

**Image Requirements**

- An image of the business must be rendered in the email
- The image should be sourced from the Google Places API (photo reference)
- If no business image is available from the API, the system must fall back to a generic placeholder image (to be provided)
- The image must be included in the precomputed content and stored for reuse

### 2. Local News or Development Theme ⚠️ **Future Work (Out of Scope)**

**Description**  
A generalized summary of a recent local trend or development.

**Example Output**  
> Recent approvals and investments suggest continued development activity in your area.

**Data Sources**

- NewsAPI.org  
- Optional fallback. GNews API

**Rules**

- Summarize themes, not headlines
- Avoid precise dates or time-sensitive phrasing
- Keep language intentionally high-level

### 3. Local Market Micro-Insight ⚠️ **Future Work (Out of Scope)**

**Description**  
A ZIP-level observation derived from existing market data.

**Example Output**  
> Homes in your ZIP code continue to sell faster than the broader metro average.

**Data Source**

- Existing MLS or market data already used by Dripr

**Rules**

- Observational only
- No advice or predictions
- Neutral tone

### 4. Expert Tip (Fallback)

**Description**  
If we are unable to compute any valuable local insights, then we fall back to the expert tip for the month which I will continue to populate.

## Precomputation and Caching Requirements

### Precomputation Trigger

- When local market metrics for a ZIP code are computed for the **first time in a given month**, the localized neighborhood content must also be generated
- This content is stored and reused for all emails sent to that ZIP during the same month

### Storage Requirements

Content must be stored keyed by:

- ZIP code
- Year
- Month

Stored content should include:

- Rendered text
- Content type used (business or fallback for this project)
- Image URL or reference (for Local Business Highlight content)
- Source metadata for debugging and observability

**Recipient Content History:**

To ensure recipients never receive duplicate content, the system must track:
- Which business highlights have been shown to each recipient (by recipient identifier)
- This history should be used to exclude previously shown businesses when generating new content for the same recipient

### Reuse Rules

- Emails sent within the same month for the same ZIP code must reuse the stored content
- No regeneration should occur unless:
  - A new month begins, or
  - Stored content is missing or invalid

## Functional Requirements

- Content generation must be deterministic per ZIP per month
- The system must gracefully fall back if an API returns no data
- API usage must be minimized through caching and reuse
- Email generation must never block on live external API calls
- The block must always render with some content
- **Recipients must never receive the same content twice** - the system must track which content (specifically which business highlights) have been shown to each recipient and exclude previously shown content from future selections
- **Local Business Highlight must include an image** - the email must render a business image when displaying a Local Business Highlight, falling back to a provided generic placeholder image if no business image is available

## Section Naming and UX

The section must not be labeled “Expert Tip.”

Approved naming options include:

- Around Your Neighborhood
- Neighborhood Notes
- What’s Happening Nearby

Final label selection is TBD.

## Cadence Considerations

- Email cadence varies between 1 and 3 months
- Content updates monthly regardless of email send frequency
- An email sent after multiple months should always use the most recently computed monthly content

## Constraints and Assumptions

### Constraints

- ZIP code is the only guaranteed location input
- Content must not depend on same-day freshness
- Feature is always on and not configurable by agents

### Assumptions

- ZIP-to-geo lookup already exists
- Market data ingestion already occurs monthly
- Existing email templates support replacing the current block

## Notes for Technical Planning

This feature should be treated as a **monthly ZIP-level enrichment process**, not an email-time operation. All external API calls must occur during precomputation, not during email rendering.
