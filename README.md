# Harness — Step-Based Multi-Agent Development Workflow for Claude Code

> Claude · Codex 를 **하나의 워크플로우**로 묶어 도메인 설계·구현·리뷰·QA·커스터머 테스트를 자동화하는 Claude Code skill.

`/harness <task>` 한 번 호출로 **step1 (초기화) → step2 (도메인) → step3 (구현 계획) → step4 (구현) → step5 (Codex 리뷰) → step6 (QA) → step7 (커스터머 테스트, production 설치본) → step8 (commit) → complete** 전 과정을 진행하고, 모든 산출물을 `<project>/.harness/` 아래 마크다운으로 보존합니다.

---

## ✨ 무엇이 다른가

- **Step 기반 워크플로우**: step1~complete 까지 step 자체 규칙(워크플로우 다이어그램의 조건 분기)에 의한 것이 아니면 **어떤 step 도 스킵·통합·무시 금지**. 실수로 빠지는 단계 없음.
- **Plan-first**: step2 에서 `plan` skill 로 도메인 설계 → Codex critique → 사용자 승인. 자명한 누락·위험을 잡아냄.
- **Codex 가 코드 리뷰**: step5 에서 Codex 가 LGTM/이슈 분석. LGTM:NO 면 **반드시 step3 (구현 계획 수정) 로 되돌아감** (리뷰는 직접 수정 권한 없음).
- **QA + 일반인 시점 검증 2단**: step6 `harness-qa-engineer` 가 사양 일치 QA (스크린샷+클릭) → step7 `harness-customer-user` 가 **실제 production 설치본** 으로 일반인 시점 테스트.
- **토큰 절감 기본 모드**: step2/step3/step5(fallback)/step8 은 메인 Claude 의 skill 호출(plan, code-review 등). step6/step7 만 페르소나 가치 위해 subagent 유지.
- **`--noagent` 옵션**: `/harness --noagent <task>` → 모든 harness-* subagent 호출 비활성. skill·메인 Claude 직접으로 진행 (페르소나 가치는 잃지만 토큰 추가 절감).
- **리서치는 메인 Claude 직접**: 외부 정보 필요 시 WebSearch/WebFetch 등으로 직접 조사, 결과는 `.harness/research/research-<slug>-<NN>-<topic>.md` 로 파일 저장.
- **모든 산출물 영구 보존**: `.harness/` 아래 mdfile. PR/audit/resume 가능. 학습 데이터는 `.gitignore` 권장.
- **fail-fast 정책**: Codex 인증 실패(exit 2) → 즉시 중단 + 로그인 창. Quota 소진(exit 3) → `code-review` skill fallback.

---

## 📋 Prereq (Windows + WSL)

`/harness-setup` 한 번으로 자동 검진 + npm 패키지 설치:

| # | 항목 | 필수/선택 | 자동 설치? |
|---|------|----------|----------|
| 1 | WSL (Ubuntu) | 필수 | — |
| 2 | Windows Terminal (`wt.exe`) | 선택 (별창 모드용) | 가이드 |
| 3 | 기본 도구 (`bash`/`git`/`curl`/`stdbuf`) | 필수 | 가이드 (sudo apt) |
| 4 | NVM | 필수 | 가이드 |
| 5 | Node ≥ 20 | 필수 | 가이드 (nvm install) |
| 6 | Codex CLI (`@openai/codex`) | 필수 | ✅ 자동 |
| 7 | Codex 로그인 | 필수 | 가이드 (interactive) |
| 8 | Agent learning 구조 (harness-* agents + learning + templates) | 필수 | ✅ 자동 |

> macOS/Linux 네이티브는 현재 미지원. WSL 안에서만 동작.

---

## 🚀 설치

세 가지 방법 중 환경에 맞는 것 선택. **방법 1(PowerShell)** 이 가장 간단합니다 — WSL 미설치 PC에서도 파일 설치만 먼저 끝낼 수 있음.

### 방법 1: PowerShell 한 줄 (WSL 불필요 ⭐ 추천)

**관리자 PowerShell** 열고 그대로 붙여넣기 (WSL 자동 설치 포함):

```powershell
$ErrorActionPreference = "Stop"
$url = "https://github.com/chdnl0420-svg/Harness/archive/refs/heads/main.zip"
$tmp = "$env:TEMP\harness-install-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
$zip = "$tmp.zip"
$claude = "$env:USERPROFILE\.claude"

if (-not (Get-Command wsl -ErrorAction SilentlyContinue) -or -not (wsl -l -q 2>$null | Where-Object { $_ -match 'Ubuntu' })) {
  wsl --install -d Ubuntu
}

Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1

New-Item -ItemType Directory -Force -Path "$claude\skills","$claude\commands" | Out-Null
Copy-Item -Path "$($src.FullName)\skills\harness" -Destination "$claude\skills\" -Recurse -Force
Get-ChildItem -Path "$($src.FullName)\commands\harness-*.md" | ForEach-Object {
  Copy-Item -Path $_.FullName -Destination "$claude\commands\" -Force
}

try {
  $commit = (Invoke-RestMethod -Uri "https://api.github.com/repos/chdnl0420-svg/Harness/commits/main" -UseBasicParsing).sha
  $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  @"
commit: $commit
installed: $now
source: https://github.com/chdnl0420-svg/Harness
branch: main
"@ | Set-Content -Path "$claude\skills\harness\.version" -Encoding utf8
} catch {}

Remove-Item -Path $zip,$tmp -Recurse -Force -ErrorAction SilentlyContinue
```

**설치 후 다음 단계**:
1. 재부팅
2. Claude Code 재시작
3. Claude Code 에서 `/harness-setup` → 8 개 prereq 검진. 누락 항목은 화면 안내대로 처리.

**필요 조건**: PowerShell 5.0+ (Windows 10/11 기본 포함) + 인터넷. git/WSL 없어도 됨.

### 방법 2: WSL bash 한 줄 (이미 WSL 사용 중인 경우)

WSL Ubuntu 터미널 또는 Git Bash에서:

```bash
git clone https://github.com/chdnl0420-svg/Harness.git /tmp/h && \
W=$(cmd.exe /c "echo %USERNAME%" | tr -d '\r\n') && \
SKILL="/mnt/c/Users/$W/.claude/skills/harness" && \
mkdir -p "/mnt/c/Users/$W/.claude/skills" "/mnt/c/Users/$W/.claude/commands" && \
cp -r /tmp/h/skills/harness "/mnt/c/Users/$W/.claude/skills/" && \
cp /tmp/h/commands/harness-*.md "/mnt/c/Users/$W/.claude/commands/" 2>/dev/null && \
chmod +x "$SKILL"/{core,wrappers}/*.sh && \
SHA=$(git -C /tmp/h rev-parse HEAD) && \
printf 'commit: %s\ninstalled: %s\nsource: https://github.com/chdnl0420-svg/Harness\nbranch: main\n' \
   "$SHA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SKILL/.version" && \
rm -rf /tmp/h && \
echo "✅ 설치 완료 (SHA: ${SHA:0:7})"
```

### 방법 3: 수동 복사

저장소 clone 또는 ZIP 다운로드 후:
```
clone한 디렉토리/
├── skills/harness/        → %USERPROFILE%\.claude\skills\harness\
└── commands/harness-*.md  → %USERPROFILE%\.claude\commands\
```

---

### 설치 후 다음 단계

1. **WSL + Ubuntu 미설치 시** (관리자 PowerShell):
   ```powershell
   wsl --install -d Ubuntu
   ```
   재부팅 → Ubuntu 첫 실행 (사용자명/비밀번호 설정).

2. **Claude Code 재시작** (skill 목록 갱신).

3. **Claude Code 에서**:
   ```
   /harness-setup
   ```
   → 모든 항목 ✅ 통과해야 사용 가능. 누락 항목(Codex 로그인 등)은 화면 안내대로 처리.

---

## 🎯 사용법

### 새 워크플로우 시작
```
/harness <자연어 요청>
/harness --noagent <자연어 요청>     # subagent 호출 전부 비활성 (토큰 절감 모드)
```

예시:
- `/harness "OWASP 2025 권장값으로 Argon2id 패스워드 해시 함수 추가"`
- `/harness --noagent "src/util/discount.js 에 discount(price, percent) 추가, percent 0~100 검증"`

### 그 외 명령
| 명령 | 동작 |
|------|------|
| `/harness resume [id]` | 중단된 작업 재개 (마지막 또는 지정 ID) |
| `/harness status` | in_progress 작업 리스트 |
| `/harness list` | 모든 작업 (최근 20) |
| `/harness sync` | 마스터 wrapper → 프로젝트 `.harness/` 동기화 |
| `/harness-setup` | 의존성 검진 + npm 자동 설치 + **GitHub 버전 자동 확인** |
| `/harness-setup --update` | GitHub 최신으로 즉시 업데이트 (백업 자동 생성) |
| `/harness-review` | Codex 로 즉석 리뷰 (자연어로 파일·focus 자동 해석) |
| `/harness-help` | 전체 도움말 (워크플로우, agent, 폴더 구조 등) |
| `/harness-spec` | 프로젝트 사양 문서 (PRD/ARCHITECTURE/ADR/UI_GUIDE) + CLAUDE.md 작성 |
| `/harness-audit` | repo health 점수표 |
| `/harness-distill` | agent learning 파일 정리·압축 |

### 환경변수

| 변수 | 기본값 | 용도 |
|------|--------|------|
| `HARNESS_IDLE_LIMIT` | `180` | Codex 무응답 N 초 시 abort. tmux pane content hash 변화로 idle 판정. **`0` 설정 시 idle 검사 비활성** (HARD_LIMIT 만 적용) |
| `HARNESS_HARD_LIMIT` | `3600` | runaway 안전망 (절대 상한, 1시간) |
| `HARNESS_WAIT_LIMIT` | (deprecated) | 설정 시 `HARNESS_HARD_LIMIT` 으로 매핑 (하위호환) |
| `HARNESS_NO_VISIBLE` | (unset) | `1` 설정 시 tmux attach 별창 비활성 |
| `HARNESS_TMUX_READY_TIMEOUT` | `30` | Codex TUI 로딩 대기 한도(초) |
| `HARNESS_LARGE_PROMPT_BYTES` | `10240` | (legacy, 항상 `tmux load-buffer + paste-buffer` 사용) |
| `HARNESS_MAX_ONBOARDING_ENTER` | `3` | Codex 첫 사용 시 onboarding 화면 감지 시 자동 Enter 주입 최대 횟수 |
| `HARNESS_SKIP_DRIFT_CHECK` | (unset) | `1` 설정 시 drift 검사 skip (CI/자동화) |
| `HARNESS_REPO_URL` | (default) | 업데이트 대상 GitHub URL override |
| `HARNESS_REPO_API` | (default) | 업데이트 대상 GitHub API URL override |

---

## 📐 워크플로우

```
사용자: /harness [--noagent] <task>
    ↓
step1: harness 초기화
       (REQUEST_ID, .harness/ 폴더, wrapper 동기화, --noagent 플래그 처리)
    ↓
step2: 도메인 설계 (plan skill + 메인 Claude 직접 리서치 + Codex 리뷰 + 사용자 승인)
       산출물: domain-<slug>.md
    ↓
step3: 구현 계획 (plan skill + Codex 리뷰, 자동)
       산출물: implementation-<slug>.md
    ↓
step4: 구현 (메인 Claude 직접 코드 작성)
       산출물: 프로젝트 코드 + progress 기록
    ↓
step5: 리뷰 (Codex; 불가 시 code-review skill fallback)
       산출물: review-<slug>.md (누적)
       ├─ LGTM YES → step6
       └─ LGTM NO → step3 으로 루프 (동일 문제 5회 시 중단)
    ↓
step6: QA 테스트 (test-guide 작성 + harness-qa-engineer 스크린샷·클릭)
       산출물: test-guide-<slug>.md, qa-<slug>.md
       ├─ PASS → step7
       ├─ FAIL → step3 으로 루프
       └─ BLOCKED → 사용자 결정
    ↓
step7: 커스터머 유저 테스트 (전체 1회. production 설치본 빌드/설치/실행 후
                          harness-customer-user 가 일반인 시점 테스트)
       산출물: customer-<slug>.md
    ↓
step8: git commit / push (git remote 있을 때만; 없으면 complete 로 직행)
    ↓
complete: report-<slug>.md (사람 가독 보고서) + ADR append
```

### 기본 모드 vs `--noagent` 모드

| step | 기본 모드 | `--noagent` 모드 |
|------|----------|------------------|
| step2 도메인 설계 | `plan` skill (메인 Claude) | `plan` skill (메인 Claude) |
| step3 구현 계획 | `plan` skill (메인 Claude) | `plan` skill (메인 Claude) |
| step4 구현 | 메인 Claude 직접 | 메인 Claude 직접 |
| step5 리뷰 | Codex CLI (fallback: `code-review` skill) | Codex CLI (fallback: `code-review` skill) |
| step6 QA | **`harness-qa-engineer` subagent** | `browser-qa` skill / 메인 직접 |
| step7 커스터머 | **`harness-customer-user` subagent** | `browser-qa` skill / 메인 직접 (페르소나 가치 손실) |
| step8 commit | 메인 Claude 직접 | 메인 Claude 직접 |

### 산출물 트리

```
<project>/.harness/
├── .noagent                          # --noagent 플래그 상태 (있으면 모드 ON)
├── domain-<slug>.md                  # step2 도메인 설계
├── implementation-<slug>.md          # step3 구현 계획
├── test-guide-<slug>.md              # step6/step7 공용 테스트 가이드
├── research/research-<slug>-NN-*.md  # 메인 Claude 가 직접 수행한 리서치 (선택)
├── reviews/review-<slug>.md          # step5 Codex 리뷰 (누적)
├── results/qa-<slug>.md              # step6 QA 보고서
├── results/customer-<slug>.md        # step7 커스터머 테스트 보고서
├── results/report-<slug>.md          # complete 사람 가독 보고서
├── progress/progress-<slug>.md       # 실시간 상태
├── wrappers/                         # 마스터에서 부트스트랩
├── core/                             # 마스터에서 부트스트랩
├── agents/learning/                  # 프로젝트 학습 데이터 (.gitignore 권장)
└── backups/                          # drift sync 시 백업
```

---

## 🧱 폴더 생성 규칙 (구현 시)

step4 구현 단계에서 새 폴더를 만들 때:
- **root 폴더에 파일을 직접 만들지 않는다.** 폴더를 먼저 만들고 그 안에 파일을 넣는다.

---

## 🪟 Interactive Command Policy

sudo·OAuth 로그인·비밀번호 입력이 필요한 명령은 **반드시 `core/run-interactive.sh` 헬퍼**로 wt.exe 별창에서 실행. Claude Code Bash 도구의 inline 실행은 stdin 입력 불가라 좀비 프로세스 됨.

```bash
bash "$HOME/.claude/skills/harness/core/run-interactive.sh" \
  "🔓 codex login" "codex login"
```

→ 새 Windows Terminal 창에서 명령 실행, 사용자 직접 입력, Enter 로 닫기.

---

## 🩺 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| Codex 로그인 필요 | Codex CLI 인증 만료 | wt.exe 별창에서 `codex login` 완료 후 메인 채팅에 "완료" |
| Codex quota 소진 (exit 3) | ChatGPT Plus 한도 도달 | `code-review` skill 또는 Claude self critique 로 자동 fallback. 그대로 진행됨 |
| `codex_core::tools::router: error=write_stdin failed` (exit 4) | Codex CLI 버그 — tool router 가 닫힌 subprocess stdin 에 write | `npm i -g @openai/codex@latest` 후 재시도 |
| `Argument list too long` | code review prompt 가 ARG_MAX 초과 | `--prompt-file` 패턴 사용 (step5 Codex 리뷰 호출 시) |
| `This command must run inside a Git repository` | Codex CLI 가 git 강제 요구 | wrapper 가 자동 `git init -q -b main` 수행. 안내 메시지 출력 |
| `warning: Codex could not find bubblewrap on PATH` | WSL 에 bubblewrap 미설치, 번들 fallback | **무시 가능**. 깔끔히 없애려면: `sudo apt install -y bubblewrap` |
| `harness-* agent not found` | Claude Code 세션 시작 후 추가된 agent | Claude Code 재시작. registry 는 시작 시만 스캔 |
| Drift 감지 | 마스터 wrapper 가 갱신됨 | `/harness sync` 또는 다음 `/harness` 호출 시 A 선택 |

상세: [skills/harness/docs/setup.md](skills/harness/docs/setup.md)

---

## 📂 디렉토리 구조

```
Harness/
├── README.md                      # 이 문서
├── commands/
│   ├── harness-setup.md           # /harness-setup
│   ├── harness-help.md            # /harness-help
│   ├── harness-spec.md            # /harness-spec
│   ├── harness-review.md          # /harness-review
│   ├── harness-audit.md           # /harness-audit
│   └── harness-distill.md         # /harness-distill
└── skills/harness/
    ├── SKILL.md                   # 메인 skill 정의 (워크플로우 명세 + CRITICAL 규칙)
    ├── core/                      # 인프라 스크립트 (bootstrap, doctor, drift 검사, interactive 헬퍼)
    ├── wrappers/                  # 외부 CLI 호출 wrapper (codex-review)
    ├── templates/                 # 산출물 템플릿 (plan, result, review, progress 등)
    ├── agents/                    # harness-* 서브에이전트 (planner/architect/code-reviewer/security-reviewer/tdd-guide/build-resolver/qa-engineer/customer-user)
    │   └── learning/              # 각 agent 의 누적 학습 데이터
    └── docs/
        ├── workflow.md            # 전체 흐름 + CRITICAL Step 스킵 금지 + --noagent 모드
        ├── steps/                 # step1 ~ step8 + complete 각 단계 상세
        ├── test-guide-format.md   # step6/step7 테스트 가이드 양식
        ├── setup.md               # 설치·환경 상세
        └── ...
```

---

## 🤝 기여

- 이슈/PR 환영. wrapper 동작이나 새 환경에서 마주친 트랩 등을 setup.md 에 추가하면 다른 사용자에게도 도움됨.
- Mac/Linux 네이티브 지원은 별도 fork 권장 (현재 코드는 WSL `wsl.exe`/`wt.exe` 직접 호출 가정).

---

## 📄 라이선스

MIT — 자유롭게 사용·수정·재배포. 사용자 책임.

---

## 🙏 Credits

- [Claude Code](https://docs.claude.com/claude-code) — 호스트 환경
- [OpenAI Codex CLI](https://github.com/openai/codex) — primary reviewer
