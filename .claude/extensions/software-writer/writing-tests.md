## Named-value assignments

- `project.stacks` =
  | Stack | Where | Toolchain |
  |---|---|---|
  | bash | `plugins/*/hooks/scripts/`, `plugins/*/mcp-server-*/`, `plugins/*/lsp-server-*/`, `plugins/*/shared/`, `templates/`, `.github/scripts/`, `plugin-tests/**/*.bats` | bash 4+ for MCP servers, bash 3.2+ for `.github/scripts/`; `jq`; ShellCheck v0.11.0 in CI |
  | python (root project) | `plugins/dev-tooling/shared/lsp_proxy.py`, `plugin-tests/dev-tooling/lsp_proxy/` | 3.12, `uv`; ruff line-length 100 selecting `E W F I B UP SIM RUF`; mypy `strict`, scoped by `files` to exactly these two paths and nothing else |
  | python (`agent-skills-export/`) | `agent-skills-export/src/`, `agent-skills-export/tests/` | A separate `uv` project with its own lockfile, its own ruff (adds `C4 ARG PTH`, **ignores `E501`**), and its own mypy `strict`. Root ruff `extend-exclude`s it and root mypy does not see it — never apply the root project's rules here. |

  No other stack is in play. PHP, TypeScript, and Twig appear only as the *subjects* the plugins operate on in other repositories, never as source here.
- `tests.frameworks` =
  | Stack | Framework | Test files | Run |
  |---|---|---|---|
  | bash | BATS — bats-core 1.13.0, bats-support, bats-assert 2.2.4; every file declares `bats_require_minimum_version 1.11.0` | `plugin-tests/<plugin>/*.bats` | `./.github/scripts/setup-bats.sh` once, then `.bats/bats-core/bin/bats plugin-tests/**/*.bats`; CI runs `bats --timing -r plugin-tests/` |
  | python | pytest with `asyncio_mode = "auto"` and `pytest-subprocess` | `plugin-tests/dev-tooling/lsp_proxy/test_*.py` | `uv run pytest plugin-tests/dev-tooling/lsp_proxy/` |
  | python | pytest, a separate uv project with its own dependency set | `agent-skills-export/tests/test_*.py` | `make test` (`uv run --project agent-skills-export pytest agent-skills-export/tests/`) |

  Select per file being edited. A `.bats` file is bash regardless of what language the script under test drives.
- `tests.fixture_sources` =
  - `plugin-tests/test_helper/common_setup.bash` — `run_hook`, `assert_hook_blocks`, and `REPO_ROOT` resolution; loads bats-support and bats-assert. Every `.bats` file reaches it through its plugin helper.
  - `plugin-tests/<plugin>/test_helper/common_setup.bash` — sets `SCRIPTS_DIR` for that plugin and holds its own builders, such as dev-tooling's `setup_config` and `setup_php_mcp_env`.
  - `plugin-tests/dev-tooling/fixtures/coverage/*.xml` — committed Clover reports, read with `$(< file)` in `setup()`.
  - `plugin-tests/dev-tooling/lsp_proxy/conftest.py` and `agent-skills-export/tests/conftest.py` — the pytest fixtures for their respective suites.

## Pre-Step-1

When the code under test is a file listed in `templates/README.md` §Directories, place the test in `plugin-tests/mcp-shared/` and source the template at `templates/mcp-shared/<file>` directly — never a plugin copy. The template-sync check in `.github/workflows/validate.yml` keeps every copy byte-identical, so one suite covers all consumers and a per-plugin duplicate suite adds no coverage.

Otherwise place the test at `plugin-tests/<plugin>/<feature>.bats`, mirroring `plugins/<plugin>/`.

## Pre-Step-4

Before writing a BATS test body, read `plugin-tests/README.md` §Adding Tests for the file-header skeleton (`bats_require_minimum_version`, the `# bats file_tags=` line) and the tag vocabulary the suite filters on.
