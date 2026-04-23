#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "[FAIL] $1"
  exit 1
}

test_build_single_file_creates_executable() {
  local dist_dir="$ROOT_DIR/dist"
  local artifact="$ROOT_DIR/dist/ntfs-perm-fix"
  local temp_dir
  local copied_artifact
  local content
  local first_line
  local smoke_output
  local smoke_status

  rm -rf "$dist_dir"
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$dist_dir" "$temp_dir"' RETURN

  bash "$ROOT_DIR/scripts/build-single-file.sh"

  [[ -f "$artifact" ]] || fail "build should create dist/ntfs-perm-fix"
  [[ -x "$artifact" ]] || fail "dist/ntfs-perm-fix should be executable"
  first_line="$(head -n 1 "$artifact")"
  [[ "$first_line" == "#!/usr/bin/env bash" ]] || fail "artifact first line must be bash shebang"
  content="$(cat "$artifact")"
  [[ "$content" == *"interactive_main_menu"* ]] || fail "artifact should include real entrypoint content from bin/ntfs-perm-fix"

  copied_artifact="$temp_dir/ntfs-perm-fix"
  cp "$artifact" "$copied_artifact"
  chmod +x "$copied_artifact"

  set +e
  smoke_output="$("$copied_artifact" --help 2>&1)"
  smoke_status=$?
  set -e
  [[ "$smoke_status" -eq 0 ]] || fail "copied artifact --help should succeed"
  [[ "$smoke_output" == *"Usage:"* ]] || fail "copied artifact --help should print usage"
}

test_build_single_file_inlines_modules() {
  local dist_dir="$ROOT_DIR/dist"
  local artifact="$ROOT_DIR/dist/ntfs-perm-fix"

  rm -rf "$dist_dir"
  trap 'rm -rf "$dist_dir"' RETURN

  bash "$ROOT_DIR/scripts/build-single-file.sh"

  grep -q "interactive_main_menu()" "$artifact" || fail "artifact should inline interactive_main_menu() definition"
  grep -q "collect_mount_info()" "$artifact" || fail "artifact should inline collect_mount_info() definition"
  grep -q "write_report_files()" "$artifact" || fail "artifact should inline write_report_files() definition"
  ! grep -qE '^[[:space:]]*source "\$ROOT_DIR/lib/.+\.sh"' "$artifact" || fail "artifact should not depend on source \"\$ROOT_DIR/lib/*.sh\""
}

test_build_single_file_uses_entrypoint_source_order() {
  local fixture_root
  local fixture_artifact
  local fixture_content

  fixture_root="$(mktemp -d)"
  trap 'rm -rf "$fixture_root"' RETURN
  mkdir -p "$fixture_root/scripts" "$fixture_root/bin" "$fixture_root/lib"
  cp "$ROOT_DIR/scripts/build-single-file.sh" "$fixture_root/scripts/build-single-file.sh"

  cat > "$fixture_root/bin/ntfs-perm-fix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/first.sh
source "$ROOT_DIR/lib/first.sh"
# shellcheck source=../lib/second.sh
source "$ROOT_DIR/lib/second.sh"

usage() {
  printf 'Usage: fixture\n'
}
EOF

  cat > "$fixture_root/lib/first.sh" <<'EOF'
#!/usr/bin/env bash
first_func() {
  echo first
}
EOF

  cat > "$fixture_root/lib/second.sh" <<'EOF'
#!/usr/bin/env bash
second_func() {
  echo second
}
EOF

  bash "$fixture_root/scripts/build-single-file.sh"

  fixture_artifact="$fixture_root/dist/ntfs-perm-fix"
  [[ -f "$fixture_artifact" ]] || fail "fixture build should create artifact"
  fixture_content="$(cat "$fixture_artifact")"
  [[ "$fixture_content" == *"first_func()"* ]] || fail "fixture artifact should include first_func() from sourced modules"
  [[ "$fixture_content" == *"second_func()"* ]] || fail "fixture artifact should include second_func() from sourced modules"
}

test_build_single_file_inlines_modules
test_build_single_file_creates_executable
test_build_single_file_uses_entrypoint_source_order

echo "[PASS] test_packaging.sh"
