---
name: comment-reviewing
version: 1.2.0
description: Reviews and improves code comments following 'why not what' principle. Removes redundant and obvious comments, improves vague comments by adding context, condenses verbose documentation, and flags inconsistencies. Evaluates uncertainty of automated changes and identifies edits requiring manual verification with actionable prompts. Use when reviewing comments in files, directories, git changes, git diffs, commits, or commit ranges. Handles all comment styles: C-style (//, /* */), PHPDoc, JSDoc, Python (#), HTML, Twig, SQL.
allowed-tools: Read, Edit, Glob, Grep, Bash, TodoWrite
---

# Comment Reviewing

Specialized skill for improving comment quality by identifying and fixing redundant, obvious, or misleading comments while preserving valuable documentation.

## Scope Detection

Automatically detect review scope from user requests:

1. **Directory paths** - Scan specified directory recursively
2. **Git changes** - Review modified files vs branch (uses `scripts/git-helpers.sh` - see Utility Scripts section for invocation examples)
3. **Git commits** - Review specific commits or ranges (uses `scripts/git-helpers.sh` - see Utility Scripts section for invocation examples)
4. **Specific files** - Review only mentioned files
5. **Current directory** - Scan files in working directory

All git operations use `scripts/git-helpers.sh` for reliable branch detection, commit validation, and diff extraction. See Utility Scripts section for usage. Focus review on added/modified lines only.

## Supported Languages
Works with all standard comment styles (C-style, doc blocks, shell, HTML, templates, SQL).

## Utility Scripts

This skill includes bash utility scripts for reliable git operations and edit validation. All scripts contain functions that must be sourced before calling.

**Invocation pattern:**
```bash
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/script-name.sh && function_name arg1 arg2"
```

**Important:** The `WORK_DIR` variable must be set to the user's project directory before sourcing git-helpers.sh. This ensures git commands execute in the correct repository even when the script is sourced from the plugin installation directory.

**Available scripts:**

**git-helpers.sh** - Git operations with error handling
```bash
# Detect main branch
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-helpers.sh && detect_main_branch"

# Validate commit reference
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-helpers.sh && validate_commit HEAD~3"

# Get changed files for a single commit
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-helpers.sh && get_changed_files commit abc123"

# Get changed files for a commit range
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-helpers.sh && get_changed_files commit-range main HEAD"

# Get changed files for a commit list (space-separated)
bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-helpers.sh && get_changed_files commit-list 'abc123 def456 ghi789'"
```

**validate-edit.sh** - Pre-edit validation
```bash
# Check if file exists and is readable
bash -c "source scripts/validate-edit.sh && validate_file_exists '/path/to/file.php'"

# Verify string uniqueness in file
bash -c "source scripts/validate-edit.sh && find_string_in_file '/path/to/file.php' '// old comment'"
```

## Comment Type Detection

Detect type before categorizing:

**Implementation Comments**
- All non-API comments (single-line, block, inline): `//`, `/* */`, `#`, `<!-- -->`
- Treatment: Remove if obvious, Improve if vague (add WHY context), Condense if verbose WHY

**API Documentation**
- Contract documentation identified by position before declarations, structured tags (@param/@return), doc syntax (/** */ or docstrings), and multi-line parameter descriptions
- Treatment: CONDENSE if verbose (brief purpose + vital non-obvious info only)
- See references/api-docs-core-principles.md for detailed detection criteria and examples

**Visibility Rule**: Private methods with structured docs (`/** */` with `@param`/`@return`) are implementation explanations, not API contracts—apply implementation comment rules (WHY not WHAT, remove if obvious). Public/protected methods with structured docs are API contracts—apply API documentation rules (condense if verbose).

**Load `references/api-docs-core-principles.md` for detailed examples when encountering API documentation or uncertain about visibility rules**

## Rules for Removal

Remove obvious, redundant, or trivial comments that restate code without adding context.
**For detailed patterns and code examples, see `references/removal-patterns.md`**

## Rules for Flagging

Flag comments for human verification when inconsistent with code (behavior, return values, function names, exception handling) or incomplete (TODO/FIXME without owner/ticket, temporal markers like "will"/"soon").
**For detailed patterns and examples, see `references/consistency-checking.md`**

## Rules for Uncertainty Evaluation

During review, evaluate uncertainty for each change made to identify changes requiring manual verification. Classify each change as HIGH, MEDIUM, or LOW uncertainty based on risk of removing valuable information. Track HIGH/MEDIUM items for the "Changes Requiring Verification" section in the final report.

### Lightweight Classification (No Reference Load)

Before loading uncertainty-patterns.md, apply quick heuristics to each change using content signal detection:

**Likely HIGH uncertainty (requires reference load for detailed evaluation)**:
- File in conservative_paths AND change is substantive (not just typo/formatting)
- Removed examples from interface/abstract class documentation
  - Content signals: "Examples:", "e.g.,", "like", quoted patterns
- Removed architectural pattern explanations
  - Pattern names: Factory, Strategy, DI, Observer, Singleton, etc.
- Substantially reduced WHY comments on complex algorithms containing:
  - Causal language: `because`, `due to`, `since`, `prevents`, `avoids`
  - Complexity notation: `O(n)`, `O(log n)`, `O(n²)`
  - Trade-off descriptions: `faster but`, `memory vs speed`, `X vs Y`
  - Anti-pattern warnings, performance requirements
- Changed framework/library-specific behavior comments
  - ORM terms: `lazy load`, `eager load`, `hydration`, `cascade`
  - SQL terms: `ORDER BY`, `NULL first`, `JOIN`, `HAVING`
  - Framework APIs: routing, middleware, lifecycle
- Removed naming conventions, format specifications, or transformation rules

**Likely MEDIUM uncertainty (requires reference load for detailed evaluation)**:
- Removed @param descriptions with constraint keywords: `must`, `cannot`, `only`, `if`, `when`
- Substantive change to comment in complex code with content signals:
  - Specific numbers, thresholds, limits
  - Concrete examples or patterns
  - External references: `RFC`, `bug #`, `issue #`, `JIRA-`, standards
  - Constraint language: `must`, `cannot`, `only`, `required`, `never`
  - Rationale language: `because`, `prevents`, `due to`, `enables`
  - Trade-off descriptions: `but`, `however`, `X vs Y`
- Minimal comments remaining on complex logic
- Changed domain-specific terminology (domain_terms config)

**Confirmed LOW uncertainty (no reference load needed)**:
- Fixing typos or grammar only (even in conservative_paths)
- Removing obviously redundant comments ("// Get user" above getUserById())
- Formatting-only changes (line breaks, indentation)
- Comments that literally restate method names
- Condensation with all meaning preserved (only filler words removed)

**When potential HIGH/MEDIUM pattern detected**, load `references/uncertainty-patterns.md` for:
- Complete pattern definitions with detailed examples
- Content signal keyword library (7 information types)
- Verification prompt templates and generation guidance
- Decision guidance for edge cases

**For each HIGH/MEDIUM item, track:** file, line range, change description, uncertainty reason, specific verification prompt

## Rules for Improvement

**Applies to: Implementation comments only (NOT API documentation)**
Improve vague comments by adding WHY context: business rules (ticket numbers, RFCs), constraints (performance limits, thresholds), workarounds (bug numbers), design decisions (backward compatibility).
**For detailed before/after examples, see `references/improvement-examples.md`**

## Rules for Condensation (Implementation Comments)

**Applies to: Implementation comments that explain WHY but are verbose**
Condense comments with redundant explanations or verbose phrasing while preserving WHY content. Different from vague (improve) or obvious (remove).
**For detailed condensation patterns and examples, see `references/implementation-comment-condensation.md`**

## Rules for Condensation (API Documentation)

Condense API documentation that describe implementation rather than contract, restate obvious parameters/types, or exhaustively list options. Focus on capabilities and guarantees.
**For detailed contract vs implementation examples, see `references/api-docs-core-principles.md`**

## Rules for Preservation

Preserve comments with external references, algorithms, workarounds, security/performance warnings, contextualized TODOs, test rationale, or design decisions.
**For detailed examples and preservation checklist, see `references/preservation-guidelines.md`**

## Progressive Disclosure: Loading References On-Demand

Load detailed reference files using the Read tool ONLY when needed:

**When uncertain about removal patterns**, load:
`references/removal-patterns.md`

**When uncertain about improving vague comments**, load:
`references/improvement-examples.md`

**When encountering verbose implementation comments with good WHY content**, load:
`references/implementation-comment-condensation.md`

**When uncertain about preservation rules**, load:
`references/preservation-guidelines.md`

**When checking code-comment consistency or flagging inconsistencies**, load:
`references/consistency-checking.md`

**When potential HIGH/MEDIUM uncertainty pattern detected**, load:
`references/uncertainty-patterns.md` - For complete decision tree, detailed classification patterns, and verification prompt templates

**When validation issues are detected during self-validation loop**, load:
`references/self-validation-checks.md` - For detailed validation rules, auto-correction algorithms, edge case handling, and escalation conditions

**When handling legacy code, algorithms, or generated files**, load:
`references/special-cases.md`

**When detecting API documentation** (see Comment Type Detection section), load based on specific need:
- `references/api-docs-core-principles.md` - For visibility rules (public/protected/private) and contract vs implementation distinction
- `references/api-docs-parameters-and-returns.md` - For parameter/return value documentation decisions
- `references/api-docs-contracts.md` - For preconditions, postconditions, and class invariants
Load api-docs-core-principles.md IMMEDIATELY when detecting API documentation to prevent misapplying implementation comment rules.

**When configuration help is needed**, load based on specific need:
- `references/config-overview.md` - For quick start, file location, configuration format, or getting started questions
- `references/config-options-reference.md` - For detailed documentation of specific config options (ignore_paths, preserve_patterns, ticket_format, conservative_paths, exemption_markers, domain_terms)
- `references/config-recipes.md` - For common patterns (GitHub, JIRA, Linear), troubleshooting, or migration help
Load config-overview.md when: user asks about configuration basics, YAML parsing fails, or needs quick reference.
Load config-options-reference.md when: user needs details on specific option or invalid regex/glob patterns detected.
Load config-recipes.md when: user needs tool-specific examples, reports config not working, or troubleshooting pattern matching.

**When you need complete workflow examples**, load `references/workflow-examples.md`:
- User asks to see example outputs
- Clarification needed on report format
- Understanding expected behavior for different scope types (files, directories, git changes, commits)

Do not load all references at once. Load them individually as specific needs arise during the review process.

## Review Approach

### Core Review Principles

1. **Detect comment type FIRST** - API documentation (/** */ with @param/@return) need condensation; implementation comments need WHY context
2. **Verify code-comment consistency** - #1 quality attribute; inconsistent comments are worse than missing comments
3. **Preserve over remove when uncertain** - Flag for human review rather than auto-removing
4. **Load references progressively** - Load specific guides as patterns arise, not upfront
5. **Respect project configuration** - Honor ignore_paths, preserve_patterns, conservative_paths, exemption_markers, domain_terms, ticket_format
6. **Report transparently** - Document all changes with line numbers, rationale, and categories

### Review Strategy

**Default workflow checklist** (adapts to scope):
- [ ] Count files and determine scope (batch if overwhelming, use TodoWrite for complex reviews)
- [ ] Load project config if present (`.reviewrc.md` or `.claude/comment-reviewing-config.md`)
- [ ] Categorize comments (Remove/Improve/Condense/Preserve/Flag)
- [ ] For git diffs: use `scripts/git-helpers.sh`, focus on changed lines only
- [ ] Run self-validation loop (validate categorizations, apply auto-corrections, escalate systematic issues)
- [ ] Apply changes systematically
- [ ] Generate report using appropriate output format based on scope size and user intent

**Variations:**
- **Read-only mode:** Report without edits (when user requests analysis only); validation still runs but reports violations instead of auto-correcting
- **Interactive mode:** Show proposed changes and wait for confirmation before applying; validation runs first, presents corrected categorizations for approval
- **Large scope:** Process in batches when overwhelming (prevents context overflow, enables incremental progress), prioritize high-impact files; validation summarizes corrections instead of itemizing
- **Complex changes:** Load relevant references early (api-docs-core-principles.md, implementation-comment-condensation.md, self-validation-checks.md if validation issues detected)

### Quality Assurance Checkpoints

**Configuration Validation**
- Load project config (`.reviewrc.md` or `.claude/comment-reviewing-config.md`) if present
- Validate regex patterns (preserve_patterns, ticket_format) and glob patterns (ignore_paths, conservative_paths)
- Warn on errors, skip invalid patterns

**Scope Verification**
- Determine review scope (directory, git diff, specific files, commits) and count files
- Skip generated files (vendor/, node_modules/, dist/, *.generated.*, lock files, @generated markers)
- For git diffs: use `scripts/git-helpers.sh`, focus only on changed lines

**Comment Analysis**
- Read entire file before categorizing
- Detect comment type: API documentation (/** */ with @param/@return before public/protected method) vs implementation comments
- Private methods with structured docs → use implementation comment rules
- Skip comments with exemption_markers entirely
- Categorize: Remove (obvious), Improve (vague), CONDENSE (verbose), Preserve (valuable), FLAG (inconsistent)
- Verify consistency: comment matches function name, return value, parameters, behavior, ticket_format

**Uncertainty Evaluation**
- For each change, apply lightweight classification heuristics (see Rules for Uncertainty Evaluation)
- If potential HIGH/MEDIUM pattern detected: load `references/uncertainty-patterns.md` for detailed evaluation
- For confirmed HIGH/MEDIUM items: generate specific verification prompt using templates from reference
- Track uncertainty items for "Changes Requiring Verification" section in report

**Self-Validation Loop**
- Run after all comments are categorized, before applying edits
- Validate categorizations against 5 check categories: configuration compliance, consistency, categorization logic, uncertainty alignment, completeness
- Apply auto-corrections where safe (preserve_pattern violations, consistency issues, logic errors)
- Escalate systematic issues immediately (>10% same violation type, configuration conflicts)
- Generate validation report for transparency
- For detailed validation rules and auto-correction logic, load `references/self-validation-checks.md`
- Validation ensures: config rules respected, internal consistency maintained, logic sound, uncertainty tracked, scope complete

**Pre-Edit Review**
- Count changes by category (Remove/Improve/Condense/Preserve/Flag)
- Count uncertainty items by level (HIGH/MEDIUM)
- Identify flagged comments (do NOT auto-remove)
- If accumulating multiple HIGH uncertainty items OR changes feel extensive for scope: consider previewing and requesting confirmation
- Goal: catch potentially problematic batches early without over-interrupting
- Show summary including uncertainty: "5 changes (2 need verification)"
- Extra caution in conservative_paths files

**Edit Operations**
- Use validation functions from `scripts/validate-edit.sh` before editing:
  ```bash
  # Example: Validate file before editing
  bash -c "source scripts/validate-edit.sh && validate_file_exists '$file_path'"

  # Example: Ensure old_string is unique
  bash -c "source scripts/validate-edit.sh && find_string_in_file '$file_path' '$old_string'"
  ```
  Functions: `validate_file_exists`, `find_string_in_file`, `should_skip_file`
- Make one Edit at a time with exact old_string matching
- Preserve formatting and indentation
- Include surrounding context if string not unique

**Post-Edit Verification**
- Confirm edits succeeded
- Track completed changes for final report
- Note any files skipped due to errors

### Error Recovery Patterns

Handle errors gracefully using available validation utilities:

**Edit Failures - Non-Unique String**
1. Use `suggest_unique_string <file> <string>` to get context-enhanced version
2. Retry Edit with expanded old_string including surrounding lines
3. If still failing after 2 attempts: report to user with specific line numbers and skip

**Edit Failures - File Not Found**
1. Verify path is absolute (not relative)
2. Check if file was moved/renamed during review
3. Report to user and skip file

**Large Files**
If Read tool returns truncation warnings or you encounter token limits:
1. Use Read tool with offset/limit parameters to read file in chunks
2. Focus on sections containing comments
3. Process incrementally, tracking reviewed sections

**Git Command Failures**
- Use `scripts/git-helpers.sh` for reliable git operations with error handling:
  ```bash
  # Example: Detect main branch with fallbacks
  bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-helpers.sh && detect_main_branch"

  # Example: Validate commit before processing
  bash -c "WORK_DIR=\$(pwd) && cd {baseDir} && source scripts/git-helpers.sh && validate_commit $commit_ref"
  ```
  Available functions: `check_git_repo`, `validate_commit`, `detect_main_branch`, `get_changed_files`, `get_diff_content`
- Report specific error (command + stderr output) to user

**Configuration Errors**
1. Warn user with specific error message (e.g., "Invalid regex in preserve_patterns: ...")
2. Skip invalid pattern, continue with remaining configuration
3. Use default rules for failed sections
4. Note configuration issues in final report

**Uncertain Comments**
- Err on side of caution and preserve the comment
- Note in report with preservation reason
- Flag for human review if potentially inconsistent (don't assume comment is wrong—code might be buggy)

### Output Standards

Adapt output verbosity based on scope size and user intent to balance transparency with token efficiency:

**Output verbosity** (choose based on context):
- **Verbose**: Small scope, user requests detailed analysis, or learning mode
  - Detailed rationale for all decisions including preserved comments
  - Before/after text for improvements
  - Explanation of why comments were preserved

- **Standard**: Medium scope where transparency matters
  - Per-file changes with line numbers and categories
  - Summary statistics
  - Flagged comments section with details

- **Concise**: Large scope, user requests summary, or batch processing
  - Summary statistics + flagged comments only
  - Omit per-file line-by-line details
  - Focus on actionable information requiring attention

**For complete format templates, selection guidance, and examples, see `references/output-formats.md`**

#### Changes Requiring Verification Section

Include a "Changes Requiring Verification ⚠️" section in the report when HIGH or MEDIUM uncertainty items exist. This section appears after "Files Reviewed" and before "Summary".

**Format:**
```markdown
### Changes Requiring Verification ⚠️

#### High Priority - Please Review
1. **[Filename]:[line-range]**
   - **Change**: [concise description of what was changed]
   - **Uncertainty**: [why manual verification needed]
   - **Verify**: [specific actionable check for user]

#### Medium Priority - Optional
[same format as High Priority]
```

**Verbosity adaptation:**
- **Verbose**: Full details with examples and context for each item
- **Standard**: Structured list with change/uncertainty/verify for each item
- **Concise**: Summary counts only ("3 High Priority items across 2 files - see file summaries")

**Omit this section entirely** if no HIGH or MEDIUM uncertainty items detected (only LOW uncertainty = routine changes).

#### Standard Format Example

```markdown
## Comment Review Results

### Configuration
Loaded from .reviewrc.md (3 ignore paths, 2 preserve patterns)

### Files Reviewed: src/services/UserService.php

**src/services/UserService.php**
- Line 45: Removed "// Get user by ID" (redundant implementation comment)
- Line 67: Improved "// Process data" → "// Sanitize HTML to prevent XSS" (vague implementation comment)
- Line 102: PRESERVED "// Workaround for bug #4521" (important context)
- Line 120: FLAGGED "// Returns full name" but function get_email() returns email (inconsistent)

### Changes Requiring Verification ⚠️

#### High Priority - Please Review
1. **ContentLayoutInterface.php:25-40**
   - **Change**: Removed concrete examples ('productId', 'categoryId', 'landingPageId') from interface method documentation
   - **Uncertainty**: Examples might serve as implementation guidance for developers creating new entity adapters
   - **Verify**: Are these naming patterns documented elsewhere? Check if new implementations need this guidance.

### Summary
- Removed: 2 redundant comments
- Improved: 1 vague implementation comment
- Flagged: 1 comment requiring verification
- Preserved: 1 valuable comment
- Files changed: 1

### Flagged Comments Requiring Attention
1. **UserService.php:120** - Comment vs code mismatch
```

## Special Cases

- **Legacy Code**: Be conservative, check git blame for context, preserve historical comments
- **Complex Algorithms**: Preserve algorithm choice explanations and performance characteristics
- **Generated Code**: Skip files with @generated markers, build artifacts, lock files

**For complete guidelines and examples, see `references/special-cases.md`**
