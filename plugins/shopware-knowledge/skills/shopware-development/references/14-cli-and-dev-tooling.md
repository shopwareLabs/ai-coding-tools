# CLI and Dev Tooling

## Console Commands

- Build commands with Symfony console conventions: clear name, description, arguments, options, and help text.
- Keep commands orchestration-only; business logic belongs in services.
- Support `--dry-run`, bounded execution, and confirmation prompts for expensive operations.
- Use `SymfonyStyle` and progress output for long-running work.
- Chunk large operations instead of loading everything into memory.
- Do not spawn internal sync or maintenance work via `Symfony Process` from controllers or services just to run your own commands. Use Messenger, scheduled tasks, or invoke the service directly.

Example:
- a sync command
  Accept IDs optionally, add `--limit` and `--since`, confirm large runs, and report a compact success/failure summary.

```php
// Preferred: command stays orchestration-only and delegates business work
final class SyncCommand extends Command
{
    public function __construct(private readonly SyncService $syncService)
    {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $this->syncService->sync((int) $input->getOption('limit'));

        return Command::SUCCESS;
    }
}
```

## Workers and Transports

- On production, prefer CLI workers over the browser-driven admin worker.
- If CLI workers are configured, disable the admin worker explicitly in `config/packages/shopware.yaml`.
- Consume the transports you actually configured. Keep checkout-relevant async work separate from low-priority transport consumption.
- Use `shopware.messenger.routing_overwrite` when a specific Shopware message should be forced onto `low_priority` or another transport without changing the message class.
- Use process supervision such as `systemd` or `supervisor` for long-running workers instead of relying on manual shells or cron.
- Include failed-message inspection and retry commands in operator guidance when the project depends on Messenger.

Example:

```yaml
# config/packages/shopware.yaml
shopware:
  admin_worker:
    enable_admin_worker: false
  messenger:
    routing_overwrite:
      'Your\Custom\Message\RebuildPartnerSnapshotMessage': low_priority
```

Use **single** backslashes. YAML single-quoted scalars do not process escapes, so `'Your\\Custom\\…'` is the literal two-backslash string and never matches `$message::class`. The override is then silently ignored and the message keeps default routing.

```text
Preferred production worker commands:
- bin/console messenger:consume async low_priority --time-limit=60 --memory-limit=512M
- bin/console messenger:failed:show --transport=failed
- bin/console messenger:failed:retry --transport=failed --force
```

## Static Analysis and Quality Gates

- Use the repo's existing quality toolchain first.
- If the project lacks one, prefer PHPStan with Shopware and Symfony-aware configuration, consistent code style tooling, and targeted tests.
- Keep generated resources, migrations, and build output out of the most aggressive analysis paths when that matches the team's setup.

## Local Development and Debugging

For the `shopware-cli project dev` Docker environment (generated compose, running commands in `web`, rebuilds, local queue/search, production-dump safety), see `28-local-dev-environment.md`.

- Prefer reproducible local environments over machine-specific assumptions.
- Use targeted profiling and debugging for hot paths instead of leaving verbose debug tooling enabled by default.
- Keep build artifacts, coverage reports, and local editor state out of distributable extension packages.

## CI Behavior

- Run the narrowest checks that prove the change.
- For extension packages, include packaging and validation checks before release when the project uses them.
- Keep quality gates incremental so teams can improve rather than disable tooling wholesale.
- Add sanity checks for duplicate handler registration, container compilation, and command wiring when background jobs or scheduled tasks are involved.

```text
Bad: add a new command and scheduled task but only run php -l on one file.
Good: run the targeted test or command check plus one container-boot or wiring sanity check.
```

## 6.7 CLI Additions

### Storefront Vite Dev Server

`composer storefront:dev-server` (6.7.11+) provides HMR without a proxy, and deprecates `composer watch:storefront`.

Both scripts exist only in a `shopware/shopware` source checkout. The `shopware/production` template — what most plugin and agency projects use — defines neither. There, use `shopware-cli project storefront-watch`.

### Sales-Channel URL Rewrite

```bash
bin/console sales-channel:replace:url --from=https://old.example.com --to=https://new.example.com
```

Use in domain-migration runbooks. Source: release notes 6.7.5.

### Cache Debug Commands

- `bin/console cache:watch:delayed` — watch pending delayed invalidations.
- `bin/console cache:clear:delayed` — flush pending invalidations manually.

Full delayed-invalidation semantics in `23-cache-and-http-cache.md`.

### Webhook Transport Consumer

With `WEBHOOKS_REWORK`, include `webhook` in the transport list:

```bash
bin/console messenger:consume webhook async low_priority --time-limit=60 --memory-limit=512M
```

The core default for `shopware.admin_worker.transports` already includes `webhook` (`["webhook", "async", "low_priority"]`). Only if you override that key in `config/packages/shopware.yaml` do you need to prepend it yourself. Rollback path: `bin/console webhook:drain-to-async`. Source: release notes 6.7.12, UPGRADE-6.7.md §6.7.12.0.

### Translation CLI

- `bin/console translation:validate` — renamed from `snippets:validate` in **6.7.3** (UPGRADE-6.7.md §6.7.3.0). The old plural name survives as a deprecated alias until 6.8.
- `bin/console translation:list`
- `bin/console translation:install --locales it-IT,fr-FR` (interactive multi-select)

Full snippet/translation details in `21-internationalization-and-snippets.md`.

Source: release notes 6.7.11, UPGRADE-6.7.md §6.7.2.0.

### Admin Codemod

```bash
composer run admin:code-mods -- --plugin-name MyPlugin --fix -v 6.7
```

Requires the plugin to live under `custom/plugins/`. Adds `// TODO` where manual work is needed.

### Reproducible Builds

Use the project's pinned build environment. If using the `shopware-cli` image, pin its version/digest, verify PHP/Node compatibility, and build the actual target revision; a successful unrelated branch build does not validate the extension.

### Rector And Frosh Tools

- `FriendsOfShopware/shopware-rector` can assist upgrades when compatible with the existing toolchain. Select version-specific rules and review generated diffs; a codemod is not proof of compatibility.
- `FriendsOfShopware/FroshTools` for in-admin queue/cache/task visibility.

Full details in `25-patching-and-dependency-tooling.md`.
