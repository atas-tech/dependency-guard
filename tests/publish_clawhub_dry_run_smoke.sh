#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

output="$("$repo_root/scripts/publish_clawhub.sh" --version 1.0.0 --dry-run --path "$repo_root")"

[[ "$output" == *"dry_run=1"* ]]
[[ "$output" == *"clawhub publish"* ]]
[[ "$output" == *"--version 1.0.0"* ]]

echo "publish_clawhub dry-run smoke test passed"
