# Writing Rules for Feature-Branch PR Descriptions

> **HARD BAN: no em dashes (—) or en dashes (–) anywhere in output.** This is the single most common anti-slop violation. Replace with: period + new sentence, comma, parentheses, or delete the aside entirely.

## Core Principle

Feature-branch PR descriptions explain **design rationale**. The diff shows what changed. The description explains why this approach was chosen over alternatives, how it connects to the feature branch's goals, and what trade-offs were made. A reviewer reading the description should be able to assess the approach without reading the diff first.

## Audience

The audience is **colleagues reviewing incremental work on a shared feature**. Assume familiarity with the feature branch's goals and prior PRs in the chain. Don't explain the feature from scratch. Focus on what changed relative to the feature branch and why this slice looks the way it does.

## Structure

### Opening paragraph

Every description opens with a context paragraph that follows this pattern:

1. **State the prior situation** (what existed, what was wrong or missing)
2. **State the change** (what this PR does about it)
3. Optionally: **connect to the chain** (which prior PR established the context)

### Topical subsections

Use `###` subsections, each covering one concern or aspect of the change. Choose headers based on what the PR actually does, not from a fixed list. Headers should describe what was done and why.

Good: `### Event-based type override`, `### DI decentralization`, `### Compile-time collection`
Bad: `### Changes`, `### What changed`, `### Updates`, `### Improvements`

### Tables

Use markdown tables when listing structured mappings: file moves, new classes with their locations, config key changes, loader-to-route delegations. Don't use tables for unstructured information that reads better as prose.

### What not to include

- No numbered template sections (`### 1. Why is this change necessary?`)
- No checklist
- No reproduction steps (feature-branch PRs describe design and implementation, not user-facing bug workflows)

## Cross-References

Feature-branch PRs reference related PRs in the chain. Standardize these under a `## References` section at the end of the description.

| Type | Format | When to use |
|---|---|---|
| Tracking issue | `Ref #issue` | Links to the overarching issue for the feature |
| Dependency | `Blocked by #PR` | This PR can't merge until another merges first |
| Predecessor | `Follows #PR` or prose in opener | This PR builds on patterns/work from another |
| Successor | `Follow-up: #PR` | Another PR continues work started here |

Never use `closes` or `fixes`. Feature-branch PRs don't close issues directly.

## Diagrams

Two-step reasoning before adding any Mermaid diagram:

1. **Would the reviewer understand this better by seeing it than reading about it?** If the relationships between components can be followed from prose or a table, don't add a diagram.
2. **Can it fit one focused diagram?** If the flow has distinct concerns (e.g., a build-time discovery pipeline and a separate app lifecycle flow), split into focused diagrams. A single diagram that tries to show everything is as hard to follow as the prose it replaced.

## Do's

- Explain **design decisions**: why this approach, what alternatives exist, what trade-offs were made
- Describe components at the level of contracts and responsibilities: what goes in, what comes out, why it exists. Leave the implementation (how it works internally) to the diff.
- Name classes, methods, events, and DI changes concretely
- Reference prior PRs in the chain when the current PR follows or extends their patterns
- Use backticks for all code references: classes, methods, config keys, CLI commands, API endpoints, file paths
- Use full namespace paths for PHP classes on first mention
- Include code examples (before/after, usage) when they clarify more than prose
- State scope boundaries for large changes: "This PR does X but does not yet Y"

## Don'ts

- Do not delegate context to issues without summarizing: "see issue" forces reviewers to context-switch
- Do not restate the diff. The obvious form is naming files and line numbers. The subtler form is walking through implementation logic step by step. If a reviewer will read those lines in the diff, the description adds nothing by repeating them. Describe at the level of contracts and responsibilities, not method internals.

  Bad (walks through `extractEntityType()` line by line):
  > "The pass walks the constructor arguments of each tagged service, resolves each `Reference` against the container, checks whether the referenced class extends `AbstractContentLayoutAssignableDefinition`, instantiates the definition class, and calls `getContentLayoutEntityType()`."

  Good (contract level, one sentence):
  > "The pass resolves each tagged service's `AbstractContentLayoutAssignableDefinition` dependency and extracts its entity type."
- Do not use emojis or emoji checklists
- Do not write marketing copy: "exciting new feature", "powerful API"
- Do not add contributor attribution in the description
- Do not include `diffhunk://` link references
- Do not describe WHAT without WHY. Descriptions that enumerate file changes without explaining motivation are the most common anti-pattern.

## Tense

| Context | Tense | Example |
|---|---|---|
| Describing new behavior | Present | "The sort function **handles** null values." |
| Describing old/broken behavior | Past | "Previously, the sort function **threw** a TypeError on null values." |
| Future plans or deprecation | Future | "The old endpoint **will be** removed in v6.8.0." |

## Anti-Slop Rules

LLMs produce text with a statistical fingerprint: uniform sentence lengths, predictable vocabulary, formulaic structures, and absence of human texture. All written output must read like it was written by a developer, not generated. These rules target the most common patterns in LLM-generated technical writing.

### Punctuation Patterns

**Em dashes:** Do not use em dashes (—). LLMs use them as a universal connector, substituting for commas, parentheses, colons, and periods. Typical AI density: one em dash every 50-80 words. Human baseline: roughly one per 500 words. Em dash overuse is the most visually obvious surface-level tell.

Replace with:
- A period and a new sentence (most common fix)
- Parentheses for genuine asides
- A comma
- Delete the aside entirely if it isn't essential

Bad: "The dispatch sites had `Context` in scope — but didn't pass it to the event constructors."
Better: "The dispatch sites had `Context` in scope but didn't pass it to the event constructors."

**Colon overuse:** LLMs insert colons before nearly every explanation. Combined with phrases like "Here's the key point:" and "The answer is simple:", it creates a lecturing cadence.

Replace with:
- Weave the explanation into the sentence without a colon
- Lead with the interesting part instead of the setup
- Delete the setup clause. If you're writing "The key takeaway is: X," just write X.

**Semicolons:** LLMs use semicolons to stitch together simple declarative sentences that don't share a tight logical relationship. Most casual and professional human writing uses semicolons sparingly.

Replace with "and", "but", or separate sentences.

### Banned Vocabulary

Never use these words. They appear at 12-182x their normal frequency in LLM output and are immediate tells:

- **Verbs:** delve, leverage, harness, utilize, foster, streamline, elevate, unleash, empower, unlock, underscore, showcase, embark, illuminate, unravel
- **Adjectives:** comprehensive, robust, nuanced, multifaceted, pivotal, cutting-edge, meticulous, seamless, innovative, groundbreaking, dynamic, holistic
- **Nouns:** landscape, tapestry, realm, paradigm, ecosystem, synergy, cornerstone, catalyst, nexus, journey, testament, beacon, interplay
- **Adverbs:** moreover, furthermore, notably, arguably, fundamentally, remarkably, significantly, meticulously, seamlessly, profoundly
- **Intensifiers:** truly, really, incredibly, very (before already-strong adjectives). "Truly groundbreaking" and "incredibly versatile" are double filler. Delete the intensifier or replace with a specific measurement.

Use the plain word instead: utilize → use, leverage → use, comprehensive → full, robust → strong. Or delete the word entirely. Most are filler.

### Banned Sentence Patterns

- **Contrastive reframe:** "It's not just X, it's Y" / "not only X but also Y". State the fact directly.
- **Hedging filler:** "It's worth noting that," "It's important to understand," "It should be mentioned". Delete and state the fact.
- **Formulaic transitions:** "Moreover," "Furthermore," "Additionally," "That said," "With that in mind". Delete or use a short bridging sentence.
- **Summary opening:** "This pull request introduces..." / "This PR adds..." / "This change introduces...". The context already frames the content. Start with the substance.
- **Restating the topic:** Do not open by paraphrasing a heading or title. The heading already says what changed; the body explains why it matters.
- **Summary conclusion:** Do not end with "Overall," "In summary," or a restatement. End on the last substantive point.
- **"This" + abstract noun:** "This approach enables...", "This methodology provides...", "This framework ensures...". Name the actual thing. Instead of "This approach enables," write "The caching layer enables" or merge with the previous sentence.
- **Rule of three:** LLMs compulsively group items in threes ("speed, accuracy, and scalability"). If you have two things, list two. If you have four, list four. Don't pad to three and don't trim to three.

### Banned Description Formats

- **AI-copilot style:** Category headers ("Refactor and Centralization", "API Enhancements", "Error Handling Improvements") with bullet lists that restate the diff. This format describes WHAT without WHY.
- **Checklist features:** Emoji bullet lists (checkmark + feature name). Reads like a product launch, not a code change.
- **Diff link references:** `[[1]](diffhunk://...)` style references auto-generated by tools. They're unclickable outside GitHub's diff view.

### Sentence Rhythm

Vary sentence lengths. LLMs produce sentences that cluster around 15-20 words, creating a metronomic rhythm. Mix short sentences (5-8 words) with longer ones (25-30 words). A short sentence after a long one creates emphasis. Uniform length creates suspicion.

Bad (metronomic):
> The system now validates input before processing. This prevents invalid data from reaching the database. The validation uses the same rules as the API layer.

Better (varied):
> Input validation now runs before processing, using the same rules as the API. Invalid data never reaches the database.

### Concreteness Over Abstraction

Never write "improved performance" when you can write "eliminated redundant child category fetch from SEO URL updater." Never write "better error handling" when you can name the exception class and the condition that triggers it. Developers want specifics: class names, config keys, method signatures, version numbers. Abstraction is filler.

Don't mistake counts for concreteness. Prefer omitting numbers entirely. A count that restates what the text already shows (e.g., "nine events" when the text lists all nine) is noise, not specificity. If a number isn't needed, leave it out. If imprecision is acceptable, use wording like "additional" or "several." Use a specific number only when the value itself matters for understanding the change AND isn't deducible from the rest of the text: percentages, thresholds, version numbers, limits.

Bad: "This enhancement significantly improves the developer experience."
Better: "The `quantityStart` and `quantityEnd` fields now require a minimum value of `1`."

Bad: "Nine events now implement `ShopwareEvent`."
Better: "Events dispatched during import/export, media validation, SEO URL persistence, and theme changes now implement `ShopwareEvent`."

### Don't Assume Intent

Never attribute motivation or intent to the original authors of code you're describing. "This was an oversight" or "the original developer forgot to..." are assumptions. You don't know why the code was written the way it was. Describe what the code does and what you changed, not why someone else made a past decision.

Bad: "This was an oversight. The dispatch just didn't pass Context in."
Better: "The dispatch sites had `Context` in scope but didn't pass it to the event constructors."

### Formatting Discipline

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
