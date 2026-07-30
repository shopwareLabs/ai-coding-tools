---
name: xml-config-migrating
version: 1.0.0
description: Use this skill when a Shopware plugin or app-server extension needs its XML configuration migrated to PHP — phrases like "migrate services.xml", "convert my plugin config to PHP", "xml to php migration", "fix the XML deprecation", "prepare my plugin for Shopware 6.8 / Symfony 8", or when a deprecation like "The XML configuration file ... is deprecated and will not be loaded in v6.8.0.0" appears in logs or CI. Migrates services.xml, services_test.xml, routes*.xml, and packages/*.xml to PHP configurators 1:1, proves the compiled container and routes are unchanged via dump diffs, runs the extension's tests, and produces a verification report.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Migrate Shopware Extension XML Configuration to PHP

Shopware 6.7 deprecates loading Symfony configuration from XML for bundles and plugins; Shopware 6.8 removes it, because Symfony 8 drops the XML loaders entirely. Extensions that still ship XML config break with 6.8.

This skill performs a **purely mechanical, behavior-neutral migration**: the compiled container and route collection must be identical before and after, and that identity is **proven by dump diffs**, not assumed. Never "improve" wiring during migration.

## Scope

| In scope | Out of scope (Shopware-specific XML formats — keep as XML) |
|---|---|
| `src/Resources/config/services.xml`, `services_test.xml` | `Resources/config/config.xml` (plugin settings) |
| `src/Resources/config/routes.xml`, `routes_<env>.xml`, `routes_overwrite.xml`, any XML under `Resources/config/routes/` | `Resources/config/custom-fields.xml`, `flow.xml`, `rule-conditions.xml` |
| `src/Resources/config/packages/**/*.xml` | App `manifest.xml` |

## Prerequisites

- A working Shopware installation (6.6+) with the extension **installed and active**, and `bin/console` working. All console commands below run inside the project's environment (Docker/DDEV users: prefix accordingly, e.g. `docker compose exec web bin/console ...`).
- `jq` available for dump normalization.

## Workflow

### Step 1 — Inventory

Find every XML config file in the extension and classify it:

```bash
find <extension-root>/src -path '*/Resources/config/*' -name '*.xml' | grep -vE 'config\.xml|custom-fields\.xml|flow\.xml|rule-conditions\.xml'
```

The sweep covers the whole `src` tree, not just the top-level config directory: plugins registering extra bundles via `getAdditionalBundles()` carry config in each bundle's own `Resources/config`.

For each file note: type (services / routes / packages) and the environments it applies to (`services_test.xml` → `test` env, `routes_dev.xml` → `dev` env, everything else → default). Envs can also hide inside a file: grep each routes file for `<when env=` — every env targeted by a `<when>` block counts as an affected env for that file.

If the inventory is empty, report "nothing to migrate" and stop.

### Step 2 — Baseline snapshot (BEFORE any edit)

Snapshot the compiled state for the default env, plus every env an inventoried file is specific to:

```bash
mkdir -p var/xml-migration
bin/console cache:clear
bin/console debug:container --format=json               | jq -S . > var/xml-migration/before-services-default.json
bin/console debug:container --format=json --show-hidden | jq -S . > var/xml-migration/before-hidden-default.json
bin/console debug:container --parameters --format=json  | jq -S . > var/xml-migration/before-params-default.json
bin/console debug:router --format=json                  | jq -S . > var/xml-migration/before-routes-default.json
```

For additional envs, repeat with `APP_ENV=<env>` set for both `cache:clear` and the dumps, writing `before-*-<env>.json`.

Notes:
- `--show-hidden` is **exclusive**, not additive — both dumps are required (decorated inner services get hidden `.`-prefixed ids).
- `jq -S` sorts object keys only; array order (tags, arguments) is intentionally preserved — order is behavior.
- Before/after must run on the same installation, database, and plugin state.

### Step 3 — Migrate, one XML file → one PHP file

Apply the rules and translation table in [references/xml-to-php-translation.md](references/xml-to-php-translation.md). The invariants:

1. Same directory, same basename: `services.xml` → `services.php`, `services_test.xml` → `services_test.php`, `routes.xml` → `routes.php`. Package XML may go to YAML or PHP.
2. **Delete the XML file in the same change.** The plugin system globs `services.*` and loads ALL matches — if both exist, both load and the XML silently wins on collision. Coexistence is a trap, not a transition strategy.
3. **Convention-discovered files need no loader or bundle-class changes.** `Bundle::registerContainerFile()`, `configureRoutes()`, and `buildDefaultConfig()` already discover `.php` (and `.yaml`) files. But if the plugin loads XML manually (an `XmlFileLoader` in `Plugin::build()` or a bundle's `loadExtension()`), replace that `$loader->load('....xml')` line with a `PhpFileLoader` equivalent **at the same position** — load order is behavior and must not change.
4. Preserve 1:1: service ids, class names, argument values **and order**, tags with all attributes and priorities, method calls, factories, configurators, decoration (priority + on-invalid), public/private, lazy, shared, synthetic, abstract, deprecations, aliases, parameters, `<defaults>`.
5. Do NOT: enable autowire/autoconfigure, rename ids, reorder anything, merge or split files, add or remove services, or clean up "while you're at it".

### Step 4 — Verify: container and routes must be identical

First a cheap import-completeness pre-check: a bare `Foo::class` without a matching `use` silently resolves against the config file's own namespace — no parse error, just a wrong service id. For each migrated PHP file:

```python
imported = re.findall(r'use [\w\\]+\\(\w+);', src) + re.findall(r'use [\w\\]+ as (\w+);', src)
used = re.findall(r'(?<![\\\w])(\w+)::class', src)
missing = set(used) - set(imported) - {'ContainerConfigurator'}  # must be empty
```

Then the dump diff:

```bash
bin/console cache:clear
# repeat the four dumps as after-*-default.json (and per env)
diff var/xml-migration/before-services-default.json var/xml-migration/after-services-default.json
# ... one diff per artifact per env
```

**Every diff must be empty**, with exactly one documented exception: anonymous inline services (`<service>` without id used as an argument). The XML loader hoists them into hidden `.N_ClassName~hash` services; PHP's `inline_service()` keeps them inline in the argument. If a diff shows only this shape, record it as an inert diff in the report. Any other diff is a migration bug — fix the PHP file until the diff is empty; never "fix" the diff by adjusting expectations.

Also confirm no XML reference survived — match any `.xml` mention in PHP, minus the Shopware-specific formats that legitimately stay XML:

```bash
grep -rn '\.xml' <extension-root>/src --include='*.php' \
  | grep -vE 'config\.xml|custom-fields\.xml|flow\.xml|rule-conditions\.xml|manifest\.xml'
```

### Step 5 — Test

1. Run the extension's own test suite (PHPUnit; Jest/E2E if config-relevant) and its static analysis / code style tools if configured.
2. Confirm the deprecation is gone: `bin/console cache:clear` must no longer log `The XML configuration file "..." ... is deprecated` for this extension.
3. Strict check (recommended if the project is on 6.7+): `FEATURE_ALL=major bin/console cache:clear` must succeed — with the major flag, remaining XML config throws instead of logging.

### Step 6 — Report

End with this report — it is the deliverable, not the diff noise along the way:

```markdown
## XML → PHP configuration migration: <ExtensionName>

| File | Type | Migrated to | Env |
|---|---|---|---|
| src/Resources/config/services.xml | service definitions | services.php | default |
| ... | | | |

### Verification
| Artifact | default | <env>... |
|---|---|---|
| services | ✅ identical | ... |
| hidden services | ✅ identical | ... |
| parameters | ✅ identical | ... |
| routes | ✅ identical | ... |

Inert diffs: <none | N anonymous inline services (documented, behavior-neutral)>
Tests: <suite, count, result>
Deprecations on cache:clear: <none for this extension>
FEATURE_ALL=major boot: <ok | not checked (reason)>
```

If any verification row is not ✅ and not a documented inert diff, the migration is **not done** — say so explicitly instead of softening the result.
