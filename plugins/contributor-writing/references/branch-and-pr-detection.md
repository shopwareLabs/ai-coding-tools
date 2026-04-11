# Branch and PR Detection

Shared procedure for detecting the current branch, looking up an existing PR, and identifying the target branch. Skills execute this procedure at the start of their first phase, then apply skill-specific routing and diff gathering.

## Step 1 — Get Current Branch

```bash
git branch --show-current
```

If on `trunk` or `main`, stop: "This skill works on feature branches. Switch to a feature branch first."

## Step 2 — Look Up Existing PR

- If the user provided a PR number or URL, use `pr_view` to read it
- Otherwise, use `pr_list` filtered to the current branch
- If a PR exists, read its current title and description

## Step 3 — Identify Target Branch

- If a PR exists: read the `baseRefName` field. This is the target branch.
- If no PR exists: the skill defines the fallback (see routing table)

## Step 4 — Route by Target

| Target | Active skill | Action |
|---|---|---|
| `trunk` | pr-description-writing | Continue (target = `trunk`) |
| `trunk` | feature-branch-pr-writing | Stop: "This PR targets `trunk`. Use the `pr-description-writing` skill for trunk-targeting PRs." |
| `trunk` | commit-message-writing | Continue (base = `trunk`) |
| Non-trunk | pr-description-writing | Stop: "This PR targets a feature branch (`<branch>`), not `trunk`. Use the `feature-branch-pr-writing` skill for non-trunk PRs." |
| Non-trunk | feature-branch-pr-writing | Continue (target = detected branch) |
| Non-trunk | commit-message-writing | Continue (base = detected branch) |
| No PR found | pr-description-writing | Assume `trunk`, continue |
| No PR found | feature-branch-pr-writing | Stop: "No PR found and target branch is unknown. Create a PR targeting the feature branch first, or use `pr-description-writing` for trunk-targeting work." |
| No PR found | commit-message-writing | Ask user: "No PR found for this branch. What's the target branch for the squash merge?" |
