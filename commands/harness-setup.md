---
description: Harness skill 의존성 검진 + npm 패키지 자동 설치 (Windows+WSL)
---

# Harness Setup — 검진 + 자동 설치 (한 번에)

이 명령은 `harness` skill이 동작하기 위한 prereq를 점검하고, **npm 패키지 누락 항목은 즉시 자동 설치**합니다.

## 동작 절차

1. **9개 항목 검사:**
   1. WSL 환경
   2. Windows Terminal (`wt.exe`) — 선택
   3. 기본 도구 (`bash`/`git`/`curl`/`stdbuf` 등)
   4. NVM
   5. Node ≥ 20
   6. Codex CLI (`@openai/codex`)
   7. Codex 로그인 (`~/.codex/`)
   8. Gemini CLI (`@google/gemini-cli`)
   9. Gemini API key (`~/.bashrc` `GEMINI_API_KEY`)

2. **결과 리포트** — 각 항목 ✅/❌/⏭.

3. **npm 패키지 자동 설치** — Codex CLI / Gemini CLI 누락 시 `npm install -g` 자동 실행.

4. **OS 도구·인증·API key** — 자동 처리 불가. 화면 안내 따라 사용자가 직접 처리.

## 실행 명령

```bash
SKILL_WIN="$(cmd.exe /c echo %USERPROFILE% 2>/dev/null | tr -d '\r')\\.claude\\skills\\harness"
wsl -e bash -lc '
  SKILL_WSL=$(wslpath -u "$1")
  bash "$SKILL_WSL/core/harness-doctor.sh" --fix
' _ "$SKILL_WIN"
```

> **`/harness-setup`는 항상 `--fix` 모드로 실행됩니다.** 검진만 원하시면:
> ```bash
> wsl -e bash -lc 'bash ~/.claude/skills/harness/core/harness-doctor.sh'
> ```

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
| Gemini CLI | ✅ | 동일 |
| Node ≥ 20 | ⚠️ 가이드 | `nvm install 20` 권한 거부 빈도 → 사용자 직접 |
| NVM | ❌ 가이드 | 시스템 설치 |
| 기본 도구 (apt) | ❌ 가이드 | sudo 필요 |
| Codex 로그인 | ❌ 가이드 | interactive 입력 필요 |
| Gemini API key | ❌ 가이드 | 보안 (사용자가 발급 + bashrc 편집) |

## 트러블슈팅 (이번 세션에서 발견된 트랩들)

### 1. Gemini "untrusted folder" 거부
→ wrapper에 `--skip-trust` 플래그 이미 적용됨.

### 2. Free tier 모델 정책 변경 (gemini-2.5-pro 차단)
→ wrapper가 `-m` 미지정으로 CLI 기본값 사용. 필요 시 `HARNESS_GEMINI_MODEL=gemini-3-flash-preview` env override.

### 3. Quota retry storm (분 단위 hang)
→ wrapper의 awk watcher가 `Attempt N failed ≥4회` 감지 시 즉시 abort + exit 3 → Claude fallback.

### 4. `~/.bashrc` interactive-guard로 GEMINI_API_KEY 누락
→ wrapper가 grep+eval로 interactive guard 우회.

### 5. API key 만료 (Google 자동 회수)
→ 채팅이나 공개 위치에 키 노출 시 자동 만료. 반드시 새 키 발급 후 bashrc 갱신.

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

- `/harness-setup` 자체 (Codex/Gemini CLI 설치는 sudo 불필요라 inline OK, 그 외는 별창)
- `harness` skill의 모든 단계 (Step 0~Phase 5)
- 다른 슬래시 커맨드에서도 동일 정책 권장

## Related

- **마스터 doctor 스크립트**: `~/.claude/skills/harness/core/harness-doctor.sh`
- **Interactive 헬퍼**: `~/.claude/skills/harness/core/run-interactive.sh`
- **상세 셋업 가이드**: `~/.claude/skills/harness/docs/setup.md`
- **`/harness` skill**: 워크플로우 시작 (Step 0에서 doctor 자동 호출)
