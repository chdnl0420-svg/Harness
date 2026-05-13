#!/bin/bash
# gemini-research.sh - Gemini로 리서치 또는 plan-critique (Codex fallback)
#
# 사용법:
#   bash gemini-research.sh "<조사 주제>"                    (기본: 리서치)
#   bash gemini-research.sh --mode plan-critique "<plan>"    (Codex fallback)
#   bash gemini-research.sh --mode research "<topic>"        (명시적 리서치)
#   echo "<details>" | bash gemini-research.sh
#
# 출력: stdout에 결과 (Gemini 그대로)
# Exit code:
#   0 = 성공
#   1 = 일반 오류
#   2 = 인증 실패 (로그인 필요) → 작업 중단 + 로그인 요청
#   3 = quota/rate limit 소진 → Claude fallback

# NVM 로딩
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh" >/dev/null 2>&1

# CLI 존재 사전 체크
if ! command -v gemini >/dev/null 2>&1; then
    echo "❌ Gemini CLI 미설치 (gemini 명령 없음)" >&2
    echo "💡 해결: /harness-setup --fix  (또는 수동: npm install -g @google/gemini-cli)" >&2
    exit 2
fi

# GEMINI_API_KEY 주입:
# - headless `gemini -p` 모드는 ~/.gemini/gemini-credentials.json 을 안 읽고
#   GEMINI_API_KEY env 를 강제 요구함.
# - ~/.bashrc 는 non-interactive에서 early-return 되므로 source 무효.
# - export 라인만 직접 grep + eval 하여 안전하게 주입.
if [ -z "$GEMINI_API_KEY" ] && [ -f "$HOME/.bashrc" ]; then
    while IFS= read -r line; do
        eval "$line" 2>/dev/null || true
    done < <(grep -E '^[[:space:]]*export[[:space:]]+(GEMINI_API_KEY|GOOGLE_API_KEY|GEMINI_CLI_TRUSTED_WORKSPACE)=' "$HOME/.bashrc")
fi

# 모델 선택: 기본은 -m 미지정 (CLI가 free/paid tier에 맞춰 자동 선택).
# Free tier에서 특정 pro 모델은 정책으로 차단되므로 강제 지정 금지.
# 명시적 override: HARNESS_GEMINI_MODEL=gemini-3-flash-preview (등)
if [ -n "$HARNESS_GEMINI_MODEL" ]; then
    GEMINI_MODEL_ARG=(-m "$HARNESS_GEMINI_MODEL")
else
    GEMINI_MODEL_ARG=()
fi

CORE_DIR="$(dirname "$0")/../core"

# credentials 동기화
[ -f "$CORE_DIR/sync-creds.sh" ] && bash "$CORE_DIR/sync-creds.sh" 2>/dev/null

# 모드 파싱
MODE="research"
if [ "$1" = "--mode" ]; then
    MODE="$2"
    shift 2
fi

# 입력
if [ -n "$1" ]; then
    INPUT="$1"
else
    INPUT=$(cat)
fi

if [ -z "$INPUT" ]; then
    echo "Usage: $0 [--mode research|plan-critique] <content>" >&2
    exit 1
fi

# 모드별 시스템 프롬프트
case "$MODE" in
    research)
        SYSTEM_PROMPT="당신은 기술 리서치 전문가입니다. 다음 주제를 조사하세요:
- 현재 업계 트렌드 / 모범 사례
- 주요 라이브러리/프레임워크 비교
- 최근 변경사항 / 마이그레이션 정보
- 실제 사용 사례 / 케이스 스터디
- 출처 명시 (가능하면)

응답 형식:
## 📊 핵심 요약 (3-5문장)
## 🔍 상세 발견
## 📚 참고/출처 (있으면)
## 💡 권장사항

추측·환각 금지. 모르면 '확실치 않음' 명시."
        ;;
    plan-critique)
        SYSTEM_PROMPT="당신은 시니어 엔지니어로, Claude가 작성한 작업 계획서를 리뷰합니다 (Codex 대체 critic).
실제 구현 시작 전 최종 게이트입니다. 누락/위험/개선점을 적극적으로 찾아내세요.

다음 관점에서 critique:

## 1. Missing Pieces (누락)
## 2. Hidden Risks (숨은 위험, severity 명시)
## 3. Better Approaches (대안)
## 4. Scope Issues (Over/Under)
## 5. Critical Issues (필수 수정)

응답 형식 (STRICT):
\`\`\`markdown
## Plan Critique

### Missing Pieces
- [item]

### Hidden Risks
- [risk] (severity: HIGH/MEDIUM/LOW)

### Better Approaches
- [suggestion]

### Scope Issues
- Over: [item]
- Under: [item]

### Critical Issues
- [must fix item]

### LGTM
[YES/NO]
\`\`\`

추측 금지, 구체적 근거만."
        ;;
    *)
        echo "Unknown mode: $MODE (use 'research' or 'plan-critique')" >&2
        exit 1
        ;;
esac

FULL_PROMPT="--- SYSTEM PROMPT ---
${SYSTEM_PROMPT}

--- 요청 ---
${INPUT}"

INPUT_LEN=${#INPUT}
START_TS=$(date +%s)
START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')

WORK_ID=$(mktemp -u /tmp/harness-gemini-XXXXXX)
RESULT_FILE="${WORK_ID}.out"
EXIT_FILE="${WORK_ID}.exit"
DONE_FILE="${WORK_ID}.done"
PROMPT_FILE="${WORK_ID}.prompt"

printf '%s' "$FULL_PROMPT" > "$PROMPT_FILE"

USE_VISIBLE=1
if [ -n "$HARNESS_NO_VISIBLE" ]; then
    USE_VISIBLE=0
fi
if ! command -v wt.exe >/dev/null 2>&1; then
    USE_VISIBLE=0
fi

# Wait 정책 — idle 기반 + hard limit safety net (Codex wrapper와 동일):
#   IDLE_LIMIT  : 마지막 stdout byte 이후 N초 무응답이면 멈춤으로 간주
#   HARD_LIMIT  : runaway 안전망
IDLE_LIMIT=${HARNESS_IDLE_LIMIT:-180}
HARD_LIMIT=${HARNESS_HARD_LIMIT:-3600}
if [ -n "${HARNESS_WAIT_LIMIT:-}" ]; then
    HARD_LIMIT=$HARNESS_WAIT_LIMIT  # 하위호환
fi

if [ "$USE_VISIBLE" = "1" ]; then
    INNER=$(mktemp /tmp/harness-gemini-inner-XXXXXX.sh)
    cat > "$INNER" <<EOF
#!/bin/bash
trap 'echo "\${PIPESTATUS[1]:-130}" > "$EXIT_FILE" 2>/dev/null; touch "$DONE_FILE" 2>/dev/null' EXIT

export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && source "\$NVM_DIR/nvm.sh" >/dev/null 2>&1

# GEMINI_API_KEY 주입 (headless 모드 강제 요구)
if [ -f "\$HOME/.bashrc" ]; then
    while IFS= read -r __line; do
        eval "\$__line" 2>/dev/null || true
    done < <(grep -E '^[[:space:]]*export[[:space:]]+(GEMINI_API_KEY|GOOGLE_API_KEY|GEMINI_CLI_TRUSTED_WORKSPACE)=' "\$HOME/.bashrc")
fi

clear
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo '💎 Gemini — mode: ${MODE}'
echo '📤 요청 길이: ${INPUT_LEN} chars   ⏱  ${START_HUMAN}'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo ''

NO_COLOR=1 TERM=dumb cat "$PROMPT_FILE" \\
    | stdbuf -oL -eL gemini "${GEMINI_MODEL_ARG[@]}" -p "" --yolo --skip-trust 2>&1 \\
    | stdbuf -oL -eL awk '
        BEGIN { fail_count = 0 }
        { print; fflush() }
        /Attempt [0-9]+ failed/ {
            fail_count++
            if (fail_count >= 4) {
                print "[harness] Gemini retry storm (>=4 failures) — aborting"
                fflush()
                system("pkill -TERM -f \"gemini.*--yolo\" 2>/dev/null || true")
                exit 3
            }
        }
      ' \\
    | stdbuf -oL -eL tee "$RESULT_FILE"
ACTUAL_EXIT=\${PIPESTATUS[1]}
# awk exit 3 → quota out (force ACTUAL_EXIT=3 for downstream parsing)
if [ "\$ACTUAL_EXIT" != "3" ] && grep -qiE "Gemini retry storm" "$RESULT_FILE" 2>/dev/null; then ACTUAL_EXIT=3; fi
echo "\$ACTUAL_EXIT" > "$EXIT_FILE"
touch "$DONE_FILE"

echo ''
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo "✅ Gemini 완료 (exit \$ACTUAL_EXIT) — 3초 후 자동 닫힘"
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
sleep 3
EOF
    chmod +x "$INNER"

    wt.exe --window 0 new-tab --title "💎 Gemini ${MODE}" \
        wsl.exe -- bash "$INNER" >/dev/null 2>&1 &
    disown 2>/dev/null || true

    echo "🪟 새 Windows Terminal 창에서 Gemini 실행 중... (idle limit: ${IDLE_LIMIT}s, hard limit: ${HARD_LIMIT}s)" >&2

    # idle 기반 대기: stdout이 계속 자라면 IDLE 카운터 리셋, 무응답일 때만 abort
    WAITED=0
    IDLE=0
    LAST_SIZE=0
    HEARTBEAT=0
    while [ ! -f "$DONE_FILE" ] && [ "$WAITED" -lt "$HARD_LIMIT" ]; do
        sleep 2
        WAITED=$((WAITED + 2))
        CURRENT_SIZE=$(stat -c %s "$RESULT_FILE" 2>/dev/null || echo 0)
        if [ "$CURRENT_SIZE" -gt "$LAST_SIZE" ]; then
            IDLE=0
            LAST_SIZE=$CURRENT_SIZE
        else
            IDLE=$((IDLE + 2))
        fi
        if [ "$IDLE" -ge "$IDLE_LIMIT" ]; then
            break
        fi
        if [ $((WAITED - HEARTBEAT)) -ge 30 ]; then
            HEARTBEAT=$WAITED
            echo "  ⏱  Gemini 작업 중... (${WAITED}s elapsed, ${CURRENT_SIZE} bytes captured)" >&2
        fi
    done

    if [ ! -f "$DONE_FILE" ]; then
        if [ "$IDLE" -ge "$IDLE_LIMIT" ]; then
            echo "🚨 Gemini 무응답 ${IDLE_LIMIT}s — 멈춘 것으로 판단 (총 경과 ${WAITED}s)" >&2
        else
            echo "🚨 Gemini hard limit ${HARD_LIMIT}s 초과 (runaway 안전망)" >&2
        fi
        echo "    새 Windows Terminal 창 직접 확인 권장" >&2
        EXIT_CODE=124
        OUTPUT=$(cat "$RESULT_FILE" 2>/dev/null || echo "ERROR: timeout, no output captured")
    else
        EXIT_CODE=$(cat "$EXIT_FILE" 2>/dev/null || echo 1)
        OUTPUT=$(cat "$RESULT_FILE" 2>/dev/null || echo "ERROR: result file missing")
    fi

    rm -f "$RESULT_FILE" "$EXIT_FILE" "$DONE_FILE" "$PROMPT_FILE" "$INNER"
else
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "💎 Gemini — mode: ${MODE} (inline)"
        echo "📤 요청 길이: ${INPUT_LEN} chars   ⏱  ${START_HUMAN}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } >&2

    NO_COLOR=1 TERM=dumb printf '%s' "$FULL_PROMPT" \
        | stdbuf -oL -eL gemini "${GEMINI_MODEL_ARG[@]}" -p "" --yolo --skip-trust 2>&1 \
        | stdbuf -oL -eL awk '
            BEGIN { fail_count = 0 }
            { print; fflush() }
            /Attempt [0-9]+ failed/ {
                fail_count++
                if (fail_count >= 4) {
                    print "[harness] Gemini retry storm (>=4 failures) — aborting"
                    fflush()
                    system("pkill -TERM -f \"gemini.*--yolo\" 2>/dev/null || true")
                    exit 3
                }
            }
          ' \
        | stdbuf -oL -eL tee "$RESULT_FILE" >&2
    EXIT_CODE=${PIPESTATUS[1]}
    if grep -qiE "Gemini retry storm" "$RESULT_FILE" 2>/dev/null; then
        EXIT_CODE=3
    fi
    OUTPUT=$(cat "$RESULT_FILE")
    rm -f "$RESULT_FILE" "$PROMPT_FILE"
fi

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
OUTPUT_LEN=${#OUTPUT}

# 🚨 핵심 정책: 패턴 매칭은 EXIT_CODE != 0 일 때만 수행
# (Gemini가 0으로 종료했다면 출력이 어떻든 정상 응답. 사용자가 "rate limit 처리 방법"
#  같은 주제를 물어봐서 답변에 quota 관련 단어가 들어가는 경우 오탐을 방지.)
if [ "$EXIT_CODE" -ne 0 ]; then
    TAIL_BLOCK=$(printf '%s\n' "$OUTPUT" | tail -n 30)

    # 1) 인증 실패 패턴 (로그인 필요) → 로그인 창 + exit 2
    if echo "$TAIL_BLOCK" | grep -qiE "GEMINI_API_KEY|API_KEY_INVALID|API.?key.?expired|authentication.*required|401|please.*log.*in|need.*auth|not authenticated|login required|/auth"; then
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🔓 Gemini 인증 실패 — exit 2, ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        bash "$(dirname "$0")/auth-helper.sh" gemini >&2
        echo "GEMINI_AUTH_REQUIRED: login window opened — workflow must halt" >&2
        echo "💡 의존성 검진: /harness-setup" >&2
        exit 2
    fi

    # 2) Quota/rate limit 패턴 → Claude fallback 신호
    if echo "$TAIL_BLOCK" | grep -qiE "rate.?limit|quota.?exceeded|quota.?will.?reset|exhausted.*capacity|exhausted.*quota|resource_exhausted|usage.?limit|too many requests|429|daily.?limit|monthly.?limit"; then
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "⚠️  Gemini quota 소진 — exit 3, ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        echo "GEMINI_QUOTA_EXHAUSTED: logged in but quota out — fallback to Claude" >&2
        exit 3
    fi
fi

# 정상 종료 마커
{
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Gemini 응답 수신 — exit ${EXIT_CODE}, ${ELAPSED}s, ${OUTPUT_LEN} chars"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} >&2

# stdout으로 결과 emit
echo "$OUTPUT"
exit $EXIT_CODE
