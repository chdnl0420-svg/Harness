#!/bin/bash
# harness-doctor.sh — Windows+WSL 환경의 harness 의존성 검진
#
# 사용법:
#   bash harness-doctor.sh           # 검사만 + 상세 리포트
#   bash harness-doctor.sh --fix     # npm 패키지 자동 설치 시도
#   bash harness-doctor.sh --quiet   # 모두 OK면 출력 없음 + exit 0 / 누락 시 출력 + exit 1
#
# Exit code:
#   0 = 모든 prereq OK (또는 --fix로 모두 해결됨)
#   1 = 누락 항목 있음 (자동 설치 불가능한 가이드 항목 포함)
#   2 = 환경 자체가 부적합 (WSL 없음 등 — 진행 자체 불가)

set -u

# ===== 옵션 파싱 =====
MODE="report"  # report | fix | quiet
for arg in "$@"; do
    case "$arg" in
        --fix) MODE="fix" ;;
        --quiet) MODE="quiet" ;;
        --help|-h)
            sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
    esac
done

# ===== 색상/심볼 =====
if [ -t 1 ] && [ "$MODE" != "quiet" ]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_DIM=$'\033[2m'
else
    C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_DIM=""
fi

OK="${C_GREEN}✅${C_RESET}"
FAIL="${C_RED}❌${C_RESET}"
WARN="${C_YELLOW}⚠️${C_RESET}"
SKIP="${C_DIM}⏭${C_RESET}"

# ===== 상태 누적 =====
TOTAL=9
PASSED=0
FAILED=()       # (label, hint)
AUTO_FIXABLE=() # (label, install cmd)

log() { [ "$MODE" != "quiet" ] && echo "$@" >&2; }
header() {
    if [ "$MODE" != "quiet" ]; then
        echo "" >&2
        echo "🩺 Harness Doctor — Windows+WSL 환경 검진" >&2
        echo "" >&2
    fi
}

record_pass() {
    PASSED=$((PASSED + 1))
    local idx="$1" label="$2" detail="${3:-}"
    log "[${idx}/${TOTAL}] ${label} ${OK} ${C_DIM}${detail}${C_RESET}"
}

record_fail() {
    local idx="$1" label="$2" hint="$3" autofix_cmd="${4:-}"
    FAILED+=("${label}|||${hint}")
    if [ -n "$autofix_cmd" ]; then
        AUTO_FIXABLE+=("${label}|||${autofix_cmd}")
    fi
    log "[${idx}/${TOTAL}] ${label} ${FAIL}"
    log "        ${hint}" | sed 's/\\n/\n        /g' >&2
}

record_skip() {
    local idx="$1" label="$2" reason="$3"
    log "[${idx}/${TOTAL}] ${label} ${SKIP} ${C_DIM}${reason}${C_RESET}"
}

# ===== 검사 1: WSL 자체 (WSL 안에서 이 스크립트 실행되니 사실상 통과 보장) =====
# Windows에서 wsl --status를 호출할 방법이 없으니, WSL 안에서 실행되고 있음을 확인하는 것으로 갈음
check_1_wsl() {
    if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
        record_pass 1 "WSL 환경" "(running inside WSL)"
    else
        # WSL이 아니면 Linux/macOS 시도 — 지원 안 함
        record_fail 1 "WSL 환경" \
            "이 doctor는 Windows+WSL 전용입니다.\n        현재 환경: $(uname -a)\n        Linux/macOS 네이티브는 지원되지 않습니다."
        return 2  # 치명적
    fi
    return 0
}

# ===== 검사 2: wt.exe (선택, 없으면 인라인 모드 fallback) =====
check_2_wt() {
    if command -v wt.exe >/dev/null 2>&1; then
        record_pass 2 "Windows Terminal (wt.exe)" "(별창 모드 가능)"
    else
        # 치명적 아님 — 경고 + 인라인 fallback 안내
        FAILED+=("Windows Terminal (선택)|||Microsoft Store에서 'Windows Terminal' 설치 권장.\n        없어도 동작 (HARNESS_NO_VISIBLE 자동 fallback).")
        log "[2/${TOTAL}] Windows Terminal (wt.exe) ${WARN} ${C_DIM}(선택, 인라인 fallback 동작함)${C_RESET}"
    fi
}

# ===== 검사 3: 기본 도구 (bash/git/curl/stdbuf) =====
check_3_basics() {
    local missing=()
    for cmd in bash git curl stdbuf grep awk sed; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        record_pass 3 "기본 도구 (bash/git/curl/stdbuf/...)" ""
    else
        record_fail 3 "기본 도구" \
            "누락: ${missing[*]}\n        WSL에서: sudo apt update && sudo apt install -y ${missing[*]}"
    fi
}

# ===== 검사 4: NVM =====
check_4_nvm() {
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        record_pass 4 "NVM" "(~/.nvm)"
    else
        record_fail 4 "NVM" \
            "NVM 미설치. 설치 명령:\n        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash\n        설치 후 새 shell 또는 source ~/.bashrc"
    fi
}

# ===== 검사 5: Node ≥ 20 =====
check_5_node() {
    # NVM 로드 시도
    # shellcheck disable=SC1091
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
    if ! command -v node >/dev/null 2>&1; then
        record_fail 5 "Node ≥ 20" \
            "Node 미설치. NVM 설치 후:\n        nvm install 20 && nvm use 20"
        return
    fi
    local ver major
    ver=$(node --version 2>/dev/null | sed 's/^v//')
    major=${ver%%.*}
    if [ "$major" -ge 20 ] 2>/dev/null; then
        record_pass 5 "Node ≥ 20" "(v${ver})"
    else
        record_fail 5 "Node ≥ 20" \
            "현재 v${ver} (요구 ≥ 20). 업그레이드:\n        nvm install 20 && nvm use 20"
    fi
}

# ===== 검사 6: Codex CLI =====
check_6_codex() {
    # shellcheck disable=SC1091
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
    if command -v codex >/dev/null 2>&1; then
        local ver
        ver=$(codex --version 2>/dev/null | head -1)
        local extra=""
        # bubblewrap 존재 여부 (선택, 없으면 Codex가 번들 사용)
        if ! command -v bwrap >/dev/null 2>&1; then
            extra=" ${C_DIM}[bubblewrap 없음 — Codex 번들 사용, 무해. 설치: sudo apt install -y bubblewrap]${C_RESET}"
        fi
        record_pass 6 "Codex CLI" "(${ver:-installed})${extra}"
    else
        record_fail 6 "Codex CLI (@openai/codex)" \
            "자동 설치 가능: bash harness-doctor.sh --fix\n        수동: npm install -g @openai/codex" \
            "npm install -g @openai/codex"
    fi
}

# ===== 검사 7: Codex 인증 =====
check_7_codex_auth() {
    # shellcheck disable=SC1091
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
    if ! command -v codex >/dev/null 2>&1; then
        record_skip 7 "Codex 로그인" "(CLI 미설치)"
        return
    fi
    # codex auth 상태 확인 — config/credentials 파일 존재 여부로 갈음
    if [ -f "$HOME/.codex/auth.json" ] || [ -f "$HOME/.codex/config.toml" ]; then
        record_pass 7 "Codex 로그인" "(~/.codex/)"
    else
        record_fail 7 "Codex 로그인" \
            "Codex 미인증. 새 터미널에서 실행:\n        codex login\n        (ChatGPT Plus 계정 또는 API key 등록)"
    fi
}

# ===== 검사 8: Gemini CLI =====
check_8_gemini() {
    # shellcheck disable=SC1091
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
    if command -v gemini >/dev/null 2>&1; then
        local ver
        ver=$(gemini --version 2>/dev/null | head -1)
        record_pass 8 "Gemini CLI" "(${ver:-installed})"
    else
        record_fail 8 "Gemini CLI (@google/gemini-cli)" \
            "자동 설치 가능: bash harness-doctor.sh --fix\n        수동: npm install -g @google/gemini-cli" \
            "npm install -g @google/gemini-cli"
    fi
}

# ===== 검사 9: Gemini API key =====
check_9_gemini_key() {
    local key_in_env="${GEMINI_API_KEY:-}"
    local key_in_bashrc=""
    if [ -f "$HOME/.bashrc" ]; then
        key_in_bashrc=$(grep -E '^[[:space:]]*export[[:space:]]+GEMINI_API_KEY=' "$HOME/.bashrc" | tail -1 | sed -E 's/.*=//; s/^"//; s/"$//')
    fi
    # env가 있거나, bashrc에 비어있지 않은 값이 있으면 OK
    if [ -n "$key_in_env" ] || [ -n "$key_in_bashrc" ]; then
        local src="env"
        [ -z "$key_in_env" ] && src="~/.bashrc"
        record_pass 9 "Gemini API key" "(${src})"
    else
        record_fail 9 "Gemini API key" \
            "API key 미설정.\n\n        ▶ 한 줄 등록 (가장 간단):\n            ① https://aistudio.google.com/apikey 에서 키 발급 + 복사\n            ② WSL 터미널에 아래 줄을 붙여넣고, 따옴표 안만 발급받은 키로 교체 후 Enter:\n\n            bash ~/.claude/skills/harness/core/setup-gemini-key.sh \"AIzaSy_여기에_키_붙여넣기\"\n\n            ③ Claude Code 에서: /harness-setup (재검진)\n\n        (별창 자동 띄우기를 원하면 /harness-setup --fix 자동 호출되는 경로 참고)"
    fi
}

# ===== --fix 모드: 자동 설치 시도 =====
do_fix() {
    if [ ${#AUTO_FIXABLE[@]} -eq 0 ]; then
        log ""
        log "✓ 자동 설치 가능한 누락 항목 없음."
        return 0
    fi
    log ""
    log "🔧 --fix 모드: 자동 설치 시작"
    log ""
    # shellcheck disable=SC1091
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
    for entry in "${AUTO_FIXABLE[@]}"; do
        local label cmd
        label=$(echo "$entry" | awk -F'\\|\\|\\|' '{print $1}')
        cmd=$(echo "$entry" | awk -F'\\|\\|\\|' '{print $2}')
        log "→ ${label}: ${cmd}"
        if bash -c "$cmd" 2>&1 | tail -5; then
            log "  ${OK} 설치 완료"
        else
            log "  ${FAIL} 설치 실패 — 수동으로 ${cmd} 실행 권장"
        fi
        log ""
    done
}

# ===== 메인 실행 =====
[ "$MODE" != "quiet" ] && header

check_1_wsl || exit 2
check_2_wt
check_3_basics
check_4_nvm
check_5_node
check_6_codex
check_7_codex_auth
check_8_gemini
check_9_gemini_key

# 결과 요약
FAIL_COUNT=${#FAILED[@]}
AUTO_COUNT=${#AUTO_FIXABLE[@]}

if [ "$MODE" = "fix" ] && [ "$AUTO_COUNT" -gt 0 ]; then
    do_fix
fi

# Interactive 보조 fix: Gemini API key 누락 시 별창 띄워 안전한 paste
if [ "$MODE" = "fix" ]; then
    for entry in "${FAILED[@]}"; do
        label=$(echo "$entry" | awk -F'\\|\\|\\|' '{print $1}')
        if [ "$label" = "Gemini API key" ]; then
            SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
            HELPER="$SCRIPT_DIR/run-interactive.sh"
            KEY_SCRIPT="$SCRIPT_DIR/setup-gemini-key.sh"
            if [ -x "$HELPER" ] && [ -x "$KEY_SCRIPT" ]; then
                log ""
                log "🔑 Gemini API key 등록 별창 띄우는 중..."
                bash "$HELPER" "🔑 Gemini API key 등록" "bash $KEY_SCRIPT" || true
                log "    별창에서 키 paste 후 Enter로 닫기."
            fi
            break
        fi
    done
fi

# fix 모드에서 뭐든 시도했으면 재검진 필요
if [ "$MODE" = "fix" ] && [ "${#FAILED[@]}" -gt 0 ]; then
    log ""
    log "🔁 재검진 권장: /harness-setup"
    exit 1
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
    [ "$MODE" != "quiet" ] && log "" && log "${OK} 모든 prereq 충족 (${PASSED}/${TOTAL})"
    # 마커 갱신
    mkdir -p "$HOME/.harness" 2>/dev/null || true
    touch "$HOME/.harness/.doctor-passed" 2>/dev/null || true
    exit 0
fi

log ""
log "${WARN}  ${FAIL_COUNT}개 누락 항목"
if [ "$AUTO_COUNT" -gt 0 ]; then
    log "    자동 설치 가능: ${AUTO_COUNT}개 → bash $(basename "$0") --fix"
fi
log "    가이드 필요: $((FAIL_COUNT - AUTO_COUNT))개 (위 메시지 참고)"
log ""
log "재검진: bash $(basename "$0")"
# 누락 항목 있으면 마커 제거
rm -f "$HOME/.harness/.doctor-passed" 2>/dev/null || true
exit 1
