# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-15

### Added
- PHPStan static analysis tool (`phpstan_analyze`)
- ECS code style checking tool (`ecs_check`)
- ECS code style fixing tool (`ecs_fix`)
- PHPUnit test runner tool (`phpunit_run`)
- Multi-environment support: native, docker, vagrant, ddev
- Auto-detection of development environment from project files
- Configuration via `.lintrc.local.json` file
- Bash-based MCP server implementation (minimal dependencies)
