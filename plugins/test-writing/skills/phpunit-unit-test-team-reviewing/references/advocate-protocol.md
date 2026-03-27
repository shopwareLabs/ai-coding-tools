# Advocate Protocol

Rules for devil's advocate agents in the red team round. Distinct from the reviewer debate protocol — round 1 is cooperative, the advocate protocol is adversarial.

## Advocate Rules

1. **Challenge bias** — default stance is skepticism. For every consensus finding, ask: "Would this survive if someone pushed back harder?" If unclear, challenge it.

2. **Resurrection requires evidence** — when resurrecting a withdrawn finding, explain why the original concession was premature. Cite the detection algorithm and the code. "Reviewer-1 was right the first time because..." is a valid argument.

3. **New findings are permitted** — unlike round 1, advocates may introduce findings that no reviewer reported. These must follow standard format (rule_id, enforce, location, current, suggested) and cite the detection algorithm.

4. **Target weak concessions** — prioritize withdrawn findings where the concession reason is vague ("peer made a good point") or where the detection algorithm wasn't cited in the debate. These are the likeliest groupthink casualties.

5. **Don't challenge everything** — challenges must be substantive. Endorsing a consensus finding as correct is valid and expected for strong findings. Blanket opposition undermines credibility.

6. **Cross-file patterns are your weapon** — advocates see findings across files. If file A's consensus accepted a pattern that file B's consensus flagged as a violation, that inconsistency is a high-value challenge.

## Defense Round Rules

Rules for original reviewers responding to advocate challenges in Phase 7.

1. **"I already conceded" is not a defense** — if an advocate resurrects a finding you withdrew in round 1, engage with their argument on its merits. Your round 1 concession doesn't bind you. Reconsider.

2. **New findings get full treatment** — advocate-introduced findings must be challenged or conceded, same as round 1 peer findings.

3. **You may change your mind in either direction** — re-adopt a finding you previously withdrew, or withdraw a finding you previously defended, based on the advocate's argument.

4. **Round 2 final stance is binding** — replaces round 1 final stance as input to consensus merge.
