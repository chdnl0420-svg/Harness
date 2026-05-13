#!/bin/bash
# check-drift.sh — 마스터 (~/.claude/skills/harness/{core,wrappers}/*.sh) 와
#                  프로젝트 (<PROJECT>/.harness/{core,wrappers}/*.sh) 간 drift 검출
#
# 사용:
#   bash check-drift.sh <PROJECT_DIR>           # 사람용 리포트 (drift 항목만)
#   bash check-drift.sh <PROJECT_DIR> --json    # JSON (Claude orchestrator 파싱용)
#   bash check-drift.sh <PROJECT_DIR> --quiet   # exit code만, 출력 없음
#
# Exit code:
#   0  = drift 없음 (모든 파일 동일)
#   10 = drift 있음 (출력에 목록)
#   2  = 사용 오류 (인자 누락 등)
#   3  = 환경 오류 (sha256sum 없음, 마스터 디렉토리 없음 등)
#
# 검사 대상:
#   - core/*.sh (단, check-drift.sh 자신은 제외)
#   - wrappers/*.sh
#
# Skip 트리거 (이 스크립트가 직접 확인하는 게 아니라 호출자가 확인):
#   - $HARNESS_SKIP_DRIFT_CHECK env
#   - ~/.harness/.skip-drift-check 파일
#   - <PROJECT>/.harness/.skip-drift-this-task 파일 (one-shot — 호출자가 사용 후 삭제)

set -u

PROJECT_DIR="${1:-}"
MODE="report"  # report | json | quiet
for arg in "${@:2}"; do
    case "$arg" in
        --json) MODE="json" ;;
        --quiet) MODE="quiet" ;;
    esac
done

if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: $0 <PROJECT_DIR> [--json|--quiet]" >&2
    exit 2
fi

if ! command -v sha256sum >/dev/null 2>&1; then
    [ "$MODE" != "quiet" ] && echo "❌ sha256sum 미설치 (WSL: sudo apt install -y coreutils)" >&2
    exit 3
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
MASTER_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
PROJECT_HARNESS="$PROJECT_DIR/.harness"

if [ ! -d "$MASTER_ROOT/core" ] || [ ! -d "$MASTER_ROOT/wrappers" ]; then
    [ "$MODE" != "quiet" ] && echo "❌ 마스터 경로 비정상: $MASTER_ROOT" >&2
    exit 3
fi

# 검사 대상 수집: 마스터에 있는 모든 .sh (check-drift 자신 제외)
gather_master_files() {
    local f
    for f in "$MASTER_ROOT"/core/*.sh "$MASTER_ROOT"/wrappers/*.sh; do
        [ -f "$f" ] || continue
        case "$(basename "$f")" in
            check-drift.sh) continue ;;
        esac
        # 마스터 상대 경로 (core/foo.sh)
        echo "${f#$MASTER_ROOT/}"
    done
}

sha() {
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

DRIFT_ENTRIES=()   # 각 항목: "rel|master_sha|project_sha|status"
DRIFT_COUNT=0

while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    master_file="$MASTER_ROOT/$rel"
    project_file="$PROJECT_HARNESS/$rel"

    master_sha=$(sha "$master_file")

    if [ ! -f "$project_file" ]; then
        DRIFT_ENTRIES+=("$rel|$master_sha||missing-in-project")
        DRIFT_COUNT=$((DRIFT_COUNT + 1))
        continue
    fi

    project_sha=$(sha "$project_file")
    if [ "$master_sha" != "$project_sha" ]; then
        DRIFT_ENTRIES+=("$rel|$master_sha|$project_sha|modified")
        DRIFT_COUNT=$((DRIFT_COUNT + 1))
    fi
done < <(gather_master_files)

# 결과 출력
if [ "$DRIFT_COUNT" -eq 0 ]; then
    [ "$MODE" = "report" ] && echo "✓ drift 없음 (마스터 == 프로젝트)"
    exit 0
fi

case "$MODE" in
    json)
        printf '{"drift_count": %d, "files": [' "$DRIFT_COUNT"
        first=1
        for entry in "${DRIFT_ENTRIES[@]}"; do
            IFS='|' read -r rel m_sha p_sha status <<< "$entry"
            if [ "$first" = "0" ]; then printf ','; fi
            first=0
            printf '{"file":"%s","master":"%s","project":"%s","status":"%s"}' \
                "$rel" "${m_sha:0:12}" "${p_sha:0:12}" "$status"
        done
        printf ']}\n'
        ;;
    report)
        echo ""
        echo "⚠️  마스터 vs 프로젝트 drift: ${DRIFT_COUNT}건"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "%-40s %-12s %-12s %s\n" "FILE" "MASTER" "PROJECT" "STATUS"
        echo "─────────────────────────────────────────────────────────────────────────────────"
        for entry in "${DRIFT_ENTRIES[@]}"; do
            IFS='|' read -r rel m_sha p_sha status <<< "$entry"
            printf "%-40s %-12s %-12s %s\n" "$rel" "${m_sha:0:8}" "${p_sha:0:8}" "$status"
        done
        echo ""
        echo "동기화 (마스터 → 프로젝트):"
        echo "  bash $SCRIPT_DIR/sync-from-master.sh \"$PROJECT_DIR\""
        ;;
    quiet) ;;
esac

exit 10
