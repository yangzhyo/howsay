#!/usr/bin/env bash
# 在终端里用和快捷指令完全相同的请求调 Gemini，方便调 prompt.txt。
#
# 用法：
#   export GEMINI_API_KEY=...
#   ./check.sh 他走了
#   ./check.sh --raw 他走了        # 打印完整返回 JSON，用来核对返回结构
#   ./check.sh --dry-run 他走了    # 只打印将要发送的请求体，不调接口
#   MODEL=gemini-3.7-flash ./check.sh 他走了   # 临时换型号
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
model="${MODEL:-gemini-3.5-flash-lite}"
url="https://generativelanguage.googleapis.com/v1beta/interactions"

mode=normal
case "${1:-}" in
  --raw)     mode=raw;    shift ;;
  --dry-run) mode=dry;    shift ;;
esac

source_text="${*:-}"
if [[ -z "$source_text" ]]; then
  echo "用法: $0 [--raw|--dry-run] <一句中文>" >&2
  exit 2
fi

# jq 负责把提示词和输入转义成合法 JSON，输入里有引号、换行都不怕。
body="$(jq -n \
  --arg model "$model" \
  --rawfile sys "$here/prompt.txt" \
  --arg input "$source_text" \
  '{model: $model,
    system_instruction: $sys,
    input: $input,
    store: false,
    generation_config: {thinking_level: "minimal"}}')"

if [[ "$mode" == dry ]]; then
  printf '%s\n' "$body"
  exit 0
fi

: "${GEMINI_API_KEY:?请先 export GEMINI_API_KEY}"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
# 返回体写到临时文件，stdout 只留 curl 统计的总耗时。
elapsed="$(curl -sS -o "$tmp" -w '%{time_total}' -X POST "$url" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Api-Revision: 2026-05-20" \
  -d "$body")"
resp="$(cat "$tmp")"

if [[ "$mode" == raw ]]; then
  printf '%s\n' "$resp" | jq .
  exit 0
fi

# 取最后一个 model_output 步里的所有 text 块；思考过程是独立的 thought 步，不会混进来。
text="$(printf '%s' "$resp" | jq -r '
  [.steps[]? | select(.type == "model_output") | .content[]? | select(.type == "text") | .text]
  | last // empty')"

if [[ -z "$text" ]]; then
  echo "没拿到文字，完整返回如下：" >&2
  printf '%s\n' "$resp" | jq . >&2
  exit 1
fi

printf '%s\n' "$text"
printf '\n(%s, %ss)\n' "$model" "$elapsed" >&2
