# Comparison Strategies

How to contrast Phase 1 intuitive impressions against the Phase 2 consensus package. Work through each strategy per file.

## Gap Analysis

Map each Phase 1 concern to consensus findings:

1. For each concern from your intuitive scan, search the consensus findings for a matching rule_id or location
2. **Unmatched concerns** (you flagged it, consensus didn't) are the highest-value candidates for new findings. These represent what the reviewers' rule-driven framework missed.
3. **Unmatched consensus findings** (consensus flagged it, you didn't) — evaluate whether this is something you'd endorse or whether it feels like a false positive

## Strength Assessment

For each consensus finding, assess its robustness:

1. Did your Phase 1 intuitive scan independently flag the same area? If yes, the finding is likely strong — endorse it.
2. If you didn't flag it independently, ask: did the reviewers see something you missed, or did they anchor to a rule that doesn't genuinely apply here?
3. MAJORITY findings (2-of-3) are inherently weaker than UNANIMOUS (3-of-3). Prioritize challenging MAJORITY findings where your intuition disagrees.

## Withdrawal Scrutiny

For each withdrawn finding in the consensus package, evaluate the concession:

1. **Vague concession reason**: "peer made a good point" or "agreed after discussion" without citing the specific detection algorithm — flag for resurrection
2. **Uncited algorithm**: the reviewer conceded without referencing the rule's detection algorithm — the concession may be social rather than evidence-based
3. **Bandwagon concession**: only one reviewer pushed back, and the others followed without independent reasoning — classic groupthink pattern
4. **Intuition alignment**: your Phase 1 scan flagged the same area the withdrawn finding covered — strong signal for resurrection

## Assumption Surfacing

For each consensus finding, state the unstated premise:

1. "This finding assumes the test should cover X" — is that assumption valid for this source class's role?
2. "This finding assumes the mocking strategy in setUp() is correct" — but what if the setUp() itself is the problem?
3. "This finding assumes the test categories are correctly detected" — verify the category assignment
4. Look for findings that are technically correct but solve the wrong problem — the reviewers may have applied a rule correctly to code that shouldn't exist in the first place
