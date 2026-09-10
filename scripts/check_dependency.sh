#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  check_dependency.sh <ecosystem> <package> [version] [--mode deep|shallow] [--output <path>]

Examples:
  check_dependency.sh npm zod
  check_dependency.sh npm react 19.1.0 --mode deep
  check_dependency.sh pypi requests 2.32.3 --output tmp/socket-report.md
  check_dependency.sh rust serde 1.0.219

Direct package ecosystems:
  npm|yarn|pnpm|bun|vlt       JavaScript and TypeScript (PURL: npm)
  pypi|python|pip|uv|poetry   Python (PURL: pypi)
  go|golang                   Go Modules (PURL: golang)
  maven|java|scala|kotlin     Maven/Gradle (PURL: maven)
  gem|ruby|rubygems            RubyGems (PURL: gem)
  nuget|dotnet                NuGet (PURL: nuget)
  cargo|rust                  Rust (PURL: cargo)
  composer|packagist|php      Composer (PURL: composer)

The helper maps "deep" to Socket's "socket package score" command. Use socket scan/ci for
repository-wide manifest and lockfile scans; see references/ecosystems.md.

This helper produces a Socket CLI markdown report artifact for agent review.
Interpret the result with references/decision-matrix.md.

Authentication:
  - Preferred: Socket MCP `depscore`
  - CLI fallback: `socket login`
  - If your installed CLI supports it, submitting a blank token may enable limited public access
  - Users with a private Socket token can also set SOCKET_SECURITY_API_TOKEN
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 64
fi

ecosystem="$1"
package="$2"
version=""
mode="deep"
output=""

shift 2

case "${ecosystem,,}" in
  npm|javascript|typescript|yarn|pnpm|bun|vlt)
    ecosystem="npm"
    ;;
  pypi|python|pip|uv|poetry|pdm)
    ecosystem="pypi"
    ;;
  golang|go)
    ecosystem="golang"
    ;;
  maven|java|scala|kotlin|gradle|sbt)
    ecosystem="maven"
    ;;
  gem|ruby|rubygems|bundler)
    ecosystem="gem"
    ;;
  nuget|dotnet)
    ecosystem="nuget"
    ;;
  cargo|rust)
    ecosystem="cargo"
    ;;
  composer|packagist|php)
    ecosystem="composer"
    ;;
  *)
    echo "Unsupported ecosystem: $ecosystem" >&2
    echo "See --help or references/ecosystems.md for supported direct package ecosystems." >&2
    exit 64
    ;;
esac

if [[ $# -gt 0 && "${1:-}" != --* ]]; then
  version="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --mode" >&2
        usage >&2
        exit 64
      fi
      mode="${2:-}"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --output" >&2
        usage >&2
        exit 64
      fi
      output="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ "$mode" != "deep" && "$mode" != "shallow" ]]; then
  echo "Invalid mode: $mode" >&2
  exit 64
fi

if [[ -z "$package" ]]; then
  echo "Package name must not be empty" >&2
  exit 64
fi

purl="pkg:${ecosystem}/${package}"
if [[ -n "$version" ]]; then
  purl="${purl}@${version}"
fi

if ! command -v socket >/dev/null 2>&1; then
  echo "Socket CLI not found. Install it first: npm install -g socket" >&2
  exit 69
fi

if [[ -z "$output" ]]; then
  mkdir -p tmp/socket-reports
  safe_name="${package//\//_}"
  output="tmp/socket-reports/${safe_name}-${mode}.md"
fi

mkdir -p "$(dirname "$output")"

socket_mode="score"
if [[ "$mode" == "shallow" ]]; then
  socket_mode="shallow"
fi

if ! socket package "$socket_mode" "$purl" --markdown >"$output"; then
  rm -f "$output"
  echo "Socket package lookup failed. Authenticate with \`socket login\` or set SOCKET_SECURITY_API_TOKEN. If your Socket CLI supports blank-submit login, that may enable limited public access." >&2
  exit 70
fi

cat <<EOF
status=report_generated
tool=socket-cli
mode=$mode
socket_command=$socket_mode
purl=$purl
report=$output
next_step=apply references/decision-matrix.md to the generated report before changing manifests or lockfiles
EOF
