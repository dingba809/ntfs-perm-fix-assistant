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

collect_module_files() {
  local entrypoint_path="$1"

  awk -v root_dir="$ROOT_DIR" '
    match($0, /^[[:space:]]*source[[:space:]]+"\$ROOT_DIR\/lib\/([^"]+\.sh)"/, m) {
      print root_dir "/lib/" m[1]
    }
  ' "$entrypoint_path"
}

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
    /^ROOT_DIR=/ { next }
    /^# shellcheck source=\.\.\/lib\// { next }
    /^source "\$ROOT_DIR\/lib\// { next }
    { print }
  ' "$file_path"
}

{
  mapfile -t module_files < <(collect_module_files "$ENTRYPOINT")
  if [[ "${#module_files[@]}" -eq 0 ]]; then
    echo "[ERROR] no source \"\$ROOT_DIR/lib/*.sh\" entries found in entrypoint: $ENTRYPOINT" >&2
    exit 1
  fi

  echo "#!/usr/bin/env bash"
  echo "set -euo pipefail"
  echo

  for module_file in "${module_files[@]}"; do
    if [[ ! -f "$module_file" ]]; then
      echo "[ERROR] module not found: $module_file" >&2
      exit 1
    fi
    strip_module_content "$module_file"
    echo
  done

  cat <<'SHIM'
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

SHIM

  strip_entrypoint_content "$ENTRYPOINT"
} > "$ARTIFACT"

chmod +x "$ARTIFACT"
echo "built: $ARTIFACT"
