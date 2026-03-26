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

## Message Formats

### Findings (after independent review)

```yaml
type: findings
reviewer: reviewer-{n}
findings:
  - rule_id: CONV-001
    enforce: must-fix
    location: ClassTest.php:45
    summary: "Description of violation"
    current: |
      # problematic code
    suggested: |
      # fixed code
```

### Debate Response (after receiving peer findings)

```yaml
type: debate
reviewer: reviewer-{n}
endorsements:
  - rule_id: CONV-001
    from: reviewer-2
    comment: "Agree — reason"
challenges:
  - rule_id: DESIGN-003
    from: reviewer-3
    reason: "Evidence from detection algorithm"
justifications:
  - rule_id: UNIT-003
    reason: "Evidence from code and detection algorithm"
concessions:
  - rule_id: ISOLATION-003
    reason: "Peer's argument is correct because..."
```

### Final Stance (after debate)

```yaml
type: final_stance
reviewer: reviewer-{n}
findings:
  - rule_id: CONV-001
    enforce: must-fix
    location: ClassTest.php:45
    current: |
      # code
    suggested: |
      # fix
withdrawn:
  - rule_id: ISOLATION-003
    reason: "Conceded after reviewer-2's argument"
```
