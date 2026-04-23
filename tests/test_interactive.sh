#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "[FAIL] $1"
  exit 1
}

test_main_menu_exit_with_zero() {
  local output
  local status

  set +e
  output="$(printf '0\n' | "$ROOT_DIR/bin/ntfs-perm-fix" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    fail "interactive mode should exit successfully when input is 0"
  fi

  if [[ "$output" != *"主菜单"* ]]; then
    fail "interactive mode should display main menu"
  fi
}

test_main_menu_exit_with_zero

echo "[PASS] test_interactive.sh"
