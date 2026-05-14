#!/bin/bash
# bootstrap-runtime.sh — 프로젝트 .harness/ 구조 초기화 + 마스터 동기화
#
# 사용:
#   bash bootstrap-runtime.sh <PROJECT_WSL_PATH> [--force]
#
# --force: stale 파일을 마스터로 덮어쓰기 (백업 .bak-<ts> 생성). `/harness sync` 용.
#
# Exit 0: 성공 (stale 알림은 stderr로 정보 출력)
# Exit 1: 마스터 무결성 실패

set -euo pipefail

PROJECT_WSL=${1:?"Usage: $0 <PROJECT_WSL_PATH> [--force]"}
FORCE=${2:-}

if [ ! -d "$PROJECT_WSL" ]; then
    echo "FATAL: PROJECT path not found: $PROJECT_WSL" >&2
    exit 1
fi

# 자기 자신 위치 기준으로 마스터 추론 (core 의 부모 = skill 루트)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SKILL_WSL=$(dirname "$SCRIPT_DIR")

# 필수 파일 목록
WRAPPERS="codex-review.sh gemini-research.sh auth-helper.sh"
CORES="sync-creds.sh"

# 1. 마스터 무결성 sanity check
for f in $WRAPPERS; do
    if [ ! -f "$SKILL_WSL/wrappers/$f" ]; then
        echo "FATAL: master wrapper missing: $SKILL_WSL/wrappers/$f" >&2
        echo "       skill 폴더가 손상됐을 수 있습니다. harness skill을 재설치하세요." >&2
        exit 1
    fi
done
for f in $CORES; do
    if [ ! -f "$SKILL_WSL/core/$f" ]; then
        echo "FATAL: master core missing: $SKILL_WSL/core/$f" >&2
        exit 1
    fi
done

# 2. 프로젝트 디렉터리 구조 보장
mkdir -p "$PROJECT_WSL/.harness"/{plans,progress,research,reviews,improvements,results,wrappers,core,agents/learning}

# 3. 파일 복사 (없거나 --force면)
copy_if_needed() {
    local src=$1 dst=$2 force=$3
    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        echo "📦 bootstrap: copied $(basename "$dst")" >&2
    elif [ "$force" = "--force" ]; then
        local m p
        m=$(sha256sum "$src" | cut -d' ' -f1)
        p=$(sha256sum "$dst" | cut -d' ' -f1)
        if [ "$m" != "$p" ]; then
            cp "$dst" "${dst}.bak-$(date +%Y%m%d-%H%M%S)"
            cp "$src" "$dst"
            echo "🔄 sync: overwrote $(basename "$dst") (backup saved as .bak-*)" >&2
        fi
    fi
}

for f in $WRAPPERS; do
    copy_if_needed "$SKILL_WSL/wrappers/$f" "$PROJECT_WSL/.harness/wrappers/$f" "$FORCE"
done
for f in $CORES; do
    copy_if_needed "$SKILL_WSL/core/$f" "$PROJECT_WSL/.harness/core/$f" "$FORCE"
done

# 4. CRLF 정규화 + 실행권한 (idempotent)
sed -i 's/\r$//' "$PROJECT_WSL/.harness/wrappers/"*.sh "$PROJECT_WSL/.harness/core/"*.sh 2>/dev/null || true
chmod +x "$PROJECT_WSL/.harness/wrappers/"*.sh "$PROJECT_WSL/.harness/core/"*.sh 2>/dev/null || true

# 5. Stale 감지 (마스터 ≠ 프로젝트 → 알림만)
STALE_COUNT=0
check_stale() {
    local src=$1 dst=$2
    local m p
    m=$(sha256sum "$src" | cut -d' ' -f1)
    p=$(sha256sum "$dst" | cut -d' ' -f1)
    if [ "$m" != "$p" ]; then
        echo "ℹ️ stale: $(basename "$dst") differs from master" >&2
        STALE_COUNT=$((STALE_COUNT + 1))
    fi
}

for f in $WRAPPERS; do
    check_stale "$SKILL_WSL/wrappers/$f" "$PROJECT_WSL/.harness/wrappers/$f"
done
for f in $CORES; do
    check_stale "$SKILL_WSL/core/$f" "$PROJECT_WSL/.harness/core/$f"
done

if [ "$STALE_COUNT" -gt 0 ] && [ "$FORCE" != "--force" ]; then
    echo "ℹ️ $STALE_COUNT file(s) differ from master — run '/harness sync' to update" >&2
fi

# 6. Agent learning 파일 시드 (빈 5섹션 템플릿, 프로젝트 측에만)
LEARNING_TEMPLATE="$SKILL_WSL/templates/learning-file.md"
if [ -f "$LEARNING_TEMPLATE" ]; then
    for agent in harness-planner harness-architect harness-code-reviewer harness-security-reviewer harness-tdd-guide harness-build-resolver; do
        dst="$PROJECT_WSL/.harness/agents/learning/$agent.md"
        if [ ! -f "$dst" ]; then
            sed "s|<AGENT_NAME>|$agent|g" "$LEARNING_TEMPLATE" > "$dst"
            echo "🧠 learning seed: $agent.md" >&2
        fi
    done
fi

exit 0
