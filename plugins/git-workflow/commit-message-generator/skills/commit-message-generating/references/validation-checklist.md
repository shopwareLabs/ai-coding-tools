# Quality Assurance Checkpoints

Validation procedures for commit message generation and validation.

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

1. Check for `.commitmsgrc.md` in project root
2. Parse YAML frontmatter safely with error handling
3. Validate regex patterns (ticket_format) for syntax errors
4. Warn user if configuration is invalid, fall back to defaults
5. Apply custom types, scopes, and rules if configuration is valid

**Error handling:**
- Invalid YAML: Warn user, use defaults
- Invalid regex: Warn user, skip pattern
- Missing file: Use defaults (silent)

### Validation checklist:

- [ ] `.commitmsgrc.md` exists in project root
- [ ] YAML frontmatter parses successfully
- [ ] Custom types/scopes are valid strings
- [ ] `ticket_format` regex compiles without errors
- [ ] Numeric constraints are positive integers
- [ ] Breaking change marker is single/short string

---

## Git State Verification

### Repository validation

```bash
git rev-parse --git-dir 2>/dev/null  # Verify repository exists
git diff --cached --quiet            # Check staged changes
```

**Checklist:**
- [ ] Working directory is a git repository
- [ ] Git commands execute without errors
- [ ] Repository is in valid state (not mid-merge, mid-rebase)

### Staged changes validation (Generation mode)

```bash
git diff --cached --quiet         # 0=no changes, 1=changes exist
git diff --cached --name-status   # List staged files
```

**Checklist:**
- [ ] At least one file is staged
- [ ] Diff can be extracted successfully

### Commit validation (Validation mode)

```bash
git rev-parse --verify <commit-ref> 2>/dev/null  # Verify commit exists
git merge-base --is-ancestor <commit-ref> HEAD   # Ensure reachable
```

**Checklist:**
- [ ] Commit reference resolves to valid SHA
- [ ] Commit is accessible in repository
- [ ] Commit message can be retrieved
- [ ] Commit diff can be extracted

---

## Change Analysis

### Diff parsing

**Extract:**
- File paths from changes
- Change types (A/M/D/R) for categorization
- File extensions/directories for scope
- Line changes for magnitude assessment

**Checklist:**
- [ ] File paths extracted and categorized by change type
- [ ] Directories and extensions identified for scope/type inference

### Type detection confidence

**Process:**
1. Apply quick heuristics to determine commit type
2. Calculate confidence level based on signal clarity
3. Load detailed type detection heuristics (internal) if confidence is LOW
4. Ask user for confirmation when uncertain

- **HIGH**: Single type clearly indicated (new files only = feat, test files only = test)
- **MEDIUM**: Primary type clear with mixed signals
- **LOW**: Multiple types equally valid or unclear

**Checklist:**
- [ ] Commit type determined
- [ ] Confidence level assessed
- [ ] Detailed reference loaded if needed (confidence < HIGH)
- [ ] User consulted if still uncertain after reference

### Breaking change detection

- API surface changes (signatures, public methods, parameters)
- Removed functionality
- Configuration/schema/dependency changes

**Checklist:**
- [ ] Public API/parameter changes identified
- [ ] Removed functionality detected
- [ ] Breaking changes flagged and migration notes assessed

---

## Pre-Generation Review

### Scope clarity

- Single module: Use module name
- Multiple related: Use parent
- Multiple unrelated/unclear: Ask user or omit
- Scope optional: Suggest omission

**Checklist:**
- [ ] Changed file paths analyzed
- [ ] Scope inferred or determined as not inferrable
- [ ] User consulted if scope required but unclear
- [ ] `references/scope-detection.md` loaded if needed

### Message completeness

**Components:**
- Type, Subject (required)
- Scope (if required by config)
- Body (if breaking change or complex)
- Footer (if breaking change or ticket required)

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
- Type in allowed list (config or defaults)
- Scope format: alphanumeric/kebab-case/slash-separated
- Subject: no period, imperative mood, lowercase after type/scope
- Breaking change marker (!) matches footer
- Ticket reference if required

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

### Body validation

**Presence rules:**
- Required for breaking changes (always)
- Required for complex changes (file count > threshold)
- Required for configured types (feat, fix, perf)
- Optional for simple changes

**Quality:**
- Explains WHY (motivation, reasoning) not WHAT (code)
- Provides non-obvious context
- Clear, specific language avoiding vagueness

**Structure:**
- Blank line separates subject and body
- Lines wrapped at recommended length (~72 chars)
- Proper paragraph organization

**Migration instructions:**
- Present for breaking changes
- Clear step-by-step guidance
- Before/after examples when helpful
- Actionable instructions

**Checklist:**
- [ ] Body presence determined (required vs optional)
- [ ] Body exists if required
- [ ] Body structure validated (blank line, line length)
- [ ] Body content quality assessed (explains WHY)
- [ ] Migration instructions present for breaking changes
- [ ] Body doesn't restate obvious information from diff

---

## Self-Validation Workflow

**Quality loop:**
1. Generate commit message
2. Validate format and consistency
3. Attempt automatic fix on issues
4. Regenerate (max 3 iterations)
5. Present final message with results

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
