#!/bin/bash
# Fixtures for the chunkhound-integration sweep.sh suite.

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

SWEEP_SH="${REPO_ROOT}/plugins/chunkhound-integration/skills/researching-code/scripts/sweep.sh"

# Invoke sweep.sh, keeping stdout and stderr apart so that usage errors
# can be asserted on the stream the contract names.
# Sets: $status, $output (stdout), $stderr
run_sweep() {
    run --separate-stderr bash "${SWEEP_SH}" "$@"
}
