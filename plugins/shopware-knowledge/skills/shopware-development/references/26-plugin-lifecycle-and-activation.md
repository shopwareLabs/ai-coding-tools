# Plugin Lifecycle and Activation

Index: why this class of defect is invisible, lifecycle methods, the version chain, what needs a bump, migrations, `updateDestructive()`, fresh-install vs update, deployment ordering, review prompts.

## Why This Class Of Defect Is Invisible

A change that only executes from a plugin lifecycle hook can merge, deploy, and never run — and fail **only on already-installed systems**. A fresh install runs `install()`, so the code works in every local setup, every CI run, and every new environment. The defect appears only on the shops that already had the plugin.

Fresh-install-only tests miss this; an upgrade-path test can catch it. Review whether lifecycle-only work reaches already-installed shops through the actual deployment/version gate.

## Lifecycle Methods

`Plugin.php` defines exactly seven overridable methods:

`install` · `postInstall` · `update` · `postUpdate` · `activate` · `deactivate` · `uninstall`

- **There is no `postActivate()` method.** `PluginPostActivateEvent` exists as an event, but there is nothing to override.
- `activate()` and `deactivate()` run *before* the state change.
- Fresh install runs `install()` → `postInstall()`. Update runs `update()` → `postUpdate()`. `update()` never runs on a fresh install.
- Inside `PluginLifecycleService::installPlugin()` the exact order is `install()` → plugin migrations → custom-field XML sync → `postInstall()`. Tables a migration creates **do not exist yet in `install()`**. Seed data that needs them (mail templates, flows, default records) in the migration itself or in `postInstall()`. A migration that inserts mail templates therefore also runs on a fresh install.

### What Does Not Run On Activate

- **Migrations do not run.** `activatePlugin()` sets `setAutoMigrate(false)` before calling `activate()`, so `runMigrations()` returns at its guard. Same on deactivate and uninstall.
- **Custom-field XML sync does not run.** It happens only on install and update.

Do not rely on activation to apply schema or field changes.

## The Version Chain

```
composer.json version bump
  → bin/console plugin:refresh        writes upgrade_version when filesystem version > DB version
  → upgrade_version > version         plugin is now considered updatable
  → bin/console plugin:update <Name>  runs update() + migrations + custom-field sync
  → version = upgrade_version, upgrade_version = null, upgraded_at = now()
```

Two details that change how you debug this:

**`PluginLifecycleService::updatePlugin()` has no version guard.** It computes the target as `getUpgradeVersion() ?? getVersion()` and runs everything regardless. The gate is in the callers, and they disagree:

| Caller | Version-gated? |
| --- | --- |
| `plugin:update:all` | Yes — skips when `upgradeVersion === null`, **and skips inactive plugins** |
| Deployment Helper | Yes |
| `bin/console plugin:update <Name>` | **No** — runs on any installed plugin |

So a targeted `plugin:update <Name>` will run `update()` without a bump, while the automated paths will not. Use that to force a sync when debugging; do not rely on it in deployment.

**For Composer-managed plugins in `vendor/`, editing `composer.json` is not enough.** The version comes from the resolved package in `composer.lock` — run `composer update` for the new version to be visible at all.

The same applies to the plugin's **name and description** (`extra.label`, `extra.description`). `PluginFinder` takes Composer-managed plugins from Composer's installed-package data. A local copy in `custom/plugins/` wins, but `custom/static-plugins/` path packages are not local copies. After renaming a static plugin, run `composer update <package>` and then `plugin:refresh` before the admin shows the new label.

## What Needs A Version Bump To Reach Production

Anything invoked from `update()` or `postUpdate()`:

- custom-field installers (both the declarative XML and hand-written installer services)
- entity/config installers and default-config seeding
- data backfills and repair routines
- new migrations, in practice — see below

## Migrations

Migration execution is tracked by class in the `migration` table, with `creation_timestamp` used for ordering/cutoffs and separate `update` / `update_destructive` completion fields, not by plugin version. Automatic execution normally happens through the plugin update flow. Without a bump, version-gated deployment paths skip the plugin and new migrations do not run either.

Manual escape hatch:

```bash
bin/console database:migrate <BundleName> --all
```

## Automatic vs Explicit Destructive Migrations

Automatic plugin install/update runs the non-destructive pass only. Put additive schema and changes required by the deployed code in `update()`; do not require destructive cleanup for the new code to boot.

`PluginLifecycleService::runMigrations()` calls `migrateInPlace()` → `MigrationRuntime::migrate()` → `update()`. The explicit destructive command also supports a plugin bundle identifier, not just core:

```bash
bin/console database:migrate-destructive <BundleName> --all
```

`MigrationDestructiveCommand::collectMigrations()` applies core version-selection rules only for `core`; other identifiers use `loader->collect($identifier)`. `MigrationRuntime::migrateDestructive()` runs `updateDestructive()` for migrations whose `update` completed and whose destructive pass is still pending.

Plan that command explicitly after retention requirements, backup/restore rehearsal, old application/worker shutdown, and rollback compatibility are settled. Do not infer that every merchant/deployment already runs it, or move destructive SQL into `update()` to bypass the decision. Uninstall cleanup is a different lifecycle and must honor `UninstallContext::keepUserData()`; it is not a substitute for deployed schema evolution.

Related trap: `MigrationStep::isInstallation()` reads the `SHOPWARE_INSTALL` env var — the **core** install flag, not "my plugin is installing". Do not branch plugin migration behavior on it.

## Fresh Install vs Update — Behavioral Differences

- `install()` syncs custom fields with `deleteMissingXml: false`; `update()` syncs with `deleteMissingXml: true`. The update path **deletes** field sets and fields the plugin previously declared and has since dropped from the XML.
- A re-install does not run `update()`. `installPlugin()` promotes a pending `upgradeVersion` into `version` first, then runs `install()`.
- Declarative `custom-fields.xml` at `Resources/config/custom-fields.xml` is available from **6.7.13.0**. Before that, use an installer service called from the lifecycle hooks.

## Deployment Ordering

After deploying changed plugin metadata, run `plugin:refresh` before commands that need the refreshed version/discovery state. The following is an ordering sketch, not instructions to run mutually exclusive lifecycle actions on every deploy:

```
plugin:refresh
plugin:install → plugin:update → plugin:deactivate → plugin:remove
theme:compile
cache clear
```

Two gotchas:

- **`plugin:install --activate --refresh` silently skips activation** — it prints "Can not refresh and activate in same request." Run `plugin:refresh` as its own command first.
- **Cache is not cleared automatically.** Without `-c`, lifecycle commands only print a reminder.

## Review Prompts

- Does this change run from a lifecycle hook? If so, is there a version bump in the same diff?
- Is the plugin in `vendor/`? Then is there a `composer.lock` change too, not just `composer.json`?
- Was this tested on an already-installed system, or only on a fresh install?
- Can the new code run before destructive cleanup, and is any destructive pass explicitly authorized and sequenced with retention/rollback decisions?
- Does the diff drop a field from `custom-fields.xml` that the update path will now delete from existing shops?
- Does the deployment run `plugin:refresh` before `plugin:update`?

## Source Anchors

Checked against 6.7.15.1; inspect the installed patch and deployment helper. The automatic/explicit migration distinction also needs preserving on 6.6, but declarative custom-field XML is not available there.

- [Plugin lifecycle hooks](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Plugin.php) and [PluginLifecycleService](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Plugin/PluginLifecycleService.php): install/update ordering, activation auto-migrate guard, `runMigrations`, and custom-field synchronization.
- [MigrationCollection](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Migration/MigrationCollection.php), [MigrationRuntime](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Migration/MigrationRuntime.php), and [MigrationDestructiveCommand](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Migration/Command/MigrationDestructiveCommand.php): tracked identity and explicit plugin destructive pass.
- [UninstallContext::keepUserData](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Plugin/Context/UninstallContext.php) and [MigrationStep::isInstallation](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Framework/Migration/MigrationStep.php).
