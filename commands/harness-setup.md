---
description: Harness skill 의존성 검진 + npm 자동 설치 + GitHub 최신화 확인 (Windows+WSL)
argument-hint: '[--update] [--no-version-check]'
---

# Harness Setup — 검진 + 자동 설치 + 버전 확인 (한 번에)

이 명령은 `harness` skill이 동작하기 위한 prereq를 점검하고, **npm 패키지 누락 항목은 즉시 자동 설치**하며, 모든 검진 통과 후 **GitHub 최신 버전 여부를 자동 확인**합니다.

## 주요 모드

| 호출 | 동작 |
|------|------|
| `/harness-setup` | 검진 + npm/apt/key 자동 설치 + **outdated면 자동 업데이트** (백업 자동 생성) |
| `/harness-setup --update` | 검진 skip + 즉시 업데이트 (force, 동일 버전이어도 강제 적용) |
| `/harness-setup --no-update` | 검진은 진행, outdated 감지해도 자동 업데이트 안 함 (안내만) |
| `/harness-setup --no-version-check` | GitHub 호출 자체 skip (오프라인용) |

## 동작 절차

1. **항목 검사:**
   1. WSL 환경
   2. Windows Terminal (`wt.exe`) — 선택
   3. 기본 도구 (`bash`/`git`/`curl`/`stdbuf` 등)
   4. NVM
   5. Node ≥ 20
   6. Codex CLI (`@openai/codex`)
   7. Codex 로그인 (`~/.codex/`)
   8. Agent learning 구조 (harness-* agents + learning + templates, 마스터 측)

2. **결과 리포트** — 각 항목 ✅/❌/⏭.

3. **npm 패키지 자동 설치** — Codex CLI 누락 시 `npm install -g` 자동 실행.

4. **OS 도구·Codex 로그인** — 자동 처리 불가. 화면 안내 따라 사용자가 직접 처리.

## 실행 명령

`$ARGUMENTS`를 받아 doctor 스크립트에 그대로 전달:

```bash
SKILL_WIN="$(cmd.exe /c echo %USERPROFILE% 2>/dev/null | tr -d '\r')\\.claude\\skills\\harness"
ARGS="$ARGUMENTS"
# 인자 없으면 기본 --fix 모드 (검진 + npm 자동 + 버전 비교)
if [ -z "$ARGS" ]; then ARGS="--fix"; fi
wsl -e bash -lc '
  SKILL_WSL=$(wslpath -u "$1")
  bash "$SKILL_WSL/core/harness-doctor.sh" '"$ARGS"'
' _ "$SKILL_WIN"
```

지원 인자:
- (없음) → `--fix` 자동 적용 (검진 + npm 설치 + 버전 비교)
- `--update` → GitHub 최신으로 업데이트 (검진 skip)
- `--no-version-check` → GitHub 호출 안 함 (오프라인용)

## Exit Code 의미

| Exit | 의미 | 다음 행동 |
|------|------|---------|
| 0 | 모든 prereq 충족. `~/.harness/.doctor-passed` 마커 생성 | `/harness <task>` 가능 |
| 1 | 자동 설치 시도했거나 가이드 필요 항목 있음 | 화면 안내 따라 처리 후 `/harness-setup` 재실행 |
| 2 | 환경 자체 부적합 (WSL 아님) | 진행 불가 |

## 자동 설치 vs 가이드

| 항목 | 자동? | 이유 |
|------|------|------|
| Codex CLI | ✅ | npm 패키지, user 영역, sudo 불필요 |
| **기본 도구 (apt: tmux, curl 등)** | ✅ **반자동** | `/harness-setup --fix` 가 wt.exe 별창 띄움 → 사용자가 sudo 비밀번호 입력 |
| Node ≥ 20 | ⚠️ 가이드 | `nvm install 20` 권한 거부 빈도 → 사용자 직접 |
| NVM | ❌ 가이드 | 시스템 설치 |
| Codex 로그인 | ❌ 가이드 | OAuth (브라우저 인증) |

## 트러블슈팅 (이번 세션에서 발견된 트랩들)

### 1. Codex CLI 내부 에러 (exit 4)
→ codex_core::tools::router stdin closed. `npm i -g @openai/codex@latest` 후 재시도.

### 2. Quota retry storm (분 단위 hang)
→ wrapper의 awk watcher가 `Attempt N failed ≥4회` 감지 시 즉시 abort → Claude fallback.

### 3. `Argument list too long`
→ code review prompt 가 ARG_MAX 초과. `--prompt-file` 패턴 사용 (step5 Codex 리뷰 호출 시).

## 🪟 Interactive Command Policy (필수 준수)

**sudo·비밀번호·OAuth 로그인 등 사용자 입력이 필요한 명령은 절대 inline Bash로 실행 금지.**
Claude Code의 Bash 도구는 stdin 입력을 받을 수 없어서 매달려 좀비가 됩니다 (이번 세션에 `apt-get install unzip`이 3시간 대기한 사례 발생).

### 규칙

다음 패턴이 발생할 때 **반드시 `core/run-interactive.sh` 헬퍼로 별창 실행**:

| 패턴 | 예시 |
|------|------|
| `sudo <명령>` | `sudo apt install ...`, `sudo kill ...` |
| OAuth/로그인 흐름 | `codex login`, `gh auth login` |
| 대화형 prompt | `npm init` (기본값 외), CLI tool 첫 실행 인증 |
| 비밀번호 입력 | SSH passphrase, gpg sign 등 |

### 호출 패턴

```bash
SKILL="$HOME/.claude/skills/harness"
bash "$SKILL/core/run-interactive.sh" "🔓 codex login" "codex login"
bash "$SKILL/core/run-interactive.sh" "📦 unzip 설치" "sudo apt update && sudo apt install -y unzip"
```

→ wt.exe 새 창에서 명령 실행, 사용자가 직접 입력, 종료 후 Enter로 창 닫기.

### Fallback

- `wt.exe` 없을 때: 헬퍼가 자동으로 사용자에게 "이 명령을 직접 실행하세요" 안내 (exit 1)
- 그 경우 절대 inline Bash로 sudo 시도 금지 — 좀비 발생.

### 적용 범위

- `/harness-setup` 자체 (Codex CLI 설치는 sudo 불필요라 inline OK, 그 외는 별창)
- `harness` skill의 모든 step (step1~complete)
- 다른 슬래시 커맨드에서도 동일 정책 권장

## GitHub 버전 확인 / 업데이트

`/harness-setup` 호출 시 모든 항목 통과하면 자동으로 다음 정보 출력 중 하나:

```
✅ Harness 최신 (SHA: abc1234)
```
또는
```
⬆ 업데이트 가능
    현재: abc1234
    최신: def5678
    적용: /harness-setup --update
```
또는 (오프라인 / GitHub 일시 장애):
```
⚠ GitHub 조회 실패 (오프라인 또는 일시 장애)
설치된 파일은 그대로 사용 가능.
```

**업데이트 적용** (`/harness-setup --update`):
- ✅ `~/.claude/skills/harness.bak-<timestamp>` 자동 백업
- ✅ tarball 다운로드 → 추출 → 적용
- ✅ `.version` 갱신 (commit SHA + ISO 타임스탬프)
- ✅ `~/.harness/.doctor-passed` 마커 초기화 (재검진 권유)

캐시: `~/.harness/.last-github-check` (1시간 TTL).

## Related

- **마스터 doctor 스크립트**: `~/.claude/skills/harness/core/harness-doctor.sh`
- **Interactive 헬퍼**: `~/.claude/skills/harness/core/run-interactive.sh`
- **상세 셋업 가이드**: `~/.claude/skills/harness/docs/setup.md`
- **`/harness` skill**: 워크플로우 시작 (step1 초기화에서 doctor 자동 호출)
