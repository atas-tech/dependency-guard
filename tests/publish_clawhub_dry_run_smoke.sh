#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
skill_file="$repo_root/SKILL.md"
before_contents="$(cat "$skill_file")"
current_version="$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep -E '^version:' | head -1 | sed 's/^version:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/')"
IFS='.' read -r major minor patch <<< "$current_version"
expected_version="${major}.${minor}.$((patch + 1))"

output="$("$repo_root/scripts/publish_clawhub.sh" --bump patch --dry-run)"
after_contents="$(cat "$skill_file")"

[[ "$output" == *"dry_run=1"* ]]
[[ "$output" == *"version_bumped=${current_version} -> ${expected_version}"* ]]
[[ "$output" == *"clawhub publish"* ]]
[[ "$output" == *"version=${expected_version}"* ]]
[[ "$output" == *"staged_files:"* ]]
[[ "$output" == *"SKILL.md"* ]]
[[ "$output" == *"scripts/discover_scan_targets.sh"* ]]
[[ "$before_contents" == "$after_contents" ]]

echo "publish_clawhub dry-run smoke test passed"
