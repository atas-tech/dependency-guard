#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  discover_scan_targets.sh [path]

Find supported dependency manifests and lockfiles under a repository and print
the Socket scan coverage and any CVE-only or experimental limitations.

This is discovery only. It does not authenticate with Socket or run a scan.
After reviewing the output, run `socket scan create <path>` locally or `socket ci` in CI.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  echo "Expected zero or one path argument" >&2
  usage >&2
  exit 64
fi

scan_root="${1:-.}"
if [[ ! -d "$scan_root" ]]; then
  echo "Scan path is not a directory: $scan_root" >&2
  exit 66
fi
scan_root="$(cd "$scan_root" && pwd)"

declare -A detected_files=()
declare -A coverage=()
declare -A warnings=()
declare -A labels=()

labels[javascript]="JavaScript/TypeScript"
labels[python]="Python"
labels[go]="Go"
labels[jvm]="Java/Scala/Kotlin"
labels[ruby]="Ruby"
labels[dotnet]=".NET"
labels[rust]="Rust"
labels[php]="PHP"
labels[github-actions]="GitHub Actions"
labels[swift]="Swift"
labels[cpp]="C/C++"
labels[julia]="Julia"
labels[dart]="Dart"
labels[elixir]="Elixir/Erlang"

coverage[javascript]="GA"
coverage[python]="GA"
coverage[go]="GA"
coverage[jvm]="GA"
coverage[ruby]="GA"
coverage[dotnet]="GA"
coverage[rust]="GA"
coverage[php]="Beta"
coverage[github-actions]="Experimental"
coverage[swift]="GA; CVE-only"
coverage[cpp]="GA; CVE-only"
coverage[julia]="GA; CVE-only"
coverage[dart]="GA; CVE-only"
coverage[elixir]="GA; CVE-only"

warnings[php]="Composer support is less mature; state the limitation in the review."
warnings[github-actions]="Workflow scanning only; this is not a package-level depscore review."
warnings[swift]="Socket scores are CVE-only while full Swift support is in progress; do not classify from full health-score criteria."
warnings[cpp]="C/C++ coverage is CVE-only and may require Socket Basics; do not infer full supply-chain scores."
warnings[julia]="Julia coverage is CVE-only and may require Socket Basics; do not infer full supply-chain scores."
warnings[dart]="Dart coverage is CVE-only and may require Socket Basics; do not infer full supply-chain scores."
warnings[elixir]="Elixir/Erlang coverage is CVE-only and may require Socket Basics; do not infer full supply-chain scores."

record_file() {
  local ecosystem="$1"
  local relative_path="$2"

  if [[ -n "${detected_files[$ecosystem]:-}" ]]; then
    detected_files[$ecosystem]+=$'\n'
  fi
  detected_files[$ecosystem]+="$relative_path"
}

while IFS= read -r -d '' file; do
  relative_path="${file#"$scan_root"/}"
  basename="${file##*/}"

  case "$relative_path" in
    .github/workflows/*.yml|.github/workflows/*.yaml|.github/workflow.yml|.github/workflow.yaml)
      record_file github-actions "$relative_path"
      continue
      ;;
    action.yml|action.yaml)
      record_file github-actions "$relative_path"
      continue
      ;;
  esac

  case "$relative_path" in
    requirements/*.txt)
      record_file python "$relative_path"
      continue
      ;;
  esac

  case "$basename" in
    package.json|package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|pnpm-lock.yml|pnpm-workspace.yaml|pnpm-workspace.yml|rush.json|bun.lock|bun.lockb|vlt-lock.json)
      record_file javascript "$relative_path"
      ;;
    pyproject.toml|poetry.lock|uv.lock|pylock.toml|pylock.*.toml|Pipfile|Pipfile.lock|setup.py|PKG-INFO|METADATA|requirements*.txt|requirements*.lock|requirements.frozen)
      record_file python "$relative_path"
      ;;
    go.mod|go.sum)
      record_file go "$relative_path"
      ;;
    pom.xml|*.pom|*.gradle|*.gradle.kts|gradle.lockfile|libs.versions.toml|build.sbt|ivy.xml|project.clj|Buildfile|maven_install.json|*_maven_install.json)
      record_file jvm "$relative_path"
      ;;
    Gemfile|Gemfile.lock|*.gemspec)
      record_file ruby "$relative_path"
      ;;
    *.sln|*.*proj|*.nuspec|packages.config|packages.*.config|packages.lock.json)
      record_file dotnet "$relative_path"
      ;;
    Cargo.toml|Cargo.lock)
      record_file rust "$relative_path"
      ;;
    composer.json|composer.lock)
      record_file php "$relative_path"
      ;;
    Package.swift|Package.resolved)
      record_file swift "$relative_path"
      ;;
    conanfile.py|conanfile.txt|conanfile.*)
      record_file cpp "$relative_path"
      ;;
    Project.toml|Manifest.toml)
      record_file julia "$relative_path"
      ;;
    pubspec.yaml|pubspec.lock)
      record_file dart "$relative_path"
      ;;
    mix.exs|mix.lock)
      record_file elixir "$relative_path"
      ;;
  esac
done < <(
  find "$scan_root" \
    -type d \( -name .git -o -name node_modules -o -name target -o -name vendor -o -name dist -o -name build -o -name .gradle -o -name .venv -o -name venv -o -name .dart_tool -o -name _build -o -name deps \) -prune \
    -o -type f -print0
)

ecosystem_order=(javascript python go jvm ruby dotnet rust php github-actions swift cpp julia dart elixir)
found=0

printf 'scan_root=%s\n' "$scan_root"
printf 'discovery=manifest_and_lockfile_inventory\n'
for ecosystem in "${ecosystem_order[@]}"; do
  if [[ -z "${detected_files[$ecosystem]:-}" ]]; then
    continue
  fi

  found=1
  printf 'ecosystem=%s\n' "$ecosystem"
  printf 'label=%s\n' "${labels[$ecosystem]}"
  printf 'coverage=%s\n' "${coverage[$ecosystem]}"
  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] && printf 'file=%s\n' "$relative_path"
  done <<< "${detected_files[$ecosystem]}"
  if [[ -n "${warnings[$ecosystem]:-}" ]]; then
    printf 'warning=%s\n' "${warnings[$ecosystem]}"
  fi
done

if [[ "$found" -eq 0 ]]; then
  printf 'result=no_known_manifests\n'
else
  printf 'result=known_manifests_found\n'
fi

printf 'direct_package_helper=Only the direct package ecosystems in references/ecosystems.md are accepted by check_dependency.sh.\n'
printf 'recommended_command=socket scan create %q\n' "$scan_root"
