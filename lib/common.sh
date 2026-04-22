#!/usr/bin/env bash

project_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

default_config_path() {
  if [[ -n "${NTFS_PERM_FIX_CONFIG:-}" ]]; then
    printf '%s\n' "$NTFS_PERM_FIX_CONFIG"
    return 0
  fi
  printf '%s/config/default.yaml\n' "$(project_root)"
}

timestamp_now() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

bool_normalize() {
  local raw="${1:-}"
  local normalized
  normalized="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"

  case "$normalized" in
    1|true|yes|on)
      printf 'true\n'
      ;;
    0|false|no|off)
      printf 'false\n'
      ;;
    *)
      return 1
      ;;
  esac
}

_log() {
  local level="$1"
  shift
  printf '[%s] [%s] %s\n' "$(timestamp_now)" "$level" "$*" >&2
}

log_info() { _log INFO "$@"; }
log_warn() { _log WARN "$@"; }
log_error() { _log ERROR "$@"; }

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "required command not found: $cmd"
    return 1
  fi
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log_error 'this command must be run as root'
    return 1
  fi
}

yaml_get() {
  local file="$1"
  local key_path="$2"

  [[ -f "$file" ]] || {
    log_error "yaml file not found: $file"
    return 1
  }

  awk -v path="$key_path" '
    BEGIN {
      n = split(path, parts, ".")
    }
    {
      if ($0 ~ /^[[:space:]]*#/ || $0 ~ /^[[:space:]]*$/) {
        next
      }
      if (match($0, /^([[:space:]]*)([A-Za-z0-9_.-]+):[[:space:]]*(.*)$/, m)) {
        indent = length(m[1])
        level = int(indent / 2) + 1
        key = m[2]
        value = m[3]

        stack[level] = key
        for (i = level + 1; i <= 32; i++) {
          delete stack[i]
        }

        if (value == "") {
          next
        }

        ok = 1
        if (level != n) {
          ok = 0
        } else {
          for (i = 1; i <= n; i++) {
            if (stack[i] != parts[i]) {
              ok = 0
              break
            }
          }
        }

        if (ok) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
          if ((value ~ /^\".*\"$/) || (value ~ /^\047.*\047$/)) {
            value = substr(value, 2, length(value) - 2)
          }
          print value
          exit 0
        }
      }
    }
    END {
      if (NR > 0) {
        exit 1
      }
    }
  ' "$file"
}
