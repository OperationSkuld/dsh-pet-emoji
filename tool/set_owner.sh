#!/usr/bin/env bash
# 把仓库地址里的占位符 / 旧账号替换成你的 GitHub 用户名。
#
#   bash tool/set_owner.sh <github用户名>
#
# 会改：README、docs/、lib/core/app_links.dart。脚本自己不会被改。
# 替换前建议先 `git status` 确认工作区干净，方便回滚。
set -euo pipefail

PLACEHOLDER="OWNER"

if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "用法: bash tool/set_owner.sh <github用户名>" >&2
  exit 1
fi

NEW_OWNER="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_LINKS="$ROOT/lib/core/app_links.dart"

# 当前账号：从 app_links.dart 读取，这样 fork 之后也能一键改成自己的名字
CURRENT_OWNER=""
if [ -f "$APP_LINKS" ]; then
  CURRENT_OWNER=$(sed -n "s/^const String kRepoOwner = '\(.*\)';$/\1/p" "$APP_LINKS" | head -1)
fi

if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "提示：当前不是 git 仓库，替换后不便回滚，请自行备份。" >&2
fi

cd "$ROOT"

TARGETS=$(grep -rlE --include='*.md' --include='*.dart' --include='*.yml' --include='*.yaml' \
  --include='*.json' "(${PLACEHOLDER}${CURRENT_OWNER:+|$CURRENT_OWNER})" . \
  | grep -v '^./build/' | grep -v '^./.dart_tool/' | grep -v '^./tool/set_owner.sh$' || true)

if [ -z "$TARGETS" ]; then
  echo "没有找到需要替换的账号名。"
  exit 0
fi

echo "即将修改以下文件："
echo "$TARGETS" | sed 's/^/  - /'

for file in $TARGETS; do
  sed -i -e "s/${PLACEHOLDER}/${NEW_OWNER}/g" "$file"
  if [ -n "$CURRENT_OWNER" ] && [ "$CURRENT_OWNER" != "$PLACEHOLDER" ]; then
    sed -i -e "s/${CURRENT_OWNER}/${NEW_OWNER}/g" "$file"
  fi
done

echo
echo "完成。仓库地址现在指向 https://github.com/${NEW_OWNER}/dsh-pet-emoji"
echo "下一步："
echo "  git add -A && git commit -m \"chore: point links to ${NEW_OWNER}\""
