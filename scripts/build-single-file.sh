#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ARTIFACT="$DIST_DIR/ntfs-perm-fix"
ENTRYPOINT="$ROOT_DIR/bin/ntfs-perm-fix"
MODULE_FILES=(
  "$ROOT_DIR/lib/common.sh"
  "$ROOT_DIR/lib/interactive.sh"
  "$ROOT_DIR/lib/detect.sh"
  "$ROOT_DIR/lib/mount_fix.sh"
  "$ROOT_DIR/lib/tree_fix.sh"
  "$ROOT_DIR/lib/report.sh"
)

mkdir -p "$DIST_DIR"

if [[ ! -f "$ENTRYPOINT" ]]; then
  echo "[ERROR] entrypoint not found: $ENTRYPOINT" >&2
  exit 1
fi

strip_module_content() {
  local file_path="$1"

  awk '
    NR == 1 && /^#!\/usr\/bin\/env bash$/ { next }
    /^# shellcheck source=/ { next }
    /^source / { next }
    { print }
  ' "$file_path"
}

strip_entrypoint_content() {
  local file_path="$1"

  awk '
    NR == 1 && /^#!\/usr\/bin\/env bash$/ { next }
    /^set -euo pipefail$/ { next }
    /^# shellcheck source=\.\.\/lib\// { next }
    /^source "\$ROOT_DIR\/lib\// { next }
    { print }
  ' "$file_path"
}

{
  echo "#!/usr/bin/env bash"
  echo "set -euo pipefail"
  echo

  for module_file in "${MODULE_FILES[@]}"; do
    if [[ ! -f "$module_file" ]]; then
      echo "[ERROR] module not found: $module_file" >&2
      exit 1
    fi
    strip_module_content "$module_file"
    echo
  done

  strip_entrypoint_content "$ENTRYPOINT"
} > "$ARTIFACT"

chmod +x "$ARTIFACT"
echo "built: $ARTIFACT"
