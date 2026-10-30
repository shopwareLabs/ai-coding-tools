# Patching And Dependency Tooling

Contents: [patches](#cweaganscomposer-patches-for-vendor-patches), [analysis tools](#phpstan-and-php-cs-fixer-compatibility), [Rector](#froshshopware-rector), [FroshTools](#friendsofshopwarefroshtools), [dumps](#mysql-dump-canonical-form), [auditing](#security-audit).

## `cweagans/composer-patches` For Vendor Patches

Do not ship fixes that exist only as edits in `vendor/`; reinstalls/CI will lose them. Use the project's reproducible patch mechanism or a maintained fork. `cweagans/composer-patches` is one option, not a required tool for every project.

Setup:

```bash
composer require cweagans/composer-patches
```

Choose a major compatible with the project's Composer/PHP versions and existing patch config; inspect its workflow before changing dependencies. Create the patch from a temporary checkout of the exact affected package, with paths relative to its package root:

```bash
git diff --relative <known-base> -- path/to/file.php > <project>/custom/patches/short-descriptive-name.patch
```

Declare in root `composer.json`:

```json
{
  "extra": {
    "patches": {
      "shopware/core": {
        "Descriptive name of the fix": "custom/patches/short-descriptive-name.patch"
      }
    }
  }
}
```

Keep patch content and any patch lock metadata in version control. Verify application on a clean install using the installed plugin major's workflow; do not assume editing `extra.patches` re-patches an already-installed package. Remove the patch only after verifying the upstream fix in the resolved target version.

## Backport Policy

Some Shopware fixes ship only in 6.7 (or a specific 6.7.x) and are not backported to 6.6. Example: `shopware/shopware` PR #18205 (language active-filter fix) is only in 6.7.13.0+.

- Check the PR's target branches on GitHub before assuming a 6.6 backport exists.
- If a fix you need is 6.7-only and the project runs 6.6, use `composer-patches` to backport locally.
- Document each patch with the upstream URL and the version where it can be removed.

## PHPStan And PHP-CS-Fixer Compatibility

Select versions compatible with the project's PHP floor, PHPStan extensions/config, and supported Shopware packages. The core tag's dev dependencies provide evidence for core's own analysis setup, not mandatory pins for independent plugins.

At 6.7.15.1 core uses PHPStan 2.x; PHPStan 1→2 changes configuration/rules and extension compatibility. Check the installed lock/config rather than applying one version recipe to every 6.6/6.7 project:

```bash
composer show phpstan/phpstan
composer show phpstan/phpstan-symfony
composer show friendsofphp/php-cs-fixer
```

Verify constraints against the matching target tag's `composer.json` and extension package constraints before an upgrade; the project's lock pins the actual selected versions.

Analyze owned source/tests as configured, not a whole dependency tree by accident. Raise memory when the measured run needs it, for example:

```bash
vendor/bin/phpstan analyse --memory-limit=2G custom/plugins/YourPlugin/src
```

PHPStan extension registration may be explicit in configuration or handled by `phpstan/extension-installer`. Review a Composer plugin's identity/code and project policy before granting `allow-plugins`; a prompt is not a reason to trust it automatically. Do not change unrelated trust settings to make analysis run.

Wire php-cs-fixer through a `cs-fix` composer script. Shopware's current script names are `cs` / `cs-fix`; the older `ecs` / `ecs-fix` names survive only as deprecation shims that print a notice.

```json
{
  "scripts": {
    "cs": "vendor/bin/php-cs-fixer fix --dry-run --diff custom/plugins/YourPlugin/src",
    "cs-fix": "vendor/bin/php-cs-fixer fix -v custom/plugins/YourPlugin/src",
    "phpstan": "vendor/bin/phpstan analyse --memory-limit=2G custom/plugins/YourPlugin/src"
  }
}
```

Per-plugin/per-folder remediation can keep baselines manageable; broader changes are valid when explicitly scoped and coordinated. Preserve the project's scripts/config rather than replacing them with this example wholesale.

## `frosh/shopware-rector`

Rector rule sets can assist Shopware upgrades. Use a compatible installed version, preview the diff, and retain manual review/tests; it is optional automation, not an upgrade completeness check.

The Packagist name is `frosh/shopware-rector` and the namespace is `Frosh\Rector\Set` — `friendsofshopware/shopware-rector` does not exist and `FriendsOfShopware\ShopwareRector\Set` is a class-not-found.

Install:

```bash
composer require --dev frosh/shopware-rector
```

Config:

```php
// rector.php
use Rector\Config\RectorConfig;
use Frosh\Rector\Set\ShopwareSetList;

return static function (RectorConfig $rectorConfig): void {
    $rectorConfig->paths([__DIR__ . '/custom/plugins/YourPlugin/src']);
    $rectorConfig->sets([ShopwareSetList::SHOPWARE_6_7_0]);
};
```

Run: `vendor/bin/rector process`.

What `SHOPWARE_6_7_0` actually contains:

- a v6.7 renaming map
- `SymfonySetList::COMPOSER_BASED`
- `AddEntityNameToEntityExtension`
- `AddLoggerToScheduledTaskConstructorRector`
- `ChangeReturnTypeOfClassMethodRector`

It does **not** automate the payment-handler migration. `InterfaceReplacedWithAbstractClassRector` is a generic configurable rule shipping no `AsyncPaymentHandlerInterface → AbstractPaymentHandler` mapping, and `ThumbnailGenerateSingleToMultiGenerateRector` is a 6.5 rule. Expect to migrate payment handlers by hand.

For 6.5 legacy work still in flight: `MigrateCaptchaAnnotationToRouteRector`, `MigrateLoginRequiredAnnotationToRouteRector`, `MigrateRouteScopeToRouteDefaults`, `ContextMetadataExtensionToStateRector`, `FakerPropertyToMethodCallRector`.

## `FriendsOfShopware/FroshTools`

Optional in-admin observability, when the installed FroshTools/Shopware versions support the relevant feature:

- cache pool status
- Messenger transport queues (Doctrine, Redis, AMQP) with counts
- scheduled task list, last run, and next run
- `var/log/` recent errors
- Elasticsearch indices, aliases, and mapping snapshots
- feature-flag list with current state
- registered webhooks
- state machine dumps
- Fastly integration status

Install: `composer require frosh/tools`. Enable in admin.

Queue-count endpoint (Admin API): `GET /api/_action/frosh-tools/queue/list`.

Check counters against the installed implementation and actual transport, especially across 6.6/6.7 upgrades. Do not promise reliable per-message-type counts solely from the Shopware major/minor. Core CLI queue/task commands provide an alternative when the plugin is absent.

## MySQL Dump Canonical Form

Example for an InnoDB-based database, adjusted for the actual client/server and restore target:

```bash
mysqldump \
  --routines \
  --hex-blob \
  --single-transaction \
  --no-tablespaces \
  <database> > dump.sql
```

Choose flags deliberately:

- Compression may help a remote dump; use the client's supported options (`--compress` is deprecated), not a mandatory local flag.
- `--routines` includes stored procedures/functions when needed; assess events/triggers and privileges too.
- `--hex-blob` writes binary columns safely.
- `--single-transaction` gives a consistent InnoDB snapshot, not consistency for non-transactional tables or concurrent DDL. Coordinate schema changes and validate the restore.
- `--no-tablespaces` omits tablespace statements and can avoid associated privilege requirements; use it only when those objects are not part of the required restore.
- `DEFINER` names affect import privileges and routine/view execution identity. Preserve them when valid, or deliberately map them to approved target accounts after reviewing security semantics. Broad regex stripping can damage SQL or change execution privileges; it is not a universal portability fix.

## Security Audit

Run before every release:

```bash
composer audit
composer show --outdated --direct
```

Triage each advisory against the resolved package, affected range, and reachable use; update or apply a verified mitigation. A Shopware patch may resolve bundled advisories but is not proof that every plugin dependency is covered.

## What Not To Do

- Keep production Composer credentials out of version control; use the project's credential injection. Assess an exposure by actual credential scope and access, not an assumed universal severity or claim that source-read credentials are harmless.
- Review Composer plugin authorization per project; PHPStan can also register extensions explicitly without the installer plugin.
- Do not run Rector against `vendor/`. Scope to `custom/plugins/*/src`.

## Source Anchors

- [Composer Patches definition formats](https://docs.cweagans.net/composer-patches/usage/defining-patches/) and [recommended workflows](https://docs.cweagans.net/composer-patches/usage/recommended-workflows/): match the installed major.
- [Shopware 6.7.15.1 development dependencies/scripts](https://github.com/shopware/shopware/blob/v6.7.15.1/composer.json) and [Composer allow-plugins](https://getcomposer.org/doc/06-config.md#allow-plugins).
- [FroshTools capabilities](https://github.com/FriendsOfShopware/FroshTools#readme) and [shopware-rector](https://github.com/FriendsOfShopware/shopware-rector): inspect the installed tag before relying on a counter or transformation.
- [MySQL 8.4 mysqldump options](https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html) and [stored-object access control](https://dev.mysql.com/doc/refman/8.4/en/stored-objects-security.html): snapshot limits, object privileges, and definers.
