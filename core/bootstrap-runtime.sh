#!/bin/bash
# bootstrap-runtime.sh — 프로젝트 .harness/ 구조 초기화 + 페르소나 agent 등록
#
# 사용:
#   bash bootstrap-runtime.sh <PROJECT_WSL_PATH>
#
# 2026-05-20 슬림화: harness-sync / drift check / 마스터 코드 복사 폐기.
# 마스터가 진실 원천, 프로젝트엔 산출물 (md/html) 만 남는다.
# 이 스크립트는 산출물 폴더 mkdir + 사양 docs/CLAUDE.md 시드 + 페르소나 agent 등록만 수행.
#
# Exit 0: 성공
# Exit 1: PROJECT 경로 부재

set -euo pipefail

PROJECT_WSL=${1:?"Usage: $0 <PROJECT_WSL_PATH>"}

if [ ! -d "$PROJECT_WSL" ]; then
    echo "FATAL: PROJECT path not found: $PROJECT_WSL" >&2
    exit 1
fi

# 자기 자신 위치 기준으로 마스터 추론 (core 의 부모 = skill 루트)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SKILL_WSL=$(dirname "$SCRIPT_DIR")

# 1. 프로젝트 산출물 디렉터리 보장 (워크플로우가 실제로 쓰는 폴더만)
mkdir -p "$PROJECT_WSL/.harness"/{progress,research,reviews,results}

# 2. 프로젝트 사양 문서 시드 (docs/{PRD,ARCHITECTURE,ADR,UI_GUIDE}.md + 프로젝트 CLAUDE.md)
#    이미 있는 파일은 절대 안 건드림 (사용자 콘텐츠 보호).
mkdir -p "$PROJECT_WSL/docs"
seed_doc() {
    local tmpl=$1 dst=$2 label=$3
    if [ ! -f "$dst" ] && [ -f "$tmpl" ]; then
        cp "$tmpl" "$dst"
        echo "📄 spec seed: $label" >&2
    fi
}
seed_doc "$SKILL_WSL/templates/doc-prd.md"          "$PROJECT_WSL/docs/PRD.md"          "docs/PRD.md"
seed_doc "$SKILL_WSL/templates/doc-architecture.md" "$PROJECT_WSL/docs/ARCHITECTURE.md" "docs/ARCHITECTURE.md"
seed_doc "$SKILL_WSL/templates/doc-adr.md"          "$PROJECT_WSL/docs/ADR.md"          "docs/ADR.md"
seed_doc "$SKILL_WSL/templates/doc-ui-guide.md"     "$PROJECT_WSL/docs/UI_GUIDE.md"     "docs/UI_GUIDE.md (empty placeholder)"
seed_doc "$SKILL_WSL/templates/project-claude.md"   "$PROJECT_WSL/CLAUDE.md"            "CLAUDE.md (project constitution)"

# 3. 페르소나 agent 3개를 ~/.claude/agents/ 로 등록 (Claude Code 가 subagent_type 으로 인식하려면 필수)
#    skill-scoped agents/*.md 는 자동 등록되지 않으므로 user-level agents 디렉토리에 복사.
#    *나머지 6개 (planner/architect/code-reviewer/security-reviewer/tdd-guide/build-resolver) 는 일반 skill 로 대체됐다 — 2026-05-20 폐기.
CLAUDE_AGENTS_DIR="$(cd "$SKILL_WSL/../.." 2>/dev/null && pwd)/agents"
if [ -d "$CLAUDE_AGENTS_DIR" ] || mkdir -p "$CLAUDE_AGENTS_DIR" 2>/dev/null; then
    for agent in harness-customer-user harness-qa-engineer harness-deep-researcher; do
        src="$SKILL_WSL/agents/$agent.md"
        dst="$CLAUDE_AGENTS_DIR/$agent.md"
        if [ ! -f "$src" ]; then
            continue
        fi
        if [ ! -f "$dst" ] || ! cmp -s "$src" "$dst"; then
            # 기존 사용자 수정본 있으면 백업
            if [ -f "$dst" ]; then
                cp "$dst" "${dst}.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
            fi
            cp "$src" "$dst" 2>/dev/null && echo "📋 agent 등록: $agent" >&2
        fi
    done
fi

exit 0
