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

WAIT_LIMIT=${HARNESS_WAIT_LIMIT:-600}

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

    echo "🪟 새 Windows Terminal 창에서 Codex 실행 중... (mode: ${MODE}, wait limit: ${WAIT_LIMIT}s)" >&2

    # 부모: done flag 동기 wait
    WAITED=0
    while [ ! -f "$DONE_FILE" ] && [ $WAITED -lt $WAIT_LIMIT ]; do
        sleep 1
        WAITED=$((WAITED + 1))
    done

    if [ ! -f "$DONE_FILE" ]; then
        echo "🚨 Codex 응답 ${WAIT_LIMIT}s 초과 — 새 창 확인 필요" >&2
        EXIT_CODE=124
        OUTPUT="ERROR: timeout after ${WAIT_LIMIT}s"
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

# 패턴 매칭은 **최종 결과의 마지막 30줄**만 — retry 메시지 오탐 방지
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
# `Attempt N failed` 같은 retry 메시지는 마지막 블록에는 보통 없음 → 오탐 감소
if echo "$TAIL_BLOCK" | grep -qiE "rate.?limit|quota.?exceeded|insufficient_quota|usage.?limit|too many requests|429|model.?usage.?limit|monthly.?limit|daily.?limit|plan.?limit|out of credits"; then
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  Codex quota 소진 — exit 3, ${ELAPSED}s"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } >&2
    echo "CODEX_QUOTA_EXHAUSTED: logged in but quota out — fallback to Claude" >&2
    exit 3
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
