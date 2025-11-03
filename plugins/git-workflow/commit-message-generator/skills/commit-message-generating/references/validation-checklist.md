# Quality Assurance Checkpoints

Systematic validation procedures for ensuring reliable commit message generation and validation.

## Table of Contents

- [Configuration Validation](#configuration-validation)
- [Git State Verification](#git-state-verification)
- [Change Analysis](#change-analysis)
- [Pre-Generation Review](#pre-generation-review)
- [Pre-Validation Review](#pre-validation-review)
- [Self-Validation Workflow](#self-validation-workflow-for-generated-messages)
- [Final Quality Gates](#final-quality-gates)

## Configuration Validation

### Load project configuration

**Steps:**
1. Check for `.commitmsgrc.md` in project root
2. Parse YAML frontmatter safely with error handling
3. Validate regex patterns (ticket_format) for syntax errors
4. Warn user if configuration is invalid, fall back to defaults
5. Apply custom types, scopes, and rules if configuration is valid

**Configuration error handling:**
- Invalid YAML → Warn user, use default configuration
- Invalid regex → Warn user, skip that specific pattern
- Missing file → Silently use defaults (not an error)

### Validation checklist:

- [ ] `.commitmsgrc.md` exists in project root
- [ ] YAML frontmatter parses successfully
- [ ] Custom types are valid strings
- [ ] Custom scopes are valid strings
- [ ] `ticket_format` regex compiles without errors
- [ ] Numeric constraints are positive integers
- [ ] Breaking change marker is single character or short string

---

## Git State Verification

### Repository validation

**Commands:**
```bash
# Verify git repository exists
git rev-parse --git-dir 2>/dev/null

# Check for staged changes (generation mode)
git diff --cached --quiet
```

**Checklist:**
- [ ] Working directory is a git repository
- [ ] Git commands execute without errors
- [ ] Repository is in valid state (not mid-merge, mid-rebase)

### Staged changes validation (Generation mode)

**Commands:**
```bash
# Check if any files are staged
git diff --cached --quiet
# Returns 0 if no changes, 1 if changes exist

# Get staged file list
git diff --cached --name-status
```

**Checklist:**
- [ ] At least one file is staged
- [ ] Staged files exist and are readable
- [ ] Diff can be extracted successfully

### Commit validation (Validation mode)

**Commands:**
```bash
# Verify commit reference exists
git rev-parse --verify <commit-ref> 2>/dev/null

# Ensure commit is reachable (optional)
git merge-base --is-ancestor <commit-ref> HEAD
```

**Checklist:**
- [ ] Commit reference resolves to valid SHA
- [ ] Commit is accessible in repository
- [ ] Commit message can be retrieved
- [ ] Commit diff can be extracted

---

## Change Analysis

### Diff parsing

**Extract information:**
- File paths from staged changes or commit diff
- Change types: added (A), modified (M), deleted (D), renamed (R)
- File extensions and directories for scope inference
- Line additions/deletions for magnitude

**Checklist:**
- [ ] All changed file paths extracted
- [ ] Files categorized by change type
- [ ] Directories identified for scope inference
- [ ] File extensions identified for file type analysis

### Type detection confidence

**Heuristic application:**
1. Apply quick heuristics to determine commit type
2. Calculate confidence level based on signal clarity
3. Agent loads type detection heuristics internally when confidence is LOW
4. Ask user for confirmation when uncertain about type

**Confidence levels:**
- **HIGH**: Single type clearly indicated (e.g., only new files = feat, only test files = test)
- **MEDIUM**: Primary type clear but mixed signals (e.g., mostly feat with minor fixes)
- **LOW**: Multiple types equally valid or unclear patterns

**Checklist:**
- [ ] Commit type determined
- [ ] Confidence level assessed
- [ ] Detailed reference loaded if needed (confidence < HIGH)
- [ ] User consulted if still uncertain after reference

### Breaking change detection

**Check for:**
- API surface changes (function signatures, public methods)
- Removed public functionality
- Changed function parameters (non-backward compatible)
- Configuration format changes
- Database schema changes
- Dependency version major bumps

**Checklist:**
- [ ] Public API changes identified
- [ ] Removed functionality detected
- [ ] Parameter changes analyzed
- [ ] Breaking changes flagged for user review
- [ ] Migration notes needed assessment

---

## Pre-Generation Review

### Scope clarity

**Decision tree:**
- Single module changed → Use module name as scope
- Multiple related modules → Use parent scope
- Multiple unrelated modules → Ask user or omit scope
- Config requires scope but unclear → Ask user
- Config allows omitting scope → Suggest omission

**Checklist:**
- [ ] Changed file paths analyzed
- [ ] Scope inferred or determined as not inferrable
- [ ] User consulted if scope required but unclear
- [ ] `references/scope-detection.md` loaded if needed

### Message completeness

**Required components:**
- Type (always required)
- Scope (if required by config)
- Subject (always required)
- Body (if breaking change or complex change)
- Footer (if breaking change or ticket reference required)

**Checklist:**
- [ ] Type selected
- [ ] Scope determined (if required)
- [ ] Subject crafted
- [ ] Body added if needed
- [ ] Breaking change documented if applicable
- [ ] Ticket reference added if required

### Length validation

**Constraints from config:**
- `max_subject_length` (default: 72)
- `min_subject_length` (default: 10)
- Body line length (recommendation: 72-100 chars)

**Checklist:**
- [ ] Subject length within limits
- [ ] Subject meets minimum length
- [ ] Truncation performed if needed
- [ ] User consulted if cannot shorten while preserving meaning

---

## Pre-Validation Review

### Message parsing

**Extract components:**
```regex
^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: .+
```

**Components:**
- Type (required)
- Scope (optional, in parentheses)
- Breaking change marker (! after type/scope)
- Subject (required, after ": ")
- Body (optional, after blank line)
- Footer (optional, after body)

**Checklist:**
- [ ] Message matches conventional commits format
- [ ] Type extracted successfully
- [ ] Scope extracted (if present)
- [ ] Breaking change marker detected (if present)
- [ ] Subject extracted
- [ ] Body extracted (if present)
- [ ] Footer extracted (if present)

### Format compliance

**Validation rules:**
- Type is in allowed types list (from config or defaults)
- Scope format is alphanumeric/kebab-case/slash-separated
- Subject doesn't end with period
- Subject uses imperative mood (heuristic check)
- Subject is lowercase after type/scope
- Breaking change marker (!) matches BREAKING CHANGE in footer
- Ticket reference present if required by config

**Checklist:**
- [ ] Type is valid
- [ ] Scope format is correct (if present)
- [ ] Subject format is correct
- [ ] Subject length within limits
- [ ] Imperative mood check passed
- [ ] Breaking change consistency verified
- [ ] Ticket reference validated (if required)

### Consistency preparation

**Gather context:**
- Load commit diff for comparison with message
- Identify claimed type, scope, subject from message
- Prepare to validate claims against actual changes

**Checklist:**
- [ ] Commit diff retrieved
- [ ] Message components extracted
- [ ] Ready to compare message claims vs actual changes

---

## Self-Validation Workflow (for Generated Messages)

**Integrated quality loop:**
1. Generate candidate commit message
2. Run format compliance check
3. Run consistency check against changes
4. If issues found:
   - Assess severity (blocking vs warning)
   - Attempt automatic fix if possible
   - Regenerate message with adjustments
5. Repeat until validation passes or max iterations reached (3)
6. Present final message to user with validation results

**Checklist:**
- [ ] Message generated
- [ ] Format compliance checked
- [ ] Consistency validated
- [ ] Issues identified and categorized
- [ ] Automatic fixes attempted
- [ ] Final message validated
- [ ] User presented with high-quality message

---

## Final Quality Gates

Before presenting output to user:

- [ ] All required components present
- [ ] Format compliance verified
- [ ] Consistency checked (for validation mode)
- [ ] Error messages are clear and actionable
- [ ] Recommendations are specific and helpful
- [ ] Configuration was loaded or defaults applied
- [ ] Git operations completed successfully
- [ ] Output verbosity matches context
