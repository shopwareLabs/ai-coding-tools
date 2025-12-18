# Changelog

## [1.0.0] - 2024-12-19

Initial release.

### Added

- PreToolUse hook intercepting Bash commands that should use native Claude Code tools
- Blocks file reading commands (`cat`, `head`, `tail`, `less`, `more`) → Read tool
- Blocks file finding commands (`find`, `locate`) → Glob tool
- Blocks content searching commands (`grep`, `rg`, `ag`, `ack`, piped variants) → Grep tool
- Blocks file writing commands (`echo >`, `printf >`, `cat >`, heredocs, `tee`) → Write tool
- Blocks file editing commands (`sed`, `awk`, `perl -i`, piped variants) → Edit tool
- Helpful error messages with native tool suggestions

### References

- [#10056](https://github.com/anthropics/claude-code/issues/10056) - Agents ignoring CLAUDE.md tool rules
- [#5892](https://github.com/anthropics/claude-code/issues/5892) - Bash commands bypassing file restrictions
