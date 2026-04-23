#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[RUN] test_common.sh"
bash "$ROOT_DIR/tests/test_common.sh"
echo "[RUN] test_detect.sh"
bash "$ROOT_DIR/tests/test_detect.sh"
echo "[RUN] test_tree_fix.sh"
bash "$ROOT_DIR/tests/test_tree_fix.sh"
echo "[RUN] test_interactive.sh"
bash "$ROOT_DIR/tests/test_interactive.sh"

echo "[RUN] interactive smoke: help then exit"
help_output="$(printf '3\n0\n' | bash "$ROOT_DIR/bin/ntfs-perm-fix" 2>&1)"
if [[ "$help_output" != *"先扫描 NTFS 挂载点"* ]]; then
  echo "[FAIL] interactive help smoke should mention '先扫描 NTFS 挂载点'"
  exit 1
fi

echo "[RUN] interactive smoke: recent report missing hint"
temp_root="$(mktemp -d)"
mkdir -p "$temp_root/bin"
ln -s "$ROOT_DIR/lib" "$temp_root/lib"
ln -s "$ROOT_DIR/bin/ntfs-perm-fix" "$temp_root/bin/ntfs-perm-fix"
report_output="$(printf '2\n0\n' | bash "$temp_root/bin/ntfs-perm-fix" 2>&1)"
rm -rf "$temp_root"
if [[ "$report_output" != *"暂无可查看的报告"* ]]; then
  echo "[FAIL] interactive report smoke should show friendly missing-report hint"
  exit 1
fi

echo "[RUN] test_cli.sh"
bash "$ROOT_DIR/tests/test_cli.sh"
echo "[RUN] test_report.sh"
bash "$ROOT_DIR/tests/test_report.sh"
echo "[RUN] test_packaging.sh"
bash "$ROOT_DIR/tests/test_packaging.sh"
