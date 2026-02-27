# Product Requirements Document: Bulk Lead Upload via CSV

## 1. Overview

### 1.1 Purpose
Enable real estate agents to import multiple leads/campaigns in bulk via CSV file upload, eliminating the need to manually create hundreds of leads one at a time during onboarding.

### 1.2 Background
Currently, agents must create each campaign individually by entering client name, email, and property address. For agents with hundreds of existing clients, this manual process is infeasible and creates a significant barrier to adoption.

## 2. User Stories

**As a** real estate agent onboarding to the platform  
**I want to** upload hundreds of leads at once via CSV  
**So that** I can quickly import my existing client base without manual data entry

**As a** real estate agent using bulk upload  
**I want to** see success/failure status for each lead as it processes  
**So that** I can identify and fix any data issues

**As a** real estate agent during bulk upload  
**I want to** cancel the upload process if errors occur  
**So that** I can fix my CSV file and try again without waiting for all rows to process

## 3. Functional Requirements

### 3.1 Navigation & Access

**FR-1.1**: Add a [Bulk Upload] button to the Leads page  
- **Location**: Left of the existing [+ New Lead] button  
- **Access**: Available to all authenticated agents  
- **Behavior**: Navigates user to the Bulk Upload page

**FR-1.2**: Bulk Upload page navigation  
- **URL**: Dedicated page for bulk upload functionality  
- **Not Required**: Bulk Upload page does not need to be accessible from the sidebar navigation  
- **Back Navigation**: Include a Cancel/Back button that returns user to the Leads page

### 3.2 CSV File Format & Instructions

**FR-2.1**: Display CSV format instructions on Bulk Upload page  
Instructions must clearly specify the required CSV format:
- **Required Headers**: 
  - `first_name` - Lead's first name
  - `last_name` - Lead's last name  
  - `email` - Lead's email address
  - `zip_code` - Lead's zip code
- **Optional Headers**:
  - `formatted_address` - Full property address

**FR-2.2**: Campaign type determination based on CSV data  
- **Home-Value Campaign**: Created when `formatted_address` is included and populated
- **Non-Home-Value Campaign**: Created when `formatted_address` is empty or not included
- **User Communication**: Clearly explain this distinction in the instructions

**FR-2.3**: CSV header validation  
- Validate that CSV contains all required headers
- Display error if required headers are missing
- Case-insensitive header matching

### 3.3 File Upload & Selection

**FR-3.1**: File upload control  
- Standard file picker interface
- Accept only `.csv` files
- Display selected filename after selection
- Maximum file size: 1000 rows

**FR-3.2**: Upload initiation  
- Provide clear "Upload" or "Start Import" button
- Button should be disabled until a valid CSV file is selected

**FR-3.3**: Pre-upload validation  
Before processing any rows:
- Validate CSV file structure (headers present, proper formatting)
- Validate all rows contain properly formatted data (email format, required fields present)
- Display validation errors if found, preventing upload from starting
- Only begin row-by-row campaign creation after pre-validation passes

**FR-3.4**: Upload confirmation  
- After file selection and before processing begins, display confirmation dialog
- Show: "Ready to import [N] leads. Continue?"
- Allow user to cancel or proceed with import

### 3.4 Upload Processing & Feedback

**FR-4.1**: Progress indicator  
- Display progress counter showing current status (e.g., "Processing lead 45 of 200")
- Show progress bar or percentage if appropriate

**FR-4.2**: Real-time processing feedback  
For each row processed, display:
- Row number being processed
- Lead name (first_name + last_name)
- Success or failure status
- Specific reason for any failures

**FR-4.3**: Processing status display  
- Show running list or table of processed rows
- Differentiate visually between successful and failed imports (e.g., green/red indicators, icons)
- Display messages should be clear and actionable

**FR-4.4**: Failure reason reporting  
Display specific, actionable error messages from the campaign creation process:
- "Email undeliverable"
- "Email already exists in system"
- "Property data not found for address"
- "Error creating campaign: [specific error from create_campaign endpoint]"
- Any other errors returned by the create_campaign endpoint
- Note: Basic format validation (email format, required fields) will be caught in pre-validation

**FR-4.5**: Upload summary  
At the completion of the upload process, display:
- Total rows processed
- Number of successful imports
- Number of failed imports
- Detailed list of any failures with reasons

### 3.5 Upload Control & Cancellation

**FR-5.1**: Cancel upload functionality  
- Provide a "Cancel Upload" button visible during processing
- Allow user to stop processing at any point
- Clearly indicate that cancellation will stop processing remaining rows
- Successfully uploaded leads remain in the system (no rollback)

**FR-5.2**: Cancel confirmation  
- Show confirmation dialog: "Are you sure you want to cancel? [N] remaining rows will not be imported."
- Make it clear that already imported leads will remain in the system

### 3.6 Data Validation

**FR-6.1**: Pre-validation (before processing begins)  
Validate formatting of all rows before any campaign creation:
- All required fields (first_name, last_name, email, zip_code) are present and not empty
- Email addresses are properly formatted
- CSV structure is valid (consistent column counts, proper encoding)
- If pre-validation fails, display errors and do not begin processing

**FR-6.2**: Row-by-row validation (during processing)  
Delegate campaign creation and deeper validation to the existing `create_campaign` endpoint:
- Email deliverability (undeliverable email addresses)
- Duplicate email detection (email already exists in system)
- Property data lookup (property data not found for home-value campaigns)
- Address validation (when formatted_address is provided)
- Any other errors from the campaign creation process
- Display specific error message returned by create_campaign endpoint for each failed row

### 3.7 Error Handling & Edge Cases

**FR-7.1**: Empty CSV handling  
- Detect and display error message for empty CSV files (no data rows)
- Caught during pre-validation phase

**FR-7.2**: Malformed CSV handling  
- Detect and display error for malformed CSV files (inconsistent column counts, encoding issues)
- Provide helpful error message indicating the problem
- Caught during pre-validation phase

**FR-7.3**: File size limit  
- Reject CSV files with more than 1000 rows
- Display clear error: "CSV file exceeds maximum of 1000 rows. This file contains [N] rows."

**FR-7.4**: Duplicate email handling  
- When create_campaign endpoint detects an email already exists in system, skip that row
- Display message: "Skipped: Email already exists in system"
- Continue processing remaining rows

**FR-7.5**: Partial row data  
- Handle rows with missing optional data (formatted_address) gracefully
- Create non-home-value campaign when formatted_address is empty
- Only fail row if required data is missing (caught in pre-validation)

**FR-7.6**: Campaign creation failures  
- When create_campaign endpoint returns an error, display the specific error message
- Continue processing remaining rows (don't halt entire upload)

### 3.8 Post-Upload Actions

**FR-8.1**: Return to Leads page  
- Provide button to return to Leads page after upload completes
- Newly imported leads should be visible in the Leads page list

**FR-8.2**: Success confirmation  
- Display clear success message when all rows import successfully
- Example: "Successfully imported [N] leads. [View Leads]"

## 4. Out of Scope (for this release)

The following features are explicitly NOT included in this version:
- CSV template file download (instructions will be displayed on the page instead)
- Failed row export for correction and re-upload
- Excel (.xlsx) file support
- Mapping custom column names to expected fields
- Bulk editing of existing campaigns
- Scheduled/automated imports
- Import history or audit log
- Advanced data transformation or cleanup
- Rollback of partial uploads (successful imports remain even if upload is cancelled)

## 5. Key Design Decisions

The following decisions have been made to guide implementation:

**D-1**: Maximum rows per upload: **1000 rows**

**D-2**: Duplicate email handling: **Skip duplicates** and display message "Skipped: Email already exists in system"

**D-3**: Validation approach: **Two-phase validation**
   - Phase 1: Pre-validation of formatting (email format, required fields, CSV structure) before processing
   - Phase 2: Row-by-row campaign creation using existing create_campaign endpoint

**D-4**: CSV template: **No template download** - provide clear, friendly instructions on the upload page instead

**D-5**: Failed row export: **Not included** - users will see detailed failure messages during upload

**D-6**: Partial upload handling: **Successfully uploaded leads remain in system** if user cancels (no rollback)

**D-7**: Progress indicator: **Yes** - display "Processing lead X of Y" counter and progress bar

**D-8**: Validation timing: **Pre-validation for formatting**, then delegate deeper validation (email deliverability, property lookup, etc.) to create_campaign endpoint during row-by-row processing

**D-9**: Address validation failures: **Handle during row-by-row processing** - display specific error from create_campaign endpoint and continue with remaining rows

**D-10**: Upload confirmation: **Yes** - show confirmation dialog "Ready to import [N] leads. Continue?" before processing begins

## 6. Success Metrics

- Time to onboard a new agent with 100+ existing clients (target: <15 minutes)
- Percentage of CSV uploads that complete successfully
- Average error rate per upload
- User satisfaction with bulk upload feature (survey/feedback)

## 7. Dependencies

- Existing campaign creation logic (both home-value and non-home-value types)
- Email validation service/logic
- Address validation/lookup API
- Property value API
- Market data API
- Database lead/campaign storage

## 8. Notes

- The UI should prioritize clarity and actionable feedback over speed
- Error messages should help users fix their CSV files, not just report failures
- The feature should feel reliable and trustworthy for importing valuable client data

