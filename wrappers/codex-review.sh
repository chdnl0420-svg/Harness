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

# ===== 인자 파싱 (--mode, --prompt-file 자유 순서) =====
MODE="code"
PROMPT_FILE_ARG=""
while [ $# -gt 0 ]; do
    case "${1:-}" in
        --mode)
            MODE="${2:-code}"
            shift 2
            ;;
        --prompt-file)
            PROMPT_FILE_ARG="${2:-}"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

# ===== 입력 (우선순위: --prompt-file > $1 인자 > stdin) =====
# 대용량 prompt 는 ARG_MAX (Linux 보통 ~128KB, WSL 경계는 더 작음) 회피용으로
# --prompt-file 사용 권장.
if [ -n "$PROMPT_FILE_ARG" ]; then
    if [ ! -f "$PROMPT_FILE_ARG" ]; then
        echo "❌ --prompt-file 경로 없음: $PROMPT_FILE_ARG" >&2
        exit 1
    fi
    INPUT=$(cat "$PROMPT_FILE_ARG")
elif [ -n "${1:-}" ]; then
    INPUT="$1"
else
    INPUT=$(cat)
fi
if [ -z "$INPUT" ]; then
    echo "Usage: $0 [--mode code|plan-critique] [--prompt-file <file>] [<content>]" >&2
    echo "       대용량 prompt 는 --prompt-file 사용 권장 (ARG_MAX 회피)" >&2
    exit 1
fi

# ===== 모드별 시스템 프롬프트 =====
case "$MODE" in
    code)
        SYSTEM_PROMPT='[중요 — 파일 쓰기 금지, 읽기는 허용]
당신은 리뷰만 수행합니다. 이 작업 중 어떤 소스 파일도 수정/생성/삭제하지 마세요.
파일 읽기(file-read / cat 등) 는 허용 — 사용자 prompt 에 리뷰 대상 파일이 본문 없이 "Files to review" 경로 목록으로만 전달되었다면 당신의 file-read 도구로 그 경로를 직접 읽어 검토하세요. 경로는 프로젝트 루트 기준 상대 경로 입니다.
유일한 쓰기 예외: 작업 끝에 sentinel 파일 한 개만 작성 (지시는 프롬프트 끝에 있음).
코드 변경·리팩토링·테스트 작성 모두 금지. 지적만 텍스트로.

당신은 시니어 코드 리뷰어입니다. 코드/설계를 다음 기준으로 검토하세요:
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
        SYSTEM_PROMPT='[중요 — 파일 수정 금지]
당신은 plan critique 만 수행합니다. 어떤 파일도 수정/생성/삭제하지 마세요.
유일한 예외: 작업 끝에 sentinel 파일 한 개만 작성 (지시는 프롬프트 끝에 있음).

당신은 시니어 엔지니어로, Claude가 작성한 작업 계획서를 리뷰합니다.
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
SENTINEL="$SESSION_DIR/${MODE}-${TS}-$$.done.html"
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
# 일반 repo: .git 디렉토리, worktree: .git 파일(gitdir 포인터) — 둘 다 인정
IS_GIT_REPO=0
WORKTREE_GITDIR=""
if [ -e "$PROJECT_DIR/.git" ]; then
    IS_GIT_REPO=1
    if [ -f "$PROJECT_DIR/.git" ]; then
        # worktree: .git 파일에서 실제 gitdir 추출
        WORKTREE_GITDIR=$(sed -n 's/^gitdir: //p' "$PROJECT_DIR/.git" 2>/dev/null | head -1)
    fi
elif (cd "$PROJECT_DIR" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    IS_GIT_REPO=1
fi

if [ "$IS_GIT_REPO" = "0" ]; then
    # 2026-05-14: workspace-write 샌드박스이지만 system prompt 가 sentinel 외 쓰기 금지.
    # 비-git 폴더 자동 init 안 함 (사용자 환경 오염 회피).
    echo "ℹ️  $PROJECT_DIR 는 git repo 가 아님 (리뷰는 텍스트 응답 + sentinel 만 쓰므로 무관)." >&2
fi

# ===== sentinel 지시 suffix 구축 =====
SENTINEL_TEMPLATE="$CORE_DIR/sentinel-instructions.html"
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
# 2026-05-14: sandbox=workspace-write 로 복귀.
# 이유: sentinel 완료 신호는 wrapper가 파일 쓰기로 감지함. read-only 면 sentinel 작성 불가 → 무한 대기.
# 안전성: system prompt + sentinel-instructions.html 에서 "sentinel 외 파일 수정 절대 금지" 명시.
exec codex --sandbox workspace-write -C "$PROJECT"
INNER_EOF
sed -i "s|__PROJECT__|$PROJECT_DIR|g" "$INNER"
chmod +x "$INNER"

# ===== 시작 마커 =====
PROJECT_DISPLAY="$PROJECT_DIR"
[ -n "$WORKTREE_GITDIR" ] && PROJECT_DISPLAY="$PROJECT_DIR  (worktree → $WORKTREE_GITDIR)"
{
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🤖 Codex TUI — mode: ${MODE}"
    echo "📂 PROJECT_DIR: ${PROJECT_DISPLAY}"
    echo "📤 요청 길이: ${INPUT_LEN} chars (+ system prompt + sentinel suffix = ${PROMPT_LEN} chars)"
    echo "📺 tmux session: $SESSION_NAME"
    echo "🎯 sentinel: $SENTINEL"
    echo "⏱  ${START_HUMAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} >&2

# ===== tmux 세션 시작 =====
# 주의: remain-on-exit 는 설정하지 않는다. codex 가 pane 안에서 끝나면 pane 도 자연 종료되어
# tmux session → bash → wsl.exe → wt.exe 탭 순서로 graceful close 가 일어나야 하기 때문.
# 디버그용 결과는 sentinel 파일과 `.harness/reviews/_codex-raw-*.txt` 에 이미 저장됨.
tmux new-session -d -s "$SESSION_NAME" "bash $INNER" 2>&1 | sed 's/^/  [tmux] /' >&2

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

    # Trust prompt (codex 0.130+) — `Do you trust the contents of this directory?`
    # 이 화면이 떠 있는 동안 wrapper 가 Escape 를 보내면 codex 가 곧바로 status 0 으로
    # 종료해서 pane dead 가 됨. ready 판단 전에 '1' + Enter 로 통과시킨다.
    if echo "$PANE_CAPTURE" | grep -qiE "trust the contents of this directory|Yes, (continue|proceed) and trust"; then
        echo "  🛡  trust prompt 감지 → '1' + Enter 자동 응답" >&2
        tmux send-keys -t "$SESSION_NAME" "1"
        sleep 0.2
        tmux send-keys -t "$SESSION_NAME" Enter
        sleep 1.2
        continue
    fi

    # 정상 prompt 라인 감지 (gpt-5.5 default, Write tests for @filename 등)
    # 주의: codex 0.130+ trust prompt 가 `› 1. Yes, continue` 라인을 포함하므로
    # `› ` 만 매칭하면 trust 화면을 ready 로 오인 → Escape 후 quit. `› ` 제거.
    if echo "$PANE_CAPTURE" | grep -qE 'gpt-[0-9.]+ default|Write tests for @' 2>/dev/null; then
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
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null
    rm -f "$INNER"
    exit 1
fi
echo "  ✅ Codex TUI ready" >&2

# ===== Stale 모드(자동 resume / scroll / edit) 빠져나오기 =====
# 2026-05-15: Codex v0.130.0 부터 비정상 종료된 직전 세션을 자동 resume 함.
# 그 결과 새 호출 시 메인 input box 대신 메시지 스크롤/편집 모드로 진입 →
# paste-buffer 가 input box 에 들어가지 못해 prompt 주입이 실패.
# 해결: paste 전에 Escape 를 여러 번 보내 어떤 모드든 메인 input box 로 강제 복귀.
TARGET_PANE="$SESSION_NAME:0.0"
for _ in 1 2 3; do
    tmux send-keys -t "$TARGET_PANE" Escape 2>/dev/null
    sleep 0.25
done
sleep 0.4

POST_ESC=$(tmux capture-pane -t "$TARGET_PANE" -p 2>/dev/null)
if ! echo "$POST_ESC" | grep -qE '› |gpt-[0-9.]+ default' 2>/dev/null; then
    echo "  ⚠ Escape 후에도 메인 input box 미감지 — 화면 마지막 8줄:" >&2
    echo "$POST_ESC" | tail -8 | sed 's/^/      │ /' >&2
fi

# ===== 프롬프트 주입 (load-buffer + paste-buffer + 검증 + 재시도) =====
PROMPT_FILE=$(mktemp /tmp/harness-codex-prompt-XXXXXX.txt)
printf '%s' "$FULL_PROMPT" > "$PROMPT_FILE"

# 항상 load-buffer + paste-buffer 사용:
# - send-keys -l 은 멀티라인 텍스트의 newline 을 codex TUI 가 submit 으로 해석할 수 있어 prompt 쪼개짐.
# - load-buffer + paste-buffer 는 input box 에 buffer 내용을 한 덩어리로 paste → 안전.
# - -p: bracketed paste 모드 (TUI 가 paste 임을 명확히 인지, newline 을 줄바꿈으로 처리)
# - -d: paste 후 buffer 자동 삭제
inject_prompt() {
    local buf_name="$1"
    tmux load-buffer -b "$buf_name" "$PROMPT_FILE"
    tmux paste-buffer -t "$TARGET_PANE" -b "$buf_name" -p -d
}

# prompt 의 첫 의미 있는 단어 추출 (입력 검증용 marker)
PROMPT_MARKER=$(printf '%s' "$FULL_PROMPT" | tr '\n' ' ' | awk '{for(i=1;i<=NF;i++){ if(length($i)>=4){ print $i; exit } }}')
[ -z "$PROMPT_MARKER" ] && PROMPT_MARKER=$(printf '%s' "$FULL_PROMPT" | head -c 12)

# 입력 박스에 prompt 가 실제로 들어갔는지 확인하는 함수.
# Codex TUI 는 large paste 를 `[Pasted Content NNN chars]` 로 collapse 표시하기 때문에
# marker 자체가 capture 텍스트에 안 보일 수 있음 → 그 collapse 표기도 success 로 인정.
verify_paste() {
    local cap
    cap=$(tmux capture-pane -t "$TARGET_PANE" -p -S - 2>/dev/null)
    # 1) Codex 의 paste collapse 표기
    if echo "$cap" | grep -qE '\[Pasted Content [0-9]+ chars\]'; then
        return 0
    fi
    # 2) marker 가 그대로 보임 (소형 prompt)
    if [ -n "$PROMPT_MARKER" ] && echo "$cap" | grep -qF "$PROMPT_MARKER"; then
        return 0
    fi
    return 1
}

echo "  ⌨  prompt 주입 (load-buffer + paste-buffer, ${PROMPT_LEN} bytes, marker='${PROMPT_MARKER}')..." >&2
inject_prompt "harness-prompt-$$"
sleep 2.5

if ! verify_paste; then
    echo "  ⚠ paste 후 입력박스에 콘텐츠 미감지 — Escape 후 1회 재시도" >&2
    # 입력박스에 잘못 들어간 부분이 있다면 Ctrl+U 로 라인 비움
    tmux send-keys -t "$TARGET_PANE" C-u 2>/dev/null
    sleep 0.3
    for _ in 1 2; do
        tmux send-keys -t "$TARGET_PANE" Escape 2>/dev/null
        sleep 0.3
    done
    inject_prompt "harness-prompt-retry-$$"
    sleep 3.0
    if ! verify_paste; then
        echo "❌ 재시도에도 입력박스에 prompt 미반영 — 진단 후 종료" >&2
        tmux capture-pane -t "$TARGET_PANE" -p 2>/dev/null | tail -15 | sed 's/^/    │ /' >&2
        tmux kill-session -t "$SESSION_NAME" 2>/dev/null
        rm -f "$INNER" "$PROMPT_FILE"
        exit 1
    fi
fi

# paste 완료 후 추가 안정화 → submit
sleep 0.6
tmux send-keys -t "$TARGET_PANE" Enter
echo "  ✅ prompt 전송 + Enter (검증 OK)" >&2

# ===== 폴링 (sentinel + pane 종료 + idle + 에러 패턴) =====
# Idle 감지: pane capture **내용 hash** 변화로 활동 판정.
# - Codex TUI는 spinner/token-count가 같은 위치에서 갱신 → 길이는 같고 내용만 변함.
# - md5sum 비교로 1글자 변화도 활동으로 인식. IDLE 카운터 리셋.
# - HARNESS_IDLE_LIMIT=0 으로 idle 비활성화 가능 (HARD_LIMIT만 적용).
WAITED=0
IDLE=0
LAST_CAPTURE_HASH=""
LAST_SENTINEL_SIZE=0
HEARTBEAT=0
END_REASON=""
SENTINEL_RETRY_SENT=0   # codex 0.130+ 자동복구: 응답완료 후 sentinel 누락 시 1회 재요청 plаg

while [ "$WAITED" -lt "$HARD_LIMIT" ]; do
    sleep 2
    WAITED=$((WAITED + 2))

    # 1. sentinel 파일 (최우선)
    if [ -f "$SENTINEL" ] && grep -q '<<<HARNESS-DONE>>>' "$SENTINEL" 2>/dev/null; then
        END_REASON="sentinel"
        break
    fi

    # 1-B. 자동 복구 (codex 0.130+ 패턴 대응)
    #      응답 출력 완료 후 codex 가 sentinel 작성을 누락하고 입력박스로 바로 복귀하는
    #      케이스. 트리거: "─ Worked for ... ─" 종료 마커 + 입력박스(gpt-X.X default)
    #      가 capture 에 동시에 보이면 codex 에 sentinel 작성을 한 번만 재요청한다.
    #      재요청에도 실패하면 기존 idle-timeout 경로로 자연 종료.
    if [ ! -f "$SENTINEL" ] && [ "$SENTINEL_RETRY_SENT" = "0" ]; then
        FULL_CAPTURE=$(tmux capture-pane -t "$SESSION_NAME" -p -S - 2>/dev/null)
        if echo "$FULL_CAPTURE" | grep -qE '─+ Worked for [0-9]+'; then
            if echo "$FULL_CAPTURE" | tail -30 | grep -qE 'gpt-[0-9.]+ default'; then
                echo "  📥 응답 완료 + 입력박스 복귀 감지 → codex 에 sentinel 작성 재요청 (one-shot)" >&2
                REMIND_TMP=$(mktemp /tmp/harness-codex-retry-XXXXXX.txt)
                cat > "$REMIND_TMP" <<EOF
방금 출력한 응답 본문을 아래 sentinel 파일에 누락 없이 작성해 주세요. 이 파일이 없으면 호출자(harness wrapper) 가 무한 대기 후 timeout 으로 작업이 실패합니다.

파일 경로:
$SENTINEL

파일 내용 (정확히 이 형식 — 응답 본문은 방금 화면에 출력한 내용 그대로 한 글자도 변형 금지):

\`\`\`
<응답 본문 전체>

<<<HARNESS-DONE>>>
\`\`\`

마커 \`<<<HARNESS-DONE>>>\` 는 마지막 단독 라인. 다른 파일은 절대 만들거나 수정하지 마세요.
EOF
                BUF="harness-retry-$$"
                tmux load-buffer -b "$BUF" "$REMIND_TMP" 2>/dev/null
                tmux paste-buffer -t "$TARGET_PANE" -b "$BUF" -p -d 2>/dev/null
                sleep 0.6
                tmux send-keys -t "$TARGET_PANE" Enter 2>/dev/null
                rm -f "$REMIND_TMP"
                SENTINEL_RETRY_SENT=1
                # idle 카운터 reset 유도 (capture 가 paste 로 변경됨)
                LAST_CAPTURE_HASH=""
                continue
            fi
        fi
    fi

    # 2. tmux pane 종료 감지
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        END_REASON="pane-died"
        break
    fi
    PANE_DEAD=$(tmux list-panes -t "$SESSION_NAME" -F '#{pane_dead}' 2>/dev/null | head -1)
    if [ "$PANE_DEAD" = "1" ]; then
        END_REASON="pane-died"
        break
    fi

    # 3. 에러 패턴 (capture-pane scan)
    # 마지막 200 라인만 검사 → 큰 prompt 의 paste echo 는 위로 스크롤되어 영향 감소.
    CAPTURE=$(tmux capture-pane -t "$SESSION_NAME" -p -S -200 2>/dev/null)

    # sentinel 미존재 시에만 에러 패턴 스캔.
    # sentinel 이 생성됐다는 건 Codex 가 이미 인증·과금 통과하고 응답 작성 중이라는 뜻.
    # 그 시점 이후엔 quota/auth 메시지가 capture 에 새로 나올 일이 거의 없고,
    # 사용자 prompt 본문에 들어간 "rate limit" 같은 일반 단어가 false positive 를 일으킴.
    if [ ! -f "$SENTINEL" ]; then
        # Codex 내부 subprocess 에러 — 매우 specific 한 Rust 모듈 prefix 라 prompt 와 충돌 거의 없음.
        if echo "$CAPTURE" | grep -qiE "codex_core::tools::router:[[:space:]]*error=|write_stdin failed: stdin is closed for this session"; then
            END_REASON="codex-internal-error"
            break
        fi
        # 인증 실패 — API 에러 코드 형태로 anchoring (prompt 일반어와 분리).
        if echo "$CAPTURE" | grep -qiE "token_invalidated|HTTP/[0-9.]+ 401|\"code\":[[:space:]]*\"unauthorized\"|refresh_token_reused|please log in again|/login"; then
            END_REASON="auth-failure"
            break
        fi
        # Quota 소진 — OpenAI/Codex API 가 실제로 emit 하는 에러 코드/문구만 매칭.
        # 일반 명사 "rate limit", "plan limit" 단독 매칭 제거 (prompt 본문 false positive 원인).
        if echo "$CAPTURE" | grep -qiE "rate_limit_exceeded|insufficient_quota|quota_exceeded|usage_limit_exceeded|HTTP/[0-9.]+ 429|You've reached your (usage|monthly) limit|Plus plan limit reached|out of credits"; then
            END_REASON="quota-exhausted"
            break
        fi
    fi

    # 4. idle 검사 — IDLE_LIMIT=0 이면 skip (사용자가 비활성화)
    if [ "$IDLE_LIMIT" -gt 0 ]; then
        # sentinel 크기 변화
        CURRENT_SENTINEL_SIZE=0
        if [ -f "$SENTINEL" ]; then
            CURRENT_SENTINEL_SIZE=$(stat -c %s "$SENTINEL" 2>/dev/null || echo 0)
        fi
        # capture 내용 hash
        CURRENT_CAPTURE_HASH=$(printf '%s' "$CAPTURE" | md5sum 2>/dev/null | awk '{print $1}')

        if [ "$CURRENT_SENTINEL_SIZE" -gt "$LAST_SENTINEL_SIZE" ] || \
           [ "$CURRENT_CAPTURE_HASH" != "$LAST_CAPTURE_HASH" ]; then
            IDLE=0
            LAST_SENTINEL_SIZE=$CURRENT_SENTINEL_SIZE
            LAST_CAPTURE_HASH=$CURRENT_CAPTURE_HASH
        else
            IDLE=$((IDLE + 2))
        fi
        if [ "$IDLE" -ge "$IDLE_LIMIT" ]; then
            END_REASON="idle-timeout"
            break
        fi
    fi

    if [ $((WAITED - HEARTBEAT)) -ge 30 ]; then
        HEARTBEAT=$WAITED
        SENTINEL_INFO="MISSING"
        if [ -f "$SENTINEL" ]; then
            SENTINEL_INFO="$(stat -c %s "$SENTINEL" 2>/dev/null || echo 0)B"
        fi
        IDLE_INFO=""
        [ "$IDLE_LIMIT" -gt 0 ] && IDLE_INFO=", idle=${IDLE}s/${IDLE_LIMIT}s"
        echo "  ⏱  Codex 작업 중... (${WAITED}s elapsed, sentinel ${SENTINEL_INFO}${IDLE_INFO})" >&2
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
            # false positive 디버깅: 어떤 라인이 매칭됐는지 마지막 3개 출력.
            echo "📝 매칭된 라인 (false positive 의심 시 검토):"
            echo "$CAPTURE" | grep -iE "rate_limit_exceeded|insufficient_quota|quota_exceeded|usage_limit_exceeded|HTTP/[0-9.]+ 429|You've reached your (usage|monthly) limit|Plus plan limit reached|out of credits" | tail -3 | sed 's/^/    │ /'
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
            echo "디버그: sentinel 보존 → $SENTINEL"
            echo ""
            echo "💡 Codex가 실제로 작업 중인데 idle로 잘못 감지된 경우:"
            echo "   - HARNESS_IDLE_LIMIT=0           (idle 검사 자체 비활성, HARD_LIMIT만 적용)"
            echo "   - HARNESS_IDLE_LIMIT=600         (idle 한도 연장, 기본 180s → 10분)"
            echo "   - HARNESS_HARD_LIMIT=7200        (전체 한도 연장)"
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
# tmux 세션은 success/fail 무관 항상 종료 — wt.exe 탭이 안 닫히는 증상 차단.
# sentinel + .harness/reviews/_codex-raw-*.txt 는 audit 위해 보존됨.
rm -f "$INNER" "$PROMPT_FILE"
tmux kill-session -t "$SESSION_NAME" 2>/dev/null
if [ "$EXIT_CODE" != "0" ]; then
    echo "  (디버그: sentinel 보존 → $SENTINEL)" >&2
fi

# ===== stdout 출력 =====
echo "$OUTPUT"
exit $EXIT_CODE
