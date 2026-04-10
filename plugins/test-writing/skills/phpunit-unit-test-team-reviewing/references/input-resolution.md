# Input Resolution

Resolve user input into a validated file manifest. Try resolution strategies in order until one matches.

## Resolution Strategies

| Input pattern | Resolution | Tool | Method scope |
|---|---|---|---|
| Explicit file path(s) | Verify existence, check `*Test.php` in `tests/unit/` | `Read` | No scope — full-class review |
| Glob pattern | Expand, filter to `*Test.php` in `tests/unit/` | `Glob` | No scope — full-class review |
| Commit SHA / `HEAD~N` | Get changed files, filter to test files | `Bash(git diff-tree --no-commit-id --name-only -r <ref>)` | Parse changed method names from diff hunks |
| Branch / "current branch" | **MUST** ask user for base branch before diffing — do not assume or infer it | `AskUserQuestion("What is the base branch?")` → `Bash(git diff --name-only <base>...<branch>)` | Parse changed method names from diff hunks |
| PR reference | Get PR file list, filter to test files | PR files tool | Parse changed method names from PR diff |
| Directory path | Find all test files recursively | `Glob("{dir}/**/*Test.php")` | No scope — full-class review |
| Natural language | Interpret intent, search for matching tests | `Glob` + `Grep` | No scope — full-class review |

For branch-based resolution: always ask — never guess, even if the base branch seems obvious from git context. Use the user's answer with `Bash(git merge-base HEAD <base-branch>)` to determine the diff range.

## Diff-to-Method Resolution

For commit, branch, and PR inputs, resolve which test methods were changed:

1. Run `git diff <base>...<ref> -- <file>` per test file (for PRs, use the PR diff tool)
2. Extract changed hunks
3. Identify which `public function test*` methods contain changed lines
4. If ALL methods in the file are changed (or the file is new), set `methods` to empty (full-class review)
5. If a subset of methods changed, set `methods` to only those method names

Data provider methods associated with scoped test methods do not need to be listed — the reviewing skill resolves them from `#[DataProvider]` attributes.

## Post-Resolution Validation

For each resolved path:

1. Deduplicate paths
2. Verify each file exists and ends with `*Test.php` in `tests/unit/`
3. `Grep` for `#[CoversClass(...)]` — exclude files missing it (report them but continue with the rest)

If 0 files remain after validation, abort:

```
# PHPUnit Team Review: FAILED

**Reason**: No valid test files found.
**Input**: {user_input}
**Tried**: {strategies_attempted}
**Excluded**: {files_excluded_with_reasons}
```

## Output

File manifest with optional method scope:

```yaml
- path: tests/unit/Core/Checkout/Cart/CartServiceTest.php
  methods: [testHandlesEmptyCart, testThrowsOnInvalidItem]  # changed/added methods
- path: tests/unit/Core/Content/Product/ProductServiceTest.php
  methods: []  # entire file is new → full-class review
```

Each entry has:
- `path` — validated test file path
- `methods` — list of changed/added test method names. Empty means full-class review.
