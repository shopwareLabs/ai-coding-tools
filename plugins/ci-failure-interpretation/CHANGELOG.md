# Changelog

## [1.0.1] - 2026-05-13

### Changed
- `ci-log-interpretation` description rewritten to follow https://agentskills.io/skill-creation/optimizing-descriptions. Leads with imperative "Use this skill when..." and retains the existing "activate even if the user does not mention 'CI'" pushy clause so GitHub Actions failure output still routes through the skill when the user only pastes logs. No behavior change.

## [1.0.0] - 2026-02-28

### Added
- Initial release of ci-failure-interpretation plugin
- `ci-log-interpretation` skill with tool identification and noise filtering
- PHP tool reference covering PHPUnit, PHPStan, and ECS failure anatomy
- JavaScript tool reference covering ESLint, tsc, Stylelint, Prettier, and Jest failure anatomy
- E2E tool reference covering Playwright, Lighthouse, and ludtwig failure anatomy
- GitHub Actions log envelope reference with noise budget and step marker documentation
