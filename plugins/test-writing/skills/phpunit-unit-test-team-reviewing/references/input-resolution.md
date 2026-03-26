# Input Resolution

Resolve user input into a validated file manifest. Try resolution strategies in order until one matches.

## Resolution Strategies

| Input pattern | Resolution | Tool |
|---|---|---|
| Explicit file path(s) | Verify existence, check `*Test.php` in `tests/unit/` | `Read` |
| Glob pattern | Expand, filter to `*Test.php` in `tests/unit/` | `Glob` |
| Commit SHA / `HEAD~N` | Get changed files, filter to test files | `Bash(git diff-tree --no-commit-id --name-only -r <ref>)` |
| Branch / "current branch" | **MUST** ask user for base branch before diffing — do not assume or infer it | `AskUserQuestion("What is the base branch?")` → `Bash(git diff --name-only <base>...<branch>)` |
| PR reference | Get PR file list, filter to test files | `mcp__plugin_gh-tooling_gh-tooling__pr_files` |
| Directory path | Find all test files recursively | `Glob("{dir}/**/*Test.php")` |
| Natural language | Interpret intent, search for matching tests | `Glob` + `Grep` |

For branch-based resolution: always ask — never guess, even if the base branch seems obvious from git context. Use the user's answer with `Bash(git merge-base HEAD <base-branch>)` to determine the diff range.

## Post-Resolution Validation

For each resolved path:

1. Deduplicate paths
2. `Read` each test file
3. `Grep` for `#[CoversClass(...)]` to identify the source class
4. `Read` each source class
5. Detect category (A-E) per [{baseDir}/../phpunit-unit-test-reviewing/references/test-categories.md]({baseDir}/../phpunit-unit-test-reviewing/references/test-categories.md)
6. Exclude files missing `#[CoversClass]` — report them but continue with the rest

If 0 files remain after validation, abort:

```
# PHPUnit Team Review: FAILED

**Reason**: No valid test files found.
**Input**: {user_input}
**Tried**: {strategies_attempted}
**Excluded**: {files_excluded_with_reasons}
```

## Output

File manifest: `[{path, source_path, category}]`
