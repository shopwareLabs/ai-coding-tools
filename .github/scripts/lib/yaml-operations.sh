#!/bin/bash
#
# yaml-operations.sh
#
# YAML manipulation functions for issue template dropdowns.
# Provides extraction and update operations for dropdown options in YAML files.
#
# Usage:
#   source lib/yaml-operations.sh
#   options=$(extract_dropdown_options "$file" "$dropdown_id")
#   update_dropdown "$file" "$dropdown_id" "${options[@]}"
#

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "Error: This is a library file and should be sourced, not executed directly." >&2
  exit 1
fi

# Extract dropdown options from YAML file
# Args: file_path dropdown_id
# Output: One option per line, sorted, "Other" excluded
extract_dropdown_options() {
  local file="$1"
  local dropdown_id="$2"

  # Extract options from YAML using awk
  awk -v id="$dropdown_id" '
    BEGIN { in_dropdown=0; in_options=0 }

    # Found the target dropdown by id
    /^  - type: dropdown/ { in_dropdown=0 }
    /id: / {
      if ($0 ~ "id: " id "$") {
        in_dropdown=1
      }
    }

    # Found options within target dropdown
    /^    attributes:/ && in_dropdown { in_options=0 }
    /^      options:/ && in_dropdown {
      in_options=1
      next
    }

    # Print options (skip "Other")
    in_options {
      if (/^      [a-z]/ || /^    [a-z]/ || /^  - type:/) {
        in_options=0
      } else if (/^        - /) {
        option = substr($0, 11)
        if (option != "Other") {
          print option
        }
      }
    }
  ' "$file" | sort
}

# Update dropdown options in YAML file
# Args: file_path dropdown_id option1 option2 ...
# Creates backup file with .bak extension
update_dropdown() {
  local file="$1"
  local dropdown_id="$2"
  shift 2
  local options=("$@")

  # Create backup
  cp "$file" "${file}.bak"

  # Build the options YAML (8 spaces indentation)
  local options_yaml=""
  for option in "${options[@]}"; do
    options_yaml+="        - $option\n"
  done
  options_yaml+="        - Other"

  # Use awk to replace the options section for the specific dropdown
  awk -v id="$dropdown_id" -v opts="$options_yaml" '
    BEGIN { in_dropdown=0; in_options=0; skip=0 }

    # Found the target dropdown by id
    /^  - type: dropdown/ { in_dropdown=0 }
    /id: / {
      if ($0 ~ "id: " id "$") {
        in_dropdown=1
      }
    }

    # Found options within target dropdown
    /^    attributes:/ && in_dropdown { in_options=0 }
    /^      options:/ && in_dropdown {
      print
      printf "%s\n", opts
      in_options=1
      skip=1
      next
    }

    # Skip old options until next field
    in_options && skip {
      if (/^      [a-z]/ || /^    [a-z]/ || /^  - type:/) {
        skip=0
        in_options=0
      } else {
        next
      }
    }

    # Print all other lines
    { print }
  ' "${file}.bak" > "$file"
}
