#!/bin/bash
# setup-gemini-key.sh — Gemini API key를 ~/.bashrc 에 안전하게 등록
#
# 사용법:
#   bash setup-gemini-key.sh
#   (interactive, 별창에서 호출 권장: run-interactive.sh 헬퍼로 wrap)
#
# 동작:
#   1. 키 입력 받기 (read -s, 화면 표시 안 됨)
#   2. 형식 검증 (AIzaSy로 시작 + 39자)
#   3. ~/.bashrc 백업 후:
#      - 기존 GEMINI_API_KEY 라인 있으면 그 자리만 교체
#      - 없으면 맨 아래 append
#   4. 결과 검증 (grep 으로 새 값 확인, 키 값은 로그 안 함)

set -u

BASHRC="$HOME/.bashrc"
BACKUP="$BASHRC.bak-$(date +%Y%m%d-%H%M%S)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 Gemini API Key 등록"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1) 키가 없으면 https://aistudio.google.com/apikey 에서 발급"
echo "2) 발급 페이지의 'Show key' 클릭 후 키 복사 (AIzaSy... 로 시작)"
echo "3) 아래 프롬프트에 마우스 우클릭(Windows Terminal) 또는 Ctrl+Shift+V 로 붙여넣기"
echo ""
echo "주의: 입력 중 키는 화면에 보이지 않습니다 (보안)."
echo ""

# read -s 로 입력 숨김
read -r -s -p "Gemini API key: " KEY
echo ""
echo ""

# 형식 검증
KEY_LEN=${#KEY}
if [ "$KEY_LEN" -eq 0 ]; then
    echo "❌ 입력 없음. 중단."
    exit 1
fi

if [ "$KEY_LEN" -ne 39 ]; then
    echo "⚠️  키 길이가 39자가 아닙니다 (현재: ${KEY_LEN}자)"
    echo "    Google API key는 보통 'AIzaSy' + 33자 = 39자입니다."
    read -r -p "그래도 진행? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "중단."
        exit 1
    fi
fi

if [[ ! "$KEY" =~ ^AIzaSy ]]; then
    echo "⚠️  키가 'AIzaSy' 로 시작하지 않습니다."
    read -r -p "그래도 진행? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "중단."
        exit 1
    fi
fi

# ~/.bashrc 없으면 만들기
if [ ! -f "$BASHRC" ]; then
    touch "$BASHRC"
    echo "ℹ️  ~/.bashrc 새로 생성됨"
fi

# 백업
cp "$BASHRC" "$BACKUP"
echo "📦 백업: $BACKUP"

# 기존 라인 있는지 확인 후 교체 or append
if grep -qE '^[[:space:]]*export[[:space:]]+GEMINI_API_KEY=' "$BASHRC"; then
    # sed 로 교체 (key 값은 변수 expansion으로 안전하게 주입)
    # 구분자는 | 사용 (키에 / 들어갈 가능성 0)
    sed -i.tmp "s|^[[:space:]]*export[[:space:]]\+GEMINI_API_KEY=.*|export GEMINI_API_KEY=\"${KEY}\"|" "$BASHRC"
    rm -f "${BASHRC}.tmp"
    echo "✏️  기존 GEMINI_API_KEY 라인 교체"
else
    echo "" >> "$BASHRC"
    echo "# Added by harness setup-gemini-key.sh" >> "$BASHRC"
    echo "export GEMINI_API_KEY=\"${KEY}\"" >> "$BASHRC"
    echo "✏️  GEMINI_API_KEY 라인 추가"
fi

# 결과 검증 (키 값은 로그 안 함, prefix/suffix만)
NEW_LINE=$(grep -E '^[[:space:]]*export[[:space:]]+GEMINI_API_KEY=' "$BASHRC" | tail -1)
if [ -z "$NEW_LINE" ]; then
    echo "❌ 검증 실패 — ~/.bashrc 에 키가 안 들어갔습니다."
    echo "   백업에서 복구하려면: cp \"$BACKUP\" \"$BASHRC\""
    exit 1
fi

WRITTEN_KEY=$(echo "$NEW_LINE" | sed -E 's/.*=//; s/^"//; s/"$//')
WRITTEN_LEN=${#WRITTEN_KEY}
WRITTEN_PREFIX="${WRITTEN_KEY:0:6}"
WRITTEN_SUFFIX="${WRITTEN_KEY: -3}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 등록 완료"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  파일: $BASHRC"
echo "  값: ${WRITTEN_PREFIX}...${WRITTEN_SUFFIX} (총 ${WRITTEN_LEN}자)"
echo ""
echo "다음 단계:"
echo "  - 현재 셸: source ~/.bashrc"
echo "  - 또는 새 WSL 셸을 열면 자동 적용"
echo "  - 검증: /harness-setup (Claude Code 에서)"
echo ""

unset KEY WRITTEN_KEY
exit 0
