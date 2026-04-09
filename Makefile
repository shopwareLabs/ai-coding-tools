SKILL ?=
DIST_DIR ?= agent-skills-export/dist
UV_RUN = uv run --project agent-skills-export

.PHONY: build-skill build-skills lint typecheck test check

## Build a single skill: make build-skill SKILL=plugins/contributor-writing/skills/adr-writing
build-skill:
	@test -n "$(SKILL)" || (echo "Usage: make build-skill SKILL=path/to/skill-dir" >&2; exit 1)
	$(UV_RUN) build-agent-skill $(SKILL) $(DIST_DIR)

## Build all skills with .agent-skills markers
build-skills:
	@found=0; \
	for marker in $$(find plugins -name ".agent-skills" -type f 2>/dev/null); do \
		skill_dir=$$(dirname "$$marker"); \
		echo "Building $$skill_dir..."; \
		$(UV_RUN) build-agent-skill "$$skill_dir" $(DIST_DIR); \
		found=1; \
	done; \
	if [ "$$found" = "0" ]; then echo "No skills with .agent-skills markers found"; fi

## Lint agent-skills-export
lint:
	$(UV_RUN) ruff check agent-skills-export/src/ agent-skills-export/tests/
	$(UV_RUN) ruff format --check agent-skills-export/src/ agent-skills-export/tests/

## Type-check agent-skills-export
typecheck:
	$(UV_RUN) mypy agent-skills-export/src/

## Test agent-skills-export
test:
	$(UV_RUN) pytest agent-skills-export/tests/

## Run all checks (lint + typecheck + test)
check: lint typecheck test
