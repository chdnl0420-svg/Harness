#!/bin/bash
# codex-review.sh - Codex로 코드 리뷰 또는 plan critique 수행
#
# 사용법:
#   bash codex-review.sh "<요청 텍스트>"              (기본: 코드 리뷰)
#   bash codex-review.sh --mode plan-critique "<plan>" (plan critique)
#   bash codex-review.sh --mode code "<code>"          (명시적 코드 리뷰)
#   echo "<content>" | bash codex-review.sh
#
# 출력: stdout에 리뷰/critique 결과 (Codex 그대로)
# Exit code:
#   0 = 성공
#   1 = 일반 오류 (CLI 실행 실패)
#   2 = 인증 실패 (로그인 안 됨 / 토큰 만료) → 작업 중단 + 로그인 요청
#   3 = quota/rate limit 소진 (로그인은 됐으나 작업 불가) → Claude fallback
#   4 = Codex CLI 내부 subprocess 에러 (codex_core::tools::router stdin issue) → Claude fallback

# NVM 로딩
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh" >/dev/null 2>&1

# CLI 존재 사전 체크
if ! command -v codex >/dev/null 2>&1; then
    echo "❌ Codex CLI 미설치 (codex 명령 없음)" >&2
    echo "💡 해결: /harness-setup --fix  (또는 수동: npm install -g @openai/codex)" >&2
    exit 2
fi

CORE_DIR="$(dirname "$0")/../core"

# credentials 동기화
[ -f "$CORE_DIR/sync-creds.sh" ] && bash "$CORE_DIR/sync-creds.sh" 2>/dev/null

# 모드 파싱
MODE="code"
if [ "$1" = "--mode" ]; then
    MODE="$2"
    shift 2
fi

# 입력: 인자 또는 stdin
if [ -n "$1" ]; then
    INPUT="$1"
else
    INPUT=$(cat)
fi

if [ -z "$INPUT" ]; then
    echo "Usage: $0 [--mode code|plan-critique] <content>" >&2
    exit 1
fi

# 모드별 시스템 프롬프트
case "$MODE" in
    code)
        SYSTEM_PROMPT="당신은 시니어 코드 리뷰어입니다. 코드/설계를 다음 기준으로 검토하세요:
- 명확성과 가독성
- 잠재적 버그 / edge case
- 보안 취약점
- 성능 이슈
- 유지보수성

응답 형식 (STRICT — 오케스트레이터가 파싱함):
\`\`\`markdown
## Code Review

### Summary
[1-line verdict]

### Issues by Severity

#### CRITICAL
- [file:line] [issue]

#### HIGH
- [file:line] [issue]

#### MEDIUM
- [file:line] [issue]

#### LOW
- [file:line] [issue]

### LGTM
[YES/NO]
\`\`\`

verbatim 인용만, 추측 금지."
        ;;
    plan-critique)
        SYSTEM_PROMPT="당신은 시니어 엔지니어로, Claude가 작성한 작업 계획서를 리뷰합니다.
실제 구현 시작 전 최종 게이트입니다. 누락/위험/개선점을 적극적으로 찾아내세요.

다음 관점에서 critique 하세요:

## 1. Missing Pieces (누락)
Claude가 빠뜨린 단계, 파일, 고려사항이 있는가?

## 2. Hidden Risks (숨은 위험)
Claude가 식별하지 못한 위험은? (보안/성능/유지보수/의존성/엣지케이스)

## 3. Better Approaches (대안)
더 단순/안전/효율적인 구현 방법이 있는가?

## 4. Scope Issues (범위 문제)
- Over-engineering: 사용자 요청 대비 과한 부분
- Under-scoped: 누락된 기능

## 5. Critical Issues (필수 수정)
계획 그대로 진행하면 안 되는 부분 (있다면)

응답 형식 (STRICT — 오케스트레이터가 파싱함):
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
        echo "Unknown mode: $MODE (use 'code' or 'plan-critique')" >&2
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

# 작업 sync 파일들 (visible window mode 와 inline mode 공통)
WORK_ID=$(mktemp -u /tmp/harness-codex-XXXXXX)
RESULT_FILE="${WORK_ID}.out"
EXIT_FILE="${WORK_ID}.exit"
DONE_FILE="${WORK_ID}.done"
PROMPT_FILE="${WORK_ID}.prompt"

# prompt를 파일로 저장 (heredoc quoting 회피)
printf '%s' "$FULL_PROMPT" > "$PROMPT_FILE"

# Visible window mode 사용 여부 결정
USE_VISIBLE=1
if [ -n "$HARNESS_NO_VISIBLE" ]; then
    USE_VISIBLE=0
fi
if ! command -v wt.exe >/dev/null 2>&1; then
    USE_VISIBLE=0
fi

# Wait 정책 — 두 단계:
#   1) IDLE_LIMIT  : 마지막 stdout byte 이후 N초 무응답이면 진짜 멈춤으로 간주
#                    Codex가 reasoning/tool 호출로 계속 출력 중이면 무한 대기.
#   2) HARD_LIMIT  : runaway 안전망 (Codex가 hang 무한루프인 경우)
# 둘 다 env로 override 가능. 기본값은 일반 deep code analysis 충분히 커버.
IDLE_LIMIT=${HARNESS_IDLE_LIMIT:-180}
HARD_LIMIT=${HARNESS_HARD_LIMIT:-3600}
# 하위호환: 기존 HARNESS_WAIT_LIMIT 설정돼 있으면 HARD_LIMIT으로 매핑
if [ -n "${HARNESS_WAIT_LIMIT:-}" ]; then
    HARD_LIMIT=$HARNESS_WAIT_LIMIT
fi

if [ "$USE_VISIBLE" = "1" ]; then
    # ─── Visible window mode (Option B) ───────────────────────
    INNER=$(mktemp /tmp/harness-codex-inner-XXXXXX.sh)
    cat > "$INNER" <<EOF
#!/bin/bash
# 어떤 종료 경로든 done flag 보장 (사용자가 창 강제 종료해도)
trap 'echo "\${PIPESTATUS[0]:-130}" > "$EXIT_FILE" 2>/dev/null; touch "$DONE_FILE" 2>/dev/null' EXIT

export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && source "\$NVM_DIR/nvm.sh" >/dev/null 2>&1

clear
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo '🤖 Codex — mode: ${MODE}'
echo '📤 요청 길이: ${INPUT_LEN} chars   ⏱  ${START_HUMAN}'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo ''

PROMPT_CONTENT=\$(cat "$PROMPT_FILE")
NO_COLOR=1 TERM=dumb stdbuf -oL -eL codex exec --skip-git-repo-check -- "\$PROMPT_CONTENT" 2>&1 \\
    | stdbuf -oL -eL tee "$RESULT_FILE"
ACTUAL_EXIT=\${PIPESTATUS[0]}
echo "\$ACTUAL_EXIT" > "$EXIT_FILE"
touch "$DONE_FILE"

echo ''
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo "✅ Codex 완료 (exit \$ACTUAL_EXIT) — 3초 후 자동 닫힘"
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
sleep 3
EOF
    chmod +x "$INNER"

    # wt.exe 새 창 spawn
    wt.exe --window 0 new-tab --title "🤖 Codex ${MODE}" \
        wsl.exe -- bash "$INNER" >/dev/null 2>&1 &
    disown 2>/dev/null || true

    echo "🪟 새 Windows Terminal 창에서 Codex 실행 중... (idle limit: ${IDLE_LIMIT}s, hard limit: ${HARD_LIMIT}s)" >&2

    # 부모: done flag 동기 wait. Codex가 stdout으로 뭐든 쓰고 있으면 (reasoning, tool 호출 로그)
    # IDLE 카운터 리셋 → 무한 대기. 진짜 N초 무응답일 때만 abort.
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
            break  # 진짜 hang
        fi
        # 30초마다 heartbeat 메시지 (UX — 사용자에게 "기다리는 중")
        if [ $((WAITED - HEARTBEAT)) -ge 30 ]; then
            HEARTBEAT=$WAITED
            echo "  ⏱  Codex 작업 중... (${WAITED}s elapsed, ${CURRENT_SIZE} bytes captured)" >&2
        fi
    done

    if [ ! -f "$DONE_FILE" ]; then
        if [ "$IDLE" -ge "$IDLE_LIMIT" ]; then
            echo "🚨 Codex 무응답 ${IDLE_LIMIT}s — 멈춘 것으로 판단 (총 경과 ${WAITED}s)" >&2
        else
            echo "🚨 Codex hard limit ${HARD_LIMIT}s 초과 (runaway 안전망)" >&2
        fi
        echo "    새 Windows Terminal 창 직접 확인하여 진행 상태 확인 권장" >&2
        EXIT_CODE=124
        OUTPUT=$(cat "$RESULT_FILE" 2>/dev/null || echo "ERROR: timeout, no output captured")
    else
        EXIT_CODE=$(cat "$EXIT_FILE" 2>/dev/null || echo 1)
        OUTPUT=$(cat "$RESULT_FILE" 2>/dev/null || echo "ERROR: result file missing")
    fi

    rm -f "$RESULT_FILE" "$EXIT_FILE" "$DONE_FILE" "$PROMPT_FILE" "$INNER"
else
    # ─── Inline fallback (wt.exe 없거나 HARNESS_NO_VISIBLE=1) ───
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🤖 Codex — mode: ${MODE} (inline, no visible window)"
        echo "📤 요청 길이: ${INPUT_LEN} chars   ⏱  ${START_HUMAN}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } >&2

    NO_COLOR=1 TERM=dumb stdbuf -oL -eL codex exec --skip-git-repo-check -- "$FULL_PROMPT" 2>&1 \
        | stdbuf -oL -eL tee "$RESULT_FILE" >&2
    EXIT_CODE=${PIPESTATUS[0]}
    OUTPUT=$(cat "$RESULT_FILE")
    rm -f "$RESULT_FILE" "$PROMPT_FILE"
fi

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
OUTPUT_LEN=${#OUTPUT}

# ─── 핵심 정책: 패턴 매칭은 EXIT_CODE != 0 일 때만 수행 ───
# (Codex가 0으로 종료했다면 출력 내용이 어떻든 그건 정상 리뷰 응답이다.
#  코드 안의 "rate limit" 같은 문자열이나 Codex의 분석 문장이 quota로 오탐되는
#  사고를 차단. 예: 채팅앱 코드를 리뷰 중 "rate limit" 표현이 나옴 → 오탐)
#
# 🚨 예외: Codex CLI 내부 subprocess 에러 ─ 이 패턴은 사용자 응답에 절대 안 나옴
# (codex_core::tools::router 는 Codex 내부 Rust 모듈 로그)
# exit code와 무관하게 무조건 우선 감지.
if echo "$OUTPUT" | grep -qiE "codex_core::tools::router:[[:space:]]*error=|write_stdin failed: stdin is closed for this session"; then
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  Codex CLI 내부 subprocess 에러 — exit 4, ${ELAPSED}s"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "원인: codex_core::tools::router 가 닫힌 stdin 에 명령을 쓰려고 함."
        echo "      (Codex CLI 자체 버그, 큰 repo + rg/find 등 다중 subprocess 환경에서 가끔 발생)"
        echo ""
        echo "대응:"
        echo "  - 호출자가 Claude code-reviewer agent 로 fallback 권장"
        echo "  - Codex CLI 업데이트 확인: npm i -g @openai/codex@latest"
    } >&2
    echo "CODEX_TOOL_ROUTER_ERROR: subprocess stdin closed — fallback to Claude" >&2
    exit 4
fi

if [ "$EXIT_CODE" -ne 0 ]; then
    TAIL_BLOCK=$(printf '%s\n' "$OUTPUT" | tail -n 30)

    # 1) 인증 실패 패턴 (로그인 필요) → 로그인 창 + exit 2
    if echo "$TAIL_BLOCK" | grep -qiE "token_invalidated|authentication.*invalidated|401 Unauthorized|refresh_token_reused|access token.*could not be refreshed|sign in again|please log out|not authenticated|login required|no credentials"; then
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🔓 Codex 인증 실패 — exit 2, ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        bash "$(dirname "$0")/auth-helper.sh" codex >&2
        echo "CODEX_AUTH_REQUIRED: login window opened — workflow must halt" >&2
        echo "💡 의존성 검진: /harness-setup" >&2
        exit 2
    fi

    # 2) Quota/rate limit 패턴 (로그인 됐으나 사용 한도 초과) → Claude fallback 신호
    if echo "$TAIL_BLOCK" | grep -qiE "rate.?limit|quota.?exceeded|insufficient_quota|usage.?limit|too many requests|429|model.?usage.?limit|monthly.?limit|daily.?limit|plan.?limit|out of credits"; then
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "⚠️  Codex quota 소진 — exit 3, ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        echo "CODEX_QUOTA_EXHAUSTED: logged in but quota out — fallback to Claude" >&2
        exit 3
    fi
fi

# 정상 종료 마커
{
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Codex 응답 수신 — exit ${EXIT_CODE}, ${ELAPSED}s, ${OUTPUT_LEN} chars"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} >&2

# stdout으로 결과 emit (호출자가 변수에 capture 가능)
echo "$OUTPUT"
exit $EXIT_CODE
