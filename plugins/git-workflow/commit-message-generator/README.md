# Commit Message Generator

Generate and validate conventional commit messages with custom project rules. Automatically detects commit type, infers scope from file paths, detects breaking changes, and validates message consistency.

## Quick Start

### Slash Commands (Recommended)

Two slash commands are available:

**`/commit-gen [commit-ref]`** - Generate commit message from changes

Analyzes code changes to determine type, infer scope, and generate a properly formatted conventional commit message.

```bash
# Generate for staged changes (default)
git add src/auth/
/commit-gen

# Generate for existing commit
/commit-gen HEAD
/commit-gen abc123f
/commit-gen HEAD~3
```

**`/commit-check [commit-ref]`** - Validate commit message format and consistency

Checks format compliance, type/scope accuracy, and validates consistency with actual code changes.

```bash
# Check most recent commit
/commit-check

# Check specific commit
/commit-check HEAD~3
/commit-check abc123f
/commit-check HEAD~5..HEAD  # Check range of commits
```

### Natural Language (Alternative)

Use natural language instead of slash commands:

**Generation:**
```
Generate a commit message for my staged changes
Write a conventional commit message
```

**Validation:**
```
Check if my commit follows conventions
Validate this commit message
```

The `commit-message-generating` skill will be automatically invoked.

## Features

### Conventional Commits Format

Generates messages following the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): subject

body

footer
```

### Supported Types

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code formatting (no logic change)
- `refactor` - Code restructuring
- `perf` - Performance improvements
- `test` - Adding/updating tests
- `build` - Build system changes
- `ci` - CI/CD configuration
- `chore` - Maintenance tasks
- `revert` - Revert previous commit

### Clipboard Integration

Optionally copy generated commit messages directly to your system clipboard with cross-platform support:
- **macOS**: Uses `pbcopy` (built-in)
- **Linux X11**: Uses `xclip` or `xsel` (auto-detects available tool)
- **Linux Wayland**: Uses `wl-copy` from wl-clipboard
- **Windows/WSL**: Uses `clip.exe` (built-in)

The plugin asks for permission before copying and provides installation instructions if no clipboard tool is found.

### Intelligent Type Detection

Automatically determines the correct commit type by analyzing your code changes:

- **Smart Pattern Recognition**: Distinguishes between features, fixes, refactors, and 7 other commit types
- **Confidence-Based Suggestions**: Presents options when changes are ambiguous, accepts automatically when confident
- **Breaking Change Detection**: Identifies and marks API compatibility issues
- **Clear Reasoning**: Explains why each type was chosen, reducing manual corrections

### Intelligent Scope Detection

Automatically determines the correct scope by analyzing changed file paths:

- **Path-to-Scope Mapping**: Infers module/feature scope from directory structure (e.g., `src/auth/` → `auth`)
- **Monorepo Support**: Detects package names in monorepo structures (e.g., `packages/core/` → `core`)
- **Confidence-Based Interaction**: Asks for clarification when files span multiple modules
- **Project Configuration**: Respects allowed scopes and scope aliases from `.commitmsgrc.md`
- **Smart Omission**: Recommends omitting scope when redundant (e.g., docs-only changes)

### Additional Automatic Detection

- **Breaking Changes**: Marks breaking changes with `!` marker and generates `BREAKING CHANGE` footer
- **Consistency Validation**: Verifies that type/scope match actual changes and subject describes what changed

## Project-Specific Configuration

Customize commit rules for your project using `.commitmsgrc.md`:

```yaml
---
types:
  - feat
  - fix
  - docs
  - refactor
  - test
  - chore

scopes:
  - api
  - auth
  - ui
  - db

require_scope: true
required_ticket_format: "JIRA-\\d+"
max_subject_length: 50
---
```

**Features:**
- Control allowed commit types and scopes
- Require scope or ticket references
- Define breaking change markers and subject length limits
- Enforce custom validation rules
- Configuration commits to git and shares with team

**Documentation:**
- Quick start template: `skills/commit-message-generating/commitmsgrc-template.md`
- Complete guide: `skills/commit-message-generating/references/custom-rules.md`

Configuration is optional. Without it, the plugin uses sensible defaults.

## Functionality

### Analyze Existing Commits

Generate ideal commit messages by analyzing existing commits. This helps you understand what a well-formatted message should look like for a given set of changes (ignores the existing message entirely).

```bash
/commit-gen HEAD~5      # See what the ideal message should be for an older commit
```

### Automatic Type Detection

Analyzes code changes to determine the correct commit type:
- New files/features → `feat`
- Bug fixes → `fix`
- Code restructuring → `refactor`
- Performance improvements → `perf`
- Documentation only → `docs`

### Scope Inference

Determines scope from changed file paths:
```
src/auth/LoginService.ts  → scope: auth
src/api/v2/users.ts       → scope: api
src/components/Button.tsx → scope: ui
```

### Breaking Change Detection

Identifies breaking changes and formats them correctly:
```
feat(api)!: change authentication to OAuth2

BREAKING CHANGE: /auth/login now requires OAuth2 instead of username/password.
```

### Consistency Validation

Checks that:
- Type matches actual code changes
- Scope corresponds to changed files
- Subject accurately describes what changed
- Breaking changes are properly marked
- Project rules from `.commitmsgrc.md` are satisfied

## Supported Formats

Generates and validates:
- Single-line subject with optional scope
- Multi-line format with body and footer
- Breaking change markers and descriptions
- Ticket references and custom fields

## Example Output

**Generation from staged changes:**
```
Generated commit message:

feat(auth): add OAuth2 authentication support

Implements OAuth2 with Google and GitHub providers.
Users can link multiple providers to single account.

BREAKING CHANGE: Session-based auth deprecated.
```

**Generation from existing commit:**
```
Generated commit message for abc123f:

feat(auth): add OAuth2 authentication support

Implements OAuth2 with Google and GitHub providers.
Users can link multiple providers to single account.

BREAKING CHANGE: Session-based auth deprecated.
```

**Validation Report:**
```
Commit Message Validation Report
=================================

Commit: abc123f
Message: "fix(auth): resolve token expiration bug"

Format Compliance: ✓ PASS
Consistency Check: ✓ PASS
```

## Example Workflows

For detailed examples including new features, bug fixes, breaking changes, and performance improvements, see:
- `skills/commit-message-generating/references/examples.md`

## Documentation

- **Full specification**: `skills/commit-message-generating/references/conventional-commits-spec.md`
- **Type detection guide**: `references/type-detection.md`
- **Scope detection guide**: `references/scope-detection.md`
- **Validation guide**: `skills/commit-message-generating/references/consistency-validation.md`
- **Configuration guide**: `skills/commit-message-generating/references/custom-rules.md`
- **Config template**: `skills/commit-message-generating/commitmsgrc-template.md`

## Developer Guide

See `AGENTS.md` for plugin architecture and development guidance.

## License

MIT
