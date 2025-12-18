@README.md

## Directory & File Structure

```
plugins/guardrails/native-tools-enforcer/
├── README.md
├── AGENTS.md
├── CLAUDE.md
└── hooks/
    ├── hooks.json                    # PreToolUse hook configuration
    └── scripts/
        └── check-native-tools.sh     # Pattern matching & blocking logic
```

## Component Overview

This plugin provides:
- **PreToolUse Hook** (`hooks/hooks.json`) - Intercepts Bash tool calls
- **Validation Script** (`hooks/scripts/check-native-tools.sh`) - Blocks commands with native tool suggestions

**No commands, agents, skills, or MCP servers** - hooks-only plugin.

## Key Navigation Points

| Task | Primary File | Key Concepts |
|------|--------------|--------------|
| Add blocked command | `check-native-tools.sh` | Add `check_and_block` call in category section |
| Change block message | `check-native-tools.sh` | Edit `check_and_block()` function output |
| Adjust hook timeout | `hooks.json` | `timeout` field (default: 5s) |
| Update pattern regex | `check-native-tools.sh` | First argument to `check_and_block` |

## When to Modify What

**Adding new blocked command** → Add `check_and_block` call in appropriate category section of `check-native-tools.sh`

**Changing message format** → Edit `check_and_block()` function body in `check-native-tools.sh`

**Adjusting pattern sensitivity** → Modify regex (first arg); use `(^|;|&&)` to avoid false positives

## Integration Points

- **jq** dependency for JSON parsing
- Affects all Bash invocations (main conversation + agents)
- Requires Claude Code restart after installation

## Testing

```bash
# Should block (exit 2)
echo '{"tool_input": {"command": "grep foo"}}' | ./hooks/scripts/check-native-tools.sh

# Should allow (exit 0)
echo '{"tool_input": {"command": "git status"}}' | ./hooks/scripts/check-native-tools.sh
```

## Related Documentation

- [Official hook example](https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py)
- Related issues: [#1386](https://github.com/anthropics/claude-code/issues/1386), [#10056](https://github.com/anthropics/claude-code/issues/10056), [#5892](https://github.com/anthropics/claude-code/issues/5892)
