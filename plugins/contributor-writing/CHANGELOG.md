# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-27

### Added
- Initial release of contributor-writing plugin
- `release-info-writing` skill for drafting RELEASE_INFO and UPGRADE entries from branch analysis
- 5-phase workflow: detect target files, analyze branch scope, gather context, draft entries, write
- Classification decision tree for determining which files need entries
- Reference files for writing rules, entry examples, and file structure
- Anti-slop rules to prevent LLM-typical writing patterns (banned vocabulary, sentence rhythm, concreteness)
- GitHub tooling integration for PR analysis
