#!/bin/bash
# Setup BATS (Bash Automated Testing System) for hook script testing
# ===================================================================
# Installs BATS and helper libraries to .bats/ directory.
# Run this once before running tests locally.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BATS_DIR="${REPO_ROOT}/.bats"

BATS_VERSION="1.11.0"
BATS_SUPPORT_VERSION="0.3.0"
BATS_ASSERT_VERSION="2.1.0"

echo "Installing BATS testing framework..."

# Clean existing installation
if [[ -d "$BATS_DIR" ]]; then
    echo "Removing existing .bats/ directory..."
    rm -rf "$BATS_DIR"
fi

mkdir -p "$BATS_DIR"

echo "Cloning bats-core v${BATS_VERSION}..."
git clone --depth 1 --branch "v${BATS_VERSION}" \
    https://github.com/bats-core/bats-core.git \
    "${BATS_DIR}/bats-core" 2>/dev/null

echo "Cloning bats-support v${BATS_SUPPORT_VERSION}..."
git clone --depth 1 --branch "v${BATS_SUPPORT_VERSION}" \
    https://github.com/bats-core/bats-support.git \
    "${BATS_DIR}/bats-support" 2>/dev/null

echo "Cloning bats-assert v${BATS_ASSERT_VERSION}..."
git clone --depth 1 --branch "v${BATS_ASSERT_VERSION}" \
    https://github.com/bats-core/bats-assert.git \
    "${BATS_DIR}/bats-assert" 2>/dev/null

echo ""
echo "BATS installed successfully to ${BATS_DIR}/"
echo ""
echo "Run all tests with:"
echo "  ${BATS_DIR}/bats-core/bin/bats plugin-tests/**/*.bats"
echo ""
echo "Or run specific plugin tests:"
echo "  ${BATS_DIR}/bats-core/bin/bats plugin-tests/guardrails/native-tools-enforcer/*.bats"
