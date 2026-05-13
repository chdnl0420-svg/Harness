# Harness Setup Guide (Windows + WSL)

이 문서는 `harness` skill을 새 PC에서 처음 사용하기 위한 셋업 가이드입니다.

---

## TL;DR

```
/harness-setup           # 진단
/harness-setup --fix     # 자동 설치 가능한 것만 처리
```

→ 모두 ✅면 `/harness <task>` 호출 가능.

---

## 지원 환경

- ✅ **Windows + WSL (Ubuntu 권장)**
- ❌ macOS / Linux 네이티브 (현재 미지원)

---

## Prerequisites 매트릭스

| # | 항목 | 검사 | 누락 시 |
|---|------|------|---------|
| 1 | WSL 환경 | `/proc/version`에 microsoft 또는 `$WSL_DISTRO_NAME` | 진행 불가 — Microsoft Store에서 WSL + Ubuntu 설치 |
| 2 | Windows Terminal | `command -v wt.exe` | 선택. 없으면 인라인 모드로 fallback |
| 3 | 기본 도구 | `bash`, `git`, `curl`, `stdbuf`, `grep`, `awk`, `sed` | `sudo apt update && sudo apt install -y <missing>` |
| 4 | NVM | `~/.nvm/nvm.sh` 존재 | `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh \| bash` |
| 5 | Node ≥ 20 | `node --version` | `nvm install 20 && nvm use 20` |
| 6 | Codex CLI | `command -v codex` | **자동 설치:** `/harness-setup --fix` |
| 7 | Codex 로그인 | `~/.codex/auth.json` 또는 `config.toml` | 새 터미널에서 `codex login` (interactive) |
| 8 | Gemini CLI | `command -v gemini` | **자동 설치:** `/harness-setup --fix` |
| 9 | Gemini API key | `$GEMINI_API_KEY` env 또는 `~/.bashrc`의 export 라인 | 1. https://aistudio.google.com/apikey 에서 발급<br>2. `nano ~/.bashrc` 열어 `export GEMINI_API_KEY="<key>"` 추가<br>3. `source ~/.bashrc` |

---

## 자동 설치 정책

| 자동 (`--fix`) | 가이드만 |
|---------------|---------|
| `@openai/codex` npm 패키지 | NVM 설치 (system) |
| `@google/gemini-cli` npm 패키지 | Node 버전 변경 |
| | OS 도구 (sudo apt) |
| | Codex 로그인 (interactive 필요) |
| | Gemini API key (보안 + 사용자 입력) |

이유:
- **npm 패키지** = user-local, sudo 불필요 → 안전한 자동 설치
- **OS 도구** = sudo 필요 → 자동화 시 권한 거부 빈도가 높아 사용자 직접 권장
- **인증/API key** = 사용자 입력 또는 brower OAuth → 자동화 불가

---

## 첫 사용 흐름

```mermaid
graph TD
    A[/harness X 호출] --> B{~/.harness/.doctor-passed 마커?}
    B -->|있음| F[Step 0 Bootstrap → Phase 1]
    B -->|없음| C[harness-doctor.sh --quiet]
    C -->|exit 0| D[마커 생성]
    C -->|exit 1| E["워크플로우 중단<br>'/harness-setup' 실행 안내"]
    C -->|exit 2| G["환경 부적합<br>WSL 필요"]
    D --> F
```

---

## 흔한 트랩 (이번 세션에서 발견된 5건)

### 1. Gemini "untrusted folder" 거부 → exit 55
**증상:** `Gemini CLI is not running in a trusted directory`
**원인:** Gemini가 작업 디렉토리를 신뢰하지 않음
**해결:** wrapper에 `--skip-trust` 플래그 이미 포함됨. 추가 작업 불필요.

### 2. Free tier 모델 정책 변경
**증상:** `You have exhausted your capacity on this model`이 첫 호출부터 발생
**원인:** Google이 free tier에서 일부 pro 모델 제한
**해결:** wrapper가 `-m` 미지정으로 CLI 기본값 사용. `HARNESS_GEMINI_MODEL=gemini-3-flash-preview` env로 override 가능.

### 3. Quota retry storm (분 단위 hang)
**증상:** `Attempt 1 failed... Retrying after 5864ms` 반복, 워크플로우가 5+분 멈춤
**원인:** gemini CLI 내부 retry loop이 quota out 상태에서도 backoff 무한 시도
**해결:** wrapper의 awk watcher가 4회 연속 실패 감지 시 `pkill -TERM` + exit 3 → Claude fallback.

### 4. `~/.bashrc` interactive-guard로 `GEMINI_API_KEY` 누락
**증상:** bashrc에 키 있는데 wrapper에서 못 찾음
**원인:** `~/.bashrc` 상단에 `[[ $- != *i* ]] && return` 같은 가드가 있으면 script-mode에서 즉시 return
**해결:** wrapper가 `grep + eval`로 export 라인만 추출해 interactive guard 우회.

### 5. API key 만료 (Google 자동 회수)
**증상:** `API key expired. Please renew the API key.` HTTP 400
**원인:** Google이 공개 위치(GitHub, 채팅 로그 등)에 노출된 키를 자동 감지해 무효화
**해결:** 새 키 발급 + bashrc 갱신. **절대 채팅에 키 붙여넣지 말것.**

---

## 트러블슈팅

### `/harness-setup` 실행 시 doctor가 통과 안 됨

```bash
# 직접 실행해서 상세 메시지 보기
wsl -e bash -lc 'bash ~/.claude/skills/harness/core/harness-doctor.sh'
```

각 ❌ 항목 아래 안내 메시지를 그대로 따라하세요.

### `~/.harness/.doctor-passed` 강제 재검진

```bash
wsl -e bash -lc 'rm -f ~/.harness/.doctor-passed'
```

다음 `/harness` 호출 시 doctor 다시 실행됨.

### Codex/Gemini가 wrapper에선 안 되지만 직접 호출은 됨

CLI는 잘 동작하는데 wrapper에서만 실패하는 경우:
1. `$HOME/.nvm/nvm.sh` source 확인 (wrapper가 자동으로 함)
2. WSL과 Git Bash 경로 차이 (`wslpath`로 변환되어야 함)
3. env 전파 안 됨 → bashrc에 환경변수 등록 확인

---

## 유지보수

- **마스터 doctor 스크립트**: `~/.claude/skills/harness/core/harness-doctor.sh`
- **slash command**: `~/.claude/commands/harness-setup.md`
- **wrappers**: `~/.claude/skills/harness/wrappers/{codex-review,gemini-research,auth-helper}.sh`

wrapper 업데이트 후 프로젝트 동기화: `/harness sync`
