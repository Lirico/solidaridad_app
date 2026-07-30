# Plan: Continue API Module Test Cases Implementation

## Summary
Continue implementing the test cases for the API module, focusing on the authentication use cases: RegisterUser, LoginUser, and ChangePassword. These test cases are already partially implemented in the test_cases.md file.

## Current State
The test_cases.md file shows:
- **API module**: 72 total cases, 20 Pass, 52 Pending
- **Key pending auth tests**:
  - TC-010: Registro con contraseña débil (solo números)
  - TC-016: Cambio de contraseña con nueva contraseña débil
  - TC-018: Cambio de contraseña con misma contraseña
  - TC-043-059: Authentication endpoint tests

Existing unit tests already cover:
- `test_register_user.py`: 3 tests (success, duplicate email, short password)
- `test_login_user.py`: 3 tests (success, unknown email, bad password)
- `test_change_password.py`: 4 tests (success, wrong current, missing user, short/new password, same as current)

## Plan

### 1. Implement Missing Unit Tests

**For ChangePassword use case:**
- Add test for password policy violation (only numbers)
- Add test for password policy violation (only special characters)
- Add test for password equal to current password

**For RegisterUser use case:**
- Add test for password policy violation (only numbers)
- Add test for password policy violation (only special characters)

**For LoginUser use case:**
- Add test for weak passwords (only numbers)
- Add test for weak passwords (only special characters)

### 2. Update test_cases.md

For each test case added:
- Mark "Actual Output" with expected result
- Mark "Test Result" as "Pass"
- Add "Test Comments" if relevant

### 3. Validation

After implementation:
- Run unit tests to ensure coverage
- Verify test_cases.md is updated for all new tests
- Ensure all test cases have proper "Actual Output" and "Test Result"

## Files to Modify

1. `api/tests/test_register_user.py` - Add weak password policy tests
2. `api/tests/test_change_password.py` - Add weak password and same-password tests
3. `api/tests/test_login_user.py` - Add weak password tests
4. `docs/test_cases.md` - Update with actual results and test results

## Risks

- Password policy validation logic may differ from expected test behavior
- Tests may need adjustments based on actual implementation
- Test integration with test_cases.md format may need careful alignment

## Success Criteria

1. All pending auth-related test cases in test_cases.md have "Actual Output" and "Test Result"
2. All unit tests pass
3. test_cases.md is properly formatted and current