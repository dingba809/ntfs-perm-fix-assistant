#!/usr/bin/env bash

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

gather_issue_counts() {
  local root_path="${1:-}"
  local dir_count
  local file_count
  local dir_permission_issues
  local file_permission_issues
  local total_issues

  if [[ -z "$root_path" ]]; then
    log_error "gather_issue_counts requires a mountpoint path"
    return 1
  fi

  if [[ ! -d "$root_path" ]]; then
    log_error "target is not a directory: $root_path"
    return 1
  fi

  dir_count="$(find "$root_path" -xdev -type d | wc -l | tr -d ' ')"
  file_count="$(find "$root_path" -xdev -type f | wc -l | tr -d ' ')"
  dir_permission_issues="$(find "$root_path" -xdev -type d ! -perm 755 | wc -l | tr -d ' ')"
  file_permission_issues="$(find "$root_path" -xdev -type f ! -perm 644 | wc -l | tr -d ' ')"
  total_issues=$((dir_permission_issues + file_permission_issues))

  cat <<INFO
mountpoint=$root_path
directories=$dir_count
files=$file_count
dir_permission_issues=$dir_permission_issues
file_permission_issues=$file_permission_issues
total_issues=$total_issues
INFO
}

apply_tree_permissions() {
  local root_path="${1:-}"
  local mode="${2:-apply}"

  if [[ -z "$root_path" ]]; then
    log_error "apply_tree_permissions requires a mountpoint path"
    return 1
  fi

  if [[ ! -d "$root_path" ]]; then
    log_error "target is not a directory: $root_path"
    return 1
  fi

  case "$mode" in
    dry-run)
      log_info "dry-run: skip permission changes for $root_path"
      ;;
    apply)
      find "$root_path" -xdev -type d -exec chmod 755 {} +
      find "$root_path" -xdev -type f -exec chmod 644 {} +
      ;;
    *)
      log_error "unknown apply mode: $mode"
      return 1
      ;;
  esac

  gather_issue_counts "$root_path"
}
