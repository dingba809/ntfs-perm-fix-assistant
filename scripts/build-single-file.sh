#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ARTIFACT="$DIST_DIR/ntfs-perm-fix"

mkdir -p "$DIST_DIR"

cat > "$ARTIFACT" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

echo "ntfs-perm-fix single-file package placeholder"
STUB

chmod +x "$ARTIFACT"
echo "built: $ARTIFACT"
