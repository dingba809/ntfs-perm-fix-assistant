#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

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

assert_match() {
  local value="$1"
  local regex="$2"
  local name="$3"
  if [[ ! "$value" =~ $regex ]]; then
    fail "$name: value '$value' does not match '$regex'"
  fi
  pass_count=$((pass_count + 1))
}

test_default_config_path() {
  local got
  local expected="$ROOT_DIR/config/default.yaml"
  got="$(default_config_path)"
  assert_eq "$expected" "$got" "default_config_path returns project default"

  NTFS_PERM_FIX_CONFIG="/tmp/ntfs-fix.yaml"
  export NTFS_PERM_FIX_CONFIG
  got="$(default_config_path)"
  assert_eq "/tmp/ntfs-fix.yaml" "$got" "default_config_path respects NTFS_PERM_FIX_CONFIG"
  unset NTFS_PERM_FIX_CONFIG
}

test_timestamp_now() {
  local ts
  ts="$(timestamp_now)"
  assert_match "$ts" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{4})$' "timestamp_now ISO8601"
}

test_bool_normalize() {
  assert_eq "true" "$(bool_normalize true)" "bool true"
  assert_eq "true" "$(bool_normalize YES)" "bool YES"
  assert_eq "true" "$(bool_normalize 1)" "bool 1"
  assert_eq "true" "$(bool_normalize on)" "bool on"

  assert_eq "false" "$(bool_normalize false)" "bool false"
  assert_eq "false" "$(bool_normalize No)" "bool No"
  assert_eq "false" "$(bool_normalize 0)" "bool 0"
  assert_eq "false" "$(bool_normalize OFF)" "bool OFF"

  if bool_normalize maybe >/dev/null 2>&1; then
    fail "bool_normalize invalid input should fail"
  fi
  pass_count=$((pass_count + 1))
}

test_yaml_get() {
  local cfg="$ROOT_DIR/config/default.yaml"

  assert_eq "quick" "$(yaml_get "$cfg" scan_mode)" "yaml_get scan_mode"
  assert_eq "./reports" "$(yaml_get "$cfg" report_dir)" "yaml_get report_dir"
  assert_eq "true" "$(yaml_get "$cfg" mount_fix.enabled)" "yaml_get mount_fix.enabled"
  assert_eq "1000" "$(yaml_get "$cfg" mount_fix.uid)" "yaml_get mount_fix.uid"
  assert_eq "true" "$(yaml_get "$cfg" safety.require_root_for_apply)" "yaml_get safety.require_root_for_apply"

  if yaml_get "$cfg" not_exists >/dev/null 2>&1; then
    fail "yaml_get missing key should fail"
  fi
  pass_count=$((pass_count + 1))

  if yaml_get "$ROOT_DIR/config/not-exists.yaml" scan_mode >/dev/null 2>&1; then
    fail "yaml_get missing file should fail"
  fi
  pass_count=$((pass_count + 1))
}

test_default_config_path
test_timestamp_now
test_bool_normalize
test_yaml_get

echo "[PASS] test_common.sh ($pass_count assertions)"
