#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERACTIVE_LIB="$ROOT_DIR/lib/interactive.sh"

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

run_interactive_menu() {
  local input_data="$1"
  printf '%s' "$input_data" | bash -c "source '$INTERACTIVE_LIB'; interactive_main_menu" 2>&1
}

test_input_one_shows_help_then_exit() {
  local output
  local status

  set +e
  output="$(run_interactive_menu $'1\n0\n')"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    fail "interactive_main_menu should exit successfully for input sequence 1,0"
  fi

  assert_contains "$output" "主菜单" "main menu should be shown"
  assert_contains "$output" "这是交互模式骨架" "input 1 should show help content"
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

test_input_one_shows_help_then_exit
test_invalid_input_prompts_and_loops_then_exit
test_eof_exits_stably

echo "[PASS] test_interactive.sh"
