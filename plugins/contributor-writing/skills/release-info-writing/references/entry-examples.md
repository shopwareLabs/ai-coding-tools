# Entry Examples by Size Tier

Use these examples to calibrate the size and density of your drafted entries. Match the tier to the magnitude of the change.

## RELEASE_INFO Entry Tiers

### Tiny (2-4 lines) — Minor behavioral changes, simple constraints

Use for: single-field constraints, small behavioral tweaks, simple DX improvements.

**Example — Constraint added:**
```markdown
### Minimum value constraints added to quantity fields in ProductPriceDefinition

The fields `quantityStart` and `quantityEnd` of ProductPriceDefinition now require a minimum value of `1`.
```
Why this is tiny: one fact, no migration needed, self-explanatory impact.

**Example — Behavioral fix (notable):**
```markdown
### Existing cart recalculations no longer recreate deleted carts

When an existing cart is recalculated, Shopware now uses the cart's persisted state to avoid recreating carts that were already deleted.
This prevents race conditions where a concurrent request, such as placing an order, deletes the cart and a stale recalculation writes it back afterwards.
```
Why this is tiny: explains the fix and the "why" in 3 lines. No action needed from developers.

**Example — DX improvement:**
```markdown
### Disabled runtime error overlay in webpack dev server

The webpack dev server overlay for runtime errors has been disabled in hot-reload mode. The overlay frequently interrupted the development workflow by covering the entire viewport for non-critical runtime errors, making it difficult to interact with the storefront during development. Error details remain available in the browser console.
```
Why this is tiny: describes what changed, why, and where to find errors instead — all in 3 lines.

### Small (5-10 lines) — Config changes, deprecations, simple features

Use for: new config options, simple deprecation announcements, small features with one code example.

**Example — Behavioral change with migration note:**
```markdown
### Changed behaviour of default fields in EntityDefinition

Currently, it is not possible to overwrite the default fields `createdAt` and `updatedAt` of an entity in the definition.
This is because the default fields are applied on top of the fields defined in the `defineFields` method.
From the next major version on, the logic is turned around and the defined fields will be applied after the default fields.
This makes it possible to overwrite the current default fields `createdAt` and `updatedAt`.
Check your EntityDefinitions if this change will have an effect on your entities' behaviour. (Only applicable if you manually add `CreatedAtField` and/or `UpdatedAtField`)
```
Why this is small: explains current behavior, upcoming change, and a call to action — but no code example needed.

**Example — Feature with code:**
```markdown
### System config overrides in staging mode

The `system:setup:staging` command now supports pre-configuring system config keys during staging setup. Both global and sales channel-specific values can be set, following the same YAML structure used for static system configuration.

Use `default` for global config values and sales channel IDs for channel-specific overrides:

[YAML code example]

When `bin/console system:setup:staging` is executed, the configured keys are written to the database via `SystemConfigService`.
```
Why this is small: new feature needs a code example to be useful, but the feature itself is straightforward.

### Medium (10-25 lines) — Deprecations with migration paths, new developer features, API changes

Use for: features that need explanation + usage example, deprecations with Before/After, new API endpoints with request/response format.

**Example — Deprecation with migration guidance:**
```markdown
### Options API backward-compatibility shim for Composition API components

[explanation of the shim mechanism: what it does, why it exists, what triggers it]

**What this means for you:**

- **No immediate action required.** The shim handles the translation automatically.
- **A deprecation warning will appear** when the shim intercepts an Options API override.
- **Lifecycle hooks** are supported through the shim, with noted limitations.
- Dot-notation watch paths are not supported through the shim.

[link to migration guide]
[feature flag note]
```
Why this is medium: the change has nuance (backward compat), multiple implications, and needs a structured "what this means for you" section.

**Example — New API with endpoint documentation:**
```markdown
### External media thumbnail support

External media entities can now have external thumbnail URLs attached to them, allowing CDN-hosted thumbnails for externally referenced media.

Two new API endpoints have been added:
- `POST /api/_action/media/{id}/external-thumbnails` - attach external thumbnail URLs
- `DELETE /api/_action/media/{id}/external-thumbnails` - remove all external thumbnails

Thumbnails must include `width` and `height`. The media entity must have an external `media_url` set.

[JSON request body example]

External thumbnails are returned alongside generated thumbnails in API responses.
```
Why this is medium: new endpoints need method, path, payload format, and constraints documented.

### Large (25-70+ lines) — Major features, new systems, comprehensive schema changes

Use for: new component systems, major architectural additions, features that introduce multiple new concepts.

Characteristics of large entries:
- Multiple h3 subsections within the category
- Multiple code examples (different languages or formats)
- Links to official documentation
- Tables for structured data (schema types, config options)
- Feature flag explanation

Large entries are rare. Most changes fit in tiny-to-medium.

## UPGRADE Entry Patterns

### Simple removal (3-5 lines)

```markdown
## Removed `/api/_action/mail-template/validate` route

The `/api/_action/mail-template/validate` route has been removed without replacement, as it was not used and did not provide any significant value.
```

### Behavioral change with migration (10-20 lines)

```markdown
## Removal of `$options` parameter in custom validator's constraints

The `$options` of all Shopware's custom validator constraint are removed, if you use one of them, please use named argument instead

**Before:**
[PHP code block showing old usage]

**After:**
[PHP code block showing new usage with named arguments]

Affected constraints are:
[list of affected classes with full namespaces]
```

### Complex system change with code examples (20-40 lines)

```markdown
## Only rules relevant for product prices are considered in the `sw-cache-hash`

[explanation of what changed and why: performance improvement, reduced cache invalidation]

[PHP code example showing how to use the new extension point]

[guidance for projects with custom entities that use rule-based pricing]
```

### List of removed classes (variable length)

```markdown
## Removal of `StoreApiRouteCacheKeyEvent` and all child classes

[context: why these events existed and why they're being removed]

The concrete events being removed:
- `Shopware\Core\Content\Category\Event\...`
- `Shopware\Core\Content\Product\Event\...`
[full list of FQCNs]
```

## Critical Fix Entries (RELEASE_INFO)

Critical fixes have variable size (usually 3-8 lines). They appear under the version they fix (e.g., `# 6.7.8.1`) in the `## Critical Fixes` category. They explain the security or stability implication:

```markdown
### LoginRoute and AccountService don't throw CustomerNotFoundException

The `LoginRoute` and `AccountService` have been updated to no longer throw a `CustomerNotFoundException` when a login attempt is made with an email address that does not exist in the system.
Instead, they will now throw a generic `BadCredentialsException` without revealing whether the email address is registered or not.
This change enhances security by preventing potential attackers from enumerating valid email addresses through error messages.
```
