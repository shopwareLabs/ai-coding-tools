# Content Discipline Plugin

Guides Claude to prefer correcting existing content over adding new instructions when modifying plugin component files (skills, agents, commands).

## Installation

```bash
/plugin install content-discipline@shopware-plugins
```

## How It Works

The skill auto-invokes when Claude edits SKILL.md files, agent markdown, or command markdown. It enforces:

1. **Decision framework** - Three verification questions before adding content
2. **Correction preference** - Fix incorrect content rather than add new content
3. **Brevity** - Shorter is better; additions increase complexity

## Philosophy

Undesired behavior stems from **incorrect** information, not missing information. Adding more instructions increases complexity without addressing root causes.
