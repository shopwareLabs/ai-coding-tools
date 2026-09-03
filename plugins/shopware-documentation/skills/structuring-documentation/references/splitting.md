# Splitting a Surface

Split by moving whole `##` sections into sibling files, leaving the original as the index that routes to them.

## Where the siblings go

A surface splits into a `docs/` directory beside it: `<Module>/README.md` splits into `<Module>/docs/`, `<Module>/<Subdir>/README.md` into `<Module>/<Subdir>/docs/`.

Never name the directory for the file. A directory called `readme/` would be claimed by every module.

## What stays in the index

Keep the title and everything above the first `##`. Those scope the whole surface.

Order the index rows by the original heading order. A surface written to be read through encodes its reading order there, and alphabetising discards it.

Pack adjacent sections together up to the goal (`docs.size_goal`). Never one file per section, unless each resulting file is independently addressable by name and a reader would ask for it by that name. A per-item reference file earns its own file; two unrelated sections packed under an invented compound title do not.

A file whose title restates its only sentence belongs merged back into its neighbour.

## Headings

Drop a moved section's heading when the new file's title already names it, and promote its subsections one level. Carrying the heading across is the default outcome of moving a section into a file that then gets a title, and it produces a file opening with a heading that restates the line above it.

Drop it only after searching the old anchor and confirming nothing cites it.

Every sibling's own sections start at `##`, whatever level they sat at in the source. A section carved out of a `##` section's `###` children arrives with `###` headings under a new `#` title, skipping `##` entirely. Promote them.

Siblings carved from one source section share one heading scheme. Three files from one section that each nest differently no longer read as siblings.

## A single section over budget

A `##` section can exceed the budget alone. Split it at its own internal boundaries, and add a heading where the prose has a boundary it never marked. An invented heading that names what is already there is correct; one that imposes a division the prose does not make is not.

## After the split

Four defect classes survive every content check. Token diffs, word multisets, and duplication scans all compare content, and the content is identical: only the referent moved. Each is caught by reading, or not at all.

**1. Prose that describes its own container.** Text can move verbatim and become false, because it made a claim about the file it used to live in. Re-read every moved passage for "this file", "everything below", "the rest of", "described above", a count of what the document covers, and any sentence telling a future author where to put something.

**2. Pointers that assert what an emptied surface owns.** Re-read anything that pointed *at* a surface whose body moved out: an ownership row, a procedure naming a file by path, another document's routing sentence. The path still resolves, so nothing flags it, and the claim is now false. Look for an assertion verb beside the path: owns, covers, documents, lists, explains, carries, holds, records, details, contains.

**3. Relative citations broken by a new directory.** A bare `<Other>/<Subdir>/README.md` written in `<Module>/README.md` meant one thing while no `<Module>/<Other>/` existed. Creating any new directory changes what a relative path resolves to, in that file, in its `AGENTS.md`, and in every sibling. Re-resolve every relative citation in the files beside a newly created directory, including files the change never opened. A split breaks citations in files it never touched.

**4. A scope sentence contradicted by the body.** The split writes a correct orienting sentence at the top of each new file and leaves the body's own scope statements saying something else, so a file states its scope correctly in line 3 and contradicts it in line 18. Write each new file's orienting sentence from where that file now sits, then reconcile the body against it. That is one step; skipping it produces a contradiction per file.

## Sweeping

Run three searches, then run all three again after fixing what they found.

1. For every heading renamed and every file moved, search the old anchor and the old path, and update each reference in the same change.
2. For every surface whose body moved out, search its path where it did *not* change, and re-read what each hit claims about it.
3. For every directory the split creates, re-resolve every relative citation in the files beside it.

The repair for a stale scope sentence is writing a scope sentence, and the repair for a bare path is writing a relative one. Each repair is the same operation that produced the defect, performed by someone who now believes the file is clean. A repair pass that is not re-swept ships the class it was convened to remove.

Search every tracked file, not only the Markdown ones the budget governs. PHP comments, YAML, shell scripts, and runtime error messages cite documentation paths too.

Give any path sweep a known-positive fixture: a citation it must find. A regex written against text that is mostly backticks, punctuation, and slashes can be incapable of matching any real citation while returning the same empty output as a clean tree. `bash "${CLAUDE_SKILL_DIR}/scripts/measure.sh" links <changed directories>` fails loudly when it resolves nothing, for exactly this reason.

## What a split does not license

Prose moved verbatim does not go through a rewrite pass. A prose editor run over text that only changed address will reword domain terms the move never touched. Only prose the split itself writes, a new index row or an invented heading's opening line, is new prose.
