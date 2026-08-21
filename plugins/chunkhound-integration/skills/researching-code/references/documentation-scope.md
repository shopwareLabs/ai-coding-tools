# Documentation Scope

How to consult Markdown documentation during research and weight it against code evidence. Consumed by the `Documentation scope` rule in Step 3 of the skill.

## What counts as documentation

Files with the Markdown extensions from `supported-languages.md`: `.md`, `.markdown`, `.mdown`, `.mkd`, `.mdx`. READMEs, CHANGELOGs, ADRs, doc trees (`docs/`, `adr/`), and doc files sitting next to code all qualify.

## Standing rules

- **Code is the primary evidence; documentation is secondary.** Documentation describes what the code was, not necessarily what it is — it drifts as code moves, and in documentation-heavy domains its sheer volume can outweigh the code evidence in synthesis. Treat every doc-derived claim as potentially stale until corroborated. A Markdown chunk returned by a ChunkHound query is documentation too — arriving through the index does not make it code evidence; route it through the corroboration and reporting rules below.
- **Documentation supplements the plan; it never replaces it.** The ChunkHound plan from the Step 3 catalog runs unchanged. Do not answer a code question from documentation, and do not backfill an empty code result with doc prose — an empty code result is a finding, not a gap for documentation to fill.
- **Consult relevant documentation at every depth.** Locate candidate files with `bfs` (Markdown extension patterns, scoped to the subsystem under research plus top-level doc directories) and read them with `Read`. Where filenames alone cannot identify relevance — numbered ADRs, large opaque doc trees — narrow by content with `ugrep` confined to Markdown files (`--include` globs for the extensions above). Searching documentation content is not searching code, so the ChunkHound-opener rule does not apply, and none of these consult the index, so none reach the pre-flight gate. Skip the doc pass only when the deliverable is a bare location or enumeration that no prose could inform — a "where is X defined?" surface lookup needs none.

## Corroboration

For each doc-derived claim that would enter the findings, check it against code using the Step 3 primitive catalog — a ChunkHound primitive opens the check, as with any code search — and label it:

- **Corroborated** — code confirms the claim. Cite the code (`file:line`); the doc is context, never the citation.
- **Uncorroborated** — code neither confirms nor contradicts it (the plan did not reach that far, or the claim is not checkable against code). Mark it as an unverified doc claim.
- **Contradicted** — code contradicts the claim. Suspected drift: state what the doc says, what the code shows, and cite both.

Corroborate only claims that would enter the output, not every sentence read. Piggyback on queries the plan already runs where possible; a claim not worth a dedicated query stays **Uncorroborated** rather than triggering extra research.

Corroboration queries are ChunkHound use. When the plan reached Step 3 without pre-flight — a docs-only plan of `bfs` + `Read` — run the Step 2 pre-flight before the first corroboration query.

## Index status

Projects may deliberately exclude documentation from the index — indexed docs pollute semantic results and outrank code in synthesis. Infer the status rather than assume it: when no Markdown chunks appeared in any ChunkHound result during the run while `bfs` confirms doc files exist, record that for the Step 4 Coverage caveat — phrased as the observation it is ("no Markdown chunks surfaced from the index; documentation was consulted by direct read"), not as a definite exclusion, since docs can be indexed yet outranked in every result. Do not read `.chunkhound.json` to determine it. The handling above is identical either way — documentation is reached by `Read` and drift-weighted whether indexed or not.

## Reporting

- Doc-derived claims appear only in the Step 4 **Documentation evidence** section, each carrying its label. Overview, Key Components, and Architecture Insights build from code evidence alone.
- Suspected drift (contradicted claims) is a drive-by observation: one or two lines per contradiction inside **Documentation evidence**. It never becomes the deliverable unless the caller asked about the documentation itself.
- When documentation was inferred to be outside the index, add a **Documentation index status** note under Coverage caveats: documentation was consulted by direct read, not through the index.
