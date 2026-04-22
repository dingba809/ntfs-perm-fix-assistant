#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "[FAIL] $1"
  exit 1
}

test_config_missing_value() {
  local output
  local status

  set +e
  output="$($ROOT_DIR/bin/ntfs-perm-fix --config 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "--config without value should fail"
  fi

  if [[ "$output" == *"unbound variable"* ]]; then
    fail "should not expose unbound variable error"
  fi

  if [[ "$output" != *"--config requires a value"* ]]; then
    fail "should show controlled missing value message"
  fi
}

test_check_missing_path() {
  local output
  local status

  set +e
  output="$($ROOT_DIR/bin/ntfs-perm-fix check /tmp/path-does-not-exist 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "check should fail when path missing"
  fi

  if [[ "$output" != *"path not found"* ]]; then
    fail "check should show path not found"
  fi
}

test_check_not_mountpoint() {
  local tmp_dir
  local output
  local status

  tmp_dir="$(mktemp -d)"
  set +e
  output="$($ROOT_DIR/bin/ntfs-perm-fix check "$tmp_dir" 2>&1)"
  status=$?
  set -e
  rmdir "$tmp_dir"

  if [[ "$status" -eq 0 ]]; then
    fail "check should fail when not mountpoint"
  fi

  if [[ "$output" != *"not a mountpoint"* ]]; then
    fail "check should show mountpoint validation error"
  fi
}

test_check_root_mountpoint() {
  local output
  output="$($ROOT_DIR/bin/ntfs-perm-fix check /)"

  if [[ "$output" != *"mountpoint=/"* ]]; then
    fail "check should print mount info"
  fi
}

test_config_missing_value
test_check_missing_path
test_check_not_mountpoint
test_check_root_mountpoint

echo "[PASS] test_cli.sh"
