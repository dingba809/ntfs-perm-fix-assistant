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

assert_contains() {
  local content="$1"
  local pattern="$2"
  local name="$3"

  if [[ "$content" != *"$pattern"* ]]; then
    fail "$name: expected to contain '$pattern', got '$content'"
  fi
  pass_count=$((pass_count + 1))
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

test_classify_fs() {
  assert_eq "ntfs" "$(classify_fs ntfs)" "classify_fs ntfs"
  assert_eq "ntfs" "$(classify_fs fuseblk)" "classify_fs fuseblk"
}

test_classify_driver() {
  assert_eq "ntfs3" "$(classify_driver ntfs3 'rw,uid=1000')" "classify_driver ntfs3"
  assert_eq "ntfs-3g" "$(classify_driver fuseblk 'rw,uid=1000')" "classify_driver fuseblk"
  assert_eq "ntfs-3g" "$(classify_driver ntfs 'rw,uid=1000,windows_names')" "classify_driver ntfs windows_names"
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

test_is_mountpoint_path_with_stub() {
  local fake_bin
  fake_bin="$(setup_fake_bin)"

  make_stub "$fake_bin" "mountpoint" 'if [[ "$1" == "-q" && "$3" == "/mnt/ok" ]]; then exit 0; fi; exit 1'

  PATH="$fake_bin:$PATH"
  if ! is_mountpoint_path "/mnt/ok"; then
    fail "is_mountpoint_path should succeed via stub mountpoint"
  fi
  pass_count=$((pass_count + 1))

  if is_mountpoint_path "/mnt/no"; then
    fail "is_mountpoint_path should fail via stub mountpoint"
  fi
  pass_count=$((pass_count + 1))

  rm -rf "$fake_bin"
}

test_scan_access_issues() {
  local issues

  issues="$(scan_access_issues "fuseblk" "ro,uid=1000")"
  assert_contains "$issues" "read-only-mount" "scan_access_issues ro"

  issues="$(scan_access_issues "ntfs" "rw")"
  assert_contains "$issues" "uid-not-set" "scan_access_issues uid-not-set"

  if scan_access_issues "fuseblk" "rw,uid=1000" >/dev/null; then
    fail "scan_access_issues should not report issue for rw+uid"
  fi
  pass_count=$((pass_count + 1))
}

test_collect_mount_info_mapping_and_scope() {
  local fake_bin
  local tmp_dir
  local out_file
  local output

  fake_bin="$(setup_fake_bin)"
  tmp_dir="$(mktemp -d)"
  out_file="$tmp_dir/out.txt"

  make_stub "$fake_bin" "findmnt" 'if [[ "$1" == "-n" ]]; then echo "/dev/sdb1 fuseblk rw,uid=1000,windows_names"; exit 0; fi; exit 1'

  PATH="$fake_bin:$PATH"
  unset issues_detected || true
  collect_mount_info "/mnt/data" >"$out_file"
  output="$(cat "$out_file")"

  assert_contains "$output" "mountpoint=/mnt/data" "collect_mount_info mountpoint"
  assert_contains "$output" "source=/dev/sdb1" "collect_mount_info source"
  assert_contains "$output" "fstype=fuseblk" "collect_mount_info fstype"
  assert_contains "$output" "filesystem=ntfs" "collect_mount_info filesystem"
  assert_contains "$output" "driver=ntfs-3g" "collect_mount_info driver"
  assert_contains "$output" "options=rw,uid=1000,windows_names" "collect_mount_info options"
  assert_contains "$output" "access_issues=none" "collect_mount_info issues"

  if [[ -v issues_detected ]]; then
    fail "collect_mount_info should not leak issues_detected to global scope"
  fi
  pass_count=$((pass_count + 1))

  rm -rf "$fake_bin" "$tmp_dir"
}

test_collect_mount_info_failure_when_findmnt_missing() {
  local output
  local status

  set +e
  output="$(PATH="/nonexistent" collect_mount_info "/mnt/data" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "collect_mount_info should fail when findmnt missing"
  fi

  if [[ "$output" != *"findmnt command not found"* ]]; then
    fail "collect_mount_info should report missing findmnt"
  fi
  pass_count=$((pass_count + 1))
}

test_classify_fs
test_classify_driver
test_path_exists
test_is_mountpoint_path_with_stub
test_scan_access_issues
test_collect_mount_info_mapping_and_scope
test_collect_mount_info_failure_when_findmnt_missing

echo "[PASS] test_detect.sh ($pass_count assertions)"
