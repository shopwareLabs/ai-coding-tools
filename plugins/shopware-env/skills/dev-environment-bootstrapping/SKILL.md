---
name: dev-environment-bootstrapping
version: 1.1.0
model: sonnet
description: >-
  Bootstrap, set up, create, or initialize a Shopware development environment.
  Orchestrates the full first-run flow: detects the current state of a Shopware
  checkout, proposes a numbered action plan, confirms with the user, then executes
  dependency installation, database setup, plugin activation, and frontend builds
  via the lifecycle-tooling MCP server. Use when the user asks to bootstrap or
  set up a new Shopware dev environment, clone and install Shopware, initialize
  a plugin project, or get a fresh Shopware instance running.
allowed-tools: >-
  AskUserQuestion, Bash, Read, Glob, Write,
  mcp__plugin_shopware-env_lifecycle-tooling__install_dependencies,
  mcp__plugin_shopware-env_lifecycle-tooling__database_install,
  mcp__plugin_shopware-env_lifecycle-tooling__database_reset,
  mcp__plugin_shopware-env_lifecycle-tooling__testdb_prepare,
  mcp__plugin_shopware-env_lifecycle-tooling__frontend_build_admin,
  mcp__plugin_shopware-env_lifecycle-tooling__frontend_build_storefront,
  mcp__plugin_shopware-env_lifecycle-tooling__plugin_create,
  mcp__plugin_shopware-env_lifecycle-tooling__plugin_setup
---

# Shopware Dev Environment Bootstrapping

Orchestrate the full first-run Shopware development environment setup. Detects current state, presents a numbered plan, confirms with the user, executes the plan via lifecycle MCP tools, then stops with a handoff message.

**Output scope:** Executes MCP lifecycle tools and Bash clone commands. Writes no config files. Invokes no dev-tooling skills. Stops after printing the handoff message.

## Phase 1 — Detection (no user interaction)

Silently probe the working directory to determine what already exists and what is missing. Do not prompt the user during this phase.

### Shopware Checkout State

1. Check `composer.json` exists and contains `shopware/core` as a dependency — determines whether this is a Shopware project root.
2. Check `src/Core/` directory exists — confirms a full Shopware source checkout vs. a vendor install.
3. Check `.env` file exists and contains `DATABASE_URL` — determines if the environment has been configured.
4. Check `var/cache/` directory exists — rough indicator that `bin/console cache:clear` has run at least once.

### Environment Clues

Check for these files/directories to infer the intended execution environment:

- `docker-compose.yml` or `docker-compose.yaml` — Docker Compose environment
- `.ddev/config.yaml` — DDEV environment
- `Vagrantfile` — Vagrant environment
- None of the above — native environment assumed

### Plugin State

- Check `custom/plugins/` directory exists and list any subdirectories — these are already-present plugins.
- Determine whether the user's stated intent (from their message) involves a specific plugin name.

### Database State

- `.env` with `DATABASE_URL` present → database may be configured
- `var/cache/` present → system:install has likely run before

### Dev Tooling Config

- Check for `.mcp-php-tooling.json` in the project root — if present, environment args are already locked in and will be used by the lifecycle tools automatically.
- Check for `.mcp-php-tooling.json` in `.claude/` — same.

### JavaScript Dependencies

- Check `src/Administration/Resources/app/administration/node_modules/` exists — Admin JS deps installed.
- Check `src/Storefront/Resources/app/storefront/node_modules/` exists — Storefront JS deps installed.

## Phase 2 — Present Findings

Output a structured text summary to the user before asking anything. Format it as plain text sections, not a bulleted list of checkmarks:

```
## Environment Assessment

**Shopware checkout:** [full checkout detected at <cwd> / no shopware/core found]
**Runtime environment:** [docker-compose (docker-compose.yml detected) / ddev (.ddev/ detected) / native]
**Database:** [configured (.env with DATABASE_URL present) / not configured]
**Plugins present:** [none / SwagCommercial, MyPlugin, ...]
**Admin JS deps:** [installed / missing (no node_modules)]
**Storefront JS deps:** [installed / missing (no node_modules)]
**Dev tooling config:** [.mcp-php-tooling.json found — environment settings locked / not found — will use detected environment]

## Proposed Plan

1. [Clone shopware/shopware into <cwd> — if no checkout detected]
2. [Clone <plugin-repo> into custom/plugins/<Name>/ — if user specified a plugin repo]
3. Install dependencies (composer install + npm for admin + npm for storefront)
4. Install database (system:install --drop-database --basic-setup)
5. [Create plugin skeleton — plugin_create(<Name>, <Namespace>) — if user asked for a new plugin]
6. [Activate and install plugin — plugin_setup(<Name>) — if existing plugin present]
7. Build administration frontend
8. Build storefront frontend
```

Omit any step that is already satisfied by the detection results. If everything is already set up, say so explicitly and propose no-op plan (nothing to do).

## Phase 3 — Confirm via AskUserQuestion

Ask a single confirmation question. Use a multiSelect question with an Other text field:

```
question: "Does this look correct? Select any steps to skip, or use the text field to correct my assessment (e.g. wrong environment, different plugin repo, plugin namespace)."
options:
  - label: "Skip frontend builds"
    description: "Admin and storefront JS will not be built (faster setup, build later when needed)"
  - label: "Skip database setup"
    description: "Database will not be installed (use if you have an existing database to preserve)"
  - label: "Skip plugin activation"
    description: "Plugin will be discovered but not activated or installed"
```

Parse the response:

- Selected skip options → remove corresponding steps from the plan.
- Other text field content → re-read the correction and adjust tool arguments (e.g. different environment, container service name, plugin name, plugin namespace).

## Phase 4 — Execute Confirmed Plan

Execute the plan steps sequentially. Do not parallelize — each step may depend on the previous one completing successfully.

### Determining Environment Args

If `.mcp-php-tooling.json` was found during detection, omit `environment`, `docker_service`, and `compose_file` from all MCP tool calls — the config file takes precedence and the tools will read it directly.

If no config file was found, pass the detected environment as args:
- `environment`: `native` | `docker-compose` | `ddev` | `vagrant`
- `docker_service`: the service name (from `docker-compose.yml` inspection or user correction)
- `compose_file`: path to compose file if non-default

### Step Execution

**Git clone (Bash only — not in MCP scope)**

If no Shopware checkout was detected and a clone is needed:

```bash
git clone https://github.com/shopware/shopware.git <target-dir>
```

If the user specified a plugin repository to clone, clone it into `custom/plugins/<Name>/` after the Shopware clone:

```bash
git clone <plugin-repo-url> custom/plugins/<PluginName>/
```

If a git clone fails, report the error clearly, suggest the user clone manually, and continue with the remaining plan steps. Do not abort the entire plan on a clone failure.

**install_dependencies**

Call for first-run setup with all three flags true, unless the user's Other text field correction indicated otherwise:

```
mcp__plugin_shopware-env_lifecycle-tooling__install_dependencies(
  environment: <detected-or-user-corrected>,
  docker_service: <if applicable>,
  compose_file: <if applicable>,
  composer: true,
  administration: true,
  storefront: true
)
```

If the user only corrected the environment type (not the install scope), keep all three flags true.

**database_install**

Call unless "Skip database setup" was selected:

```
mcp__plugin_shopware-env_lifecycle-tooling__database_install(
  environment: <detected-or-user-corrected>,
  docker_service: <if applicable>,
  compose_file: <if applicable>
)
```

**plugin_create** (new plugin user story only)

Call AFTER `database_install` — plugin_create requires a working database. Never reorder.

```
mcp__plugin_shopware-env_lifecycle-tooling__plugin_create(
  plugin_name: <Name>,
  plugin_namespace: <Namespace>,
  environment: <detected-or-user-corrected>,
  docker_service: <if applicable>,
  compose_file: <if applicable>
)
```

If `plugin_name` or `plugin_namespace` were not determined during detection (e.g. the user mentioned creating a plugin but didn't specify them), ask via AskUserQuestion before calling this tool.

**plugin_setup** (existing plugin user story only)

Call unless "Skip plugin activation" was selected. For each plugin in `custom/plugins/`:

```
mcp__plugin_shopware-env_lifecycle-tooling__plugin_setup(
  plugin_name: <Name>,
  environment: <detected-or-user-corrected>,
  docker_service: <if applicable>,
  compose_file: <if applicable>
)
```

**frontend_build_admin**

Call unless "Skip frontend builds" was selected:

```
mcp__plugin_shopware-env_lifecycle-tooling__frontend_build_admin(
  environment: <detected-or-user-corrected>,
  docker_service: <if applicable>,
  compose_file: <if applicable>
)
```

**frontend_build_storefront**

Call unless "Skip frontend builds" was selected:

```
mcp__plugin_shopware-env_lifecycle-tooling__frontend_build_storefront(
  environment: <detected-or-user-corrected>,
  docker_service: <if applicable>,
  compose_file: <if applicable>
)
```

### Mid-Execution Failure Handling

If any MCP tool call fails:

1. Report which step failed and what error was returned.
2. List which preceding steps succeeded.
3. Suggest a manual recovery command if one is obvious (e.g. "run `bin/console system:install --drop-database --basic-setup` manually").
4. Continue executing any remaining steps that do not depend on the failed step.

Do not abort the entire plan on a single tool failure unless the failure blocks all remaining steps (e.g. `install_dependencies` fails — `database_install` would then also fail).

### User Story Routing

Three user stories drive which steps are included:

**Core contributor (no plugin work):**
Clone shopware/shopware (if needed) → install_dependencies → database_install → frontend builds

**Existing plugin development:**
Clone shopware/shopware (if needed) → clone plugin repo into `custom/plugins/<Name>/` → install_dependencies → database_install → plugin_setup(plugin_name) → frontend builds

**New plugin creation:**
Clone shopware/shopware (if needed) → install_dependencies → database_install → plugin_create(name, namespace) → frontend builds

Note: plugin_setup is called for existing plugins only. plugin_create is called for new plugins only. Never call both for the same plugin.

### Already-Set-Up Detection

If Phase 1 detection found all of the following:
- Full Shopware checkout present
- Database configured (.env with DATABASE_URL)
- JS deps installed for both admin and storefront
- No plugins missing setup

Then present a minimal plan in Phase 2 ("Everything appears to be set up. Nothing to do.") and after user confirmation in Phase 3, skip Phase 4 entirely. Print the Phase 5 handoff message immediately.

## Phase 5 — Hard Stop + Handoff

After the last execution step completes (or immediately after Phase 3 if nothing needed to be done), print exactly this message and STOP:

```
Development environment is ready. To get the full dev tooling experience, install these plugins:

/plugin install dev-tooling@shopware-ai-coding-tools
/plugin install gh-tooling@shopware-ai-coding-tools

After installing, run /reload-plugins and ask me to continue —
I'll walk you through configuring the dev tools for this environment.
```

Do NOT invoke any follow-up tools after this message. Do NOT call dev-tooling's `setting-up` skill or any other skill. Do NOT run any additional Bash commands. The handoff message is the final output of this skill.

## Rules

- Ask one question at a time via AskUserQuestion. Phase 3 is the single confirmation point — do not ask additional questions except when `plugin_name` or `plugin_namespace` are genuinely unknown.
- Never call `plugin_create` before `database_install`. The database must exist first.
- Git clone operations are Bash-only. Never attempt to clone via MCP tools.
- If `.mcp-php-tooling.json` is present, omit environment args from all MCP tool calls. The config file wins.
- Never call both `plugin_create` and `plugin_setup` for the same plugin in the same run.
- Skip frontend builds only when the user explicitly selected that skip option.
- Report failures with context (what succeeded, what failed, manual recovery hint) but continue remaining independent steps.
- Stop after the handoff message. No exceptions.
