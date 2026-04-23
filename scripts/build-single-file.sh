#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ARTIFACT="$DIST_DIR/ntfs-perm-fix"
ENTRYPOINT="$ROOT_DIR/bin/ntfs-perm-fix"

mkdir -p "$DIST_DIR"

if [[ ! -f "$ENTRYPOINT" ]]; then
  echo "[ERROR] entrypoint not found: $ENTRYPOINT" >&2
  exit 1
fi

{
  cat "$ENTRYPOINT"
} > "$ARTIFACT"

chmod +x "$ARTIFACT"
echo "built: $ARTIFACT"
