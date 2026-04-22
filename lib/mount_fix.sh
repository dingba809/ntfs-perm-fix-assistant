#!/usr/bin/env bash

build_fstab_line() {
  local source_spec="$1"
  local mountpoint="$2"
  local fs_type="$3"
  local uid="$4"
  local gid="$5"
  local umask="$6"

  printf '%s %s %s defaults,uid=%s,gid=%s,umask=%s 0 0\n' \
    "$source_spec" "$mountpoint" "$fs_type" "$uid" "$gid" "$umask"
}

recommend_driver() {
  local raw_fs="${1:-}"

  case "$raw_fs" in
    ntfs|ntfs3|fuseblk|ntfs-3g)
      printf 'ntfs3\n'
      ;;
    *)
      printf '%s\n' "$raw_fs"
      ;;
  esac
}
