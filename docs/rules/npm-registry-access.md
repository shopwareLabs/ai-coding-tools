# NPM Package Metadata Access

**Rule**: For npm package metadata (dependencies, versions, size, tarball URL), fetch `https://registry.npmjs.org/<name>/latest`. Never fetch `https://www.npmjs.com/*` — it returns HTTP 403 for WebFetch (bot/WAF filter). 403 here is not transient: do not retry, do not spoof a User-Agent, switch sources.

## Decision Test

Before calling WebFetch on an npm URL, ask:

> **"Am I about to hit `www.npmjs.com`?"**

- Yes → **stop**. Rewrite to `https://registry.npmjs.org/<name>/latest`.
- No → proceed.

## Endpoints

| Endpoint | Returns | Use when |
|---|---|---|
| `https://registry.npmjs.org/<name>/latest` | Single version object (small) | Default — covers deps, size, tarball, engines |
| `https://registry.npmjs.org/<name>/<version>` | Same shape, specific version | You need a historical version |
| `https://registry.npmjs.org/<name>` | Full packument (large) | You need all versions, dist-tags, or publish timeline |

**Scoped packages**: URL-encode the slash. `@scope/name` → `https://registry.npmjs.org/@scope%2Fname/latest`.

## When `/latest` Does Not Have the Data

| Need | Source |
|---|---|
| Weekly download counts | Not in the API — ask the user or leave it out |
| Transitive dependency tree | Run `npm ls` locally, or walk each direct dep the same way |
| Security advisories | GitHub Advisory Database, or `npm audit` locally |
| In-development / unreleased manifest | `package.json` on GitHub via gh-tooling `repo_file` |
