#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "[FAIL] $1"
  exit 1
}

test_build_single_file_creates_executable() {
  local artifact="$ROOT_DIR/dist/ntfs-perm-fix"

  rm -rf "$ROOT_DIR/dist"

  bash "$ROOT_DIR/scripts/build-single-file.sh"

  [[ -f "$artifact" ]] || fail "build should create dist/ntfs-perm-fix"
  [[ -x "$artifact" ]] || fail "dist/ntfs-perm-fix should be executable"
}

test_build_single_file_creates_executable

echo "[PASS] test_packaging.sh"
