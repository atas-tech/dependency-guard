#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

output="$("$repo_root/scripts/check_dependency.sh" --help)"

[[ "$output" == *"Usage:"* ]]
[[ "$output" == *"check_dependency.sh <ecosystem> <package> [version]"* ]]
[[ "$output" == *"Socket CLI markdown report artifact"* ]]

echo "check_dependency help smoke test passed"
