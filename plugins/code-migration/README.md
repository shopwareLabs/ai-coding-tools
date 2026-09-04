# code-migration

Technical migration skills for Shopware extension developers. Each skill covers one mechanical, verifiable migration; `xml-config-migrating` is the first.

## 🧩 Skills

### xml-config-migrating

Migrates a plugin's or app-server extension's XML configuration to PHP before Shopware 6.8 removes XML support (Symfony 8 drops the XML loaders entirely).

**Covers:** same-basename replacements: `services.xml` → `services.php`, `services_test.xml` → `services_test.php`, `routes.xml` → `routes.php`, and so on; `packages/**/*.xml` → same-basename YAML or PHP. Shopware-specific XML formats (`config.xml`, `custom-fields.xml`, `flow.xml`, `rule-conditions.xml`, app manifests) are out of scope — they stay XML.

> [!NOTE]
> A plugin's `packages/**` config is loaded by nothing — only Shopware's own core bundles call the loader that reads it — so neither the dump diff nor the deprecation gate can observe those files, and the skill reports a packages row as migrated with manual review instead of verified.

**Method:** strict 1:1 translation (no autowiring, no renames, no reordering), with correctness proven rather than assumed. Before the first edit and again after the last one, Claude clears the cache and takes four dumps per environment — the container plain, with `--show-hidden`, and with `--parameters`, plus the router — each as `debug:container` / `debug:router` with `--format=json`, and writes each one straight to a file under `var/xml-migration/` instead of into the conversation. The environment is selected on the console command itself (`--env=<env>` in a shell), never with an `APP_ENV` variable in front of it: the command's own arguments survive the docker, ddev, or vagrant wrapper, while a variable in front of the command does not. Three bundled scripts carry the deterministic parts around those dumps:

| Script                   | Does                                                                                                                                      |
|--------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `inventory.sh`           | Lists the in-scope XML files as TSV — path, type (services/routes/packages), and the environments each one applies to                      |
| `verify-dumps.sh`        | Checks the dump set is complete and each dump records the environment its filename claims, normalizes each dump, diffs every before/after pair, classifies inert diffs, checks for surviving XML/PHP pairs and leftover `.xml` references, prints the table |
| `check-class-imports.sh` | Fails when a migrated PHP file references a class it never imported                                                                       |

A file whose basename and location match no rule is not an error for `inventory.sh`: it reads the file's own Symfony namespace and classifies a DI or routing document accordingly, while an XML carrying neither is announced on stderr and skipped so the rest of the inventory survives. `verify-dumps.sh` reads `kernel.environment` out of each environment's parameter dumps and refuses a set whose before and after disagree, whose recorded environment contradicts the env named in the filename, or whose `default` row literally records `default` — the tell that `default` was passed as a literal environment name, a nonexistent environment the kernel boots without loading any env-specific config.

The verdict in the report comes from `verify-dumps.sh`, not from reading a diff. Anonymous inline services are the one diff shape the script classifies as inert: the XML loader hoists them to hidden `.N_Class~hash` services, `inline_service()` keeps them inline.

> [!IMPORTANT]
> The `before-*` dumps are the baseline for the whole migration. Once it starts they are never re-taken — a diff is fixed in the PHP file, not by re-recording what "before" looked like.

**Triggers:** "migrate services.xml", "convert my plugin config to PHP", "prepare my plugin for Shopware 6.8", or the deprecation message `The XML configuration file "..." is deprecated and will not be loaded in v6.8.0.0` appearing in logs or CI.

## 📦 Installation

```bash
/plugin install code-migration@shopware-ai-coding-tools
```

## 📌 Requirements

- A Shopware 6.6+ installation with the extension installed and active, and a working `bin/console`.
- `jq`, used by `verify-dumps.sh` to normalize the dumps before diffing them.

## 🧪 Tests

The bundled scripts are covered by BATS tests in `plugin-tests/code-migration/`. Run them from the repository root:

```bash
.bats/bats-core/bin/bats plugin-tests/code-migration/*.bats
```
