# PR Description Examples by Density Tier

Use these examples to calibrate the density of sections 1-3 in your drafted PR description. The tier is determined by explanation complexity — not by diff size. A 2-line fix that required tracing three code paths is medium, not small.

## Small (< 20 lines total across sections 1-3)

The change is self-explanatory from the title plus a few sentences. No ambiguity about why or how.

### Example — Simple null fix

**Title:** `fix: tax rule type needs to be nullable`

```markdown
### 1. Why is this change necessary?

Many-To-One-Association properties need to be nullable.

### 2. What does this change do, exactly?

Makes the `type` field nullable on `TaxRuleTypeEntity` to conform to Many-To-One association requirements.

### 3. Describe each step to reproduce the issue or behaviour.

Create a tax rule with a Many-To-One association where the type field can be null — previously this caused a type error during hydration.
```

Why this is small: one fact, one fix, no complexity to explain. The title already tells most of the story.

### Example — Simple behavioral fix

**Title:** `fix: don't purge reverse proxy when not turned on`

```markdown
### 1. Why is this change necessary?

Running `cache:clear:all` triggers varnish purge errors even when no reverse proxy is configured.

### 2. What does this change do, exactly?

Checks the reverse proxy enabled state before calling `banAll` during cache clearing.

### 3. Describe each step to reproduce the issue or behaviour.

Run `bin/console cache:clear:all` without a reverse proxy configured. Previously, this logged varnish purge failure errors. After the fix, the purge step is skipped entirely.
```

Why this is small: clear cause, clear fix, self-evident reproduction.

### Example — Simple constraint addition

**Title:** `fix: add min value constraints to product price quantity fields`

```markdown
### 1. Why is this change necessary?

The Administration UI already prevents `quantityStart` values below 1, but the API/EntityDefinition has no such constraint. API consumers can create invalid price rules.

### 2. What does this change do, exactly?

Adds minimum value constraints to `quantityStart` and `quantityEnd` in `ProductPriceDefinition`. Includes a migration setting all existing quantity values below 1 to 1.

### 3. Describe each step to reproduce the issue or behaviour.

Send a `POST /api/product-price` with `quantityStart: 0`. Previously accepted — now returns a validation error.
```

Why this is small: the constraint is straightforward, the migration is mechanical.

## Medium (20-50 lines total across sections 1-3)

The change needs context that isn't obvious from the diff. Most PRs land here.

### Example — Bug fix with root cause analysis

**Title:** `fix: test mail double mail attachment`

```markdown
### 1. Why is this change necessary?

When sending a test mail from the admin, configured attachments are added twice. The root cause is two independent code paths that both consume the same `mediaIds` from the request:

- **Path 1:** `MailService` reads `$data['mediaIds']` directly, resolves them to URLs, and attaches them to the mail object before sending.
- **Path 2:** The same `$data['mediaIds']` are passed to `MailSendSubscriberConfig`. During processing, `MailerTransportDecorator` calls `MailAttachmentsBuilder::buildAttachments()`, which attaches the media IDs a second time.

### 2. What does this change do, exactly?

Clears path 2 by not passing the media IDs to the subscriber config. Media IDs now only travel through path 1 (`MailService` → direct attachment).

### 3. Describe each step to reproduce the issue or behaviour.

1. Go to Settings → Mail templates → Order confirmation
2. Configure a media attachment
3. Click "Send test mail" in the sidebar
4. Inspect the received mail — attachments appear twice

After the fix, each attachment appears once.
```

Why this is medium: the root cause requires understanding two code paths. Without the path 1/path 2 explanation, a reviewer can't evaluate whether the fix is correct.

### Example — Feature with usage context

**Title:** `feat: allow system config overrides in staging mode`

```markdown
### 1. Why is this change necessary?

The staging mode setup (`system:setup:staging`) supports configuring mail delivery, sales channel domains, and extensions, but there's no way to pre-configure system config keys. Users who need staging-specific config (SMTP hosts, feature flags) have to set them manually after running the command.

### 2. What does this change do, exactly?

Adds a new `shopware.staging.system_config` configuration node. It follows the same YAML structure as static system configuration — `default` scope for global values, sales channel ID scopes for channel-specific overrides.

```yaml
shopware:
  staging:
    system_config:
      default:
        core.mailerSettings.smtpHost: "smtp.staging.local"
        core.listing.allowBuyInListing: false
      0188da12724970b9b4a708298259b171:
        core.mailerSettings.smtpHost: "smtp.other.staging.local"
```

A new `StagingSystemConfigHandler` processes these overrides when `system:setup:staging` is dispatched.

### 3. Describe each step to reproduce the issue or behaviour.

1. Add system config overrides to `config/packages/staging.yaml` as shown above
2. Run `bin/console system:setup:staging`
3. Verify the configured keys are set in the `system_config` database table
```

Why this is medium: the feature needs a YAML example to be useful, and the "why" requires explaining the gap in current staging setup.

### Example — Bug fix requiring non-trivial explanation

**Title:** `fix: and search on multiple terms should be a must query`

```markdown
### 1. Why is this change necessary?

When searching for multiple terms with AND logic (e.g., "foo bar"), Elasticsearch used a `TermsQuery` which matches if **any** term matches (OR behavior). For AND search, **all** terms must match.

### 2. What does this change do, exactly?

For multi-term AND searches, builds a `BoolQuery` with `MUST` conditions instead of using `TermsQuery`:

```php
if ($config->isAndLogic()) {
    $exactMatchQuery = new BoolQuery();
    foreach ($tokens as $tokenPart) {
        $exactMatchQuery->add(new TermQuery($config->getField(), $tokenPart), BoolQuery::MUST);
    }
    return $exactMatchQuery;
}
```

Single-term queries and OR logic queries are unchanged.

### 3. Describe each step to reproduce the issue or behaviour.

1. Create products: "Saphir Ring Gold", "Diamond Ring Silver"
2. Search for "ring saphir" with AND logic enabled
3. Expected: only "Saphir Ring Gold" matches (both terms present)
4. Before fix: "Diamond Ring Silver" also matched (OR behavior)
```

Why this is medium: the Elasticsearch query semantics (Terms vs Bool/MUST) aren't obvious from the diff. The code snippet shows the fix more clearly than prose could.

### Example — Fix with race condition explanation

**Title:** `fix: prevent SSO state invalidation caused by race condition during logout redirect`

```markdown
### 1. Why is this change necessary?

After SSO logout, the redirect to the identity provider can be followed by a Vue Router navigation that calls `getLoginTemplateConfig()` again — overwriting the CSRF state token in the PHP session and causing `SSO_LOGIN__INVALID_LOGIN_STATE` on re-authentication. Repeated logout/login cycles also fail because the `sw-sso-session` marker is cleared on first logout and never restored.

### 2. What does this change do, exactly?

Four changes:

- `logoutSso()` returns `Promise<void>` and handles navigation internally (SSO → redirect, non-SSO → `forwardLogout()`), removing the boolean return and eliminating the race condition in `onLogoutUser()`
- The `sw-sso-session` sessionStorage marker is preserved across SSO redirects so repeated cycles work
- `StateValidator::createRandom()` reuses an existing session key instead of generating a new one (idempotent)
- `StateValidator::validateRequest()` removes the session key after successful validation (one-time-use)

### 3. Describe each step to reproduce the issue or behaviour.

1. Log in via SSO
2. Log out → redirected to identity provider
3. Re-authenticate → back in admin
4. Log out again → shows local login page instead of SSO redirect, or `SSO_LOGIN__INVALID_LOGIN_STATE` on callback
```

Why this is medium: the race condition requires explaining the timing between redirect and Vue Router navigation. Four discrete changes need listing to be reviewable.

## Large (50+ lines total across sections 1-3)

The change introduces a complete new feature with new integration points — the kind of change that would justify a presentation. New API surfaces, new subsystems, architectural changes.

### Example — New subsystem with integration points

**Title:** `feat(content-system): add runtime type introspection for content data loaders`

```markdown
### 1. Why is this change necessary?

The Admin UI needs to know which data types each content data loader can deliver — for example, to populate a compatibility dropdown when configuring content elements. This type information already exists as `@extends AbstractContentDataLoader<T>` PHPDoc annotations on every loader, but only PHPStan can consume it. There's no way to access it at runtime.

### 2. What does this change do, exactly?

Makes loader type information available at runtime by parsing PHPDoc annotations at container build time, collecting results into a registry, and exposing them through an Admin API endpoint.

**Reusing PHPDoc as the single source of truth**

Rather than adding a second declaration mechanism (attributes, config, interface methods), the compiler pass reads the existing `@extends` annotations. Loaders don't need to change — if PHPStan already validates the type, the runtime registry picks it up automatically.

**Compile-time collection, resolve-time override**

A `ContentDataLoaderTypeCompilerPass` runs during container compilation:
1. Finds all services tagged `shopware.content.data_loader`
2. Parses the `@extends AbstractContentDataLoader<T>` annotation from each class
3. Stores the mapping in a `ContentDataLoaderTypeRegistry` service

At resolve time, loaders can override their compiled types via `overrideProvidedTypes()` — useful for loaders that dynamically determine their output types based on configuration.

**API endpoint**

`GET /api/_info/content-data-loader-types` returns the full type registry. Response is cached and invalidated on container rebuild.

**Error handling**

Three new exception factories handle: missing annotation (build-time failure), invalid type parameter, and registry lookup misses. Build-time failures are intentional — a loader without type information can't participate in the compatibility system.

### 3. Describe each step to reproduce the issue or behaviour.

1. Create a content data loader extending `AbstractContentDataLoader<ProductCollection>`
2. Register it as a tagged service
3. Run `bin/console cache:clear` to trigger the compiler pass
4. `GET /api/_info/content-data-loader-types` — verify the loader appears with type `ProductCollection`
5. Test override: implement `overrideProvidedTypes()` returning a different type, clear cache, verify API reflects the override
```

Why this is large: introduces a new subsystem (compiler pass + registry + API endpoint + extension mechanism). Each architectural decision needs justification. This is the kind of change you'd present in a team meeting.

### Example — New component system

**Title:** `feat: introduce storefront components based on Symfony UX Twig components`

A PR this large (17K+ lines, 79 files) would have sections 1-3 at ~50-70 lines covering: the motivation for a new component system, the Symfony UX foundation choice, what this PR includes vs. what follows in later PRs (scope boundary), how to create a component, how the rendering pipeline works, and testing instructions for both creating components and verifying existing templates still work.

The key for large PRs: break section 2 into subsections with descriptive headings. Don't write one wall of text — reviewers need to navigate to the part they're reviewing.
