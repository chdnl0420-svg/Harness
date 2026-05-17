#!/bin/bash
# setup-gemini-key.sh — Gemini API key를 ~/.bashrc 에 안전하게 등록
#
# 사용법 1 (한 줄, 권장): 키를 인자로 전달
#   bash setup-gemini-key.sh AIzaSyXXXX...
#
# 사용법 2 (interactive): 인자 없이 호출하면 prompt
#   bash setup-gemini-key.sh
#
# 동작:
#   1. 키 형식 검증 (AIzaSy 시작 + 39자) — 어긋나면 confirm
#   2. ~/.bashrc 백업 (.bak-YYYYMMDD-HHMMSS)
#   3. 기존 GEMINI_API_KEY 라인 교체 / 없으면 append
#   4. 결과 검증 (키 값은 로그 안 함, prefix/suffix만)
#   5. 현재 셸에서도 즉시 export

set -u

BASHRC="$HOME/.bashrc"
BACKUP="$BASHRC.bak-$(date +%Y%m%d-%H%M%S)"

# --- 1) 키 받기 ---
if [ -n "${1:-}" ]; then
    KEY="$1"
    SOURCE="argument"
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔑 Gemini API Key 등록"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "키 발급: https://aistudio.google.com/apikey"
    echo "(입력 중 키는 화면에 표시되지 않음)"
    echo ""
    read -r -s -p "Gemini API key: " KEY
    echo ""
    SOURCE="prompt"
fi

# --- 2) 형식 검증 ---
KEY_LEN=${#KEY}
if [ "$KEY_LEN" -eq 0 ]; then
    echo "❌ 키 입력 없음. 중단."
    exit 1
fi

WARN_ISSUED=0
if [ "$KEY_LEN" -ne 39 ]; then
    echo "⚠️  키 길이가 39자가 아닙니다 (현재: ${KEY_LEN}자)"
    WARN_ISSUED=1
fi
if [[ ! "$KEY" =~ ^AIzaSy ]]; then
    echo "⚠️  키가 'AIzaSy' 로 시작하지 않습니다."
    WARN_ISSUED=1
fi

if [ "$WARN_ISSUED" = "1" ]; then
    if [ "$SOURCE" = "argument" ]; then
        echo "    인자로 전달된 값이라 자동 confirm 없이 진행합니다."
        echo "    잘못된 값이면 다시 실행하세요."
    else
        read -r -p "그래도 진행? (y/N): " CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            echo "중단."
            exit 1
        fi
    fi
fi

# --- 3) 백업 + 편집 ---
[ -f "$BASHRC" ] || touch "$BASHRC"
cp "$BASHRC" "$BACKUP"
echo "📦 백업: $BACKUP"

if grep -qE '^[[:space:]]*export[[:space:]]+GEMINI_API_KEY=' "$BASHRC"; then
    sed -i.tmp "s|^[[:space:]]*export[[:space:]]\+GEMINI_API_KEY=.*|export GEMINI_API_KEY=\"${KEY}\"|" "$BASHRC"
    rm -f "${BASHRC}.tmp"
    echo "✏️  기존 GEMINI_API_KEY 라인 교체"
else
    echo "" >> "$BASHRC"
    echo "# Added by harness setup-gemini-key.sh" >> "$BASHRC"
    echo "export GEMINI_API_KEY=\"${KEY}\"" >> "$BASHRC"
    echo "✏️  GEMINI_API_KEY 라인 추가"
fi

# --- 4) 검증 ---
NEW_LINE=$(grep -E '^[[:space:]]*export[[:space:]]+GEMINI_API_KEY=' "$BASHRC" | tail -1)
if [ -z "$NEW_LINE" ]; then
    echo "❌ 검증 실패. 복구: cp \"$BACKUP\" \"$BASHRC\""
    exit 1
fi
WRITTEN_KEY=$(echo "$NEW_LINE" | sed -E 's/.*=//; s/^"//; s/"$//')
WRITTEN_LEN=${#WRITTEN_KEY}
WRITTEN_PREFIX="${WRITTEN_KEY:0:6}"
WRITTEN_SUFFIX="${WRITTEN_KEY: -3}"

# --- 5) 현재 셸에도 즉시 적용 ---
export GEMINI_API_KEY="$KEY"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 등록 완료"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  파일: $BASHRC"
echo "  값:   ${WRITTEN_PREFIX}...${WRITTEN_SUFFIX} (총 ${WRITTEN_LEN}자)"
echo "  현재 셸: GEMINI_API_KEY export 적용됨"
echo ""
echo "다음:"
echo "  - Claude Code 에서: /harness-setup (재검진)"
echo ""

unset KEY WRITTEN_KEY
exit 0
