#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
mkdir -p "$project_dir/.github/workflows" "$project_dir/requirements" "$project_dir/target" "$project_dir/vendor"
touch \
  "$project_dir/Package.swift" \
  "$project_dir/Package.resolved" \
  "$project_dir/conanfile.txt" \
  "$project_dir/Project.toml" \
  "$project_dir/pubspec.yaml" \
  "$project_dir/mix.exs" \
  "$project_dir/requirements/dev.txt" \
  "$project_dir/action.yaml" \
  "$project_dir/Cargo.lock" \
  "$project_dir/.github/workflows/ci.yml" \
  "$project_dir/target/Cargo.toml" \
  "$project_dir/vendor/composer.json"

output="$("$repo_root/scripts/discover_scan_targets.sh" "$project_dir")"

[[ "$output" == *"ecosystem=rust"* ]]
[[ "$output" == *"ecosystem=github-actions"* ]]
[[ "$output" == *"file=action.yaml"* ]]
[[ "$output" == *"file=requirements/dev.txt"* ]]
[[ "$output" == *"ecosystem=swift"* ]]
[[ "$output" == *"coverage=GA; CVE-only"* ]]
[[ "$output" == *"ecosystem=cpp"* ]]
[[ "$output" == *"ecosystem=julia"* ]]
[[ "$output" == *"ecosystem=dart"* ]]
[[ "$output" == *"ecosystem=elixir"* ]]
[[ "$output" == *"warning=Workflow scanning only"* ]]
[[ "$output" == *"warning=Socket scores are CVE-only"* ]]
[[ "$output" == *"recommended_command=socket scan create"* ]]
[[ "$output" != *"target/Cargo.toml"* ]]
[[ "$output" != *"vendor/composer.json"* ]]

echo "discover_scan_targets smoke test passed"
