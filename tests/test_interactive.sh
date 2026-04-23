#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERACTIVE_LIB="$ROOT_DIR/lib/interactive.sh"
DETECT_LIB="$ROOT_DIR/lib/detect.sh"

fail() {
  echo "[FAIL] $1"
  exit 1
}

assert_contains() {
  local content="$1"
  local pattern="$2"
  local name="$3"

  if [[ "$content" != *"$pattern"* ]]; then
    fail "$name: expected '$pattern', got '$content'"
  fi
}

setup_fake_bin() {
  local dir
  dir="$(mktemp -d)"
  printf '%s\n' "$dir"
}

make_stub() {
  local stub_dir="$1"
  local cmd_name="$2"
  local body="$3"

  cat >"$stub_dir/$cmd_name" <<STUB
#!/usr/bin/env bash
$body
STUB
  chmod +x "$stub_dir/$cmd_name"
}

run_interactive_menu() {
  local input_data="$1"
  printf '%s' "$input_data" | bash -c "source '$DETECT_LIB'; source '$INTERACTIVE_LIB'; interactive_main_menu" 2>&1
}

test_scan_lists_ntfs_mountpoints() {
  local fake_bin
  local output
  local status

  fake_bin="$(setup_fake_bin)"
  make_stub "$fake_bin" "findmnt" 'if [[ "$1" == "-rn" ]]; then printf "/dev/sdb1 /mnt/data ntfs3 rw\n/dev/sdc1 /mnt/usb ext4 rw\n/dev/sdd1 /mnt/backup fuseblk ro\n"; exit 0; fi; exit 1'

  set +e
  output="$(PATH="$fake_bin:$PATH" bash -c "source '$DETECT_LIB'; list_ntfs_mountpoints" 2>&1)"
  status=$?
  set -e

  [[ "$status" -eq 0 ]] || fail "list_ntfs_mountpoints should succeed"
  assert_contains "$output" "/mnt/data" "scan includes ntfs3 mount"
  assert_contains "$output" "/mnt/backup" "scan includes fuseblk mount"
  [[ "$output" != *"/mnt/usb"* ]] || fail "scan should exclude non-ntfs mount"

  rm -rf "$fake_bin"
}

test_scan_mountpoints_findmnt_failure_returns_error() {
  local fake_bin
  local output
  local status

  fake_bin="$(setup_fake_bin)"
  make_stub "$fake_bin" "findmnt" 'echo "simulated findmnt failure" >&2; exit 23'

  set +e
  output="$(PATH="$fake_bin:$PATH" bash -c "source '$DETECT_LIB'; list_ntfs_mountpoints" 2>&1)"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "list_ntfs_mountpoints should fail when findmnt fails"
  assert_contains "$output" "simulated findmnt failure" "findmnt failure message should be preserved"

  rm -rf "$fake_bin"
}

test_select_mountpoint_keeps_scan_error_semantics() {
  local fake_bin
  local output
  local status

  fake_bin="$(setup_fake_bin)"
  make_stub "$fake_bin" "findmnt" 'echo "simulated scan failure for select" >&2; exit 11'

  set +e
  output="$(printf '1\n' | PATH="$fake_bin:$PATH" bash -c "source '$DETECT_LIB'; source '$INTERACTIVE_LIB'; interactive_select_mountpoint" 2>&1)"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "interactive_select_mountpoint should fail when scan fails"
  assert_contains "$output" "simulated scan failure for select" "interactive_select_mountpoint should pass through scan errors"
  [[ "$output" != *"未检测到可处理的 NTFS 挂载点"* ]] || fail "interactive_select_mountpoint should not treat scan failure as empty result"

  rm -rf "$fake_bin"
}

test_scan_menu_lists_numbered_mountpoints_then_back_to_menu() {
  local fake_bin
  local output
  local status

  fake_bin="$(setup_fake_bin)"
  make_stub "$fake_bin" "findmnt" 'if [[ "$1" == "-rn" ]]; then printf "/dev/sdb1 /mnt/data ntfs3 rw,uid=1000\n/dev/sdc1 /mnt/usb ext4 rw\n/dev/sdd1 /mnt/backup fuseblk ro\n"; exit 0; fi; exit 1'

  set +e
  output="$(PATH="$fake_bin:$PATH" run_interactive_menu $'1\n0\n0\n')"
  status=$?
  set -e

  [[ "$status" -eq 0 ]] || fail "interactive main menu should exit successfully"
  assert_contains "$output" "[1] /mnt/data" "scan menu should show first mountpoint"
  assert_contains "$output" "[2] /mnt/backup" "scan menu should show second mountpoint"
  [[ "$output" != *"/mnt/usb"* ]] || fail "scan menu should exclude non-ntfs mount"
  assert_contains "$output" "[0] 返回主菜单" "scan menu should support back"
  assert_contains "$output" "已退出。" "input 0 should exit"

  rm -rf "$fake_bin"
}

test_select_mountpoint_returns_selected_value_and_confirms_in_menu() {
  local fake_bin
  local selected
  local select_status
  local select_stderr
  local output
  local status

  fake_bin="$(setup_fake_bin)"
  make_stub "$fake_bin" "findmnt" 'if [[ "$1" == "-rn" ]]; then printf "/dev/sdb1 /mnt/data ntfs3 rw,uid=1000\n/dev/sdd1 /mnt/backup fuseblk ro\n"; exit 0; fi; exit 1'

  select_stderr="$(mktemp)"
  set +e
  selected="$(printf '2\n' | PATH="$fake_bin:$PATH" bash -c "source '$DETECT_LIB'; source '$INTERACTIVE_LIB'; interactive_select_mountpoint" 2>"$select_stderr")"
  select_status=$?
  set -e

  [[ "$select_status" -eq 0 ]] || fail "interactive_select_mountpoint should succeed for valid selection"
  [[ "$selected" == "/mnt/backup" ]] || fail "interactive_select_mountpoint should return selected mountpoint"
  assert_contains "$(cat "$select_stderr")" "请输入编号" "interactive_select_mountpoint should prompt for index"
  rm -f "$select_stderr"

  set +e
  output="$(PATH="$fake_bin:$PATH" run_interactive_menu $'1\n2\n0\n')"
  status=$?
  set -e

  [[ "$status" -eq 0 ]] || fail "interactive menu should exit successfully after selecting mountpoint"
  assert_contains "$output" "已选择挂载点: /mnt/backup" "main menu should confirm selected mountpoint"

  rm -rf "$fake_bin"
}

test_help_option_then_exit() {
  local output
  local status

  set +e
  output="$(run_interactive_menu $'2\n0\n')"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    fail "interactive_main_menu should exit successfully for input sequence 2,0"
  fi

  assert_contains "$output" "主菜单" "main menu should be shown"
  assert_contains "$output" "这是交互模式骨架" "input 2 should show help content"
  assert_contains "$output" "已退出。" "input 0 should exit"
}

test_invalid_input_prompts_and_loops_then_exit() {
  local output
  local status

  set +e
  output="$(run_interactive_menu $'x\n0\n')"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    fail "interactive_main_menu should continue after invalid input and exit on 0"
  fi

  assert_contains "$output" "无效选择，请重试。" "invalid input should prompt retry"
  assert_contains "$output" "已退出。" "should still allow exiting after invalid input"
}

test_eof_exits_stably() {
  local output
  local status

  set +e
  output="$(run_interactive_menu "")"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    fail "interactive_main_menu should exit 0 on stdin EOF"
  fi

  assert_contains "$output" "主菜单" "EOF path should still render menu once"
}

test_diagnosis_recommends_safe_fix_for_rw_ntfs() {
  local output
  output="$(bash -c "source '$INTERACTIVE_LIB'; interactive_render_diagnosis_menu /mnt/data ntfs3 rw read-write-access-warning")"

  assert_contains "$output" "诊断结论" "diagnosis title"
  assert_contains "$output" "推荐操作" "diagnosis recommendation"
  assert_contains "$output" "执行安全修复（推荐）" "diagnosis safe fix recommendation"
}

test_select_mountpoint_enters_target_menu_and_runs_diagnosis() {
  local fake_bin
  local output
  local status

  fake_bin="$(setup_fake_bin)"
  make_stub "$fake_bin" "findmnt" 'if [[ "$1" == "-rn" ]]; then printf "/dev/sdb1 /mnt/data ntfs3 rw\n"; exit 0; fi; if [[ "$1" == "-n" ]]; then printf "/dev/sdb1 ntfs3 rw\n"; exit 0; fi; exit 1'

  set +e
  output="$(PATH="$fake_bin:$PATH" run_interactive_menu $'1\n1\n1\n0\n0\n')"
  status=$?
  set -e

  [[ "$status" -eq 0 ]] || fail "interactive target menu flow should exit successfully"
  assert_contains "$output" "当前目标：/mnt/data" "target menu should render selected mountpoint"
  assert_contains "$output" "自动诊断（推荐）" "target menu should provide diagnosis option"
  assert_contains "$output" "诊断结论" "diagnosis output should be shown"
  assert_contains "$output" "推荐操作" "diagnosis recommendation should be shown"

  rm -rf "$fake_bin"
}

test_scan_lists_ntfs_mountpoints
test_scan_mountpoints_findmnt_failure_returns_error
test_select_mountpoint_keeps_scan_error_semantics
test_scan_menu_lists_numbered_mountpoints_then_back_to_menu
test_select_mountpoint_returns_selected_value_and_confirms_in_menu
test_help_option_then_exit
test_invalid_input_prompts_and_loops_then_exit
test_eof_exits_stably
test_diagnosis_recommends_safe_fix_for_rw_ntfs
test_select_mountpoint_enters_target_menu_and_runs_diagnosis

echo "[PASS] test_interactive.sh"
