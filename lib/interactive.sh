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
- 输入 2 查看帮助说明
- 输入 0 退出程序
HELP
}

interactive_mount_info_value() {
  local mount_info="${1:-}"
  local key="${2:-}"
  local line=""

  while IFS= read -r line; do
    [[ "$line" == "$key="* ]] || continue
    printf '%s\n' "${line#*=}"
    return 0
  done <<<"$mount_info"

  return 1
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
  local scan_output=""
  local scan_status=0

  scan_output="$(interactive_scan_mountpoints)"
  scan_status=$?
  if [[ "$scan_status" -ne 0 ]]; then
    return "$scan_status"
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    entries+=("$line")
  done <<<"$scan_output"

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

interactive_render_target_menu() {
  local target="${1:-}"

  cat <<MENU
当前目标：$target

[1] 自动诊断（推荐）
[2] 查看详细信息
[3] 生成修复建议
[4] 执行安全修复
[5] 执行 dry-run
[0] 返回上一级
MENU
}

interactive_assess_risk() {
  local mount_info="${1:-}"
  local options=""
  local _driver=""
  local issues=""

  options="$(interactive_mount_info_value "$mount_info" "options" || printf '')"
  _driver="$(interactive_mount_info_value "$mount_info" "driver" || printf 'unknown')"
  issues="$(interactive_mount_info_value "$mount_info" "access_issues" || printf 'none')"

  if [[ ",$options," == *,ro,* ]]; then
    printf 'high|read-only-access-warning\n'
  elif [[ "$issues" != "none" ]]; then
    printf 'medium|read-write-access-warning\n'
  else
    printf 'low|no-obvious-access-issue\n'
  fi
}

interactive_render_diagnosis_menu() {
  local target="${1:-}"
  local fs="${2:-unknown}"
  local mount_mode="${3:-unknown}"
  local summary="${4:-unknown}"

  cat <<MENU
诊断结论：
- 目标挂载点：$target
- 文件系统：$fs
- 挂载状态：$mount_mode
- 结论：$summary

推荐操作：
[1] 执行安全修复（推荐）
[2] 先执行 dry-run
[3] 查看详细报告
[0] 返回
MENU
}

interactive_run_diagnosis() {
  local target="${1:-}"
  local mount_info=""
  local fs=""
  local options=""
  local _risk_level=""
  local summary=""

  if ! declare -F collect_mount_info >/dev/null 2>&1; then
    echo "collect_mount_info is not available" >&2
    return 1
  fi

  mount_info="$(collect_mount_info "$target")" || return 1
  fs="$(interactive_mount_info_value "$mount_info" "fstype" || printf 'unknown')"
  options="$(interactive_mount_info_value "$mount_info" "options" || printf 'unknown')"
  IFS='|' read -r _risk_level summary <<<"$(interactive_assess_risk "$mount_info")"

  interactive_render_diagnosis_menu "$target" "$fs" "$options" "$summary"
}

interactive_target_menu() {
  local target="${1:-}"
  local choice=""

  while true; do
    interactive_render_target_menu "$target"
    printf '请选择操作: '
    if ! IFS= read -r choice; then
      return 0
    fi

    case "$choice" in
      1)
        interactive_run_diagnosis "$target"
        ;;
      2|3|4|5)
        printf '该功能将在后续任务中实现。\n'
        ;;
      0)
        return 0
        ;;
      *)
        printf '无效选择，请重试。\n'
        ;;
    esac
  done
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
          interactive_target_menu "$selected_mountpoint"
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
