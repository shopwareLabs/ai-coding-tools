# Input Resolution

Resolve user input into a validated, classified file manifest. Try resolution strategies in order until one matches. The run is **mixed**: a PR touching unit, integration, and migration tests produces one manifest with each file tagged by `test_type`.

## Resolution Strategies

| Input pattern | Resolution | Tool | Method scope |
|---|---|---|---|
| Explicit file path(s) | Verify existence, check `*Test.php` under `tests/unit/`, `tests/integration/`, or `tests/migration/` | `Read` | No scope — full-class review |
| Glob pattern | Expand, filter to `*Test.php` under the three test roots | `Glob` | No scope — full-class review |
| Commit SHA / `HEAD~N` | Get changed files, filter to test files | `Bash(git diff-tree --no-commit-id --name-only -r <ref>)` | Parse changed method names from diff hunks |
| Branch / "current branch" | **MUST** ask user for base branch before diffing — do not assume or infer it | `AskUserQuestion("What is the base branch?")` → `Bash(git diff --name-only <base>...<branch>)` | Parse changed method names from diff hunks |
| PR reference | Get PR file list, filter to test files | PR files tool | Parse changed method names from PR diff |
| Directory path | Find all test files recursively | `Glob("{dir}/**/*Test.php")` | No scope — full-class review |
| Natural language | Interpret intent, search for matching tests | `Glob` + `Grep` | No scope — full-class review |

For branch-based resolution: always ask — never guess, even if the base branch seems obvious from git context. Use the user's answer with `Bash(git merge-base HEAD <base-branch>)` to determine the diff range.

## Classification (`test_type`, the primary axis)

Tag each resolved file from its path root — reliable, and the per-type reviewers already enforce their directory:

- `tests/unit/…` → `test_type=unit`
- `tests/integration/…` → `test_type=integration`
- `tests/migration/…` → `test_type=migration`

A file outside the three roots is excluded with a reported reason (continue with the rest). If 0 files survive, abort with the FAILED report below.

## Diff-to-Method Resolution

For commit, branch, and PR inputs, resolve which test methods were changed (applies to all three test types):

1. Run `git diff <base>...<ref> -- <file>` per test file (for PRs, use the PR diff tool)
2. Extract changed hunks
3. Identify which `public function test*` methods contain changed lines
4. If ALL methods in the file are changed (or the file is new), set `methods` to empty (full-class review)
5. If a subset of methods changed, set `methods` to only those method names
6. If the change touches shared code that unchanged test methods depend on — `setUp`/`tearDown`, a private helper, a data provider, or a class property — set `methods` to empty (full-class review): the change ripples beyond the methods whose lines it touched

Data provider methods associated with scoped test methods do not need to be listed — the reviewing skill resolves them from `#[DataProvider]` attributes.

## Post-Resolution Validation & Per-Type Source Resolution

For each resolved path:

1. Deduplicate paths
2. Verify each file exists and ends with `*Test.php` under one of the three test roots
3. `Grep` for `#[CoversClass(...)]` — exclude files missing it (report them but continue with the rest)
4. Resolve the `#[CoversClass]` source(s) per `test_type` (FQCN → `src/` file via the test's `use`/namespace). **Fail hard** if a surviving test file's source cannot be resolved — same discipline as an empty manifest; never proceed with an unknown source size:
   - **unit** — the single `#[CoversClass]` SUT. `source_paths = [that file]`.
   - **migration** — the `MigrationStep` subclass under `src/Core/Migration/…`. `source_paths = [that file]`.
   - **integration** — one or more `#[CoversClass]`; resolve all into `source_paths`. An integration test covering a controller + a route counts both.
5. Set `source_path` = the primary (first) entry of `source_paths`. Set `source_lines` = the **sum** of line counts across all `source_paths` (the combined size drives the track decision).

If 0 files remain after validation, abort:

```
# PHPUnit Team Review: FAILED

**Reason**: No valid test files found.
**Input**: {user_input}
**Tried**: {strategies_attempted}
**Excluded**: {files_excluded_with_reasons}
```

## Decomposition Measurement

For each surviving file record, before the run:

- `test_lines` — line count of the test file.
- `source_lines` — sum of line counts across `source_paths`.
- `method_count` — count of `public function test*` methods.
- `test_methods` — the `public function test*` method names (the list the method-shard track shards over for a full-class Track B file).

`L = test_lines + source_lines` drives the per-file track decision. The method scope (changed/added methods, or all) drives the method-shard count.

## Auto-Chunk Guard

Project the reviewer-agent total before launch: `Σ per-file reviewers`, each file's count taken from its track (Track A = 3; Track B = 3·`shards` + 3, where `shards` and `M_eff` come from the fixed coarsening formula), already bounded by `U_file`. The track decision and shard count are identical across test types.

When the projection exceeds `G` (= 300), partition the manifest into **sequential** chunks each ≤ `G` reviewer agents — greedy bin-pack on per-file projected counts; a single file never splits across chunks. Chunk boundaries are deterministic from this projection — no runtime spawning toward the cap. `log()` the projection and the chunk plan so the partition is auditable. Chunks run in order; the single global cross-file pass runs after all chunks. A projection ≤ `G` is one chunk.

## Output

File manifest with `test_type`, method scope, source resolution, and decomposition measurement:

```yaml
- path: tests/unit/Core/Checkout/Cart/CartServiceTest.php
  test_type: unit
  methods: [testHandlesEmptyCart, testThrowsOnInvalidItem]  # changed/added methods
  test_methods: [testHandlesEmptyCart, testThrowsOnInvalidItem, testAppliesDiscount, ...]  # ALL test methods
  source_path: src/Core/Checkout/Cart/CartService.php
  source_paths: [src/Core/Checkout/Cart/CartService.php]
  test_lines: 240
  source_lines: 95
  method_count: 12
- path: tests/integration/Core/Content/Product/ProductControllerTest.php
  test_type: integration
  methods: []  # entire file is new → full-class review
  test_methods: [testCreate, testList, testDelete]
  source_path: src/Core/Content/Product/ProductController.php
  source_paths: [src/Core/Content/Product/ProductController.php, src/Core/Content/Product/Route/ProductRoute.php]
  test_lines: 320
  source_lines: 210   # summed across source_paths
  method_count: 3
```

Each entry has:
- `path` — validated test file path
- `test_type` — `unit` | `integration` | `migration` (primary routing axis)
- `methods` — list of changed/added test method names. Empty means full-class review.
- `test_methods` — every `public function test*` method name in the file. Drives method-shard count when `methods` is empty.
- `source_path` — primary resolved `#[CoversClass]` source file.
- `source_paths` — all resolved `#[CoversClass]` source files (one for unit/migration; one or more for integration).
- `test_lines`, `source_lines`, `method_count` — the measurements driving track selection and shard count.
