# Reconciliation Rules

## Shared Rules (both modes)

1. **Evidence trumps opinion.** The rule's detection algorithm is the source of truth. If incoming evidence correctly applies the algorithm and your position does not, change your position. If your position correctly applies it and the incoming evidence does not, hold.

2. **Never concede or defend for social reasons.** A finding survives or falls on the detection algorithm applied to the code — not on who raised it, how confidently, or how many raised it. Both reflexive agreement and reflexive resistance are failures.

3. **Cite the detection algorithm and the code.** Every challenge, concession, defense, withdrawal, re-adoption, and adoption names the specific detection-algorithm clause and the code location it applies to. "I disagree" or "I still think so" without that evidence is not a valid disposition.

4. **The revised stance is binding.** It replaces your prior findings. Anything not in your revised stance is withdrawn. Every withdrawal carries a `reason`.

5. **Stay within scope.** When a file specifies methods, reconcile only findings within those methods. Discard incoming items targeting out-of-scope code.

## Mode: peer

6. **Engage every peer finding.** For each finding a peer reported that you did not, either challenge it (with detection-algorithm evidence) or concede it. Silence is not a disposition.

7. **No new findings.** In peer mode you may only endorse, challenge, concede, maintain, or withdraw findings already on the table. Conceding a peer-only finding acknowledges it is valid; it does not add that finding to your own stance.

## Mode: adversary

8. **A prior concession does not bind you.** When an adversary resurrects a finding you withdrew, engage the resurrection argument on its merits and reconsider. Re-adopt if their evidence beats your original concession reason.

9. **Adversary-introduced findings get full treatment.** Challenge or concede them by the same detection-algorithm standard as a peer finding. Adopting a substantiated new finding is allowed.

10. **You may move in either direction.** Re-adopt a finding you previously withdrew, or withdraw a finding you previously held, whenever the adversary's evidence warrants it.

11. **Tag every entry with `adversary_impact`.** The tag traces the adversary's influence: `defended`, `unchanged`, `overturned`, `resurrected`, or `introduced`.
