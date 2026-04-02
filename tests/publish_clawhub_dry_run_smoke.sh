#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
skill_file="$repo_root/SKILL.md"
before_contents="$(cat "$skill_file")"

output="$("$repo_root/scripts/publish_clawhub.sh" --bump patch --dry-run)"
after_contents="$(cat "$skill_file")"

[[ "$output" == *"dry_run=1"* ]]
[[ "$output" == *"version_bumped=1.0.0 -> 1.0.1"* ]]
[[ "$output" == *"clawhub publish"* ]]
[[ "$output" == *"version=1.0.1"* ]]
[[ "$output" == *"staged_files:"* ]]
[[ "$output" == *"SKILL.md"* ]]
[[ "$before_contents" == "$after_contents" ]]

echo "publish_clawhub dry-run smoke test passed"
