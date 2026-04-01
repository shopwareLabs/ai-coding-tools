# Writing Rules for PR Descriptions

> **HARD BAN: no em dashes (—) or en dashes (–) anywhere in output.** This is the single most common anti-slop violation. Replace with: period + new sentence, comma, parentheses, or delete the aside entirely.

## Core Principle

PR descriptions explain **why** a change was made and **why** reviewers should care. The diff shows **what** changed. The description adds the context the diff can't convey: motivation, root cause, reproduction steps, trade-offs, and scope decisions.

## Do's

- Explain **why**, not just what changed, but why this approach was chosen and what constraints informed it
- Be concrete: class names, config keys, method signatures, version numbers, not abstractions
- Describe components at the level of contracts and responsibilities: what goes in, what comes out, why it exists. Leave the implementation (how it works internally) to the diff.
- Include root cause analysis for bug fixes: what was broken, why, and why the fix is correct
- Reference prior art: link commits, PRs, or issues that provide context for the current change. When referencing a predecessor, explain what's different about this PR's approach, not just what's the same.
- Use backticks for all code references: classes, methods, config keys, CLI commands, API endpoints, file paths
- Use full namespace paths for PHP classes on first mention
- Include code examples (before/after, usage, SQL queries) when they clarify more than prose
- State scope boundaries for large changes: "This PR introduces X but does not yet Y"

## Don'ts

- Do not delegate context to issues without summarizing: "see issue" forces reviewers to context-switch. Always include enough context in the PR itself.
- Do not leave template sections empty. If a section doesn't apply, write a brief explanation why (e.g., "Not applicable").
- Do not restate the diff. The obvious form is naming files and line numbers. The subtler form is walking through implementation logic step by step. If a reviewer will read those lines in the diff, the description adds nothing by repeating them. Describe at the level of contracts and responsibilities, not method internals.

  Bad (walks through `extractEntityType()` line by line):
  > "The pass walks the constructor arguments of each tagged service, resolves each `Reference` against the container, checks whether the referenced class extends `AbstractContentLayoutAssignableDefinition`, instantiates the definition class, and calls `getContentLayoutEntityType()`."

  Good (contract level, one sentence):
  > "The pass resolves each tagged service's `AbstractContentLayoutAssignableDefinition` dependency and extracts its entity type."
- Do not use emojis or emoji checklists (no checkmark bullet lists for feature summaries)
- Do not write marketing copy: "exciting new feature", "powerful API", feature bullet lists with checkmarks
- Do not add contributor attribution in the description ("Thanks to @user!")
- Do not include `diffhunk://` link references. They're unreadable outside the GitHub UI.
- Do not describe WHAT without WHY. AI-copilot-style descriptions that enumerate file changes without explaining motivation are the most common anti-pattern.

## Tense

| Context | Tense | Example |
|---|---|---|
| Describing new behavior | Present | "The sort function **handles** null values." |
| Describing old/broken behavior | Past | "Previously, the sort function **threw** a TypeError on null values." |
| Future plans or deprecation | Future | "The old endpoint **will be** removed in v6.8.0." |

## Anti-Slop Rules

LLMs produce text with a statistical fingerprint: uniform sentence lengths, predictable vocabulary, formulaic structures, and absence of human texture. All written output must read like it was written by a developer, not generated. These rules target the most common patterns in LLM-generated technical writing.

### Punctuation patterns

**Em dashes:** Do not use em dashes. LLMs use them as a universal connector, substituting for commas, parentheses, colons, and periods. Replace with a period and new sentence, parentheses, a comma, or delete the aside entirely.

**Colon overuse:** LLMs insert colons before nearly every explanation. Combined with phrases like "Here's the key point:" it creates a lecturing cadence. Weave the explanation into the sentence, or delete the setup clause.

**Semicolons:** LLMs use semicolons to stitch together simple declarative sentences that don't share a tight logical relationship. Replace with "and", "but", or separate sentences.

### Banned vocabulary

Never use these words. They appear at 12-182x their normal frequency in LLM output and are immediate tells:

- **Verbs:** delve, leverage, harness, utilize, foster, streamline, elevate, unleash, empower, unlock, underscore, showcase, embark, illuminate, unravel
- **Adjectives:** comprehensive, robust, nuanced, multifaceted, pivotal, cutting-edge, meticulous, seamless, innovative, groundbreaking, dynamic, holistic
- **Nouns:** landscape, tapestry, realm, paradigm, ecosystem, synergy, cornerstone, catalyst, nexus, journey, testament, beacon, interplay
- **Adverbs:** moreover, furthermore, notably, arguably, fundamentally, remarkably, significantly, meticulously, seamlessly, profoundly
- **Intensifiers:** truly, really, incredibly, very (before already-strong adjectives). "Truly groundbreaking" and "incredibly versatile" are double filler. Delete the intensifier or replace with a specific measurement.

Use the plain word instead: utilize → use, leverage → use, comprehensive → full, robust → strong. Or delete the word entirely. Most are filler.

### Banned sentence patterns

- **Contrastive reframe:** "It's not just X, it's Y" / "not only X but also Y". State the fact directly.
- **Hedging filler:** "It's worth noting that," "It's important to understand," "It should be mentioned". Delete and state the fact.
- **Formulaic transitions:** "Moreover," "Furthermore," "Additionally," "That said," "With that in mind". Delete or use a short bridging sentence.
- **Summary opening:** "This pull request introduces..." / "This PR adds..." / "This change introduces...". The context already frames the content. Start with the substance.
- **Restating the topic:** Do not open by paraphrasing a heading or title. The heading already says what changed; the body explains why it matters.
- **Summary conclusion:** Do not end with "Overall," "In summary," or a restatement. End on the last substantive point.
- **"This" + abstract noun:** "This approach enables...", "This methodology provides...", "This framework ensures...". Name the actual thing. Instead of "This approach enables," write "The caching layer enables" or merge with the previous sentence.
- **Rule of three:** LLMs compulsively group items in threes ("speed, accuracy, and scalability"). If you have two things, list two. If you have four, list four. Don't pad to three and don't trim to three.

### Banned description formats

- **AI-copilot style:** Category headers ("Refactor and Centralization", "API Enhancements", "Error Handling Improvements") with bullet lists that restate the diff. This format describes WHAT without WHY.
- **Checklist features:** Emoji bullet lists (checkmark + feature name). Reads like a product launch, not a code change.
- **Diff link references:** `[[1]](diffhunk://...)` style references auto-generated by tools. They're unclickable outside GitHub's diff view.

### Sentence rhythm

Vary sentence lengths. LLMs produce sentences that cluster around 15-20 words, creating a metronomic rhythm. Mix short sentences (5-8 words) with longer ones (25-30 words). A short sentence after a long one creates emphasis. Uniform length creates suspicion.

Bad (metronomic):
> The system now validates input before processing. This prevents invalid data from reaching the database. The validation uses the same rules as the API layer.

Better (varied):
> Input validation now runs before processing, using the same rules as the API. Invalid data never reaches the database.

### Concreteness over abstraction

Never write "improved performance" when you can write "eliminated redundant child category fetch from SEO URL updater." Never write "better error handling" when you can name the exception class and the condition that triggers it. Developers want specifics: class names, config keys, method signatures, version numbers. Abstraction is filler.

Don't mistake counts for concreteness. Prefer omitting numbers entirely. A count that restates what the text already shows (e.g., "nine events" when the text lists all nine) is noise, not specificity. If a number isn't needed, leave it out. If imprecision is acceptable, use wording like "additional" or "several." Use a specific number only when the value itself matters for understanding the change AND isn't deducible from the rest of the text: percentages, thresholds, version numbers, limits.

Bad: "This enhancement significantly improves the developer experience."
Better: "The `quantityStart` and `quantityEnd` fields now require a minimum value of `1`."

Bad: "Nine events now implement `ShopwareEvent`."
Better: "Events dispatched during import/export, media validation, SEO URL persistence, and theme changes now implement `ShopwareEvent`."

### Don't assume intent

Never attribute motivation or intent to the original authors of code you're describing. "This was an oversight" or "the original developer forgot to..." are assumptions. You don't know why the code was written the way it was. Describe what the code does and what you changed, not why someone else made a past decision.

Bad: "This was an oversight. The dispatch just didn't pass Context in."
Better: "The dispatch sites had `Context` in scope but didn't pass it to the event constructors."

### Formatting discipline

- Write prose paragraphs, not bold-keyword-colon lists
- Do not bold every other sentence. Bold only key behavioral changes, sparingly.
- Do not use numbered lists unless items have a genuine sequence
- Match the formatting density of existing content in the target context

### Tone

- Factual and direct, not enthusiastic. Not "exciting new feature." Just describe what it does.
- Do not both-sides. If something is deprecated, say so. If behavior changed, state the new behavior.
- Use contractions where natural: "don't" not "do not," "isn't" not "is not." Developer-to-developer, not academic writing.
- Never use exclamation marks.
- Informal is fine when it's genuine: "We had a similar change years back" reads human. "This exciting enhancement" does not.

## What Adds Value in PR Descriptions

From analysis of high-quality Shopware PRs, these elements consistently help reviewers:

- **Root cause analysis:** Trace the bug to its origin, explain why the fix is correct (not just what it changes)
- **Scope boundaries:** "This PR only introduces the system itself, not any new components"
- **Before/after comparisons:** Show the old and new behavior, especially for behavioral changes
- **Code examples:** Key code changes inline when they clarify the approach (a 5-line snippet beats a paragraph of prose)
- **Cross-references:** Link to the original PR where a regression was introduced, or a related PR in another repo
- **Historical context:** "We had a similar change for products here: [link]" helps reviewers understand the pattern
- **Diagrams:** Mermaid flowcharts for complex multi-step processes (use sparingly, only when the flow is genuinely hard to follow in prose)
- **Downstream references:** Link to companion PRs in SwagCommercial, docs, or other repos

## What Reduces Value

- **"Please read the issue"** / **"see issue"**: context-switch tax on every reviewer
- **Empty template sections** left as headings with no content
- **Over-documentation:** Screenshots for text-only changes, curl examples for internal APIs, TypeScript usage examples when the PR is about PHP backend code
- **Restating the obvious:** "Changed the return type from string to int" when the diff shows exactly that
