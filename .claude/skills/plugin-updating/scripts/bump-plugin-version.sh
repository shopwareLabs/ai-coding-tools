#!/usr/bin/env bash
#
# Bumps a plugin's version in plugin.json and all SKILL.md frontmatters.
#
# Usage: bump-plugin-version.sh <plugin-name> <new-version>
#
# Updates in-place:
#   plugins/<plugin-name>/.claude-plugin/plugin.json  (top-level "version" field)
#   plugins/<plugin-name>/skills/*/SKILL.md           (frontmatter "version" field)
#
# Does NOT touch CHANGELOG.md (needs semantic content).
# Does NOT run `git add` (caller stages when ready).

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <plugin-name> <new-version>" >&2
  exit 64
fi

PLUGIN="$1"
NEW_VERSION="$2"

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "Error: '$NEW_VERSION' is not valid semver (X.Y.Z or X.Y.Z-pre)." >&2
  exit 64
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository." >&2
  exit 1
}

PLUGIN_DIR="$REPO_ROOT/plugins/$PLUGIN"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "Error: plugin directory not found: plugins/$PLUGIN" >&2
  exit 1
fi
if [ ! -f "$PLUGIN_JSON" ]; then
  echo "Error: plugin.json not found: plugins/$PLUGIN/.claude-plugin/plugin.json" >&2
  exit 1
fi

OLD_VERSION="$(awk '
  /^[[:space:]]*"version"[[:space:]]*:/ {
    match($0, /"version"[[:space:]]*:[[:space:]]*"[^"]*"/)
    v = substr($0, RSTART, RLENGTH)
    sub(/^"version"[[:space:]]*:[[:space:]]*"/, "", v)
    sub(/"$/, "", v)
    print v
    exit
  }
' "$PLUGIN_JSON")"
if [ -z "$OLD_VERSION" ]; then
  echo "Error: plugin.json has no top-level version field." >&2
  exit 1
fi

rel() { printf '%s' "${1#"$REPO_ROOT"/}"; }

# 1. plugin.json — surgical text replacement to preserve existing formatting
tmp="$(mktemp)"
awk -v v="$NEW_VERSION" '
  !done && /^[[:space:]]*"version"[[:space:]]*:/ {
    sub(/:[[:space:]]*"[^"]*"/, ": \"" v "\"")
    done = 1
  }
  { print }
' "$PLUGIN_JSON" > "$tmp"
mv "$tmp" "$PLUGIN_JSON"
printf '  %s  (%s -> %s)\n' "$(rel "$PLUGIN_JSON")" "$OLD_VERSION" "$NEW_VERSION"

# 2. SKILL.md frontmatters
SKILLS_DIR="$PLUGIN_DIR/skills"
missing_version=()
updated_count=0
if [ -d "$SKILLS_DIR" ]; then
  while IFS= read -r -d '' skill; do
    tmp="$(mktemp)"
    set +e
    awk -v ver="$NEW_VERSION" '
      BEGIN { fm_count = 0; in_fm = 0; found = 0 }
      /^---[[:space:]]*$/ {
        fm_count++
        if (fm_count == 1) { in_fm = 1 }
        else if (fm_count == 2) { in_fm = 0 }
        print; next
      }
      in_fm && /^version:[[:space:]]/ {
        print "version: " ver
        found = 1
        next
      }
      { print }
      END { exit (found ? 0 : 2) }
    ' "$skill" > "$tmp"
    awk_rc=$?
    set -e

    if [ "$awk_rc" -eq 0 ]; then
      mv "$tmp" "$skill"
      printf '  %s  (-> %s)\n' "$(rel "$skill")" "$NEW_VERSION"
      updated_count=$((updated_count + 1))
    elif [ "$awk_rc" -eq 2 ]; then
      rm -f "$tmp"
      missing_version+=("$(rel "$skill")")
    else
      rm -f "$tmp"
      echo "Error: awk failed on $skill" >&2
      exit 1
    fi
  done < <(find "$SKILLS_DIR" -type f -name SKILL.md -print0)
fi

echo
echo "Bumped plugin.json + $updated_count SKILL.md file(s) to $NEW_VERSION."

if [ "${#missing_version[@]}" -gt 0 ]; then
  echo
  echo "Warning: these SKILL.md files have no 'version:' field in their frontmatter:" >&2
  for f in "${missing_version[@]}"; do
    echo "  - $f" >&2
  done
  echo "Add a version field manually if they should be versioned." >&2
fi
