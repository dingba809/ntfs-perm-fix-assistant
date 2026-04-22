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

test_default_config_path
test_timestamp_now
test_bool_normalize

echo "[PASS] test_common.sh ($pass_count assertions)"
