# Surface Contract

Each surface declares three things: who owns its subject, which content class it holds, and what it costs to read. A surface missing any of the three cannot be checked.

## Content classes and their single home

Ask one question of every proposition:

> Does acting on the code require this fact, or does understanding the module require it?

| Class | Home | Form |
|---|---|---|
| Conceptual model, design rationale, the why | `README.md` | prose |
| Module orientation, onboarding | `README.md` | prose |
| Symbol index: class, role, path | `AGENTS.md` | terse bullet |
| Invariants, constraints, gotchas that change how you edit | `AGENTS.md` | imperative single statement |
| Subject-to-file routing | `AGENTS.md` `## Navigation`, `README.md` index rows | link rows |
| Configuration reference: YAML schemas, endpoint contracts, request and response shapes, worked examples | `docs/*.md` | reference prose plus code blocks |
| Local implementation detail tied to one call site | code comment | inline |
| Multi-step cross-cutting procedure | a skill | not a documentation surface |

A proposition belonging to two classes is split, never restated in two registers. The why goes to `README.md`, the what and where to `AGENTS.md`, the schema to `docs/`. Cross-link the halves.

## What must never appear twice

- **The enumerated symbol inventory.** It lives in `AGENTS.md` only. A `README.md` names a class inside a sentence of explanation and carries no class list.
- **Invariants.** Each lives in `AGENTS.md` only. A `README.md` describes the concept an invariant protects and never restates the rule.
- **Commands and conventions.** Stated once.

## What appears nowhere

Generic language, framework, and tooling knowledge. A model already has it, and repeating it costs context that the project's own machinery needs.

The project's non-standard machinery is the opposite case and gets documented deliberately: the conventions it invented, the framework defaults it overrides, the pattern a reader would otherwise assume is the standard one.

## `AGENTS.md` bullet discipline

One bullet names a symbol, its role, and its path, plus at most one invariant. A bullet that runs past a couple of sentences is a narrative, and a narrative belongs in the owning `README.md` or a `docs/` file.

`AGENTS.md` is inlined into every session that touches the directory. A bullet of 2,000 characters there costs more than the same prose in a `docs/` file that gets read when it is needed.

Each `AGENTS.md` carries a `## Navigation` section mapping the area's subjects to the files that own them.

## Subject ownership

One directory owns a subject. Its `README.md` explains it, its `AGENTS.md` indexes the code, its `docs/` holds the reference material. The directory that owns the code owns its documentation.

A project may supply its own ownership table, mapping each directory to the subject it owns; use that table where it exists. A surface with a budget but no stated owner cannot be checked for single ownership.

A subject documented in two directories has one of them wrong. Pick the owner, move the prose, and leave a link.

## Naming inside `docs/`

- An extension guide is `custom-<subject>.md`, so the set is findable from filenames alone.
- An introspection endpoint contract is `introspection.md`, in the directory that owns the registry it exposes.
- A per-item reference file is named for the item's identifier, not its class: `csv_export.md`, not `CsvExportHandler.md`.
- A worked example is `<subject>-example.md` or `worked-example.md`.

## Adding a surface

When the project supplies an ownership table, a file inside the measured scope but absent from it gets its row added in the same change. Without a stated owner there is nothing for the single-owner check to test.
