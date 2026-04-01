#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
skill_file="$repo_root/SKILL.md"

metadata_line="$(grep '^metadata:' "$skill_file")"

[[ "$metadata_line" == 'metadata: {"openclaw":{"emoji":"🛡️"}}' ]]

echo "openclaw frontmatter smoke test passed"
