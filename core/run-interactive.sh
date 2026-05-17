#!/bin/bash
# run-interactive.sh — interactive 입력 필요한 명령을 wt.exe 별창에서 실행
#
# 사용 시점:
#   - sudo 비밀번호 입력 필요
#   - npm/codex/gemini login 등 OAuth 흐름
#   - 대화형 prompt (y/N, password, etc.)
#
# 사용법:
#   bash run-interactive.sh "<title>" "<command...>"
#
# 예:
#   bash run-interactive.sh "🔓 codex login" "codex login"
#   bash run-interactive.sh "🧟 zombie kill" "sudo kill -9 1234; ps -ef | grep ..."
#
# 동작:
#   1. /tmp에 인라인 스크립트 생성 (heredoc, EOF로 변수 만료)
#   2. wt.exe new-tab으로 WSL bash에서 실행
#   3. 명령 종료 후 Enter 대기 → 사용자가 결과 확인 후 닫기
#
# Exit code:
#   0 = wt.exe 호출 성공 (실제 명령 결과는 별창에서)
#   1 = wt.exe 없음 (fallback 불가, 사용자에게 수동 실행 안내)
#   2 = 잘못된 사용법

set -u

if [ $# -lt 2 ]; then
    echo "Usage: $0 \"<title>\" \"<command>\"" >&2
    echo "Example: $0 \"🔓 codex login\" \"codex login\"" >&2
    exit 2
fi

TITLE="$1"
shift
COMMAND="$*"

if ! command -v wt.exe >/dev/null 2>&1; then
    echo "❌ wt.exe (Windows Terminal) 없음 — 별창 모드 불가" >&2
    echo "다음 명령을 WSL 터미널에서 직접 실행하세요:" >&2
    echo "" >&2
    echo "  $COMMAND" >&2
    echo "" >&2
    exit 1
fi

INNER=$(mktemp /tmp/harness-interactive-XXXXXX.sh)
cat > "$INNER" <<EOF
#!/bin/bash
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo '${TITLE}'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo ''
echo '\$ ${COMMAND}'
echo ''
${COMMAND}
EXIT_CODE=\$?
echo ''
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo "exit: \$EXIT_CODE"
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo ''
echo 'Enter를 누르면 창이 닫힙니다...'
read -r
rm -f "$INNER" 2>/dev/null
EOF
chmod +x "$INNER"

wt.exe --window 0 new-tab --title "$TITLE" wsl.exe -- bash "$INNER" >/dev/null 2>&1 &
disown 2>/dev/null || true

echo "🪟 새 Windows Terminal 창 열림 — 작업표시줄/Alt+Tab으로 확인" >&2
echo "   제목: $TITLE" >&2
echo "   필요한 입력(비밀번호 등) 처리 후 Enter로 창 닫기." >&2
exit 0
