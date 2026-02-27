### PRD: Email Address Validation During Campaign Creation

### Summary
Implement email address validation during campaign creation to prevent bounced emails and reduce penalties from Postmark. The system will validate client email addresses using the QuickEmailVerification API before creating campaigns, returning descriptive error messages to users when validation fails.

### Scope
- Validate `client_email` during campaign creation (POST `/api/campaigns`)
- Integrate with QuickEmailVerification API for email validation
- Return descriptive error messages when email validation fails
- Support mock data mode for development/testing
- Add environment variable configuration for API key
- Validate emails for both home valuation campaigns and no-address newsletter campaigns

### Out of Scope
- Validating `owner_email` (only `client_email` is validated)
- Batch validation of multiple emails
- Caching validation results
- Re-validation of existing campaigns
- Email validation for campaign updates (PUT endpoint)
- Suggestons from the did_you_mean field

### Key Definitions
- **Valid Email**: An email address that passes QuickEmailVerification API validation
  - `result` field must be `"valid"` OR
  - `result` field is `"invalid"` but `safe_to_send` is `"true"` (edge case handling)
- **Invalid Email**: An email address that fails validation
  - `result` field is `"invalid"` AND `safe_to_send` is `"false"`
- **Validation Failure Reason**: The `reason` field from the API response (e.g., "rejected_email", "invalid_domain", "invalid_email", etc.)

### API Integration Details

#### QuickEmailVerification API
- **Endpoint**: `http://api.quickemailverification.com/v1/verify`
- **Method**: GET
- **Parameters**:
  - `email`: The email address to validate
  - `apikey`: API key from environment variable
- **API Key**: `13f9dd4946c69ea9257f2fffda0d89c8a4b611e937e3cfb64c066005e4b8`

#### Response Structure
```json
{
    "result": "invalid",
    "reason": "rejected_email",
    "disposable": "false",
    "accept_all": "false",
    "role": "false",
    "free": "false",
    "email": "richard@quickemailverification.com",
    "user": "richard",
    "domain": "quickemailverification.com",
    "mx_record": "us2.mx1.mailhostbox.com",
    "mx_domain": "mailhostbox.com",
    "safe_to_send": "false",
    "did_you_mean": "",
    "success": "true",
    "message": ""
}
```

#### Key Response Fields
- `result`: `"valid"` or `"invalid"` - primary validation result
- `reason`: Reason code for invalid emails (e.g., "rejected_email", "invalid_domain", "invalid_email") - not used for error message mapping
- `safe_to_send`: `"true"` or `"false"` - indicates if it's safe to send emails
- `success`: `"true"` or `"false"` - indicates if the API call succeeded
- `did_you_mean`: Suggested email correction (if available) - not used in this implementation

### Validation Logic

#### Validation Flow
1. Extract `client_email` from campaign creation request
2. Check if `USE_MOCK_DATA` is `"true"`
   - If true: Use mock data (see Mock Data section)
   - If false: Call QuickEmailVerification API
3. Evaluate validation result:
   - If `success` is `"false"`: Return error "Email validation service unavailable"
   - If `result` is `"valid"`: Proceed with campaign creation
   - If `result` is `"invalid"` AND `safe_to_send` is `"false"`: Reject with descriptive error
   - If `result` is `"invalid"` BUT `safe_to_send` is `"true"`: Proceed with campaign creation (edge case)
4. If validation fails, return HTTP 400 with descriptive error message
5. If validation passes, continue with existing campaign creation logic

#### Error Messages
For simplicity and maintainability, use a single generic error message for all validation failures:
- **Generic validation error**: "The email address could not be validated. Please check the email address and try again."
- **API unavailable**: "Email validation service is currently unavailable. Please try again later."
- **API error**: "Email validation service error. Please try again later."
- **Timeout**: "Email validation service timeout. Please try again later."

Note: The API response includes a `reason` field with specific failure reasons (e.g., "rejected_email", "invalid_domain", "disposable_email"), but these are not mapped to specific error messages. All validation failures use the generic message above.

### Environment Variables

#### Required Variables
Add to both `local-dev.env` and `prod.env`:
- `QUICK_EMAIL_VERIFICATION_API_KEY`: API key for QuickEmailVerification service
  - Value: `13f9dd4946c69ea9257f2fffda0d89c8a4b611e937e3cfb64c066005e4b8`

#### Existing Variables (No Changes)
- `USE_MOCK_DATA`: Controls whether to use mock data or real API calls
  - `"true"`: Use mock data
  - `"false"`: Use real API

### Mock Data

#### Mock Data File
Create a new mock data file: `python/shared_resources/mock_data/quick_email_verification.json`

#### Mock Data Structure
The mock data file should contain a single valid email response (used when `USE_MOCK_DATA='true'`):

**Valid email response**:
```json
{
    "result": "valid",
    "reason": "",
    "disposable": "false",
    "accept_all": "false",
    "role": "false",
    "free": "false",
    "email": "valid@example.com",
    "user": "valid",
    "domain": "example.com",
    "mx_record": "mx.example.com",
    "mx_domain": "example.com",
    "safe_to_send": "true",
    "did_you_mean": "",
    "success": "true",
    "message": ""
}
```

**Note**: The mock data file will always return this valid response when `USE_MOCK_DATA='true'`. For test cases that need to test invalid email scenarios, use `unittest.mock.patch` to override the API response with invalid email examples (e.g., rejected_email, invalid_domain, disposable_email) without modifying the mock data file.

#### Mock Data Implementation
- When `USE_MOCK_DATA='true'`, read from `quick_email_verification.json`
- **Always return a valid email response** when `USE_MOCK_DATA='true'` (to allow campaign creation in dev/test without spending money on API calls)
- The mock data file should contain a single valid email response
- **For test cases**: Use `unittest.mock.patch` to provide different mock responses (valid/invalid) when testing validation logic, independent of the `USE_MOCK_DATA` setting. This allows comprehensive testing of both valid and invalid scenarios without making real API calls.

### Implementation Details

#### Code Location
- **Email validation client**: Create `python/shared_resources/quick_email_verification_client.py`
- **Integration point**: Modify `python/api_gateway/api_gateway.py` in the `create_campaign` function
- **Mock data file**: `python/shared_resources/mock_data/quick_email_verification.json`

#### Validation Timing
Email validation should occur:
1. After basic parameter validation (client_email is not empty)
2. Before checking if client_email is already taken
3. Before property validation (for home valuation campaigns)
4. Before creating the campaign in the database

#### Error Handling
- Network errors: Return "Email validation service is currently unavailable. Please try again later."
- API errors (non-200 status): Return "Email validation service error. Please try again later."
- Timeout: Set reasonable timeout (e.g., 5 seconds) and return "Email validation service timeout. Please try again later."
- Invalid API response: Log error and return generic validation error

#### Rate Limiting
- Implement rate limiting to prevent API abuse
- Use the same rate limits as Rentcast API client: **1 call per 1 second window**
- Use thread-safe locking mechanism similar to `rentcast_api_client.py` pattern
- Track call count with a global counter and lock

#### Logging
- Log validation attempts (email address, result, reason)
- Log API errors with full details
- Do not log API key in logs

### Acceptance Criteria
1. ✅ Campaign creation with valid email addresses succeeds
2. ✅ Campaign creation with invalid email addresses returns HTTP 400 with descriptive error message
3. ✅ Error messages are displayed to users in the UI
4. ✅ Mock data is used when `USE_MOCK_DATA='true'`
5. ✅ Real API is called when `USE_MOCK_DATA='false'`
6. ✅ Environment variable `QUICK_EMAIL_VERIFICATION_API_KEY` is added to both `.env` files
7. ✅ Mock data file exists and returns appropriate validation responses
8. ✅ Validation occurs before campaign is created in database
9. ✅ Validation works for both home valuation and no-address newsletter campaigns
10. ✅ Network errors and API failures are handled gracefully

### Testing Considerations
- Test with valid email addresses (both mock and real API)
- Test with invalid email addresses using patched mocks (various reasons: rejected_email, invalid_domain, disposable_email, etc.)
- Test rate limiting behavior
- Test API timeout scenarios
- Test API error responses (network errors, non-200 status codes)
- Test mock data mode (`USE_MOCK_DATA='true'` always returns valid)
- Test real API mode (`USE_MOCK_DATA='false'`)
- Integration test: campaign creation with valid email succeeds
- Integration test: campaign creation with invalid email fails with HTTP 400
- Verify generic error message appears correctly in UI
- Verify campaign creation is blocked when validation fails

### Implementation Notes
- Follow existing patterns for API clients (see `rapid_api_zillow_client.py`, `rentcast_api_client.py`)
- Follow existing patterns for mock data usage (check `USE_MOCK_DATA` environment variable)
- Use existing error handling patterns from `api_gateway.py`
- Ensure validation does not significantly slow down campaign creation (consider timeout)
- **Rate limiting**: Implement same rate limits as Rentcast (1 call per 1 second) using thread-safe locking
- The validation should be synchronous (blocking) to prevent invalid campaigns from being created
- **Error messages**: Use single generic message for all validation failures (simpler, more maintainable)
- **Mock data behavior**: When `USE_MOCK_DATA='true'`, always return valid email. For test cases, use patched mocks to test invalid scenarios

