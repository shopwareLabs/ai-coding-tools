# Scope Inference

Determine conventional commit scope from Shopware file paths with confidence-based analysis and commit history validation.

## Step 1: Infer from File Paths

Map Shopware's directory structure to a candidate scope. Sub-areas take precedence when ALL changed files fall within one sub-area. When files span multiple sub-areas within the same top-level area, use the top-level scope.

### Path-to-Scope Mapping

| Path pattern | Scope | Sub-area examples |
|---|---|---|
| `src/Core/Checkout/` | `checkout` | `Cart/` -> `cart`, `Payment/` -> `payment`, `Order/` -> `order` |
| `src/Core/Content/` | `content` | `Cms/` -> `cms`, `Product/` -> `product`, `Category/` -> `category`, `Media/` -> `media` |
| `src/Core/Framework/` | `framework` | `DataAbstractionLayer/` -> `dal`, `Api/` -> `api`, `App/` -> `app`, `Rule/` -> `rule` |
| `src/Core/System/` | `system` | `SalesChannel/` -> `sales-channel`, `Snippet/` -> `snippets`, `Tax/` -> `tax` |
| `src/Core/Profiling/` | `profiling` | |
| `src/Storefront/` | `storefront` | |
| `src/Administration/` | `admin` | |
| `src/Elasticsearch/` | `elasticsearch` | |

### Confidence Levels

**HIGH**: All changed files fall within a single area or sub-area.
- `src/Core/Content/Cms/CmsPageEntity.php` + `src/Core/Content/Cms/CmsSlotEntity.php` -> `cms`

**MEDIUM**: Multiple areas but one dominates (80%+ of changed files), or files span areas but relate to a single feature.
- `src/Core/Checkout/Cart/CartService.php` + `src/Storefront/Page/Checkout/CartPage.php` -> `checkout` (domain dominates)

**LOW**: Multiple unrelated areas with no clear dominant.
- `src/Core/Checkout/` + `src/Core/Content/` + `src/Administration/` -> ask user

### Naming Conventions

- Lowercase, kebab-case: `sales-channel` not `SalesChannel`
- Singular preferred: `product` not `products`
- Concise (1-2 words): `dal` not `data-abstraction-layer`

### When to Omit Scope

Omit scope entirely when:
- Type is `docs` with project-wide docs (README.md, root-level documentation)
- Type is `ci` with CI config only (.github/workflows/)
- Type is `style` (formatting/whitespace only)
- Root-level config files (composer.json, phpstan.neon, .gitignore)
- Cross-cutting changes spanning 3+ unrelated areas with no clear primary

## Step 2: Validate Against Commit History

For HIGH and MEDIUM confidence: extract existing scopes from recent commit subjects.

```bash
git log <base> --oneline -200 --format='%s'
```

Parse scopes from parentheses in `type(scope): subject` patterns. Compare the inferred scope against this set:

- **Exact match** in history -> confirmed, use it
- **Close variant** exists (e.g., inferred `administration`, history shows `admin`) -> use the historical variant
- **No match** and no close variant -> downgrade to LOW confidence, proceed to Step 3

For LOW confidence: skip directly to Step 3.

## Step 3: Ask User (LOW Confidence)

Use `AskUserQuestion` with structured options:

```
AskUserQuestion(
  question="Which scope best describes these changes?",
  options=[
    {label: "cart", description: "Changes primarily in Checkout/Cart"},
    {label: "checkout", description: "Broader checkout area"},
    {label: "Omit scope", description: "Cross-cutting, no single area"}
  ]
)
```

Include 2-4 options. Best guess first, historical near-matches in the middle, "Omit scope" last.

## Step 4: Persist to Project Memory

After a scope is confirmed (user-selected or HIGH confidence), save the scope-to-path mapping as a project memory through Claude's native memory system if:
- The scope is not already known in memory
- The mapping is non-obvious (sub-area scopes, historical variants)

This builds a project-specific scope vocabulary over time. On future invocations, known scope mappings appear in conversation context automatically, acting as a fast-path before commit history checking.

Do not save obvious top-level mappings (e.g., `src/Storefront/` -> `storefront`). Only save mappings that required history validation or user input.
