#!/usr/bin/env bash
# 把仓库里所有 OWNER 占位符替换成你的 GitHub 用户名。
#
#   bash tool/set_owner.sh <github用户名>
#
# 会改：README、docs/、lib/core/app_links.dart、.github/workflows/。
# 替换前建议先 `git status` 确认工作区干净，方便回滚。
set -euo pipefail

if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "用法: bash tool/set_owner.sh <github用户名>" >&2
  exit 1
fi

OWNER="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "提示：当前不是 git 仓库，替换后不便回滚，请自行备份。" >&2
fi

FILES=$(grep -rlE --include='*.md' --include='*.dart' --include='*.yml' --include='*.yaml' \
  --include='*.json' --include='*.sh' '(^|[^A-Za-z0-9_])OWNER([^A-Za-z0-9_]|$)' . \
  | grep -v '^./build/' | grep -v '^./.dart_tool/' || true)

if [ -z "$FILES" ]; then
  echo "没有找到 OWNER 占位符，可能已经替换过了。"
  exit 0
fi

echo "即将修改以下文件："
echo "$FILES" | sed 's/^/  - /'

for file in $FILES; do
  sed -i "s/OWNER/$OWNER/g" "$file"
done

echo
echo "完成。仓库地址现在指向 https://github.com/$OWNER/dsh-pet-emoji"
echo "下一步："
echo "  git add -A && git commit -m \"chore: point links to $OWNER\""
