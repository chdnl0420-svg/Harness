#!/bin/bash
# auth-helper.sh - Codex/Gemini 인증 만료 시 자동 로그인 창 띄우기
#
# 사용법:
#   bash auth-helper.sh <codex|gemini>
#
# 동작:
#   - 임시 스크립트 파일 생성 → wt.exe로 새 창 띄움 → 그 스크립트 실행
#   - wt.exe는 ';'를 서브커맨드 구분자로 해석하므로 인자에 직접 ';' 포함 금지
#   - PowerShell Start-Process fallback
#
# 사용자가 새 창에서 OAuth 완료 후 메인 채팅에서 "완료" 입력하면 harness가 재시도.

TOOL=$1
if [ -z "$TOOL" ]; then
    echo "Usage: $0 <codex|gemini>" >&2
    exit 1
fi

# 도구별 로그인 명령
case "$TOOL" in
    codex)
        LOGIN_CMD="codex login"
        HINT="브라우저가 열리면 OpenAI 계정으로 로그인하세요."
        ;;
    gemini)
        LOGIN_CMD="gemini"
        HINT="창에서 '/auth' 명령 입력 후 Google 계정으로 로그인하세요."
        ;;
    *)
        echo "Unknown tool: $TOOL (use 'codex' or 'gemini')" >&2
        exit 1
        ;;
esac

# 임시 스크립트 파일 생성 (wt.exe ';' 파싱 이슈 회피)
TMP_SCRIPT=$(mktemp /tmp/harness-auth-XXXXXX.sh)
cat > "$TMP_SCRIPT" <<EOF
#!/bin/bash
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && source "\$NVM_DIR/nvm.sh" >/dev/null 2>&1
clear
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo '🔓 [${TOOL}] 인증 만료 — 로그인 필요'
echo '${HINT}'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo ''
${LOGIN_CMD}
echo ''
echo '✅ 로그인이 완료되었으면 메인 채팅에 "완료" 또는 "done" 입력하세요.'
echo '   (이 창은 닫아도 됩니다)'
read -p '아무 키나 누르면 닫힙니다...' _dummy
EOF
chmod +x "$TMP_SCRIPT"

# 새 터미널 창 띄우기 (wt.exe > powershell > 텍스트 안내)
if command -v wt.exe >/dev/null 2>&1; then
    # 기본 WSL distro 사용 (-d 인자 제거 — distro 이름 하드코딩 회피)
    wt.exe wsl.exe -- bash "$TMP_SCRIPT"
    echo "🔓 [${TOOL}] 새 Windows Terminal 창 열림 — 작업표시줄/Alt+Tab으로 확인"
elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "Start-Process wsl.exe -ArgumentList '--','bash','$TMP_SCRIPT'"
    echo "🔓 [${TOOL}] 새 WSL 창 열림 (PowerShell)"
else
    echo "⚠️ 자동 창 열기 실패 (wt.exe / powershell.exe 둘 다 없음)"
    echo ""
    echo "수동 실행: WSL 터미널을 새로 열고 다음 명령:"
    echo "    ${LOGIN_CMD}"
    [ "$TOOL" = "gemini" ] && echo "  그 후 '/auth' 입력"
fi

echo ""
echo "${HINT}"
echo "⚠️ 워크플로우 중단 상태 — 로그인 없이는 진행 불가 (fallback 없음)"
echo "로그인 완료 후 메인 채팅에 '완료' / 'done' / '재시도' 입력 → 작업 재시도"
echo "취소하려면 '취소' / 'cancel' 입력 → 워크플로우 종료"
