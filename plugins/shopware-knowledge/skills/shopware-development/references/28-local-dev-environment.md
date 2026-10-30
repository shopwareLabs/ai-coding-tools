# Local Development With `shopware-cli project` And Docker

Index: how the pieces fit, project config, generated compose and overrides, services and ports, lifecycle commands, running commands in the container, builds and watchers, queue/scheduler/search locally, mail safety with production data, testing pitfalls, migrating from devenv or Lando, agent instructions.

Use this reference only after detecting a `shopware-cli project` **generated Docker** environment (`environments.local.type: docker`, generated compose header, and the actual services). It does not mandate Docker, replacing devenv/Lando, or changing a healthy project runtime. Baseline examples were captured with CLI 0.19.1 and generated Shopware 6.7 compose files; CLI 0.19.5 help/schema reconfirms the configuration/command interfaces, not every historical image/default. Items marked *observed* are diagnostic leads, not source-proven universal behaviour.

Public source: [shopware-cli](https://github.com/shopware/shopware-cli). Check `shopware-cli --version`, the relevant `--help`, `project config-schema`, and the generated compose file for the installed version before applying defaults below. Do not regenerate or start another environment just to inspect it.

## How The Pieces Fit

- **`.config/shopware-project.yml`** describes the project: the Docker environment, the named shop environments, build and deployment settings. `shopware-cli` still reads the legacy `.shopware-project.yml` / `.shopware-project.yaml` when the new path is absent. Create one with `shopware-cli project config init`.
- **`.config/shopware-project.local.yml`** holds per-machine overrides, for example host ports chosen after a port conflict. Keep it out of git.
- **`compose.yaml`** is generated from the project config by `shopware-cli project dev`. Its header says "managed by shopware-cli. Do not edit manually." Keep it out of git and never hand-edit it; the next `dev` run overwrites it.
- **`compose.override.yaml`** is where local changes go. Docker Compose merges it over the generated file. Commit it when the whole team needs the change.
- **`.env.local`** is loaded into the containers as `env_file`. `APP_ENV` and project secrets come from there.

```yaml
# .config/shopware-project.yml (typical)
compatibility_date: "2026-03-01"
docker:
    php:
        version: "8.4"
        # profiler: xdebug   # also blackfire, tideways, pcov, spx
    services:
        database:
            type: mysql      # default: mariadb
            version: "8.4"
environments:
    local:
        type: docker
        url: http://127.0.0.1:8000
        admin_api:
            username: admin
            password: shopware
```

`environments` can also hold `ssh` targets; `-e <name>` picks one for any `project` command. With no `-e`, commands target `environments.local`.

## Services And Ports

The captured generated stack used `ghcr.io/shopware/docker-dev:php<version>-node24-caddy` for `web` and mounted the project at `/var/www/html`. The table describes that generated setup, not ports/images promised for every CLI version or project:

| Service | Purpose | Default host port |
| --- | --- | --- |
| `web` | Caddy + PHP-FPM, Node 24 | 8000 shop, 8080 alt, 9998/9999 storefront watcher, 5173/5773 admin watcher |
| `database` | MariaDB 11.8 by default, or MySQL 8.4 | random port on `127.0.0.1` |
| `adminer` | DB UI, server `database`, `root` / `root` | 9080 |
| `mailer` | Mailpit | 8025 UI, 1025 SMTP |
| `search` | OpenSearch 2 (when present) | `127.0.0.1:9200` |
| `queue` | LavinMQ or RabbitMQ (when present) | — |

The stack is not the same for every project. `search` appears when `shopware/elasticsearch` was installed, and `queue` appeared with `symfony/amqp-messenger`. A project with `symfony/redis-messenger` also gets `cache` (Redis), `worker`, and `scheduler` services. Read the generated `compose.yaml` before assuming a worker or search engine exists.

Port overrides go in `docker.services.<service>.ports` (`false` disables publishing). When port 8000 is taken by another project, `dev start --on-port-conflict random` picks free ports and saves them to the local config. Alternatively, `shopware-cli project proxy setup` (once per machine) and `proxy up` route each project through a shared Traefik proxy at `https://<name>.shopware.local`, so several shops run side by side.

## Lifecycle

| Command | What it does |
| --- | --- |
| `shopware-cli project dev` | Start containers; in a terminal it also opens the TUI dashboard |
| `shopware-cli project dev start` | Start in the background (use this from scripts and agents) |
| `shopware-cli project dev status` | Exit code 0 when up, 1 when down |
| `shopware-cli project dev stop` | Stop containers, keep data |
| `shopware-cli project dev stop --remove-data` | Stop and **delete all named volumes declared by compose**; only after explicit deletion authorization and a verified backup of needed data |
| `shopware-cli project dev install` | Start, install Shopware without prompts (via the deployment helper), save admin credentials to the project config; skipped when already installed. `--locale`, `--currency`, `--admin-username`, `--admin-password` |

## Running Commands

For this detected Docker environment, use its container executor to match PHP, Composer, Node, extensions, and environment variables. The host may also have valid runtimes; this is not a blanket host-PHP ban.

- `shopware-cli project console <command>` and `shopware-cli project composer <command>` run through the project's executor, which for `type: docker` is the `web` container. They fail with `service "web" is not running` when the stack is down, even for `--help`.
- For anything else: `docker compose exec -T web <command>`. Use `-T` from agents and scripts, which have no TTY.
- Avoid mixing host/container PHP against the same cache when versions, paths, permissions, or environment differ: this can produce incompatible or confusing caches. Use host PHP when the project deliberately configures it and isolation/compatibility are understood; follow that project's runtime instructions instead of migrating it automatically.

| Task | Command |
| --- | --- |
| SQL | `shopware-cli project sql "SELECT …"` (`--format json`, `--file`, or stdin) |
| DB dump | `shopware-cli project dump --anonymize --clean` (`--limit order=100` keeps the newest rows and their dependants) |
| Logs | `shopware-cli project logs -f` (`--list` for files) |
| Admin API | `shopware-cli project admin-api GET /api/_info/version` (uses the configured credentials) |
| Cache | `shopware-cli project clear-cache` |
| Queue | `shopware-cli project worker async:2,low_priority:1` |
| Diagnose config | `shopware-cli project doctor` |

## Builds And Watchers

Pick the cheapest rebuild for the change:

| Changed | Rebuild |
| --- | --- |
| Theme SCSS only | `shopware-cli project console theme:compile` |
| Twig | Usually a reload in dev; `clear-cache` when a new override file isn't picked up |
| Storefront JS | `shopware-cli project storefront-build` |
| Admin JS/Twig/snippets | `shopware-cli project admin-build` |
| `theme.json` fields | `console theme:refresh`, then `clear-cache` |
| One extension's assets | `shopware-cli extension build <path>` (inside the container if the host has no Node) |
| PHP code run by a queue or scheduled task | `clear-cache` when wiring changed, then restart the workers (see below) |

- Watchers: `shopware-cli project storefront-watch` and `admin-watch`. Narrow them with `--only-extensions`, `--only-custom-static-extensions`, or `--skip-extensions`. `storefront-watch --sales-channel <id>` dumps the theme for one channel.
- `bin/watch-storefront.sh` prompts for a theme and domain and fails without a TTY (*observed*). Use `project storefront-watch --sales-channel` from agents.
- Stop any watcher you started when you are done. They keep ports 9998/9999/5173 busy.
- Running `shopware-cli extension build` in the container was observed to leave an unexpected project-root `src/Storefront/` folder; the cause was not source-traced. Inspect the build target and Git diff; remove only verified disposable output you created. Never delete an existing source directory by name alone.

## Git Worktrees

The captured generated stack mounts the directory that holds `compose.yaml`. A worktree outside that bind mount is not visible to that running container; check `volumes` before claiming a container build tests worktree edits. Use a deliberately mounted checkout or a separately authorized stack from the worktree on non-conflicting ports. Do not copy over shared-checkout changes, merge work, or start another stack automatically just to test; explain the runtime/source mismatch first.

## Queue, Scheduled Tasks, And Search

- **Messages need a consumer.** Indexing, mails, and many plugin jobs are queued. Locally they run only if there is a `worker` service, or the admin worker is enabled and an admin tab is open, or you run `project worker` / `console messenger:consume`. With `enable_admin_worker: false` and no worker service, imports finish but products never appear in the storefront.
- **Scheduled tasks need a scheduler.** Without a `scheduler` service, run `console scheduled-task:run` (or a single task with `scheduled-task:run-single`) by hand. Otherwise a cleanup task "never runs" locally even though the code is fine.
- **Workers don't pick up code changes.** `messenger:consume` and `scheduled-task:run` boot the kernel once and keep the compiled container and loaded classes in memory until they exit. After changing a handler, a subscriber, service wiring, config, or plugin state, the running worker keeps executing the old code, so a fix looks like it "didn't work". Restart every long-running consumer after the change and after `clear-cache`:
  - generated services: `docker compose restart worker scheduler` (only the ones the stack has)
  - `shopware-cli project worker` or a hand-started `messenger:consume`: stop it and start it again

  The generated `worker` and `scheduler` run with `--time-limit=300` and `restart: unless-stopped`, so they do restart by themselves, but only up to five minutes later. Don't rely on that while testing. The admin worker runs inside admin requests, so it uses the current code.
- **OpenSearch is on when the `search` service exists.** The generated compose sets `SHOPWARE_ES_ENABLED=1` and `SHOPWARE_ES_INDEXING_ENABLED=1`. A fresh or restored database has no index, so listings and search come back empty or fail. Build it with `console es:index --no-queue` (or consume the queue), and check `es:status`.
- **To run without OpenSearch**, disable it in `compose.override.yaml` for every service that boots the kernel, not only `web`:

```yaml
services:
    web:
        environment:
            SHOPWARE_ES_ENABLED: "0"
            SHOPWARE_ES_INDEXING_ENABLED: "0"
    worker:            # only if the generated stack has it
        environment:
            SHOPWARE_ES_ENABLED: "0"
            SHOPWARE_ES_INDEXING_ENABLED: "0"
    scheduler:         # only if the generated stack has it
        environment:
            SHOPWARE_ES_ENABLED: "0"
            SHOPWARE_ES_INDEXING_ENABLED: "0"
```

Decide this per project and match production. Code that works with MySQL search can return 500s on every listing when OpenSearch is on.

## Production Data Safety

A local database restored from production holds real customer addresses and production settings.

- **`MAILER_DSN` points at Mailpit, but the database can override it.** `MailerTransportLoader` uses the admin's mailer settings whenever `core.mailerSettings.emailAgent` is set in `system_config`, and only falls back to `MAILER_DSN` when it is empty. A production copy can therefore send real e-mails through the production SMTP server. Check before triggering any mail:

```bash
shopware-cli project sql "SELECT configuration_value FROM system_config WHERE configuration_key = 'core.mailerSettings.emailAgent'"
```

Check and safely override all effective SMTP settings in the **local copy**, then verify delivery to Mailpit before any mail-producing workflow; setting `MAILER_DSN` alone is not that verification. Source: [v6.7.15.1 MailerTransportLoader::fromString/create](https://github.com/shopware/shopware/blob/v6.7.15.1/src/Core/Content/Mail/Transport/MailerTransportLoader.php).

- Prefer `project dump --anonymize` when creating the copy. The `dump.rewrite` config can rewrite single columns.
- A production copy also carries `core.store.licenseHost` and the Store shop secret. Logging into the Shopware Account from a copy that shares the license host can rotate the secret and log production out of the Store.
- Missing media: a production database references files that aren't on disk. `shopware-cli project image-proxy --url https://<prod-host>` serves local files and fetches missing ones from upstream. It writes `config/packages/zzz-sw-cli-image-proxy.yml` unless you pass `--skip-config`; keep that file out of commits.

## Testing Pitfalls

- **Secure-cookie/session loss on local HTTP** (*observed*): inspect `Set-Cookie`, curl/browser version, scheme, domain/path, redirects, and trusted-proxy configuration before blaming the cookie jar. Prefer correct local HTTPS and consistent hostnames; inspect cookie-jar diagnostics. A manually supplied `Cookie:` header is at most a controlled local diagnostic that bypasses normal client policy, not a universal Secure-cookie fix or browser-parity test. Never send real session credentials to an untrusted/non-TLS endpoint.
- **Dev cache behaviour differs** (*observed*): verify cache-key/invalidation changes in a controlled production-like environment with the actual HTTP-cache/proxy configuration. `APP_ENV=prod` alone does not prove the proxy/cache path is active; isolate its cache/runtime and restore local settings afterwards.
- **Proxy hostnames split sessions** (*observed*): an admin session on the main host isn't valid on the `admin-watch` subdomain.
- **Snippets can be overridden in the database** (Settings > Snippets). Check the `snippet` table before assuming a file value is what renders.
- **Test data stays.** Customers, orders, layouts, and Mailpit messages created while testing persist in the volume. List what you created; remove only identified disposable test data when authorized, never unrelated/shared records.

## Migrating From devenv

This is an **opt-in migration**, not a troubleshooting prerequisite. Keep a working devenv/Lando setup unless the user authorized replacing it. The concrete steps below are for devenv; a Lando migration needs its own runtime/storage inventory and backup plan.

1. Run `shopware-cli project config init` and set `docker.php.version` and the database type/version to match production.
2. Gitignore `/compose.yaml` and `/.config/shopware-project.local.yml`. **Dump the devenv database first** (see below), protect the dump, and verify a restore before retiring anything. Keep `devenv.nix`, `devenv.yaml`, `devenv.lock`, `.envrc`, and `.devenv*` until the replacement works and removal is explicitly authorized; inventory shared direnv configuration rather than deleting it wholesale.
3. Start with `shopware-cli project dev start`. Import the old database as described below, or run `dev install` for a fresh shop. `dev install` runs `vendor/bin/shopware-deployment-helper`, so `shopware/deployment-helper` must be in `composer.json`; without it the install stops at `system:install` (*observed*).
4. Compare the generated services with what the old environment ran. The generated stack may enable OpenSearch where the old one didn't; decide explicitly and use `compose.override.yaml`.
5. **Update the README and `CLAUDE.md` / `AGENTS.md` in the same change.** Stale devenv instructions send agents to commands that no longer exist (*observed* repeatedly). Remove any secrets an old README copied out of `.env`, and rotate them.

### Migrating The Database

devenv keeps its MySQL data inside the project's `.devenv/` state directory, and the new stack starts with an empty database volume. Nothing carries over by itself, and deleting `.devenv*` before dumping loses the local data for good.

1. **Dump while devenv still runs.** Start it (`devenv up`) and dump with the connection flags, which override the project environment:

   ```bash
   shopware-cli project dump --host 127.0.0.1 --port 3306 --username root --password=root --database shopware --output devenv.sql
   ```

   Take the credentials from the old `DATABASE_URL` in `.env` / `.env.local`. Plain `mysqldump` inside `devenv shell` works too. Stop devenv afterwards: it also listens on port 3306 and often 8000.
2. **Match the database engine before importing.** The captured generated stack defaults to MariaDB 11.8; inspect the actual image. If devenv or production runs MySQL, set `docker.services.database.type: mysql` and the matching `version` *before* the first `dev start`. A MySQL 8 dump can use collations such as `utf8mb4_0900_ai_ci` that MariaDB may reject. Do not repoint a different engine at an existing data volume. Prefer a separate volume/backup-and-restore migration; `dev stop --remove-data` deletes all declared named volumes and requires explicit authorization plus verified backups, not an automatic engine-switch step.
3. **Import into the running stack:**

   ```bash
   shopware-cli project sql --file devenv.sql
   ```

   For a compressed or very large dump, stream it into the database container instead: `gunzip -c devenv.sql.gz | docker compose exec -T database mariadb -uroot -proot shopware`. Use `mysql` instead of `mariadb` when the stack runs MySQL. The generated MariaDB service ships `mariadb-*` client names; its own healthcheck calls `mariadb-admin`. The generated database is `shopware` with `root` / `root`.
4. **Leave `DATABASE_URL` alone.** The compose file sets `DATABASE_URL` as a container environment variable, and Symfony's Dotenv never overrides real environment variables. A devenv value left in `.env.local` is ignored inside the containers, but it still confuses anyone running host PHP, so update or remove it.
5. **Fix the domain if the URL changed.** If the shop no longer runs at the URL devenv used (another port, or a `*.shopware.local` proxy host), update the sales channel domain: `console sales-channel:update:domain <host>` (with `--previous-domain` to limit it), or `console sales-channel:replace:url --from=… --to=…`.
6. **Rebuild what the database doesn't hold:**

   ```bash
   shopware-cli project console plugin:refresh
   shopware-cli project console cache:clear
   shopware-cli project console theme:compile
   shopware-cli project console dal:refresh:index --use-queue
   ```

   With OpenSearch enabled, also run `console es:index --no-queue`. Make sure a worker consumes the queued indexing messages (see "Queue, Scheduled Tasks, And Search").
7. **Align the admin login.** The imported database keeps the old admin users. Put working credentials in `environments.local.admin_api` in the project config, or reset one with `console user:change-password admin`. Otherwise `project admin-api` and `clear-cache` via the API fail.
8. **Media stays on disk.** Files in `public/media`, `public/thumbnail`, and `files/` are part of the mounted project directory and keep working. If devenv pointed media at another location or remote storage, copy it over or use `project image-proxy`.
9. **Check mail settings.** If the devenv database came from production, the "Production Data Safety" rules apply before anything sends mail.

## Agent Instructions For The Project

A project `CLAUDE.md` saves most of the rediscovery. Include:

- how to start, check, and stop the stack (`dev start`, `dev status`, `dev stop`), and that `compose.yaml` is generated
- which PHP/Node runtime owns this project and the exact exec form for the detected Docker stack (`docker compose exec -T web …` or `shopware-cli project console …`), without claiming host runtimes cannot exist
- the URLs and logins for storefront, admin, Mailpit, Adminer
- the cheapest-rebuild table above, adapted to the project's theme paths
- whether a worker, scheduler, and OpenSearch run locally
- where theme Twig/SCSS/JS live and which core path they mirror
- the local testing pitfalls that apply (cookies, GeoIP, HTTP cache)
