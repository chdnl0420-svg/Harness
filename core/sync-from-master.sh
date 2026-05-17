#!/bin/bash
# sync-from-master.sh — drift 파일을 마스터에서 프로젝트로 동기화 (백업 자동)
#
# 사용:
#   bash sync-from-master.sh <PROJECT_DIR>            # drift 파일 모두 동기화
#   bash sync-from-master.sh <PROJECT_DIR> --dry-run  # 실제 변경 없이 시뮬레이션
#
# 동작:
#   1. check-drift.sh --json 으로 drift 목록 획득
#   2. 각 drift 파일에 대해:
#      a. project 측 파일 존재 시 → <PROJECT>/.harness/backups/<rel>.bak-<ts>
#      b. 마스터에서 cp (chmod +x + LF 보장)
#   3. 결과 요약
#
# Exit code:
#   0 = 동기화 성공 (또는 drift 없음)
#   2 = 사용 오류
#   3 = 환경 오류 (check-drift.sh 실패 등)

set -u

PROJECT_DIR="${1:-}"
DRY_RUN=0
for arg in "${@:2}"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
    esac
done

if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: $0 <PROJECT_DIR> [--dry-run]" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
MASTER_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
PROJECT_HARNESS="$PROJECT_DIR/.harness"
BACKUP_ROOT="$PROJECT_HARNESS/backups"
TS=$(date +%Y%m%d-%H%M%S)

# 1) drift 목록 (JSON)
DRIFT_JSON=$(bash "$SCRIPT_DIR/check-drift.sh" "$PROJECT_DIR" --json 2>/dev/null)
DRIFT_EXIT=$?

if [ "$DRIFT_EXIT" = "0" ]; then
    echo "✓ drift 없음. 동기화할 항목 없음."
    exit 0
fi
if [ "$DRIFT_EXIT" != "10" ]; then
    echo "❌ check-drift.sh 실패 (exit $DRIFT_EXIT)" >&2
    exit 3
fi

# 2) JSON에서 파일 경로 추출 (간단 파싱, jq 의존 없음)
# 형식: {"drift_count":N,"files":[{"file":"core/x.sh",...},...]}
REL_LIST=$(echo "$DRIFT_JSON" | grep -oE '"file":"[^"]+"' | sed -E 's/"file":"([^"]+)"/\1/')

if [ -z "$REL_LIST" ]; then
    echo "❌ drift 항목 파싱 실패: $DRIFT_JSON" >&2
    exit 3
fi

# 3) 동기화 진행
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DRY_RUN" = "1" ]; then
    echo "🔍 sync-from-master DRY-RUN"
else
    echo "🔄 sync-from-master 실행"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  마스터: $MASTER_ROOT"
echo "  프로젝트: $PROJECT_HARNESS"
echo ""

SYNCED=0
FAILED=0

while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    master_file="$MASTER_ROOT/$rel"
    project_file="$PROJECT_HARNESS/$rel"

    if [ ! -f "$master_file" ]; then
        echo "  ⚠️  마스터 파일 없음 (skip): $rel"
        FAILED=$((FAILED + 1))
        continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
        if [ -f "$project_file" ]; then
            echo "  [DRY] backup + overwrite: $rel"
        else
            echo "  [DRY] new file: $rel"
        fi
        SYNCED=$((SYNCED + 1))
        continue
    fi

    # 백업
    if [ -f "$project_file" ]; then
        backup_dest="$BACKUP_ROOT/${rel}.bak-${TS}"
        mkdir -p "$(dirname "$backup_dest")"
        cp "$project_file" "$backup_dest" 2>/dev/null
    fi

    # 디렉토리 보장 + 복사
    mkdir -p "$(dirname "$project_file")"
    if cp "$master_file" "$project_file" 2>/dev/null; then
        chmod +x "$project_file" 2>/dev/null
        # CRLF → LF 보정 (Windows에서 복사 시 가끔 발생)
        sed -i 's/\r$//' "$project_file" 2>/dev/null || true
        echo "  ✅ $rel"
        SYNCED=$((SYNCED + 1))
    else
        echo "  ❌ 복사 실패: $rel"
        FAILED=$((FAILED + 1))
    fi
done <<< "$REL_LIST"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DRY_RUN" = "1" ]; then
    echo "  완료 (DRY-RUN): ${SYNCED}건 처리 예정"
else
    echo "  완료: ${SYNCED}건 동기화, ${FAILED}건 실패"
    if [ "$SYNCED" -gt 0 ]; then
        echo "  백업 위치: $BACKUP_ROOT/*.bak-${TS}"
    fi
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
