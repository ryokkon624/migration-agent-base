#!/bin/bash
input=$(cat)

# Parse bash command from JSON input
command=$(echo "$input" | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tool_input = data.get('tool_input', data)
    print(tool_input.get('command', ''))
except:
    print('')
" 2>/dev/null)

# Skip if not a git commit (or is a dry-run)
if ! echo "$command" | grep -qE "git\s+commit"; then
    exit 0
fi
if echo "$command" | grep -q "\-\-dry-run"; then
    exit 0
fi

# Detect repository (java-migration リビルド先リポジトリ)
if echo "$command" | grep -q "jpetstore-frontend"; then
    repo="C:/work/java-migration/jpetstore-frontend"
    format_cmd="npm run format"
elif echo "$command" | grep -q "jpetstore-backend"; then
    repo="C:/work/java-migration/jpetstore-backend"
    format_cmd="./gradlew spotlessApply"
else
    # legacy-jpetstore(レガシーは無改変)・jpetstore-database・migration-agent-base 自身は整形対象外
    exit 0
fi

# Block commits to main
branch=$(git -C "$repo" branch --show-current 2>/dev/null)
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    echo "ERROR: mainへの直接コミットは禁止されています。($repo)" >&2
    echo "使用可能なプレフィックス: feature/ fix/ refactor/ docs/ hotfix/" >&2
    exit 1
fi

# Run formatter + re-stage
echo "[Format Hook] $(basename $repo): $format_cmd を実行中..." >&2
(cd "$repo" && eval "$format_cmd" && git add -u) || exit 1

exit 0
