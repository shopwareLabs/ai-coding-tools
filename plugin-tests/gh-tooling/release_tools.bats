#!/usr/bin/env bats
# bats file_tags=gh-tooling,read-tools
# Tests for the release_list read tool
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/gh-tooling"
GH_LIB_DIR="${PLUGIN_DIR}/mcp-server-gh/lib"

# Releases out of semver order on purpose: a lexicographic sort would rank v9
# above v10. Includes a prerelease and an older major line to exercise filtering.
RELEASES_FIXTURE='[
  {"tag_name":"v9.0.0","name":"9.0.0","draft":false,"prerelease":false,"published_at":"2024-01-01T00:00:00Z","html_url":"https://github.com/a/b/releases/v9.0.0"},
  {"tag_name":"v10.0.0","name":"10.0.0","draft":false,"prerelease":false,"published_at":"2024-02-01T00:00:00Z","html_url":"https://github.com/a/b/releases/v10.0.0"},
  {"tag_name":"v10.1.0-rc.1","name":"10.1.0-rc.1","draft":false,"prerelease":true,"published_at":"2024-03-01T00:00:00Z","html_url":"https://github.com/a/b/releases/v10.1.0-rc.1"},
  {"tag_name":"v4.2.0","name":"4.2.0","draft":false,"prerelease":false,"published_at":"2023-01-01T00:00:00Z","html_url":"https://github.com/a/b/releases/v4.2.0"},
  {"tag_name":"v4.1.0","name":"4.1.0","draft":false,"prerelease":false,"published_at":"2022-01-01T00:00:00Z","html_url":"https://github.com/a/b/releases/v4.1.0"}
]'

setup() {
    log() { :; }
    GH_DEFAULT_REPO="a/b"
    GH_TOOLING_CONFIG_FILE=""
    source "${GH_LIB_DIR}/common.sh"
    source "${GH_LIB_DIR}/release.sh"

    GH_STUB_SHA="deadbeefcafe1234"

    # The /releases endpoint returns the fixture; a /commits/<tag> lookup (used by
    # resolve_sha) simulates gh's --jq output and returns a bare SHA.
    gh() {
        local endpoint="$2"
        if [[ "${endpoint}" == *"/commits/"* ]]; then
            printf '%s\n' "${GH_STUB_SHA}"
            return 0
        fi
        printf '%s\n' "${RELEASES_FIXTURE}"
        return 0
    }
}

@test "release_list returns the highest semantic version as latest" {
    run tool_release_list '{"repo":"a/b","jq_filter":".[0].tag_name"}'
    assert_success
    assert_output '"v10.0.0"'
}

@test "release_list includes prereleases when asked and ranks the rc highest" {
    run tool_release_list '{"repo":"a/b","include_prereleases":true,"jq_filter":".[0].tag_name"}'
    assert_success
    assert_output '"v10.1.0-rc.1"'
}

@test "release_list with latest false returns every stable release" {
    run tool_release_list '{"repo":"a/b","latest":false,"jq_filter":"length"}'
    assert_success
    assert_output "4"
}

@test "release_list constraint pins to the highest version in a major line" {
    run tool_release_list '{"repo":"a/b","constraint":"4","jq_filter":".[0].tag_name"}'
    assert_success
    assert_output '"v4.2.0"'
}

@test "release_list constraint accepts a major.minor prefix" {
    run tool_release_list '{"repo":"a/b","constraint":"4.1","jq_filter":".[0].tag_name"}'
    assert_success
    assert_output '"v4.1.0"'
}

@test "release_list fields returns only the requested keys" {
    run tool_release_list '{"repo":"a/b","fields":["tag_name"]}'
    assert_success
    assert_output --partial '"tag_name"'
    refute_output --partial 'html_url'
}

@test "release_list batch returns one entry per repo labeled with its repo" {
    run tool_release_list '{"repos":["a/b","c/d"],"fields":["repo"]}'
    assert_success
    assert_output --partial '"a/b"'
    assert_output --partial '"c/d"'
}

@test "release_list resolve_sha adds the commit SHA for each release" {
    run tool_release_list '{"repo":"a/b","resolve_sha":true,"fields":["tag_name","commit_sha"]}'
    assert_success
    assert_output --partial '"commit_sha": "deadbeefcafe1234"'
}

@test "release_list rejects an unsupported constraint format" {
    run tool_release_list '{"repo":"a/b","constraint":">=4"}'
    assert_failure
    assert_output --partial "constraint must be a major"
}

@test "release_list rejects an unknown field name" {
    run tool_release_list '{"repo":"a/b","fields":["tagname"]}'
    assert_failure
    assert_output --partial "unknown field(s): tagname"
}
