# Bedrock Client DI Refactoring Plan

## Current State

`bedrock_client.py` has inline `USE_MOCK_DATA` checks in two main functions:

1. **`get_data_from_bedrock()`** - Lines 236-359
   - Generates intro and home report analysis
   - Has inline mock check at line 269
   - Calls `call_claude_sonnet_4()` for real API

2. **`are_addresses_the_same()`** - Lines 404-444
   - Compares two addresses for fuzzy matching
   - Has inline mock check at line 407
   - Calls `call_claude_sonnet_4()` for real API

## Target DI Pattern

### Protocol Definition
```python
class BedrockClientProtocol(Protocol):
    def generate_intro_and_analysis(
        self,
        local_market_data: LocalMarketData,
        mortgage_rate: MortgageRate,
        campaign_id: str,
        formatted_address: str = None,
        current_value: str = None,
        purchase_price: str = None,
        purchase_date: str = None,
    ) -> dict:
        """Generate intro and home report analysis."""
        ...

    def compare_addresses(self, address1: str, address2: str) -> bool:
        """Check if two addresses are the same."""
        ...
```

### Mock Client
```python
class MockBedrockClient:
    def generate_intro_and_analysis(...) -> dict:
        # Read from mock_data/bedrock_intro.json
        ...

    def compare_addresses(address1: str, address2: str) -> bool:
        # Read from mock_data/bedrock_are_addresses_the_same.txt
        ...
```

### Real Client
```python
class BedrockClient:
    def __init__(self):
        self.rate_limiter = BedrockRateLimiter()
        self.aws_access_key = AWS_ACCESS_KEY
        self.aws_secret_access_key = AWS_SECRET_ACCESS_KEY

    def generate_intro_and_analysis(...) -> dict:
        # Build prompt (lines 281-338 from current implementation)
        # Call call_claude_sonnet_4()
        # Parse response
        ...

    def compare_addresses(address1: str, address2: str) -> bool:
        # Build prompt (lines 413-422 from current implementation)
        # Call call_claude_sonnet_4()
        # Parse response
        ...
```

### Factory
```python
def create_bedrock_client() -> BedrockClient | MockBedrockClient:
    if USE_MOCK_DATA.lower() == "true":
        return MockBedrockClient()
    else:
        return BedrockClient()
```

## Required Changes

### Files to Update

1. **`bedrock_client.py`**
   - Add Protocol, Mock, Real, Factory
   - Keep `call_claude_sonnet_4()`, `initialize_bedrock_client()` as helper functions
   - Keep `update_db_with_home_report_analysis_and_intro()` but add client parameter

2. **Any files using `get_data_from_bedrock()` or `are_addresses_the_same()`**
   - Need to inject `BedrockClientProtocol` parameter
   - Examples to find:
     - `update_db_with_home_report_analysis_and_intro()` in bedrock_client.py
     - Any calls to `get_data_from_bedrock()` or `are_addresses_the_same()`

## Complexity Notes

- `db_client` is used inside the prompt building logic (line 300)
- Rate limiter is used globally (line 92)
- Helper functions like `initialize_bedrock_client()` and `call_claude_sonnet_4()` should remain as-is

## Search Required

Need to find all callers of:
- `get_data_from_bedrock()`
- `are_addresses_the_same()`
- `update_db_with_home_report_analysis_and_intro()`

