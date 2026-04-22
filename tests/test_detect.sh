#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/detect.sh
source "$ROOT_DIR/lib/detect.sh"

pass_count=0

fail() {
  echo "[FAIL] $1"
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local name="$3"

  if [[ "$expected" != "$actual" ]]; then
    fail "$name: expected '$expected', got '$actual'"
  fi
  pass_count=$((pass_count + 1))
}

test_classify_fs() {
  assert_eq "ntfs" "$(classify_fs ntfs)" "classify_fs ntfs"
  assert_eq "ntfs" "$(classify_fs fuseblk)" "classify_fs fuseblk"
}

test_classify_driver() {
  assert_eq "ntfs3" "$(classify_driver ntfs3 'rw,uid=1000')" "classify_driver ntfs3"
  assert_eq "ntfs-3g" "$(classify_driver fuseblk 'rw,uid=1000')" "classify_driver fuseblk"
}

test_path_exists() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  if ! path_exists "$tmp_dir"; then
    fail "path_exists should return success for existing path"
  fi
  pass_count=$((pass_count + 1))

  rmdir "$tmp_dir"
  if path_exists "$tmp_dir"; then
    fail "path_exists should fail for missing path"
  fi
  pass_count=$((pass_count + 1))
}

test_is_mountpoint_path() {
  if ! is_mountpoint_path "/"; then
    fail "is_mountpoint_path should treat / as mountpoint"
  fi
  pass_count=$((pass_count + 1))

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  if is_mountpoint_path "$tmp_dir"; then
    fail "is_mountpoint_path should fail for normal directory"
  fi
  pass_count=$((pass_count + 1))
  rmdir "$tmp_dir"
}

test_scan_access_issues() {
  local ro_opts="ro,uid=1000"
  local rw_opts="rw,uid=1000"

  if ! scan_access_issues "fuseblk" "$ro_opts" >/dev/null; then
    fail "scan_access_issues should detect ro as issue"
  fi
  pass_count=$((pass_count + 1))

  if scan_access_issues "fuseblk" "$rw_opts" >/dev/null; then
    fail "scan_access_issues should not report issue for rw"
  fi
  pass_count=$((pass_count + 1))
}

test_collect_mount_info() {
  local output
  output="$(collect_mount_info "/")"

  if [[ "$output" != *"mountpoint=/"* ]]; then
    fail "collect_mount_info should include mountpoint"
  fi
  pass_count=$((pass_count + 1))

  if [[ "$output" != *"driver="* ]]; then
    fail "collect_mount_info should include driver"
  fi
  pass_count=$((pass_count + 1))
}

test_classify_fs
test_classify_driver
test_path_exists
test_is_mountpoint_path
test_scan_access_issues
test_collect_mount_info

echo "[PASS] test_detect.sh ($pass_count assertions)"
