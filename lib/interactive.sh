#!/usr/bin/env bash

interactive_print_main_menu() {
  cat <<'MENU'
=== NTFS 权限修复助手主菜单 ===
1) 功能说明
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

interactive_main_menu() {
  local choice=""

  while true; do
    interactive_print_main_menu
    printf '请选择: '
    if ! IFS= read -r choice; then
      return 0
    fi

    case "$choice" in
      1)
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
