# Product Requirements Document: Managed Clients & Welcome Emails

## 1. Overview
We need to evolve the Dripr system to support a B2B "Managed Client" model while maturing our onboarding experience for self-serve users. Currently, the system assumes a single user type. We are introducing a distinction between "Self-Serve" agents (who sign up themselves) and "Managed" agents (who are provisioned by us for a B2B partner). This distinction will allow us to drive different onboarding flows and track metrics separately.

## 2. Problem Statement
*   **No differentiation:** The system currently treats all users the same. We cannot easily identify which users belong to a B2B partner for reporting purposes.
*   **Silent Onboarding:** Users currently receive no confirmation when they sign up. This is a poor experience for self-serve users.
*   **Spam Risk:** If we simply turn on welcome emails for everyone, we risk spamming managed agents who may not even know their account has been created yet, or where the B2B partner handles the communication.
*   **Verification Noise:** Managed agents currently might receive email verification requests if added via standard flows, which reveals Dripr's existence—something we must strictly avoid.

## 3. Goals & Objectives
1.  **Support Managed Clients (B2B):** Allow the creation of users who belong to a specific B2B partner.
2.  **Identifiability:** Ensure managed users can be queried and grouped by their B2B partner ID for metrics.
3.  **Differentiated Onboarding:** 
    *   **Self-Serve:** Send an automated Welcome Email + Require Email Verification.
    *   **Managed:** Silent onboarding. No Welcome Email, **No Email Verification Email**.

## 4. User Stories
*   **As a Self-Serve User**, I want to receive a welcome email immediately after signing up so that I know my account is active and where to start.
*   **As a B2B Partner**, I want Dripr to provision accounts for my agents without them receiving unexpected automated emails (Welcome or Verification) from Dripr, so that I can manage the communication flow myself.
*   **As the Dripr Admin**, I want to be able to query the system to see all agents belonging to "Partner X" so that I can generate usage reports for that partner.

## 5. Functional Requirements

### 5.1 User Identification
The system must be able to categorize users by their specific **Partner ID**:

*   **Self-Serve:** Users who sign up organically. `managed_client_id` is `NULL`.
*   **Managed:** Users provisioned by an administrator. `managed_client_id` is **NOT NULL** (e.g., "agency-one").

### 5.2 Registration Flow & Automated Emails

#### Scenario A: Self-Serve Sign Up (Standard)
*   **Condition:** User signs up via Web UI (Clerk frontend).
*   **Data State:** `managed_client_id` is empty/null.
*   **Verification:** User receives standard verification email.
*   **Welcome Email:** System detects no `managed_client_id`. Sends Welcome Email.

#### Scenario B: Managed Agent Provisioning (Silent)
*   **Condition:** Admin creates user via API.
*   **Data State:** `managed_client_id` is set to specific Partner ID.
*   **Verification:** Auto-verified by API (Silent).
*   **Welcome Email:** System detects presence of `managed_client_id`. **Suppresses** Welcome Email.

### 5.3 Email Infrastructure
*   **Provider:** The system must use **Postmark** for delivering the welcome emails.
*   **Rendering:** The email content must be rendered using **Handlebars** templates.
*   **Content:** The initial template will be a simple, generic placeholder text.

### 5.4 Admin Provisioning Tools
*   **Provisioning Workflow:** The system must provide a **CLI Script** (e.g., `create_managed_user.py`) for the Admin to create new managed users.
    *   **Reasoning:** Manual creation via the Clerk Dashboard carries a risk of accidental email triggering (Verification/Welcome). A script ensures 100% silent onboarding via the API.
*   **Inputs:** The script must accept:
    *   Email Address
    *   First Name / Last Name
    *   Partner ID String
*   **Reporting:** The system data must be structured such that an Admin can query the database for all users associated with a specific Partner ID.

## 6. Technical Note: Clerk Implementation for Managed Users
*   **Creation Method:** To achieve "Silent Onboarding" for Managed agents, we must use **Clerk's Backend API** (`users.createUser`) instead of the frontend sign-up flow or manual dashboard invitation.
*   **Auto-Verification:** When creating a user via the Clerk Backend API, the email address is **automatically marked as verified**. Clerk does **not** send a verification email in this scenario.
*   **Metadata:** When calling `users.createUser`, we must inject the identification data into the `private_metadata` field:
    ```json
    {
      "managed_client_id": "PARTNER_X"
    }
    ```
*   **Password:** Since these users should not know Dripr exists, we can create them without a password (if supported) or generate a random high-entropy password that is never shared. `skip_password_requirement` or similar flags may be used depending on the specific Clerk SDK version, but the key is that API creation bypasses the email verification loop.

## 7. Constraints & Assumptions
*   **Partner ID Validation:** No formal database table for partners is required at this stage; free-text strings are acceptable.
*   **Email Aesthetics:** The welcome email does not need to be "pretty" yet; functional delivery is the priority.
