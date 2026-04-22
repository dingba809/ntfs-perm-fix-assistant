#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

assert_file_contains() {
  local file_path="$1"
  local pattern="$2"
  local name="$3"
  local content

  content="$(cat "$file_path")"
  assert_contains "$content" "$pattern" "$name"
}

make_temp_root() {
  local temp_root
  temp_root="$(mktemp -d)"
  mkdir -p "$temp_root/bin" "$temp_root/logs"
  ln -s "$ROOT_DIR/lib" "$temp_root/lib"
  ln -s "$ROOT_DIR/bin/ntfs-perm-fix" "$temp_root/bin/ntfs-perm-fix"
  printf '%s\n' "$temp_root"
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

extract_report_path() {
  local output="$1"
  local key="$2"

  printf '%s\n' "$output" | awk -F= -v want_key="$key" '$1 == want_key {sub(/^[^=]*=/, "", $0); print $0; exit}'
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
  local temp_root
  local fake_bin
  local mount_dir
  local output
  local json_report

  temp_root="$(make_temp_root)"
  fake_bin="$(setup_fake_bin)"
  mount_dir="$(mktemp -d)"

  make_stub "$fake_bin" "mountpoint" "if [[ \"\$1\" == '-q' && \"\$3\" == '$mount_dir' ]]; then exit 0; fi; exit 1"
  make_stub "$fake_bin" "findmnt" "if [[ \"\$1\" == '-n' ]]; then echo '/dev/sdb1 ntfs3 rw,uid=1000'; exit 0; fi; exit 1"

  output="$(PATH="$fake_bin:$PATH" "$temp_root/bin/ntfs-perm-fix" check "$mount_dir")"

  if [[ "$output" != *"mountpoint=$mount_dir"* ]]; then
    fail "check should print mount info"
  fi
  assert_contains "$output" "text=" "check report text path"
  assert_contains "$output" "json=" "check report json path"

  json_report="$(extract_report_path "$output" "json")"
  [[ -f "$json_report" ]] || fail "check should create json report"
  assert_file_contains "$json_report" '"task":"check"' "check json task"
  assert_file_contains "$json_report" '"fs":"ntfs3"' "check json fs"
  assert_file_contains "$json_report" '"driver":"ntfs3"' "check json driver"

  rm -rf "$temp_root" "$fake_bin" "$mount_dir"
}

test_apply_requires_root() {
  local output
  local status

  set +e
  output="$($ROOT_DIR/bin/ntfs-perm-fix apply /tmp 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "apply should fail without root privileges"
  fi

  assert_contains "$output" "must be run as root" "apply root requirement"
}

test_plan_report_contains_fs_and_driver() {
  local temp_root
  local fake_bin
  local mount_dir
  local output
  local json_report

  temp_root="$(make_temp_root)"
  fake_bin="$(setup_fake_bin)"
  mount_dir="$(mktemp -d)"

  make_stub "$fake_bin" "mountpoint" "if [[ \"\$1\" == '-q' && \"\$3\" == '$mount_dir' ]]; then exit 0; fi; exit 1"
  make_stub "$fake_bin" "findmnt" "if [[ \"\$1\" == '-n' ]]; then echo '/dev/sdb1 ntfs3 rw,uid=1000'; exit 0; fi; exit 1"

  output="$(PATH="$fake_bin:$PATH" "$temp_root/bin/ntfs-perm-fix" plan "$mount_dir")"
  assert_contains "$output" "json=" "plan report json path"
  json_report="$(extract_report_path "$output" "json")"
  [[ -f "$json_report" ]] || fail "plan should create json report"
  assert_file_contains "$json_report" '"task":"plan"' "plan json task"
  assert_file_contains "$json_report" '"status":"warning"' "plan json status"
  assert_file_contains "$json_report" '"fs":"ntfs3"' "plan json fs"
  assert_file_contains "$json_report" '"driver":"ntfs3"' "plan json driver"

  rm -rf "$temp_root" "$fake_bin" "$mount_dir"
}

test_apply_rejects_non_ntfs_mountpoint() {
  local temp_root
  local fake_bin
  local mount_dir
  local output
  local status

  if ! command -v unshare >/dev/null 2>&1; then
    echo "[SKIP] unshare not available, skip root-only apply tests"
    return 0
  fi

  temp_root="$(make_temp_root)"
  fake_bin="$(setup_fake_bin)"
  mount_dir="$(mktemp -d)"

  make_stub "$fake_bin" "mountpoint" "if [[ \"\$1\" == '-q' && \"\$3\" == '$mount_dir' ]]; then exit 0; fi; exit 1"
  make_stub "$fake_bin" "findmnt" "if [[ \"\$1\" == '-n' ]]; then echo '/dev/sdb1 ext4 rw'; exit 0; fi; exit 1"

  set +e
  output="$(PATH="$fake_bin:$PATH" unshare -Ur "$temp_root/bin/ntfs-perm-fix" apply "$mount_dir" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "apply should fail on non-ntfs mountpoint"
  fi

  if [[ "$output" != *"NTFS"* && "$output" != *"ntfs"* ]]; then
    fail "apply should report ntfs validation failure"
  fi

  rm -rf "$temp_root" "$fake_bin" "$mount_dir"
}

test_apply_accepts_ntfs3_success_path() {
  local temp_root
  local fake_bin
  local mount_dir
  local file_path
  local output
  local status
  local text_report
  local json_report

  if ! command -v unshare >/dev/null 2>&1; then
    echo "[SKIP] unshare not available, skip root-only apply tests"
    return 0
  fi

  temp_root="$(make_temp_root)"
  fake_bin="$(setup_fake_bin)"
  mount_dir="$(mktemp -d)"
  file_path="$mount_dir/a.txt"
  printf 'hello\n' >"$file_path"
  chmod 700 "$mount_dir"
  chmod 600 "$file_path"

  make_stub "$fake_bin" "mountpoint" "if [[ \"\$1\" == '-q' && \"\$3\" == '$mount_dir' ]]; then exit 0; fi; exit 1"
  make_stub "$fake_bin" "findmnt" "if [[ \"\$1\" == '-n' ]]; then echo '/dev/sdb1 ntfs3 rw,uid=1000'; exit 0; fi; exit 1"

  set +e
  output="$(PATH="$fake_bin:$PATH" unshare -Ur "$temp_root/bin/ntfs-perm-fix" apply "$mount_dir" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    fail "apply should succeed for ntfs3 mountpoint"
  fi

  assert_contains "$output" "total_issues=0" "apply ntfs3 should repair issues"
  assert_contains "$output" "text=" "apply ntfs3 report text path"
  assert_contains "$output" "json=" "apply ntfs3 report json path"

  text_report="$(extract_report_path "$output" "text")"
  json_report="$(extract_report_path "$output" "json")"
  [[ -f "$text_report" ]] || fail "apply should create text report for ntfs3"
  [[ -f "$json_report" ]] || fail "apply should create json report for ntfs3"
  assert_file_contains "$json_report" '"task":"apply"' "apply json task"
  assert_file_contains "$json_report" '"result":"success"' "apply json result"
  assert_file_contains "$json_report" '"fs":"ntfs3"' "apply json fs"
  assert_file_contains "$json_report" '"driver":"ntfs3"' "apply json driver"
  [[ "$(stat -c '%a' "$mount_dir")" == "755" ]] || fail "apply should set directory mode to 755"
  [[ "$(stat -c '%a' "$file_path")" == "644" ]] || fail "apply should set file mode to 644"

  rm -rf "$temp_root" "$fake_bin" "$mount_dir"
}

test_apply_dry_run_success_path() {
  local temp_root
  local fake_bin
  local mount_dir
  local file_path
  local output
  local status

  if ! command -v unshare >/dev/null 2>&1; then
    echo "[SKIP] unshare not available, skip root-only apply tests"
    return 0
  fi

  temp_root="$(make_temp_root)"
  fake_bin="$(setup_fake_bin)"
  mount_dir="$(mktemp -d)"
  file_path="$mount_dir/a.txt"
  printf 'hello\n' >"$file_path"
  chmod 700 "$mount_dir"
  chmod 600 "$file_path"

  make_stub "$fake_bin" "mountpoint" "if [[ \"\$1\" == '-q' && \"\$3\" == '$mount_dir' ]]; then exit 0; fi; exit 1"
  make_stub "$fake_bin" "findmnt" "if [[ \"\$1\" == '-n' ]]; then echo '/dev/sdb1 ntfs3 rw,uid=1000'; exit 0; fi; exit 1"

  set +e
  output="$(PATH="$fake_bin:$PATH" unshare -Ur "$temp_root/bin/ntfs-perm-fix" apply --dry-run "$mount_dir" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    fail "apply --dry-run should succeed for ntfs3 mountpoint"
  fi

  assert_contains "$output" "dry-run" "apply --dry-run should mention dry-run mode"
  [[ "$(stat -c '%a' "$mount_dir")" == "700" ]] || fail "apply --dry-run should not modify directory mode"
  [[ "$(stat -c '%a' "$file_path")" == "600" ]] || fail "apply --dry-run should not modify file mode"

  rm -rf "$temp_root" "$fake_bin" "$mount_dir"
}

test_config_missing_value
test_check_missing_path
test_check_not_mountpoint
test_check_root_mountpoint
test_apply_requires_root
test_plan_report_contains_fs_and_driver
test_apply_rejects_non_ntfs_mountpoint
test_apply_accepts_ntfs3_success_path
test_apply_dry_run_success_path

echo "[PASS] test_cli.sh"
