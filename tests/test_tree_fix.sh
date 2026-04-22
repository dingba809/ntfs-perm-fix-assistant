#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/tree_fix.sh
source "$ROOT_DIR/lib/tree_fix.sh"

fail() {
  echo "[FAIL] $1"
  exit 1
}

assert_contains() {
  local content="$1"
  local pattern="$2"
  local name="$3"

  if [[ "$content" != *"$pattern"* ]]; then
    fail "$name: expected to contain '$pattern', got '$content'"
  fi
}

test_gather_issue_counts_rejects_missing_dir() {
  local output
  local status

  set +e
  output="$(gather_issue_counts /tmp/ntfs-perm-fix-missing-dir 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "gather_issue_counts should fail for missing directory"
  fi

  assert_contains "$output" "not a directory" "gather_issue_counts missing dir message"
}

test_apply_tree_permissions_fixes_basic_modes() {
  local tmp_dir
  local child_dir
  local child_file
  local output

  tmp_dir="$(mktemp -d)"
  child_dir="$tmp_dir/sub"
  child_file="$child_dir/file.txt"
  mkdir -p "$child_dir"
  printf 'demo\n' >"$child_file"

  chmod 700 "$tmp_dir" "$child_dir"
  chmod 600 "$child_file"

  output="$(apply_tree_permissions "$tmp_dir" "apply")"
  assert_contains "$output" "total_issues=0" "apply_tree_permissions total issues"

  [[ "$(stat -c '%a' "$tmp_dir")" == "755" ]] || fail "root dir permission should be 755"
  [[ "$(stat -c '%a' "$child_dir")" == "755" ]] || fail "child dir permission should be 755"
  [[ "$(stat -c '%a' "$child_file")" == "644" ]] || fail "file permission should be 644"

  rm -rf "$tmp_dir"
}

test_gather_issue_counts_rejects_missing_dir
test_apply_tree_permissions_fixes_basic_modes

echo "[PASS] test_tree_fix.sh"
