PHP LSP is available for `.php` files.

Supported ops: `documentSymbol`, `workspaceSymbol`, `hover`, `goToDefinition`, `goToImplementation`, `findReferences`.

NEVER call `prepareCallHierarchy`, `incomingCalls`, or `outgoingCalls`. The PHP LSP does not implement them; walk call chains manually with `findReferences` plus `goToDefinition`.

Scope: project `src/` and `tests/`, the full `vendor/` tree, and PHP stdlib builtins. All ops work across the vendor boundary without additional setup.

Known failure modes — assume them before trusting a result:

- `hover` is asymmetric. Dense and reliable on vendor class references — returns the full class skeleton, constants, method signatures, implemented interfaces, and `@deprecated` flags in a single call, often better than reading vendor source. Unreliable on project methods — sometimes returns "No hover information available" on real public methods. Fall back to Read for project-code phpdoc.
- `documentSymbol` returns name, kind, and line only — no visibility, no types, no signatures. For public-API audits use `Grep "public function"` instead.
- `workspaceSymbol` caps at 250 results and ignores the query string. Effectively unusable; use `documentSymbol` on a known file, or Grep.
- `goToImplementation` returns empty when it cannot resolve the symbol. An empty result does not confirm "no implementations exist" — cross-check with Grep before concluding.
- `findReferences` skips `.stub` files, PHPStan baselines, fixtures, comments, and phpdoc. Follow up with Grep when rename safety depends on those surfaces.
- First request against a file can take 10–30 seconds; subsequent requests on the same file are fast.
- Returned paths may be rooted at a different filesystem view than the host (e.g. `/var/www/html/...` for containerized runs). Rebase before feeding them to Read or Grep.
