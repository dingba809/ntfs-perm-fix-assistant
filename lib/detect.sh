#!/usr/bin/env bash

classify_fs() {
  local raw_fs="${1:-}"

  case "$raw_fs" in
    ntfs|fuseblk)
      printf 'ntfs\n'
      ;;
    *)
      printf '%s\n' "$raw_fs"
      ;;
  esac
}

classify_driver() {
  local raw_fs="${1:-}"
  local opts="${2:-}"

  case "$raw_fs" in
    ntfs3)
      printf 'ntfs3\n'
      ;;
    fuseblk)
      printf 'ntfs-3g\n'
      ;;
    ntfs)
      if [[ ",$opts," == *,windows_names,* ]]; then
        printf 'ntfs-3g\n'
      else
        printf 'ntfs\n'
      fi
      ;;
    *)
      printf '%s\n' "$raw_fs"
      ;;
  esac
}

path_exists() {
  local target_path="${1:-}"
  [[ -e "$target_path" ]]
}

is_mountpoint_path() {
  local target_path="${1:-}"

  if command -v mountpoint >/dev/null 2>&1; then
    mountpoint -q -- "$target_path"
    return $?
  fi

  findmnt -T "$target_path" >/dev/null 2>&1
}

scan_access_issues() {
  local raw_fs="${1:-}"
  local opts="${2:-}"
  local normalized_fs
  local issues=()

  normalized_fs="$(classify_fs "$raw_fs")"

  if [[ ",$opts," == *,ro,* ]]; then
    issues+=("read-only-mount")
  fi

  if [[ "$normalized_fs" == "ntfs" && ",$opts," != *,uid=* ]]; then
    issues+=("uid-not-set")
  fi

  if [[ ${#issues[@]} -eq 0 ]]; then
    return 1
  fi

  local IFS=,
  printf '%s\n' "${issues[*]}"
}

list_ntfs_mountpoints() {
  local source=""
  local target=""
  local fstype=""
  local options=""
  local normalized_fs=""

  if ! command -v findmnt >/dev/null 2>&1; then
    echo "findmnt command not found" >&2
    return 1
  fi

  while read -r source target fstype options; do
    [[ -n "$target" ]] || continue
    normalized_fs="$(classify_fs "$fstype")"
    if [[ "$normalized_fs" == "ntfs" || "$fstype" == "ntfs3" ]]; then
      printf '%s|%s|%s|%s\n' "$source" "$target" "$fstype" "$options"
    fi
  done < <(findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS)
}

collect_mount_info() {
  local mountpoint="${1:-}"
  local source=""
  local raw_fs=""
  local opts=""
  local normalized_fs=""
  local driver=""
  local issues="none"
  local issues_detected=""

  if ! command -v findmnt >/dev/null 2>&1; then
    echo "findmnt command not found" >&2
    return 1
  fi

  if ! read -r source raw_fs opts < <(findmnt -n -o SOURCE,FSTYPE,OPTIONS --target "$mountpoint"); then
    echo "failed to read mount info for $mountpoint" >&2
    return 1
  fi

  source="${source:-unknown}"
  raw_fs="${raw_fs:-unknown}"
  opts="${opts:-}"

  normalized_fs="$(classify_fs "$raw_fs")"
  normalized_fs="${normalized_fs:-unknown}"
  driver="$(classify_driver "$raw_fs" "$opts")"
  driver="${driver:-unknown}"

  if issues_detected="$(scan_access_issues "$raw_fs" "$opts")"; then
    issues="$issues_detected"
  fi

  cat <<INFO
mountpoint=$mountpoint
source=$source
fstype=$raw_fs
filesystem=$normalized_fs
driver=$driver
options=$opts
access_issues=$issues
INFO
}
