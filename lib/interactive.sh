#!/usr/bin/env bash

interactive_print_main_menu() {
  cat <<'MENU'
=== NTFS 权限修复助手主菜单 ===
1) 扫描 NTFS 挂载点
2) 功能说明
0) 退出
MENU
}

interactive_show_help() {
  cat <<'HELP'
这是交互模式骨架。
- 输入 1 查看帮助说明
- 输入 0 退出程序
HELP
}

interactive_scan_mountpoints() {
  if ! declare -F list_ntfs_mountpoints >/dev/null 2>&1; then
    echo "list_ntfs_mountpoints is not available" >&2
    return 1
  fi

  list_ntfs_mountpoints
}

interactive_select_mountpoint() {
  local entries=()
  local line=""
  local index=1
  local choice=""
  local target=""
  local fstype=""
  local options=""

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    entries+=("$line")
  done < <(interactive_scan_mountpoints)

  if [[ "${#entries[@]}" -eq 0 ]]; then
    printf '未检测到可处理的 NTFS 挂载点。\n' >&2
    return 1
  fi

  printf '检测到以下 NTFS 挂载点：\n' >&2
  for line in "${entries[@]}"; do
    IFS='|' read -r _source target fstype options <<<"$line"
    printf '[%d] %s (%s, %s)\n' "$index" "$target" "$fstype" "$options" >&2
    index=$((index + 1))
  done
  printf '[0] 返回主菜单\n' >&2
  printf '请输入编号: ' >&2
  IFS= read -r choice || return 1

  if [[ "$choice" == "0" ]]; then
    return 1
  fi

  if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
    printf '无效选择，请重新扫描。\n' >&2
    return 1
  fi

  line="${entries[$((choice - 1))]:-}"
  if [[ -z "$line" ]]; then
    printf '无效选择，请重新扫描。\n' >&2
    return 1
  fi

  IFS='|' read -r _source target _fstype _options <<<"$line"
  printf '%s\n' "$target"
}

interactive_main_menu() {
  local choice=""
  local selected_mountpoint=""

  while true; do
    interactive_print_main_menu
    printf '请选择: '
    if ! IFS= read -r choice; then
      return 0
    fi

    case "$choice" in
      1)
        if selected_mountpoint="$(interactive_select_mountpoint)"; then
          printf '已选择挂载点: %s\n' "$selected_mountpoint"
        fi
        ;;
      2)
        interactive_show_help
        ;;
      0)
        printf '已退出。\n'
        return 0
        ;;
      *)
        printf '无效选择，请重试。\n'
        ;;
    esac
  done
}
