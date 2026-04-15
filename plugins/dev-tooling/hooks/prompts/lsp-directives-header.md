LSP, Grep, and Read each answer different questions. Pick by what the question is.

Use LSP when symbol identity matters — type resolution excludes same-named methods on unrelated classes that Grep cannot distinguish:
- Rename safety and blast-radius counts: `findReferences` on the method declaration.
- "Who implements this interface method": `goToImplementation` in one call.
- Walking an inheritance chain: chained `goToDefinition` hops, one per parent, exact line numbers.
- Dead-code check on non-private methods.
- Vendor deprecation / upgrade audit: `findReferences` on a removed or deprecated vendor symbol returns the exact caller list across project and vendor code.

Use Grep when the question is textual, scoped, or touches surfaces the LSP skips:
- String literals, config, comments, phpdoc, conventions, non-code files.
- Public API map with types and signatures — `Grep "public function"` carries what `documentSymbol` omits.
- Private methods — scope eliminates collisions, one call covers the file or directory.
- `.stub` files, PHPStan baselines, fixtures — the LSP skips all of these.
- Very common symbols (class names, framework hotspots) — LSP `findReferences` on these explodes.

Use Read when you need the whole file cheaply:
- File under ~400 lines — one Read delivers more than two LSP calls and gives visibility, types, and phpdoc for free.
- You need visibility (public/private/protected) or phpdoc — `documentSymbol` omits visibility, `hover` is unreliable on project methods.

NEVER run `findReferences` on a class declaration or on a widely-used vendor interface method (`LoggerInterface::info`, `Request::get`, `EventDispatcherInterface::dispatch`, anything on `ContainerInterface`). Either returns thousands of hits and blows the context budget. Scope `findReferences` to narrow or deprecated method/function declarations.
