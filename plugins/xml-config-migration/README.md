# xml-config-migration

Migration skills for Shopware extension developers.

## Skills

### xml-config-migrating

Migrates a plugin's or app-server extension's XML configuration to PHP before Shopware 6.8 removes XML support (Symfony 8 drops the XML loaders entirely).

**Covers:** `services.xml` / `services_test.xml` → `services.php`, `routes*.xml` → `routes.php`, `packages/**/*.xml` → YAML or PHP. Shopware-specific XML formats (`config.xml`, `custom-fields.xml`, `flow.xml`, app manifests) are explicitly out of scope — they stay XML.

**Method:** strict 1:1 translation (no autowiring, no renames, no reordering), with correctness *proven* rather than assumed:

1. Snapshot `debug:container` (plain + `--show-hidden` + `--parameters`) and `debug:router` as normalized JSON before any edit, per affected environment.
2. Migrate one XML file to one PHP file with the same basename; delete the XML in the same change (the loader globs both formats and XML silently wins on collision).
3. Re-snapshot and diff — every artifact must be identical, with anonymous inline services as the only documented inert exception.
4. Run the extension's test suite and confirm the Shopware deprecation is gone (optionally under `FEATURE_ALL=major`, where leftover XML throws).
5. Emit a verification report table so the result is unambiguous.

**Triggers:** "migrate services.xml", "convert my plugin config to PHP", "prepare my plugin for Shopware 6.8", or the deprecation message `The XML configuration file "..." is deprecated and will not be loaded in v6.8.0.0` appearing in logs or CI.

## Installation

```bash
/plugin install xml-config-migration@shopware-ai-coding-tools
```

## Requirements

- A Shopware 6.6+ installation with the extension installed and active, and a working `bin/console`.
- `jq` for dump normalization.
