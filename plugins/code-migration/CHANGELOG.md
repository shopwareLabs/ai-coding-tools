# Changelog

## [1.0.0] - 2026-07-30

- Initial release with the `xml-config-migrating` skill: migrates extension XML configuration (service definitions, routes, package config) to PHP configurators 1:1, proves container and route equivalence via `debug:container` / `debug:router` dump diffs, runs the extension's tests, and reports the result in a fixed verification format.
