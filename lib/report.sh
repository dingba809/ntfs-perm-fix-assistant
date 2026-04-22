#!/usr/bin/env bash

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

json_escape() {
  local input="${1:-}"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  printf '%s' "$input"
}

render_text_summary() {
  local task_name="$1"
  local target="$2"
  local status="$3"
  local fs="${4:-unknown}"
  local driver="${5:-unknown}"

  cat <<TEXT
任务: $task_name
目标: $target
状态: $status
文件系统: $fs
驱动: $driver
时间: $(timestamp_now)
TEXT
}

render_json_summary() {
  local task_name="$1"
  local target="$2"
  local status="$3"
  local fs="${4:-unknown}"
  local driver="${5:-unknown}"
  local status_key="${6:-status}"

  case "$status_key" in
    status|result) ;;
    *)
      status_key="status"
      ;;
  esac

  printf '{"task":"%s","target":"%s","%s":"%s","fs":"%s","driver":"%s","timestamp":"%s"}\n' \
    "$(json_escape "$task_name")" \
    "$(json_escape "$target")" \
    "$status_key" \
    "$(json_escape "$status")" \
    "$(json_escape "$fs")" \
    "$(json_escape "$driver")" \
    "$(json_escape "$(timestamp_now)")"
}

write_report_files() {
  local output_dir="$1"
  local task_name="$2"
  local target="$3"
  local status="$4"
  local fs="${5:-unknown}"
  local driver="${6:-unknown}"
  local status_key="${7:-status}"
  local stamp
  local base_name
  local reservation_file
  local text_file
  local json_file

  stamp="$(date '+%Y%m%dT%H%M%S')"
  mkdir -p "$output_dir"

  reservation_file="$(mktemp "$output_dir/report-$stamp-XXXXXX.tmp")"
  base_name="${reservation_file%.tmp}"
  text_file="$base_name.txt"
  json_file="$base_name.json"

  rm -f "$reservation_file"
  render_text_summary "$task_name" "$target" "$status" "$fs" "$driver" >"$text_file"
  render_json_summary "$task_name" "$target" "$status" "$fs" "$driver" "$status_key" >"$json_file"

  printf 'text=%s\njson=%s\n' "$text_file" "$json_file"
}
