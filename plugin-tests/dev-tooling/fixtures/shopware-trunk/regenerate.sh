#!/usr/bin/env bash
# Rewrites the two package-scripts fixtures from a shopware/shopware checkout.
# Usage: regenerate.sh <shopware-checkout> [output-dir]
# The output directory defaults to the directory of this script. The checkout
# is only read.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    printf 'Usage: %s <shopware-checkout> [output-dir]\n' "${0##*/}" >&2
    exit 64
fi

checkout="$1"
output_dir="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# fixture file name -> package.json below the checkout
declare -A sources=(
    [administration-package-scripts.json]="src/Administration/Resources/app/administration/package.json"
    [storefront-package-scripts.json]="src/Storefront/Resources/app/storefront/package.json"
)

for fixture in "${!sources[@]}"; do
    package_json="${checkout}/${sources[${fixture}]}"
    if [[ ! -f "${package_json}" ]]; then
        printf 'No package.json at %s\n' "${package_json}" >&2
        exit 66
    fi
    # No -S: the fixtures keep the key order of the package.json.
    jq '.scripts' "${package_json}" > "${output_dir}/${fixture}"
done
