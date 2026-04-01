#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

shopt -s nullglob
tests=("$repo_root"/tests/*_smoke.sh)

if [[ ${#tests[@]} -eq 0 ]]; then
  echo "No smoke tests found under $repo_root/tests" >&2
  exit 1
fi

for test_script in "${tests[@]}"; do
  echo "Running $(basename "$test_script")"
  bash "$test_script"
done

echo "All smoke tests passed"
