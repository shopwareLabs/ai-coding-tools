---
name: content-disciplining
version: 1.0.0
description: Evaluates proposed changes to plugin component files (skills, agents, commands) and guides toward corrections over additions. MUST invoke when editing SKILL.md files, modifying agent markdown in agents/, updating command markdown in commands/, adding new sections or instructions, expanding skill content, user says "is this too long", "content bloat", "should I add this", or improving/enhancing skills.
allowed-tools: Read
---

# Content Discipline

Enforce the principle: **prefer correcting existing content over adding new instructions**.

## Core Principle

Undesired behavior stems from **incorrect** information, not missing information. Adding more instructions increases complexity without addressing root causes. Shorter is better.

## Decision Framework

**Before adding new content, ask:**

1. Does existing content already address this behavior incorrectly?
   - If YES: Correct the existing content instead of adding
2. Can the issue be fixed by clarifying or rewording current instructions?
   - If YES: Modify existing wording instead of adding
3. Would adding content create redundancy or conflict with existing guidance?
   - If YES: Consolidate or remove conflicting content first

**Only add new content when ALL conditions are met:**
- The capability genuinely doesn't exist in current instructions
- Existing content cannot reasonably be extended to cover the case
- The addition addresses a distinct, orthogonal concern

## When Addition is Warranted

If adding is truly necessary:
- Consider **progressive disclosure** - move detailed content to `references/`
- Consider **agent delegation** - split responsibilities into focused agents
- Keep additions **orthogonal** - distinct from existing content

Balance is key—additions are appropriate when they fill genuine gaps.
