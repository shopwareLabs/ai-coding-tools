# Security

## Reporting Vulnerabilities

To report a security vulnerability in this project, please open a [GitHub issue](https://github.com/shopwareLabs/claude-code-plugins/issues/new) with the label `security`. For sensitive disclosures, contact the Shopware Labs team directly via the Shopware GitHub organization.

We aim to acknowledge reports within 5 business days and will coordinate a fix and disclosure timeline with the reporter.

---

## DevSec Confirmation

This section documents the security baseline for this repository, as required for legal and compliance review.

**No automatic outbound network calls**
The marketplace infrastructure and all plugins operate locally. No plugin makes outbound network calls, telemetry uploads, crash reports, or update checks without explicit user-granted runtime permission through Claude Code's standard permission model. Every file access, bash command, and MCP tool invocation requires user approval at runtime.

**No hardcoded credentials or tokens**
The repository contains no hardcoded API keys, tokens, passwords, or credentials. All configuration examples use clearly marked placeholders (e.g. `YOUR_VOYAGEAI_KEY`). No `.env` files or credential files are committed.

**No personal or test data in repository or git history**
The repository (including full git history) contains no personal data, real user data, or test data containing personally identifiable information. All content is either source code, markdown documentation, JSON configuration schemas, or bash wrapper scripts.

---

## Third-Party Integration Wrapper Clarification

One plugin in this marketplace acts as a wrapper for an external tool:

**`chunkhound-integration`** invokes the user-installed `chunkhound` CLI binary via MCP server subprocess. The embedding provider (VoyageAI, OpenAI, or Ollama) and any associated API keys are configured exclusively in the user's own `.chunkhound.json` file using environment variables or local config. The plugin has no access to these credentials, does not read them, and makes no API calls itself. The data relationship exists solely between the user and their chosen provider.

Shopware Labs does not determine the technical means of any third-party processing performed by user-configured external services.
