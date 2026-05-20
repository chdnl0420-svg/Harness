---
description: Harness skill 의존성 검진 + Codex CLI 자동 설치 + GitHub 최신화 확인 (Windows native, WSL 불필요)
argument-hint: '[--update] [--no-version-check]'
---

# Harness Setup — 검진 + 자동 설치 + 버전 확인

`harness` skill 이 동작하기 위한 prereq 를 점검하고, **Codex CLI 누락 시 즉시 자동 설치**하며, 통과 후 **GitHub 최신 버전 여부를 확인**합니다.

> **2026-05-20 슬림화**: WSL · wt.exe · tmux · harness-doctor.sh · run-interactive.sh · drift sync 모두 폐기. 모든 검사는 Claude Code Bash 도구로 직접 수행.

## 모드

| 호출 | 동작 |
|------|------|
| `/harness-setup` | 검진 + Codex CLI 자동 설치 + outdated 면 자동 업데이트 |
| `/harness-setup --update` | 즉시 GitHub 최신본 재설치 (force) |
| `/harness-setup --no-version-check` | GitHub 호출 skip (오프라인용) |

## 검사 항목

| # | 항목 | 자동 처리 |
|---|------|----------|
| 1 | Node ≥ 20 | 가이드 (winget / nodejs.org) |
| 2 | Codex CLI (`@openai/codex`) | ✅ `npm i -g @openai/codex` 자동 실행 |
| 3 | Codex 로그인 (`~/.codex/auth.json`) | 가이드 (터미널에서 `codex login`) |
| 4 | 페르소나 agent 3개 (`~/.claude/agents/harness-{qa-engineer,customer-user,deep-researcher}.md`) | 가이드 (`/harness` 첫 실행 시 `bootstrap-runtime.sh` 가 자동 등록) |
| 5 | Master skill 폴더 (`~/.claude/skills/harness/skills/harness/`) — SKILL.md + agents/learning/ 존재 | 누락 시 재설치 안내 |
| 6 | GitHub 버전 비교 (`.version` ↔ origin/main SHA) | outdated 면 자동 업데이트 |

## 실행 (Claude Code Bash 도구로 직접 수행)

Claude Code 의 메인 Bash 도구가 각 항목을 순서대로 검사합니다:

```bash
# 1. Node version
node --version  # v20.x 이상이어야 함

# 2. Codex CLI
codex --version 2>/dev/null || npm i -g @openai/codex

# 3. Codex login
test -f "$HOME/.codex/auth.json" && echo "logged in" || echo "run: codex login"

# 4. Personas registered
for a in harness-qa-engineer harness-customer-user harness-deep-researcher; do
  test -f "$HOME/.claude/agents/$a.md" || echo "missing: $a"
done

# 5. Master skill folder
test -f "$HOME/.claude/skills/harness/skills/harness/SKILL.md" || echo "reinstall needed"

# 6. Version check (skip if --no-version-check)
LOCAL_SHA=$(awk -F': ' '/^commit:/{print $2}' "$HOME/.claude/skills/harness/skills/harness/.version" 2>/dev/null)
REMOTE_SHA=$(curl -s https://api.github.com/repos/chdnl0420-svg/Harness/commits/main \
  | grep -m1 '"sha":' | cut -d'"' -f4)
[ "$LOCAL_SHA" = "$REMOTE_SHA" ] && echo "✅ 최신" || echo "⬆ outdated: $LOCAL_SHA → $REMOTE_SHA"
```

> Windows PowerShell 환경에서는 동일 검사를 PowerShell 로 수행해도 됨 (Node/curl 모두 Windows native 지원).

## Exit 결과 보고

| 결과 | 의미 | 다음 행동 |
|------|------|---------|
| 모든 항목 ✅ + 최신 | 사용 가능 | `/harness <task>` 호출 |
| Codex 미설치 → 자동 설치 완료 | npm install 성공 | 그대로 진행 가능 |
| Codex 로그인 누락 | 사용자 입력 필요 | 터미널에서 `codex login` 실행 후 메인 채팅에 "완료" |
| Node < 20 | 시스템 도구 | https://nodejs.org 또는 `winget install OpenJS.NodeJS.LTS` |
| 페르소나 agent 누락 | 첫 `/harness` 호출 시 자동 등록 | `/harness <task>` 호출하면 step1 에서 `bootstrap-runtime.sh` 가 자동 처리 |
| GitHub outdated | 마스터 갱신 필요 | `/harness-setup --update` |

## `--update` 동작

```bash
# 1. 기존 마스터 백업
mv ~/.claude/skills/harness ~/.claude/skills/harness.bak-$(date +%Y%m%d-%H%M%S)

# 2. GitHub 최신 tarball 받기
curl -sL https://github.com/chdnl0420-svg/Harness/archive/refs/heads/main.tar.gz \
  | tar xz -C /tmp

# 3. skills/harness/ 만 추출해 ~/.claude/skills/harness/ 로 복사
cp -r /tmp/Harness-main/skills/harness ~/.claude/skills/
cp -r /tmp/Harness-main/commands/harness-*.md ~/.claude/commands/

# 4. .version 갱신
SHA=$(curl -s https://api.github.com/repos/chdnl0420-svg/Harness/commits/main \
  | grep -m1 '"sha":' | cut -d'"' -f4)
printf 'commit: %s\ninstalled: %s\nsource: https://github.com/chdnl0420-svg/Harness\nbranch: main\n' \
  "$SHA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > ~/.claude/skills/harness/skills/harness/.version
```

## 트러블슈팅

### Codex CLI 내부 에러 (exit 4)
→ `codex_core::tools::router: write_stdin failed`. `npm i -g @openai/codex@latest` 후 재시도.

### Quota retry storm
→ Codex quota 소진 시 `/harness` step5 에서 `code-review` skill 로 자동 fallback. 추가 조치 불필요.

### `harness-* agent not found`
→ Claude Code 세션 시작 후 `bootstrap-runtime.sh` 가 등록한 agent 는 다음 세션부터 인식됨. Claude Code 재시작 권장.

### Node 22+ 에서 Codex CLI 경고
→ Codex CLI 는 Node 20 LTS 권장. 22+ 도 동작하지만 일부 deprecation 경고 가능.

## Related

- **bootstrap 스크립트**: `~/.claude/skills/harness/skills/harness/core/bootstrap-runtime.sh` (프로젝트 측 `.harness/` 초기화 + 페르소나 agent 등록)
- **상세 셋업 가이드**: `~/.claude/skills/harness/skills/harness/docs/setup.md`
- **`/harness` skill**: 워크플로우 시작 (step1 에서 bootstrap 자동 호출)
