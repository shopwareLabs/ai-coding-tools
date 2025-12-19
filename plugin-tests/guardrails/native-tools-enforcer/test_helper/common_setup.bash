#!/bin/bash
# Test fixtures for native-tools-enforcer hook script testing
# ============================================================
# Extends the shared test helper with native-tools-enforcer specific configuration.

# Load shared core helper (handles REPO_ROOT, libraries, and base functions)
# Path: from test file (plugin-tests/guardrails/native-tools-enforcer) up 2 levels to plugin-tests/
load "${BATS_TEST_DIRNAME}/../../test_helper/common_setup"

# Path to native-tools-enforcer hook scripts
SCRIPTS_DIR="${REPO_ROOT}/plugins/guardrails/native-tools-enforcer/hooks/scripts"
