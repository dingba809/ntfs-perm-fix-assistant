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
  mkdir -p "$temp_root/bin"
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

test_render_json_summary_contains_required_fields() {
  local output
  output="$(render_json_summary 'plan' '/mnt/data' 'warning')"
  assert_contains "$output" '"task":"plan"' "render_json_summary task"
  assert_contains "$output" '"target":"/mnt/data"' "render_json_summary target"
  assert_contains "$output" '"status":"warning"' "render_json_summary status"
}

test_render_json_summary_escapes_special_characters() {
  local output
  output="$(render_json_summary 'plan"check' '/mnt/data
line2' 'warn\ing')"
  assert_contains "$output" '"task":"plan\"check"' "render_json_summary escapes quotes"
  assert_contains "$output" '"target":"/mnt/data\nline2"' "render_json_summary escapes newlines"
  assert_contains "$output" '"status":"warn\\ing"' "render_json_summary escapes backslashes"
}

test_write_report_files_creates_text_and_json_reports() {
  local tmp_dir
  local output
  local text_file
  local json_file

  tmp_dir="$(mktemp -d)"
  output="$(write_report_files "$tmp_dir" "plan" "/mnt/data" "warning")"
  text_file="$(extract_report_path "$output" "text")"
  json_file="$(extract_report_path "$output" "json")"

  [[ -f "$text_file" ]] || fail "write_report_files should create text report"
  pass_count=$((pass_count + 1))
  [[ -f "$json_file" ]] || fail "write_report_files should create json report"
  pass_count=$((pass_count + 1))

  assert_file_contains "$text_file" "任务: plan" "write_report_files text content"
  assert_file_contains "$json_file" '"target":"/mnt/data"' "write_report_files json content"

  rm -rf "$tmp_dir"
}

test_write_report_files_does_not_use_mktemp_u() {
  local tmp_dir
  local output_one
  local output_two
  local text_one
  local text_two

  tmp_dir="$(mktemp -d)"

  mktemp() {
    if [[ "${1:-}" == "-u" ]]; then
      printf '%s\n' "$tmp_dir/report-fixed"
      return 0
    fi
    command mktemp "$@"
  }

  output_one="$(write_report_files "$tmp_dir" "plan" "/mnt/data" "warning")"
  output_two="$(write_report_files "$tmp_dir" "plan" "/mnt/data" "warning")"
  unset -f mktemp
  text_one="$(extract_report_path "$output_one" "text")"
  text_two="$(extract_report_path "$output_two" "text")"

  [[ "$text_one" != "$text_two" ]] || fail "write_report_files should not rely on mktemp -u"
  pass_count=$((pass_count + 1))
  [[ -f "$text_one" ]] || fail "write_report_files should create first text report"
  pass_count=$((pass_count + 1))
  [[ -f "$text_two" ]] || fail "write_report_files should create second text report"
  pass_count=$((pass_count + 1))

  rm -rf "$tmp_dir"
}

test_write_report_files_avoids_overwrite_with_same_second_timestamp() {
  local tmp_dir
  local output_one
  local output_two
  local text_one
  local text_two
  local json_one
  local json_two

  tmp_dir="$(mktemp -d)"

  date() {
    if [[ "${1:-}" == "+%Y%m%dT%H%M%S" ]]; then
      printf '20260422T180000\n'
      return 0
    fi
    command date "$@"
  }

  output_one="$(write_report_files "$tmp_dir" "plan" "/mnt/data" "warning")"
  output_two="$(write_report_files "$tmp_dir" "plan" "/mnt/data" "warning")"

  unset -f date

  text_one="$(extract_report_path "$output_one" "text")"
  text_two="$(extract_report_path "$output_two" "text")"
  json_one="$(extract_report_path "$output_one" "json")"
  json_two="$(extract_report_path "$output_two" "json")"

  [[ "$text_one" != "$text_two" ]] || fail "write_report_files should not reuse text filename within the same second"
  pass_count=$((pass_count + 1))
  [[ "$json_one" != "$json_two" ]] || fail "write_report_files should not reuse json filename within the same second"
  pass_count=$((pass_count + 1))
  [[ -f "$text_one" && -f "$text_two" && -f "$json_one" && -f "$json_two" ]] || fail "write_report_files should preserve all report files"
  pass_count=$((pass_count + 1))

  rm -rf "$tmp_dir"
}

test_plan_preserves_uuid_source_with_equals_in_fstab_line() {
  local temp_root
  local fake_bin
  local mount_dir
  local output

  temp_root="$(make_temp_root)"
  fake_bin="$(setup_fake_bin)"
  mount_dir="$(mktemp -d)"

  make_stub "$fake_bin" "mountpoint" "if [[ \"\$1\" == '-q' && \"\$3\" == '$mount_dir' ]]; then exit 0; fi; exit 1"
  make_stub "$fake_bin" "findmnt" "if [[ \"\$1\" == '-n' ]]; then echo 'UUID=ABCD=EF12 ntfs3 rw,uid=1000'; exit 0; fi; exit 1"

  output="$(PATH="$fake_bin:$PATH" "$temp_root/bin/ntfs-perm-fix" plan "$mount_dir")"
  assert_contains "$output" "建议fstab: UUID=ABCD=EF12 $mount_dir ntfs3" "plan preserves UUID source"

  rm -rf "$temp_root" "$fake_bin" "$mount_dir"
}

test_report_fails_when_no_report_exists() {
  local temp_root
  local output
  local status

  temp_root="$(make_temp_root)"

  set +e
  output="$("$temp_root/bin/ntfs-perm-fix" report 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "report should fail when no report exists"
  fi
  pass_count=$((pass_count + 1))
  assert_contains "$output" "no report found" "report missing failure message"

  rm -rf "$temp_root"
}

test_build_fstab_line_contains_core_fields
test_render_text_summary_contains_required_labels
test_render_json_summary_contains_required_fields
test_render_json_summary_escapes_special_characters
test_write_report_files_creates_text_and_json_reports
test_write_report_files_does_not_use_mktemp_u
test_write_report_files_avoids_overwrite_with_same_second_timestamp
test_plan_preserves_uuid_source_with_equals_in_fstab_line
test_report_fails_when_no_report_exists

echo "[PASS] test_report.sh ($pass_count assertions)"
