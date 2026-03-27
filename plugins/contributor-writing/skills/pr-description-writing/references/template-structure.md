# PR Description Template Structure

## Conventional Commit Title

Format: `<type>(<scope>): <description>`

### Type

Determined by the primary story of the branch:

| Type | When to use |
|---|---|
| `fix` | Bug fix |
| `feat` | New feature or capability |
| `refactor` | Code restructuring with no behavioral change |
| `perf` | Performance improvement |
| `chore` | Maintenance, dependency updates, tooling |
| `docs` | Documentation only |
| `test` | Test additions or corrections |
| `style` | Code style (formatting, semicolons, etc.) |

### Scope

Inferred from file paths — represents the affected Shopware area:

| File path pattern | Scope |
|---|---|
| `src/Core/Checkout/Cart/` | `cart` |
| `src/Core/Checkout/Order/` | `order` |
| `src/Core/Checkout/Promotion/` | `promotion` |
| `src/Core/Content/Product/` | `product` |
| `src/Core/Content/Media/` | `media` |
| `src/Core/Content/Category/` | `category` |
| `src/Core/Content/Cms/` | `cms` |
| `src/Core/Content/Mail/` | `mail` |
| `src/Core/Framework/DataAbstractionLayer/` | `dal` |
| `src/Core/Framework/App/` | `app-system` |
| `src/Core/System/SystemConfig/` | `system-config` |
| `src/Core/System/NumberRange/` | `number-range` |
| `src/Storefront/` | `storefront` |
| `src/Administration/` | `admin` |
| `src/Elasticsearch/` | `elasticsearch` |

For changes spanning multiple areas, use the scope of the primary story. If no specific scope fits, omit the parenthetical scope entirely: `fix: description`.

### Description

- Imperative mood: "add", "fix", "remove" — not "added", "fixed", "removed"
- Lowercase first letter
- No period at the end
- Under ~60 characters after type/scope
- Describe the behavioral change, not the implementation: "skip schema update on app delete" not "add conditional check in AppLifecycleHandler"

### Title examples

Good:
- `fix(cart): skip schema update on app delete without custom entities`
- `feat(storefront): add search bar to settings page`
- `fix(mail): prevent double attachment in test mails`
- `perf(seo): don't fetch child categories in seo url updater`
- `refactor: deprecate blocking automatic promotions`

Bad:
- `fix: Fix product search SQL scoring` (redundant "Fix", capitalized)
- `feat: Allow Configuration of Custom Fields to be Searchable` (title case, too long)
- `fix: fixed bug in cart` (past tense, vague)

## Description Template

The description uses Shopware's standard 5-section PR template. Always output all sections.

### Section 1: Why is this change necessary?

```markdown
### 1. Why is this change necessary?

[motivation, root cause, business context]
```

**Content guidance:**
- Lead with the problem or gap, not the solution
- For fixes: explain the root cause — what was broken and why. "The sort function threw a TypeError" is better than "There was a bug"
- For features: explain what's not possible today and why that matters
- For performance: quantify the improvement if data is available
- The "why behind the why": not just the problem, but why this particular approach was chosen

### Section 2: What does this change do, exactly?

```markdown
### 2. What does this change do, exactly?

[technical explanation of the solution]
```

**Content guidance:**
- Explain the approach, not just name the files changed
- Add code examples only when they convey information the prose doesn't. A snippet that shows a non-obvious algorithm, a config format, or a query structure adds value. A snippet that just shows an added parameter or renamed method restates the prose — omit it.
- For complex changes, use subsections with descriptive headings
- State scope boundaries for large changes: "This PR introduces X. Specific Y will follow in separate PRs."
- Include before/after code blocks for behavioral changes or migrations where the difference isn't trivially described in a sentence
- Include mermaid diagrams for complex multi-step flows (sparingly)
- Breaking changes: if the PR's primary purpose is the breaking change, weave it into the section 2 prose — don't add a separate callout. Only use a distinct callout when the break is incidental to the PR's main story (e.g., a feature that happens to remove a deprecated method as a side effect)

### Section 3: Describe each step to reproduce the issue or behaviour.

```markdown
### 3. Describe each step to reproduce the issue or behaviour.

[reproduction steps or testing instructions]
```

**Content guidance:**
- For fixes: numbered steps with expected vs actual behavior
- For features: steps to exercise the new functionality
- For refactors: "N/A — no behavioral change. Verified by existing test suite passing." Don't leave empty.
- Be specific: "Create a product without a manufacturer" not "Set up test data"
- Include the expected outcome at each significant step

### Section 4: Please link to the relevant issues (if any).

```markdown
### 4. Please link to the relevant issues (if any).

fixes #1234
```

**Content guidance:**
- Use `fixes #N` or `closes #N` for issues this PR resolves (GitHub auto-closes them on merge)
- Use `resolves URL` for cross-repo issues
- Use `related: #N` or `downstream: URL` for companion PRs
- If no issues exist, write "None" — don't leave blank

### Section 5: Checklist

The skill does NOT generate the checklist section. It's a set of manual checkboxes the author fills in themselves. The skill's output ends after section 4.

## Enhancement Rules

Add enhancements only when they genuinely help reviewers. Don't add them to pad the description.

| Enhancement | When to add | Where it goes |
|---|---|---|
| Root cause analysis | Fix with non-trivial cause | Section 1 |
| Code example (inline) | Non-obvious algorithm, config format, query structure — not trivial parameter/rename changes | Section 2 |
| Before/after blocks | Behavioral change, migration | Section 2 |
| Scope boundaries | Large feature, multi-PR initiative | Section 2 |
| Mermaid diagram | Complex multi-step flow that's hard to follow in prose | Section 2 |
| Breaking change callout | Incidental break only — if the PR *is* the break, weave into prose | Section 2 (end) |
| Cross-references | Regression from prior PR, related work | Section 1 or 4 |
| Downstream PR links | Companion changes in other repos | Section 4 |
