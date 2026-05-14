#!/bin/bash
# harness-doctor.sh — Windows+WSL 환경의 harness 의존성 검진 + GitHub 최신화
#
# 사용법:
#   bash harness-doctor.sh                    # 검사 + npm/apt/key 자동 fix. 업데이트는 안내만 (수동 trigger 필요)
#   bash harness-doctor.sh --fix              # 위와 동일 (alias)
#   bash harness-doctor.sh --quiet            # 모두 OK면 출력 없음 + exit 0
#   bash harness-doctor.sh --update           # 검진 skip + 즉시 업데이트 (force, 명시 동의)
#   bash harness-doctor.sh --auto-update      # 검진 통과 + outdated 감지 시 자동 업데이트 (이전 default)
#   bash harness-doctor.sh --no-version-check # GitHub 조회 자체 skip (오프라인)
#
# Exit code:
#   0 = 모든 prereq OK (또는 --fix/--update 로 해결됨)
#   1 = 누락 항목 있음
#   2 = 환경 자체가 부적합 (WSL 없음 등)
#
# 정책 (2026-05-14 변경):
#   - auto-update default OFF. learning 파일을 덮어쓰는 사고 방지.
#   - GitHub 최신 감지 시 안내만 출력 후 사용자가 명시적으로 --update 또는 --auto-update 트리거.
#   - --update 도 agents/learning/*.md 는 보존 (덮어쓰기 제외).

set -u

# ===== 옵션 파싱 =====
MODE="report"           # report | fix | quiet
DO_UPDATE=0             # --update: 검진 skip하고 즉시 업데이트
SKIP_VERSION_CHECK=0    # --no-version-check: GitHub 조회 자체 skip
SKIP_AUTO_UPDATE=1      # default: 자동 업데이트 OFF. --auto-update 로 켜야 자동 적용.
for arg in "$@"; do
    case "$arg" in
        --fix) MODE="fix" ;;
        --quiet) MODE="quiet" ;;
        --update) DO_UPDATE=1 ;;
        --no-update) SKIP_AUTO_UPDATE=1 ;;       # 명시적 OFF (이미 default)
        --auto-update) SKIP_AUTO_UPDATE=0 ;;     # opt-in 으로 ON
        --no-version-check) SKIP_VERSION_CHECK=1 ;;
        --help|-h)
            sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
    esac
done

# ===== 경로 자동 감지 =====
# 스크립트 위치(.../skills/harness/core/harness-doctor.sh) 기반으로 추론.
# PowerShell 설치는 Windows %USERPROFILE%\.claude 에, WSL 직접 설치는 ~/.claude 에.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
CLAUDE_ROOT="$(cd "$SKILL_ROOT/../.." 2>/dev/null && pwd)"  # → .../.claude
COMMANDS_DIR="$CLAUDE_ROOT/commands"
VERSION_FILE="$SKILL_ROOT/.version"
HARNESS_DATA="$HOME/.harness"
REPO_URL="${HARNESS_REPO_URL:-https://github.com/chdnl0420-svg/Harness}"
REPO_API="${HARNESS_REPO_API:-https://api.github.com/repos/chdnl0420-svg/Harness}"

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
TOTAL=10
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
    for cmd in bash git curl stdbuf grep awk sed tmux; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        record_pass 3 "기본 도구 (bash/git/curl/stdbuf/tmux/...)" ""
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

# ===== 검사 10: Agent learning 구조 (마스터) =====
check_10_agent_learning() {
    local missing=()
    local agents=(harness-planner harness-architect harness-code-reviewer harness-security-reviewer harness-tdd-guide harness-build-resolver)

    for a in "${agents[@]}"; do
        [ -f "$SKILL_ROOT/agents/$a.md" ] || missing+=("agents/$a.md")
        [ -f "$SKILL_ROOT/agents/learning/$a.md" ] || missing+=("agents/learning/$a.md")
    done
    [ -f "$SKILL_ROOT/agents/learning/README.md" ] || missing+=("agents/learning/README.md")
    [ -f "$SKILL_ROOT/templates/learning-file.md" ] || missing+=("templates/learning-file.md")
    [ -f "$SKILL_ROOT/templates/learning-proposal.md" ] || missing+=("templates/learning-proposal.md")

    if [ "${#missing[@]}" -eq 0 ]; then
        record_pass 10 "Agent learning 구조" "(6 agents + 6 learning + 2 templates)"
    else
        local list
        list=$(printf '\n            - %s' "${missing[@]}")
        record_fail 10 "Agent learning 구조" \
            "마스터 측 파일 ${#missing[@]}개 누락:${list}\n\n        ▶ 해결: /harness-setup --update (GitHub 최신본 재설치)"
    fi
}

# ===== GitHub 최신 SHA 조회 (1시간 캐시) =====
check_github_latest() {
    local cache="$HARNESS_DATA/.last-github-check"
    local cache_ttl=3600

    if [ -f "$cache" ]; then
        local cached_ts now
        cached_ts=$(stat -c %Y "$cache" 2>/dev/null || echo 0)
        now=$(date +%s)
        if [ $((now - cached_ts)) -lt $cache_ttl ]; then
            cat "$cache"
            return 0
        fi
    fi

    local sha
    sha=$(curl -fsSL --max-time 5 "$REPO_API/commits/main" 2>/dev/null \
        | grep -oE '"sha":[[:space:]]*"[a-f0-9]+"' | head -1 \
        | sed -E 's/.*"([a-f0-9]+)"/\1/')

    if [ -n "$sha" ]; then
        mkdir -p "$HARNESS_DATA"
        echo "$sha" > "$cache"
        echo "$sha"
        return 0
    fi
    return 1
}

# ===== 로컬 .version 에서 commit SHA 추출 =====
get_local_sha() {
    if [ ! -f "$VERSION_FILE" ]; then
        return 1
    fi
    grep -E '^commit:' "$VERSION_FILE" | head -1 | sed -E 's/^commit:[[:space:]]*//; s/[[:space:]]*$//'
}

# ===== 버전 비교 + 안내 =====
check_version() {
    [ "$SKIP_VERSION_CHECK" = "1" ] && return 0
    [ "$MODE" = "quiet" ] && return 0

    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "📡 GitHub 버전 확인"

    local local_sha remote_sha
    local_sha=$(get_local_sha 2>/dev/null || true)
    remote_sha=$(check_github_latest 2>/dev/null || true)

    if [ -z "$remote_sha" ]; then
        log "  ${WARN} GitHub 조회 실패 (오프라인 또는 일시 장애)"
        log "  설치된 파일은 그대로 사용 가능."
        return 0
    fi

    if [ -z "$local_sha" ]; then
        log "  ${WARN} 로컬 버전 정보 없음 (오래된 설치)"
        log "  최신 SHA: ${remote_sha:0:7}"
        if [ "$SKIP_AUTO_UPDATE" = "0" ]; then
            log "  → 자동 업데이트 진행 (--auto-update 활성)"
            do_update
            return $?
        else
            log "  ℹ️  auto-update default OFF (2026-05-14 정책). 수동 실행:"
            log "      /harness-setup --update    또는    --auto-update (이번 한 번)"
        fi
        return 0
    fi

    if [ "$local_sha" = "$remote_sha" ]; then
        log "  ${OK} Harness 최신 (SHA: ${local_sha:0:7})"
    else
        log "  ⬆ 업데이트 가능"
        log "      현재: ${local_sha:0:7}"
        log "      최신: ${remote_sha:0:7}"
        if [ "$SKIP_AUTO_UPDATE" = "0" ]; then
            log "      → 자동 업데이트 진행 (--auto-update 활성)"
            do_update
            return $?
        else
            log "      ℹ️  auto-update default OFF. 수동 trigger 필요:"
            log "         /harness-setup --update          (즉시 업데이트)"
            log "         /harness-setup --auto-update     (이번 한 번 자동)"
            log "         (learning 파일은 항상 보존됨)"
        fi
    fi
}

# ===== 업데이트 실행 =====
do_update() {
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "⬆ Harness 업데이트 시작"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 0) 사전 확인
    if ! command -v curl >/dev/null 2>&1; then
        log "${FAIL} curl 미설치. WSL: sudo apt install -y curl"
        return 1
    fi
    if ! command -v tar >/dev/null 2>&1; then
        log "${FAIL} tar 미설치. WSL: sudo apt install -y tar"
        return 1
    fi

    # 1) 최신 SHA 가져오기
    local remote_sha
    remote_sha=$(check_github_latest 2>/dev/null || true)
    if [ -z "$remote_sha" ]; then
        log "${FAIL} GitHub 조회 실패. 네트워크 확인 후 재시도."
        return 1
    fi
    log "  최신 SHA: ${remote_sha:0:7}"

    # 2) 로컬 수정 감지 (.version 보다 새로운 파일)
    local local_modified=()
    if [ -f "$VERSION_FILE" ]; then
        while IFS= read -r f; do
            local_modified+=("$f")
        done < <(find "$SKILL_ROOT" -type f -newer "$VERSION_FILE" \
            ! -name '.version' ! -name '*.bak-*' 2>/dev/null | head -20)
        if [ ${#local_modified[@]} -gt 0 ]; then
            log "  ${WARN} 로컬에서 수정된 파일 감지 (자동 백업되지만 덮어쓰기 됨):"
            for f in "${local_modified[@]}"; do
                log "      ${f#$SKILL_ROOT/}"
            done
        fi
    fi

    # 3) 백업 (skills/ 밖으로! 안에 두면 Claude Code가 별도 skill로 오인)
    local ts backup_dir backup
    ts=$(date +%Y%m%d-%H%M%S)
    backup_dir="$HARNESS_DATA/backups"
    backup="$backup_dir/harness-$ts"
    mkdir -p "$backup_dir"
    if cp -r "$SKILL_ROOT" "$backup" 2>/dev/null; then
        log "  📦 백업: $backup"
    else
        log "${FAIL} 백업 실패. 권한 확인."
        return 1
    fi

    # 4) tarball 다운로드 + 추출
    local tmp
    tmp=$(mktemp -d -t harness-update-XXXXXX)
    log "  📥 다운로드 중..."
    if ! curl -fsSL --max-time 30 "$REPO_API/tarball/main" -o "$tmp/archive.tar.gz" 2>/dev/null; then
        log "${FAIL} 다운로드 실패. 백업은 보존됨: $backup"
        rm -rf "$tmp"
        return 1
    fi
    if ! tar -xzf "$tmp/archive.tar.gz" -C "$tmp" 2>/dev/null; then
        log "${FAIL} tar 추출 실패. 백업 보존: $backup"
        rm -rf "$tmp"
        return 1
    fi

    local src
    src=$(find "$tmp" -maxdepth 1 -type d -name '*Harness-*' | head -1)
    if [ -z "$src" ] || [ ! -d "$src/skills/harness" ]; then
        log "${FAIL} 압축 구조 비정상. 백업 보존: $backup"
        rm -rf "$tmp"
        return 1
    fi

    # 5) 적용 (skill + commands)
    # 5a) agents/learning/*.md 보존 — 축적된 학습 데이터는 source-of-truth 가 아니므로 덮어쓰기 제외.
    #     (2026-05-14 정책 변경: blanket cp -r 이 learning 파일을 빈 템플릿으로 덮어쓴 사고 방지)
    local learning_preserve_dir=""
    if [ -d "$SKILL_ROOT/agents/learning" ]; then
        learning_preserve_dir=$(mktemp -d -t harness-learning-preserve-XXXXXX)
        cp -r "$SKILL_ROOT/agents/learning/." "$learning_preserve_dir/" 2>/dev/null || true
        log "      🛡  agents/learning/ 보존 (덮어쓰기 제외)"
    fi

    log "  📂 적용 중..."
    if cp -r "$src/skills/harness/." "$SKILL_ROOT/" 2>/dev/null; then
        log "      skills/harness/ ✓"
    else
        log "${FAIL} skill 복사 실패. 롤백:"
        log "      rm -rf '$SKILL_ROOT' && mv '$backup' '$SKILL_ROOT'"
        [ -n "$learning_preserve_dir" ] && rm -rf "$learning_preserve_dir"
        rm -rf "$tmp"
        return 1
    fi

    # 5b) learning 파일 복원 (마스터의 빈 템플릿이 들어왔다면 사용자 데이터로 덮어쓰기)
    if [ -n "$learning_preserve_dir" ] && [ -d "$learning_preserve_dir" ]; then
        # 단, 마스터에 새로 추가된 learning 파일 (없던 agent) 은 기본 템플릿 유지.
        # → 사용자 측에 이미 있었던 파일만 복원.
        for f in "$learning_preserve_dir/"*.md; do
            [ -f "$f" ] || continue
            cp "$f" "$SKILL_ROOT/agents/learning/$(basename "$f")" 2>/dev/null || true
        done
        log "      ✓ agents/learning/ 복원 완료"
        rm -rf "$learning_preserve_dir"
    fi

    mkdir -p "$COMMANDS_DIR"
    for cmd in harness-setup.md harness-review.md harness-audit.md; do
        if [ -f "$src/commands/$cmd" ]; then
            cp "$src/commands/$cmd" "$COMMANDS_DIR/" 2>/dev/null && log "      commands/$cmd ✓"
        fi
    done

    # 6) 실행 권한 보정 + LF 변환
    chmod +x "$SKILL_ROOT/core/"*.sh 2>/dev/null
    chmod +x "$SKILL_ROOT/wrappers/"*.sh 2>/dev/null

    # 7) .version 갱신
    cat > "$VERSION_FILE" <<EOF
commit: $remote_sha
installed: $(date -u +%Y-%m-%dT%H:%M:%SZ)
source: $REPO_URL
branch: main
EOF

    # 8) 캐시 무효화 (다음 호출이 즉시 최신 확인 가능)
    rm -f "$HARNESS_DATA/.last-github-check" 2>/dev/null

    # 9) doctor-passed 마커 갱신 (전체 환경 재검진 권유)
    rm -f "$HARNESS_DATA/.doctor-passed" 2>/dev/null

    rm -rf "$tmp"
    log ""
    log "${OK} 업데이트 완료 (SHA: ${remote_sha:0:7})"
    log "    백업 위치: $backup"
    log "    재검진 권장: /harness-setup"
    return 0
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

# --update 모드 — 검진은 최소만, 업데이트 우선 실행
if [ "$DO_UPDATE" = "1" ]; then
    [ "$MODE" != "quiet" ] && header
    check_1_wsl || exit 2
    do_update || exit 1
    log ""
    log "🔁 환경 재검진 권장: /harness-setup"
    exit 0
fi

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
check_10_agent_learning

# 결과 요약
FAIL_COUNT=${#FAILED[@]}
AUTO_COUNT=${#AUTO_FIXABLE[@]}

if [ "$MODE" = "fix" ] && [ "$AUTO_COUNT" -gt 0 ]; then
    do_fix
fi

# Interactive 보조 fix:
#   1) 기본 도구 (apt 필요, sudo) — 별창에서 사용자가 비밀번호 입력
#   2) Gemini API key — 별창에서 안전한 paste
if [ "$MODE" = "fix" ]; then
    SCRIPT_DIR_LOCAL="$(cd "$(dirname "$0")" && pwd)"
    HELPER="$SCRIPT_DIR_LOCAL/run-interactive.sh"

    # 1) 기본 도구 (tmux 등 apt 패키지) 자동 설치 시도
    for entry in "${FAILED[@]}"; do
        label=$(echo "$entry" | awk -F'\\|\\|\\|' '{print $1}')
        if [ "$label" = "기본 도구" ]; then
            hint=$(echo "$entry" | awk -F'\\|\\|\\|' '{print $2}')
            # hint 형식: "누락: tmux curl\n        WSL에서: sudo apt ..." → 누락 목록 추출
            missing_pkgs=$(echo "$hint" | grep -oE '누락: [^\\]+' | sed 's/누락: //; s/[[:space:]]*$//')
            if [ -n "$missing_pkgs" ] && [ -x "$HELPER" ]; then
                log ""
                log "📦 기본 도구 자동 설치 별창 띄우는 중... ($missing_pkgs)"
                bash "$HELPER" "📦 apt install: $missing_pkgs" \
                    "sudo apt update && sudo apt install -y $missing_pkgs" || true
                log "    별창에서 sudo 비밀번호 입력 후 Enter로 닫기."
            fi
            break
        fi
    done

    # 2) Gemini API key
    for entry in "${FAILED[@]}"; do
        label=$(echo "$entry" | awk -F'\\|\\|\\|' '{print $1}')
        if [ "$label" = "Gemini API key" ]; then
            KEY_SCRIPT="$SCRIPT_DIR_LOCAL/setup-gemini-key.sh"
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
    # 9/9 통과 → GitHub 버전 안내 (quiet 아닐 때만)
    check_version
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
