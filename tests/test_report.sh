#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/mount_fix.sh
source "$ROOT_DIR/lib/mount_fix.sh"
# shellcheck source=../lib/report.sh
source "$ROOT_DIR/lib/report.sh"

pass_count=0

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
  pass_count=$((pass_count + 1))
}

test_build_fstab_line_contains_core_fields() {
  local line
  line="$(build_fstab_line 'UUID=ABCD' '/mnt/data' 'ntfs3' '1000' '1000' '0022')"
  assert_contains "$line" "UUID=ABCD /mnt/data ntfs3" "build_fstab_line core fields"
}

test_render_text_summary_contains_required_labels() {
  local text
  text="$(render_text_summary 'check' '/mnt/data' 'warning')"
  assert_contains "$text" "任务: check" "render_text_summary task"
  assert_contains "$text" "目标: /mnt/data" "render_text_summary target"
}

test_build_fstab_line_contains_core_fields
test_render_text_summary_contains_required_labels

echo "[PASS] test_report.sh ($pass_count assertions)"
