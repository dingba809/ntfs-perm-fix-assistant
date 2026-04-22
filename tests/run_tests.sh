#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT_DIR/tests/test_common.sh"
bash "$ROOT_DIR/tests/test_detect.sh"
bash "$ROOT_DIR/tests/test_cli.sh"
