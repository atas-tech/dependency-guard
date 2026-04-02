#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
skill_file="$repo_root/SKILL.md"
default_slug="dependency-guard"
default_name="Dependency Guard"

usage() {
  cat <<EOF
Usage:
  publish_clawhub.sh [--bump patch|minor|major] [--version <semver>] [--slug <skill-slug>] [--name <display-name>] [--changelog <text>] [--tags <tag1,tag2>] [--dry-run]

Version resolution (first match wins):
  1. --bump patch|minor|major   reads current version from SKILL.md, bumps it, and persists it after publish
  2. --version X.Y.Z            uses the given version literally (does not update SKILL.md)
  3. (neither)                   reads current version from SKILL.md as-is

The version field in SKILL.md frontmatter is the single source of truth.

Bundle staging:
  The publish bundle is assembled in a temporary directory containing only
  the files relevant to OpenClaw consumers:
    SKILL.md, references/, scripts/check_dependency.sh, examples/, LICENSE

Examples:
  ./scripts/publish_clawhub.sh --bump patch --dry-run
  ./scripts/publish_clawhub.sh --bump minor --changelog "Add requires.bins metadata"
  ./scripts/publish_clawhub.sh --version 2.0.0 --changelog "Breaking: require socket CLI"
  ./scripts/publish_clawhub.sh --dry-run
EOF
}

# --- helpers ----------------------------------------------------------------

read_version() {
  # Extract version: "X.Y.Z" from SKILL.md frontmatter
  sed -n '/^---$/,/^---$/p' "$skill_file" \
    | grep -E '^version:' \
    | head -1 \
    | sed 's/^version:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$/\1/'
}

write_version() {
  local new_version="$1"
  local tmp
  tmp="$(mktemp)"

  sed "s/^version:.*$/version: \"${new_version}\"/" "$skill_file" >"$tmp"
  mv "$tmp" "$skill_file"
}

write_version_in_file() {
  local file="$1"
  local new_version="$2"
  local tmp
  tmp="$(mktemp)"

  sed "s/^version:.*$/version: \"${new_version}\"/" "$file" >"$tmp"
  mv "$tmp" "$file"
}

bump_version() {
  local current="$1"
  local component="$2"

  local major minor patch
  IFS='.' read -r major minor patch <<< "$current"

  # Default to 0 if any component is empty
  major="${major:-0}"
  minor="${minor:-0}"
  patch="${patch:-0}"

  case "$component" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
    *)
      echo "Invalid bump component: $component (use patch, minor, or major)" >&2
      exit 64
      ;;
  esac

  echo "${major}.${minor}.${patch}"
}

stage_bundle() {
  local staging="$1"
  mkdir -p "$staging"

  # Core skill file
  cp "$repo_root/SKILL.md" "$staging/SKILL.md"

  # References
  mkdir -p "$staging/references"
  cp "$repo_root/references/"*.md "$staging/references/"

  # CLI helper script
  mkdir -p "$staging/scripts"
  cp "$repo_root/scripts/check_dependency.sh" "$staging/scripts/check_dependency.sh"
  chmod +x "$staging/scripts/check_dependency.sh"

  # CI example
  mkdir -p "$staging/examples/github"
  cp "$repo_root/examples/github/dependency-guard.yml" "$staging/examples/github/dependency-guard.yml"

  # License
  if [[ -f "$repo_root/LICENSE" ]]; then
    cp "$repo_root/LICENSE" "$staging/LICENSE"
  fi
}

# --- argument parsing -------------------------------------------------------

version=""
bump=""
bump_requested=0
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
    --bump)
      bump="${2:-}"
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

# --- validate ---------------------------------------------------------------

if [[ ! -f "$skill_file" ]]; then
  echo "SKILL.md not found at: $skill_file" >&2
  exit 66
fi

if [[ -n "$bump" && -n "$version" ]]; then
  echo "--bump and --version are mutually exclusive" >&2
  exit 64
fi

# --- resolve version --------------------------------------------------------

if [[ -n "$bump" ]]; then
  current_version="$(read_version)"
  if [[ -z "$current_version" ]]; then
    echo "Could not read version from SKILL.md frontmatter" >&2
    exit 65
  fi
  version="$(bump_version "$current_version" "$bump")"
  bump_requested=1
  echo "version_bumped=${current_version} -> ${version}"
elif [[ -z "$version" ]]; then
  version="$(read_version)"
  if [[ -z "$version" ]]; then
    echo "No version found in SKILL.md and no --version or --bump given" >&2
    exit 65
  fi
  echo "version_from_skill=${version}"
fi

# --- stage clean bundle -----------------------------------------------------

staging_dir="$(mktemp -d)"
trap 'rm -rf "$staging_dir"' EXIT

stage_bundle "$staging_dir"
if [[ "$bump_requested" -eq 1 ]]; then
  write_version_in_file "$staging_dir/SKILL.md" "$version"
fi

# --- build command ----------------------------------------------------------

if [[ "$dry_run" -eq 0 ]] && ! command -v clawhub >/dev/null 2>&1; then
  echo "clawhub CLI not found on PATH. Install it with: npm i -g clawhub" >&2
  exit 69
fi

cmd=(
  clawhub publish "$staging_dir"
  --slug "$slug"
  --name "$name"
  --version "$version"
  --tags "$tags"
)

if [[ -n "$changelog" ]]; then
  cmd+=(--changelog "$changelog")
fi

# --- execute ----------------------------------------------------------------

if [[ "$dry_run" -eq 1 ]]; then
  printf 'dry_run=1\n'
  printf 'version=%s\n' "$version"
  printf 'staging_dir=%s\n' "$staging_dir"
  printf 'staged_files:\n'
  find "$staging_dir" -type f | sed "s|$staging_dir/||" | sort | sed 's/^/  /'
  printf 'command='
  printf '%q ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

"${cmd[@]}"

if [[ "$bump_requested" -eq 1 ]]; then
  write_version "$version"
fi
