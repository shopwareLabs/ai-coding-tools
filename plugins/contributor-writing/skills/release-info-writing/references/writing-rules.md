# Writing Rules for Release Entries

> **HARD BAN: no em dashes (—) or en dashes (–) anywhere in output.** This is the single most common anti-slop violation. Replace with: period + new sentence, comma, parentheses, or delete the aside entirely.

## Core Principle

> "The release notes should describe **why** we made a change and **why** external developers should care; it is **not** (primarily) about **what** you changed."

The "what" is derivable from the diff. The human value is the "why" and "so what."

## Required Information Per Entry

Each entry must cover these four points (depth varies by entry size):

1. **What** changed (brief, factual)
2. **Why** it changed (the benefit or motivation)
3. **Why and when** external developers need to care
4. **How** they can or need to adjust

## Do's

- Explain **why** and **impact**, not just what changed
- Be concise: 1-3 sentences for the core message, plus code examples if needed
- Include PR reference where helpful (not mandatory)
- Use backticks for all code references: classes, methods, config keys, CLI commands, API endpoints, file paths
- Use full namespace paths for PHP classes
- Reference feature flags by name when applicable
- Link to documentation, ADRs, or external resources where relevant

## Don'ts

- Do not write stories or background narratives
- Do not be vague: "Fixed bug", "Improved performance", "Various improvements"
- Do not document internal-only changes (use the auto-generated changelog for those)
- Do not use emojis
- Do not add contributor attribution ("Thanks to @user!")
- Do not add bare PR links without context
- Do not use the word "Fixed" as a leading verb. It leads to poor descriptions.

## Tense

| Context | Tense | Example |
|---|---|---|
| Describing new behavior | Present | "Custom fields **are** now not searchable by default." |
| Describing old behavior | Past | "Previously, the maximum length **was** limited to 255 characters." |
| Deprecation timelines | Future | "**Will be** removed in v6.8.0." |

## Heading Style

- RELEASE_INFO entries use `###` (h3) headings
- UPGRADE entries use `##` (h2) headings
- Headings are descriptive of the change, not just the component name
- Don't put counts in headings. Describe the change, not how many items are affected (see "Concreteness over abstraction" for the general number rule).
- Good: "Default CMS page ID now persisted for categories"
- Good: "Reduced HTTP cache invalidation on system config changes"
- Good: "Events now require `Context` constructor parameter"
- Bad: "CMS changes"
- Bad: "Cache update"
- Bad: "Ten events now require `Context` constructor parameter"

## Opening Sentence Patterns

Start with the subject or component that changed, state what changed:

- "Custom fields are now **not searchable by default**."
- "The Storefront now emits structured data as JSON-LD..."
- "The `system:setup:staging` command now supports pre-configuring system config keys..."
- "Deleting a product stream that's been used in a product export raises a dedicated delete restriction."

## Body Structure

For entries beyond tiny size, follow this flow:

1. **Opening:** What changed (present tense)
2. **Context/Why:** Why this was done, what problem it solves
3. **Impact:** How it affects external developers
4. **Action:** What they need to do (if anything)

For UPGRADE entries specifically, use `**Before:**` / `**After:**` blocks for migration examples.

## Emphasis and Formatting

- **Bold** for key behavioral changes: `**not searchable by default**`, `**Important:**`
- Backticks for all code: `` `SystemConfigService` ``, `` `bin/console system:setup:staging` ``
- Tables for structured data (schema types, config options, deprecated items with replacements)
- `<details>` collapse tags for long lists (used in UPGRADE files)
- Bullet lists for multiple related items
- Code blocks with language tags for migration examples

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

## Deprecation Flow

Deprecations appear in **two files** across **two releases**:

1. **Minor release** → `RELEASE_INFO-6.x.md`: Announce the deprecation with:
   - What is deprecated
   - What to use instead (the alternative)
   - When it will be removed (timeline: "will be removed in v6.Y.0")

2. **Major release** → `UPGRADE-6.Y.md`: Document the removal with:
   - What was removed
   - Full migration steps with Before/After code examples
   - List of affected classes/methods if multiple
