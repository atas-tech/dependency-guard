#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
default_path="$repo_root"
default_slug="socket-dependency-guard"
default_name="Socket Dependency Guard"

usage() {
  cat <<EOF
Usage:
  publish_clawhub.sh --version <semver> [--path <skill-dir>] [--slug <skill-slug>] [--name <display-name>] [--changelog <text>] [--tags <tag1,tag2>] [--dry-run]

Examples:
  ./scripts/publish_clawhub.sh --version 1.0.0 --dry-run
  ./scripts/publish_clawhub.sh --version 1.0.0 --changelog "Initial ClawHub release"

Behavior:
  - validates the target skill bundle contains SKILL.md
  - requires the \`clawhub\` CLI on PATH
  - publishes the bundle with \`clawhub publish\`
EOF
}

version=""
skill_path="$default_path"
slug="$default_slug"
name="$default_name"
changelog=""
tags="latest"
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --path)
      skill_path="${2:-}"
      shift 2
      ;;
    --slug)
      slug="${2:-}"
      shift 2
      ;;
    --name)
      name="${2:-}"
      shift 2
      ;;
    --changelog)
      changelog="${2:-}"
      shift 2
      ;;
    --tags)
      tags="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ -z "$version" ]]; then
  echo "--version is required" >&2
  usage >&2
  exit 64
fi

if [[ ! -d "$skill_path" ]]; then
  echo "Skill path does not exist: $skill_path" >&2
  exit 66
fi

if [[ ! -f "$skill_path/SKILL.md" ]]; then
  echo "Skill path must contain SKILL.md: $skill_path" >&2
  exit 66
fi

cmd=(
  clawhub publish "$skill_path"
  --slug "$slug"
  --name "$name"
  --version "$version"
  --tags "$tags"
)

if [[ -n "$changelog" ]]; then
  cmd+=(--changelog "$changelog")
fi

if [[ "$dry_run" -eq 1 ]]; then
  printf 'dry_run=1\n'
  printf 'command='
  printf '%q ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

if ! command -v clawhub >/dev/null 2>&1; then
  echo "clawhub CLI not found on PATH. Install it with: npm i -g clawhub" >&2
  exit 69
fi

"${cmd[@]}"
