PHP LSP (phpactor) — available for `.php` files.

Supported LSP tool operations:
- documentSymbol — list symbols in a file
- workspaceSymbol — workspace-wide symbol search (see bug below)
- hover — signature and type info at a position
- goToDefinition — jump to symbol definition
- goToImplementation — jump to interface/abstract implementations (silent when none)
- findReferences — find all usages of a symbol

Not supported by phpactor — do not call: prepareCallHierarchy, incomingCalls, outgoingCalls. Phpactor has no call-hierarchy handler. Walk call chains manually with findReferences + goToDefinition.

Known issues:
- workspaceSymbol caps at 250 results and currently ignores the query — it returns the first 250 symbols regardless of what you ask for. Do not rely on it for targeted symbol search; use documentSymbol on specific files, or Grep for workspace-wide identifier search.

Latency: the first request against a file can take 10–30s while phpactor parses it and resolves its dependencies. Subsequent requests on the same file are fast.
