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

  cat <<TEXT
任务: $task_name
目标: $target
状态: $status
时间: $(timestamp_now)
TEXT
}

render_json_summary() {
  local task_name="$1"
  local target="$2"
  local status="$3"

  printf '{"task":"%s","target":"%s","status":"%s","timestamp":"%s"}\n' \
    "$(json_escape "$task_name")" \
    "$(json_escape "$target")" \
    "$(json_escape "$status")" \
    "$(json_escape "$(timestamp_now)")"
}

write_report_files() {
  local output_dir="$1"
  local task_name="$2"
  local target="$3"
  local status="$4"
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
  render_text_summary "$task_name" "$target" "$status" >"$text_file"
  render_json_summary "$task_name" "$target" "$status" >"$json_file"

  printf 'text=%s\njson=%s\n' "$text_file" "$json_file"
}
