# JavaScript Tool Failure Anatomy

## ESLint

### Invocation

`npm run lint` (in Administration or Storefront app dir)

### Output Anatomy (Stylish Formatter)

File path as header: `/home/runner/.../src/module/sw-product/...`

Error lines: `  line:col  error  Error message  rule-name`

Summary: `✖ N problems (N errors, N warnings)`

### Where the Error Is

In the last ~100 lines. File paths + error lines + summary.

### False Positives

- npm install output — noise
- Build/compile output before lint runs — noise

### Real Example

```
/home/runner/.../sw-sales-channel-detail-base.spec.js
  12:5  error  'wrapper' is assigned but never used  no-unused-vars
  15:1  error  Missing return type on function        @typescript-eslint/explicit-function-return-type

✖ 64 problems (64 errors, 0 warnings)
```

---

## TypeScript (tsc)

### Invocation

`npm run lint:types` (in Administration app dir)

### Output Anatomy

Error lines: `src/path/file.ts(line,col): error TSnnnn: Message`

No summary line (tsc exits with count in exit code).

### Where the Error Is

Grep for `error TS` to find all TypeScript errors.

### Distinguishing from ESLint

tsc errors have `error TS` followed by a 4-digit code (e.g., `error TS2345`).

---

## Stylelint

### Invocation

`npm run lint:scss` (in Administration or Storefront app dir)

### Output Anatomy

File path header, then error lines with line:col, severity, message, rule.

Summary: `✖ N problems (N errors, N warnings)` (same format as ESLint).

### Distinguishing from ESLint

Stylelint errors reference SCSS rules and file extensions are `.scss`.

---

## Prettier

### Invocation

`npm run format` (in Administration app dir)

### Output Anatomy

Lists files that don't match formatting: `Checking formatting...` then file paths.

Summary: `Code style issues found in N files` or similar.

### Where the Error Is

File paths listed after the checking line.

---

## Jest

### Invocation

`npm run unit -- --silent` (in Administration or Storefront app dir)

### Output Anatomy

`--silent` suppresses console.log/warn/error from tests but still prints failures.

- Failed test markers: `● test-suite-name › test-name` (bullet character)
- Assertion details: `expect(received).toXxx()` with expected/received values
- Stack trace with `>` pointing to the failing line in source
- Error types: `TypeError`, `SyntaxError`, `ReferenceError` with message
- ANSI color codes present in raw output: `[31m` (red), `[32m` (green), `[39m` (reset) — ignore these

### Where the Error Is

Scattered through the output (not just at the end). Each `●` marker starts a new failure block.

### False Positives

- `console.warn` / `console.error` from test setup — not assertion failures
- `PASS` lines — obviously not failures
- Snapshot warnings — not failures unless `Snapshot Summary` says "failed"

### Real Example

```
● sw-sales-channel-menu › should not be able to create sales channels when user has not the privilege

  expect(received).toBeFalsy()

  Received: true

  > 239 |         expect(buttonCreateSalesChannel.exists()).toBeFalsy();
        |                                                   ^
```
