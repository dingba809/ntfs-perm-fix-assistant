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
echo "[RUN] test_cli.sh"
bash "$ROOT_DIR/tests/test_cli.sh"
echo "[RUN] test_report.sh"
bash "$ROOT_DIR/tests/test_report.sh"
