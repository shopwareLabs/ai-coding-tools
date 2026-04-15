PHP LSP (phpactor) is available for .php files.

Supported operations: documentSymbol, workspaceSymbol, hover, goToDefinition, goToImplementation (silent when none), findReferences.

NEVER call prepareCallHierarchy, incomingCalls, or outgoingCalls. Walk call chains manually with findReferences plus goToDefinition.

workspaceSymbol caps at 250 results and ignores the query string. Use documentSymbol on a specific file, or Grep for workspace-wide identifier search.

First request against a file can take 10 to 30 seconds. Subsequent requests on the same file are fast.
