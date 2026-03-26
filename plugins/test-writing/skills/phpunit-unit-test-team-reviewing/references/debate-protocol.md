# Debate Protocol

Rules for structured debate between reviewers in a team-based test review.

## Rules

1. **Engage with every peer finding** — for each finding reported by a peer that you did NOT report, you MUST either challenge it (with reasoning) or concede (acknowledging it's valid). Silence is not acceptable.

2. **Challenges must cite the detection algorithm** — when challenging a peer's finding, reference the specific detection algorithm from the rule's markdown body. "I disagree" without evidence from the rule is not a valid challenge.

3. **Evidence trumps opinion** — if a peer's argument correctly applies the rule's detection algorithm and yours does not, you MUST concede. The detection algorithm is the source of truth.

4. **No new findings during debate** — you may only defend, challenge, endorse, or withdraw existing findings. Adding a new finding that wasn't in your original report is prohibited.

5. **Justifications must cite code** — when justifying a finding that only you reported, include the specific code location and explain which part of the detection algorithm it triggers.

6. **Final stance is binding** — your final stance replaces your original findings. Anything not in your final stance is considered withdrawn.

7. **Withdrawn findings need reasons** — every finding you withdraw in your final stance must include a `reason` explaining why (typically referencing a peer's argument).

8. **Cross-file references are valid evidence** — when debating a finding in file A, you may cite a pattern observed in file B that you also reviewed. Cross-file references carry the same weight as rule detection algorithm citations. Use the `cross_file_references` format in your debate response.

9. **Cross-file references must be first-hand** — you may only reference files you were assigned to and actually reviewed. You cannot cite a pattern described by a peer in their findings for a file you did not review. If a peer's cross-file reference cites a file you also reviewed, you may endorse or challenge it.

10. **Consistency is a supporting argument, not a standalone finding** — a cross-file reference strengthens or weakens an existing finding — it does not create a new one. "File B does it differently" is not itself a violation. It supports an argument like "this file's approach violates ISOLATION-002, and file B demonstrates the correct pattern."
