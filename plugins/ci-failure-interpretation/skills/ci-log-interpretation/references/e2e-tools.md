# E2E & Quality Tool Failure Anatomy

## Playwright

### Invocation

`npx playwright test --project=X --trace=on` (acceptance tests)

### Output Anatomy

The most complex of all tools:

- Test execution: `Running N tests using M workers`
- Failures scattered throughout (NOT concentrated at end)
- **Assertion failures**: `Error: expect(locator).toBeVisible() failed` / `Error: expect(received).toBeTruthy()`
- **Element not found**: `Error: element(s) not found`
- **Page/browser crashes**: `Error: locator.scrollIntoViewIfNeeded: Target page, context or browser has been closed`
- **Timeouts**: `Error: locator.click: Timeout N ms exceeded`
- **Infrastructure errors**: `TypeError: Failed to fetch browser webSocket URL`, `Error: connect ECONNREFUSED 127.0.0.1:9222`, `npm error Error: socket hang up`
- **Lighthouse-in-Playwright**: `Error: playwright lighthouse - Some thresholds are not matching the expectations.`

### Where the Error Is

Scattered. Each `Error:` starts a failure context. Look for the FIRST `Error:` after each test name.

### Distinguishing Infrastructure from Code Errors

- `ECONNREFUSED`, `socket hang up`, `Failed to fetch browser webSocket URL` → CI environment issue (retry may fix)
- `expect(...).toXxx() failed`, `element(s) not found` → actual test/code failure
- `Target page, context or browser has been closed` → could be either (flaky test or real crash)

### False Positives

- `npm error command failed` — wrapper error, the real error is above it
- Git fetch output showing branch names — noise

---

## Lighthouse CI

### Invocation

`treosh/lighthouse-ci-action@v12` with `lighthouserc.js` config

### Output Anatomy

Very concise failure output (~18 lines):

- Each failed assertion: `✘ audit-name failure for assertion-type assertion` with description URL
- Expected vs found: `expected: <=N` / `found: M` / `all values: X, Y, Z`
- Final: `Assertion failed. Exiting with status code 1.`
- After assertions: `##[error]N results for URL`
- Structured summary block after `##[error]`:
  ```
  ❌ `categories.performance` failure for `minScore` assertion
  Expected >= 0.65, but found 0.63
  ```

### Where the Error Is

In the last ~80 lines. The `✘` and `❌` markers are the key signals.

### False Positives

- Artifact upload output — noise
- `Uploading median LHR` — noise
- Google Storage URLs — informational, not errors

---

## ludtwig

### Invocation

`ludtwig .` (from `src/Storefront/Resources/views`)

### Output Anatomy

Error format: `error[RuleName]: Description` with file path, line, column. Shows the problematic code with pointer arrows.

### Where the Error Is

Grep for `error[` to find all violations.
