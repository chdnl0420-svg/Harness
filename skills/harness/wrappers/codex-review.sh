#!/bin/bash
# codex-review.sh — Codex CLI 대화형 TUI(tmux) 기반 리뷰/critique wrapper
#
# 사용법:
#   bash codex-review.sh "<요청 텍스트>"                # 기본: 코드 리뷰
#   bash codex-review.sh --mode plan-critique "<plan>"  # plan critique
#   bash codex-review.sh --mode code "<code>"           # 명시적 코드 리뷰
#
# 출력: stdout = Codex가 작성한 응답 본문 (sentinel 파일에서 추출)
# Exit code:
#   0 = 성공
#   1 = 일반 오류 (sentinel 누락 + pane capture fallback도 부실)
#   2 = 인증 실패 (Codex 로그인 안 됨)
#   3 = quota/rate limit 소진
#   4 = Codex CLI 내부 subprocess 에러 (codex_core::tools::router stdin issue)
#   124 = idle/hard timeout
#
# 핵심 메커니즘 (이전 `codex exec` 호출 전면 대체):
#   1) tmux 세션 detached → 안에서 'codex' 대화형 TUI 실행
#   2) wt.exe attach (옵션, HARNESS_NO_VISIBLE=1 로 비활성)
#   3) TUI 로딩 감지 (capture-pane 폴링)
#   4) tmux send-keys로 prompt 주입 (대용량은 load-buffer + paste-buffer)
#   5) sentinel 파일 폴링 → <<<HARNESS-DONE>>> 마커 검증 → 본문 추출
#   6) cleanup

set -u

# ===== NVM 로딩 =====
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh" >/dev/null 2>&1

# ===== CLI 존재 사전 체크 =====
for cmd in codex tmux; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ $cmd 미설치" >&2
        echo "💡 해결: /harness-setup --fix  (또는 수동: apt/npm)" >&2
        exit 2
    fi
done

CORE_DIR="$(cd "$(dirname "$0")/../core" && pwd)"
WRAPPER_DIR="$(cd "$(dirname "$0")" && pwd)"

# credentials 동기화 (있으면)
[ -f "$CORE_DIR/sync-creds.sh" ] && bash "$CORE_DIR/sync-creds.sh" 2>/dev/null

# ===== 모드 파싱 =====
MODE="code"
if [ "${1:-}" = "--mode" ]; then
    MODE="${2:-code}"
    shift 2
fi

# ===== 입력 =====
if [ -n "${1:-}" ]; then
    INPUT="$1"
else
    INPUT=$(cat)
fi
if [ -z "$INPUT" ]; then
    echo "Usage: $0 [--mode code|plan-critique] <content>" >&2
    exit 1
fi

# ===== 모드별 시스템 프롬프트 =====
case "$MODE" in
    code)
        SYSTEM_PROMPT='당신은 시니어 코드 리뷰어입니다. 코드/설계를 다음 기준으로 검토하세요:
- 명확성과 가독성
- 잠재적 버그 / edge case
- 보안 취약점
- 성능 이슈
- 유지보수성

응답 형식 (STRICT — 오케스트레이터가 파싱함):
```markdown
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
```

verbatim 인용만, 추측 금지.'
        ;;
    plan-critique)
        SYSTEM_PROMPT='당신은 시니어 엔지니어로, Claude가 작성한 작업 계획서를 리뷰합니다.
실제 구현 시작 전 최종 게이트입니다. 누락/위험/개선점을 적극적으로 찾아내세요.

다음 관점에서 critique 하세요:

## 1. Missing Pieces (누락)
## 2. Hidden Risks (숨은 위험, severity 명시)
## 3. Better Approaches (대안)
## 4. Scope Issues (Over/Under)
## 5. Critical Issues (필수 수정)

응답 형식 (STRICT — 오케스트레이터가 파싱함):
```markdown
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
```

추측 금지, 구체적 근거만.'
        ;;
    *)
        echo "Unknown mode: $MODE (use code|plan-critique)" >&2
        exit 1
        ;;
esac

# ===== 환경 변수 / 경로 =====
PROJECT_DIR="${HARNESS_PROJECT_DIR:-$(pwd)}"
TS=$(date +%Y%m%d-%H%M%S)
SESSION_NAME="harness-codex-${MODE}-${TS}-$$"
SESSION_DIR="$PROJECT_DIR/.harness/.codex-sessions"
SENTINEL="$SESSION_DIR/${MODE}-${TS}-$$.done.md"
IDLE_LIMIT=${HARNESS_IDLE_LIMIT:-180}
HARD_LIMIT=${HARNESS_HARD_LIMIT:-3600}
[ -n "${HARNESS_WAIT_LIMIT:-}" ] && HARD_LIMIT=$HARNESS_WAIT_LIMIT
READY_TIMEOUT=${HARNESS_TMUX_READY_TIMEOUT:-30}
LARGE_PROMPT_THRESHOLD=${HARNESS_LARGE_PROMPT_BYTES:-10240}
MAX_ONBOARDING_ENTER=${HARNESS_MAX_ONBOARDING_ENTER:-3}

mkdir -p "$SESSION_DIR"
rm -f "$SENTINEL"

START_TS=$(date +%s)
START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')

# ===== git repo 자동 보장 (대화형 codex 요구) =====
if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "ℹ️  $PROJECT_DIR 는 git repo가 아닙니다. 자동 git init..." >&2
    (cd "$PROJECT_DIR" && git init -q -b main 2>&1 | sed 's/^/   /' >&2) || {
        echo "❌ git init 실패. 권한 또는 디렉토리 확인." >&2
        exit 1
    }
fi

# ===== sentinel 지시 suffix 구축 =====
SENTINEL_TEMPLATE="$CORE_DIR/sentinel-instructions.md"
if [ ! -f "$SENTINEL_TEMPLATE" ]; then
    echo "❌ sentinel template 없음: $SENTINEL_TEMPLATE" >&2
    exit 1
fi
SENTINEL_SUFFIX=$(sed "s|<SENTINEL_PATH>|$SENTINEL|g" "$SENTINEL_TEMPLATE")

FULL_PROMPT="--- SYSTEM PROMPT ---
${SYSTEM_PROMPT}

--- 요청 ---
${INPUT}

${SENTINEL_SUFFIX}"

INPUT_LEN=${#INPUT}
PROMPT_LEN=${#FULL_PROMPT}

# ===== tmux 안에서 codex 실행할 inner 스크립트 =====
INNER=$(mktemp /tmp/harness-codex-inner-XXXXXX.sh)
cat > "$INNER" <<'INNER_EOF'
#!/bin/bash
PROJECT="__PROJECT__"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh" >/dev/null 2>&1
exec codex --sandbox workspace-write -C "$PROJECT"
INNER_EOF
sed -i "s|__PROJECT__|$PROJECT_DIR|g" "$INNER"
chmod +x "$INNER"

# ===== 시작 마커 =====
{
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🤖 Codex TUI — mode: ${MODE}"
    echo "📤 요청 길이: ${INPUT_LEN} chars (+ system prompt + sentinel suffix = ${PROMPT_LEN} chars)"
    echo "📺 tmux session: $SESSION_NAME"
    echo "🎯 sentinel: $SENTINEL"
    echo "⏱  ${START_HUMAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} >&2

# ===== tmux 세션 시작 =====
tmux new-session -d -s "$SESSION_NAME" "bash $INNER" 2>&1 | sed 's/^/  [tmux] /' >&2
tmux set-option -t "$SESSION_NAME" remain-on-exit on 2>/dev/null || true

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "❌ tmux 세션 시작 실패" >&2
    rm -f "$INNER"
    exit 1
fi

# ===== wt.exe attach (옵션) =====
USE_VISIBLE=1
[ -n "${HARNESS_NO_VISIBLE:-}" ] && USE_VISIBLE=0
command -v wt.exe >/dev/null 2>&1 || USE_VISIBLE=0
if [ "$USE_VISIBLE" = "1" ]; then
    wt.exe --window 0 new-tab --title "🤖 Codex ${MODE} (tmux: $SESSION_NAME)" \
        wsl.exe -- bash -c "tmux attach -t '$SESSION_NAME'" >/dev/null 2>&1 &
    disown 2>/dev/null || true
    echo "🪟 wt.exe attach — Codex TUI 별창" >&2
fi

# ===== TUI 로딩 감지 =====
echo "  ⏱  Codex TUI 로딩 대기 (최대 ${READY_TIMEOUT}s)..." >&2
READY=0
WAITED=0
ONBOARDING_ENTER_COUNT=0
while [ "$WAITED" -lt "$READY_TIMEOUT" ]; do
    sleep 1
    WAITED=$((WAITED + 1))
    PANE_CAPTURE=$(tmux capture-pane -t "$SESSION_NAME" -p 2>/dev/null)

    # 정상 prompt 라인 감지 (gpt-5.5 default, Write tests for @filename 등)
    if echo "$PANE_CAPTURE" | grep -qE 'gpt-[0-9.]+ default|Write tests for @|› ' 2>/dev/null; then
        READY=1
        break
    fi

    # 인증 실패 즉시 감지
    if echo "$PANE_CAPTURE" | grep -qiE "not authenticated|please log in|sign in again|no credentials|/login"; then
        echo "🔓 Codex 인증 실패 (TUI에 로그인 화면 표시)" >&2
        bash "$WRAPPER_DIR/auth-helper.sh" codex >&2 2>/dev/null || true
        echo "CODEX_AUTH_REQUIRED: login required — workflow halt" >&2
        echo "💡 /harness-setup 후 재시도" >&2
        tmux kill-session -t "$SESSION_NAME" 2>/dev/null
        rm -f "$INNER"
        exit 2
    fi

    # Onboarding 화면 감지 (옵션 5-B: 자동 Enter 주입)
    if echo "$PANE_CAPTURE" | grep -qiE "press enter|continue|onboarding|welcome to codex|accept the terms|y/n.*continue"; then
        if [ "$ONBOARDING_ENTER_COUNT" -lt "$MAX_ONBOARDING_ENTER" ]; then
            ONBOARDING_ENTER_COUNT=$((ONBOARDING_ENTER_COUNT + 1))
            echo "  ⚙  onboarding 화면 감지 → Enter 자동 주입 (${ONBOARDING_ENTER_COUNT}/${MAX_ONBOARDING_ENTER})" >&2
            tmux send-keys -t "$SESSION_NAME" Enter
            sleep 1
        fi
    fi

    if [ "$WAITED" = "10" ]; then
        echo "  ⏱  ${WAITED}s elapsed — 마지막 캡처:" >&2
        echo "$PANE_CAPTURE" | tail -5 | sed 's/^/    │ /' >&2
    fi
done

if [ "$READY" != "1" ]; then
    echo "🚨 Codex TUI 로딩 ${READY_TIMEOUT}s 안에 prompt 안 보임 — 진단:" >&2
    tmux capture-pane -t "$SESSION_NAME" -p 2>/dev/null | tail -15 | sed 's/^/    │ /' >&2
    echo "tmux session 유지 (디버그용): tmux attach -t $SESSION_NAME" >&2
    rm -f "$INNER"
    exit 1
fi
echo "  ✅ Codex TUI ready" >&2

# ===== 프롬프트 주입 (크기 기반 분기) =====
PROMPT_FILE=$(mktemp /tmp/harness-codex-prompt-XXXXXX.txt)
printf '%s' "$FULL_PROMPT" > "$PROMPT_FILE"

# 항상 load-buffer + paste-buffer 사용:
# - send-keys -l 은 멀티라인 텍스트의 newline을 codex TUI가 submit으로 해석할 수 있어 prompt 쪼개짐.
# - load-buffer + paste-buffer 는 input box에 buffer 내용을 한 덩어리로 paste → 안전.
echo "  ⌨  prompt 주입 (load-buffer + paste-buffer, ${PROMPT_LEN} bytes)..." >&2
tmux load-buffer -t "$SESSION_NAME" -b "harness-prompt-$$" "$PROMPT_FILE"
# -p: bracketed paste 모드 (TUI가 paste임을 명확히 인지)
# -d: paste 후 buffer 자동 삭제
tmux paste-buffer -t "$SESSION_NAME" -b "harness-prompt-$$" -p -d
sleep 1.0
# paste 후 Enter로 submit
tmux send-keys -t "$SESSION_NAME" Enter
echo "  ✅ prompt 전송 + Enter" >&2

# ===== 폴링 (sentinel + pane 종료 + idle + 에러 패턴) =====
WAITED=0
IDLE=0
LAST_SIZE=0
HEARTBEAT=0
END_REASON=""

while [ "$WAITED" -lt "$HARD_LIMIT" ]; do
    sleep 2
    WAITED=$((WAITED + 2))

    # 1. sentinel 파일 (최우선)
    if [ -f "$SENTINEL" ] && grep -q '<<<HARNESS-DONE>>>' "$SENTINEL" 2>/dev/null; then
        END_REASON="sentinel"
        break
    fi

    # 2. tmux pane 종료 감지 (codex가 죽었거나 사용자가 끔)
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        END_REASON="pane-died"
        break
    fi
    PANE_DEAD=$(tmux list-panes -t "$SESSION_NAME" -F '#{pane_dead}' 2>/dev/null | head -1)
    if [ "$PANE_DEAD" = "1" ]; then
        END_REASON="pane-died"
        break
    fi

    # 3. 에러 패턴 (capture-pane 결과를 scan)
    CAPTURE=$(tmux capture-pane -t "$SESSION_NAME" -p -S - 2>/dev/null)
    if echo "$CAPTURE" | grep -qiE "codex_core::tools::router:[[:space:]]*error=|write_stdin failed: stdin is closed for this session"; then
        END_REASON="codex-internal-error"
        break
    fi
    if echo "$CAPTURE" | grep -qiE "token_invalidated|401 unauthorized|refresh_token_reused|sign in again|please log out|not authenticated"; then
        END_REASON="auth-failure"
        break
    fi
    if echo "$CAPTURE" | grep -qiE "rate.?limit|quota.?exceeded|usage.?limit|too many requests|429|plan.?limit|out of credits|insufficient_quota"; then
        END_REASON="quota-exhausted"
        break
    fi

    # 4. idle / heartbeat (sentinel 크기 + capture 크기 변화 추적)
    CURRENT_SIZE=0
    if [ -f "$SENTINEL" ]; then
        CURRENT_SIZE=$(stat -c %s "$SENTINEL" 2>/dev/null || echo 0)
    fi
    # 캡처도 변화 신호로 사용
    CAPTURE_HASH_SIZE=${#CAPTURE}
    TOTAL_SIGNAL=$((CURRENT_SIZE + CAPTURE_HASH_SIZE))

    if [ "$TOTAL_SIGNAL" -gt "$LAST_SIZE" ]; then
        IDLE=0
        LAST_SIZE=$TOTAL_SIGNAL
    else
        IDLE=$((IDLE + 2))
    fi
    if [ "$IDLE" -ge "$IDLE_LIMIT" ]; then
        END_REASON="idle-timeout"
        break
    fi

    if [ $((WAITED - HEARTBEAT)) -ge 30 ]; then
        HEARTBEAT=$WAITED
        echo "  ⏱  Codex 작업 중... (${WAITED}s elapsed, sentinel $([ -f "$SENTINEL" ] && echo "${CURRENT_SIZE}B" || echo "MISSING"))" >&2
    fi
done

if [ -z "$END_REASON" ]; then
    END_REASON="hard-timeout"
fi

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

# ===== 종료 분기 + 결과 추출 =====
EXIT_CODE=0
OUTPUT=""

case "$END_REASON" in
    sentinel)
        # 마커 위 본문 추출
        OUTPUT=$(awk '/<<<HARNESS-DONE>>>/{exit} {print}' "$SENTINEL")
        # 마커 직전 빈 줄 제거
        OUTPUT=$(echo "$OUTPUT" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✅ Codex 응답 수신 (sentinel) — ${ELAPSED}s, sentinel ${#OUTPUT}B"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        EXIT_CODE=0
        ;;
    codex-internal-error)
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "⚠️  Codex CLI 내부 subprocess 에러 — exit 4, ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "원인: codex_core::tools::router stdin closed"
            echo "권장: npm i -g @openai/codex@latest"
        } >&2
        echo "CODEX_TOOL_ROUTER_ERROR: subprocess stdin closed — fallback to Claude" >&2
        EXIT_CODE=4
        ;;
    auth-failure)
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🔓 Codex 인증 실패 — exit 2, ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        bash "$WRAPPER_DIR/auth-helper.sh" codex >&2 2>/dev/null || true
        echo "CODEX_AUTH_REQUIRED: login window opened — workflow halt" >&2
        echo "💡 /harness-setup" >&2
        EXIT_CODE=2
        ;;
    quota-exhausted)
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "⚠️  Codex quota 소진 — exit 3, ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        echo "CODEX_QUOTA_EXHAUSTED: logged in but quota out — fallback to Claude" >&2
        EXIT_CODE=3
        ;;
    pane-died)
        # codex가 종료됐는데 sentinel 없음 → fallback: pane capture를 결과로
        FALLBACK_CAPTURE=$(tmux capture-pane -t "$SESSION_NAME" -p -S - 2>/dev/null || echo "")
        if [ -z "$FALLBACK_CAPTURE" ]; then
            FALLBACK_CAPTURE="(pane 종료, capture 실패)"
        fi
        OUTPUT="⚠️ Codex가 sentinel 파일 작성 없이 종료. tmux pane 마지막 capture를 fallback으로 사용:

$FALLBACK_CAPTURE"
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "⚠️  Codex pane 종료 — sentinel 누락, capture fallback, ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        EXIT_CODE=1
        ;;
    idle-timeout)
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🚨 Codex idle ${IDLE_LIMIT}s — exit 124, 총 경과 ${ELAPSED}s"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "tmux 세션 유지 (디버그): tmux attach -t $SESSION_NAME"
        } >&2
        OUTPUT="ERROR: idle timeout after ${IDLE_LIMIT}s with no progress"
        EXIT_CODE=124
        ;;
    hard-timeout)
        {
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🚨 Codex hard limit ${HARD_LIMIT}s 초과 — exit 124"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >&2
        OUTPUT="ERROR: hard timeout after ${HARD_LIMIT}s"
        EXIT_CODE=124
        ;;
esac

# ===== Cleanup =====
rm -f "$INNER" "$PROMPT_FILE"
if [ "$EXIT_CODE" = "0" ]; then
    # 성공: tmux 정리, sentinel은 audit 위해 보존
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null
else
    # 실패: tmux + sentinel 모두 보존 (디버그)
    echo "  (디버그 보존: tmux=$SESSION_NAME, sentinel=$SENTINEL)" >&2
fi

# ===== stdout 출력 =====
echo "$OUTPUT"
exit $EXIT_CODE
