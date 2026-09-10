#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/socket" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$SOCKET_ARGS_FILE"
printf 'Socket mock report\n'
EOF
chmod +x "$tmp_dir/socket"

export SOCKET_ARGS_FILE="$tmp_dir/socket-args"
report="$tmp_dir/rust-report.md"
output="$(PATH="$tmp_dir:$PATH" "$repo_root/scripts/check_dependency.sh" rust serde 1.0.219 --output "$report")"

[[ "$output" == *"mode=deep"* ]]
[[ "$output" == *"socket_command=score"* ]]
[[ "$output" == *"purl=pkg:cargo/serde@1.0.219"* ]]
[[ "$(sed -n '1p' "$SOCKET_ARGS_FILE")" == "package" ]]
[[ "$(sed -n '2p' "$SOCKET_ARGS_FILE")" == "score" ]]
[[ "$(sed -n '3p' "$SOCKET_ARGS_FILE")" == "pkg:cargo/serde@1.0.219" ]]
[[ "$(sed -n '4p' "$SOCKET_ARGS_FILE")" == "--markdown" ]]
[[ -f "$report" ]]

output="$(PATH="$tmp_dir:$PATH" "$repo_root/scripts/check_dependency.sh" go example.com/acme/widget v1.2.3 --mode shallow --output "$tmp_dir/go-report.md")"

[[ "$output" == *"mode=shallow"* ]]
[[ "$output" == *"socket_command=shallow"* ]]
[[ "$output" == *"purl=pkg:golang/example.com/acme/widget@v1.2.3"* ]]
[[ "$(sed -n '2p' "$SOCKET_ARGS_FILE")" == "shallow" ]]
[[ "$(sed -n '3p' "$SOCKET_ARGS_FILE")" == "pkg:golang/example.com/acme/widget@v1.2.3" ]]

if PATH="$tmp_dir:$PATH" "$repo_root/scripts/check_dependency.sh" unknown example >/dev/null 2>&1; then
  echo "unsupported ecosystem unexpectedly accepted" >&2
  exit 1
fi

if PATH="$tmp_dir:$PATH" "$repo_root/scripts/check_dependency.sh" swift Example 1.0.0 >/dev/null 2>&1; then
  echo "discovery-only Swift ecosystem unexpectedly accepted by direct helper" >&2
  exit 1
fi

echo "check_dependency CLI smoke test passed"
