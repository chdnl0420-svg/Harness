# Harness — Iterative Multi-LLM Development Workflow for Claude Code

> Claude · Codex · Gemini를 **하나의 워크플로우**로 묶어 계획·리뷰·구현을 자동화하는 Claude Code skill.

`/harness <task>` 한 번 호출로 **Plan → Codex critique → (필요시) Gemini research → Implement → Codex review → Complete** 전 과정을 진행하고, 모든 산출물을 `<project>/.harness/` 아래 마크다운으로 보존합니다.

---

## ✨ 무엇이 다른가

- **Plan-first**: Codex(GPT-5)가 구현 전 plan을 critique. 자명한 누락·위험을 잡아냄.
- **Codex가 코드 리뷰**: 구현 후 Codex가 LGTM/이슈 분석. NO면 자동 재구현 루프.
- **Gemini는 on-demand**: 라이브러리 비교·최신 벤치마크 등 외부 정보가 필요할 때만.
- **모든 산출물 영구 보존**: `.harness/{plans,research,reviews,improvements,results}/` 에 mdfile. PR/audit/resume 가능.
- **별창 모드**: 외부 LLM 호출을 새 Windows Terminal 창에서 실시간 stream 표시. (옵션)
- **fail-fast 정책**: 인증 실패(exit 2) → 즉시 중단 + 로그인 창 / Quota 소진(exit 3) → Claude fallback.

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
| 8 | Gemini CLI (`@google/gemini-cli`) | 필수 | ✅ 자동 |
| 9 | Gemini API key | 필수 | 가이드 (aistudio.google.com) |

> macOS/Linux 네이티브는 현재 미지원. WSL 안에서만 동작.

---

## 🚀 설치

세 가지 방법 중 환경에 맞는 것 선택. **방법 1(PowerShell)** 이 가장 간단합니다 — WSL 미설치 PC에서도 파일 설치만 먼저 끝낼 수 있음.

### 방법 1: PowerShell 한 줄 (WSL 불필요 ⭐ 추천)

PowerShell (관리자 아니어도 OK) 열고 그대로 붙여넣기:

```powershell
$ErrorActionPreference = "Stop"
$url = "https://github.com/chdnl0420-svg/Harness/archive/refs/heads/main.zip"
$tmp = "$env:TEMP\harness-install-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
$zip = "$tmp.zip"
$claude = "$env:USERPROFILE\.claude"

Write-Host "📥 Downloading..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

Write-Host "📦 Extracting..." -ForegroundColor Cyan
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1

Write-Host "📂 Installing to $claude ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "$claude\skills","$claude\commands" | Out-Null
Copy-Item -Path "$($src.FullName)\skills\harness" -Destination "$claude\skills\" -Recurse -Force
Copy-Item -Path "$($src.FullName)\commands\harness-setup.md" -Destination "$claude\commands\" -Force
Copy-Item -Path "$($src.FullName)\commands\harness-review.md" -Destination "$claude\commands\" -Force -ErrorAction SilentlyContinue

Write-Host "🔖 Recording version..." -ForegroundColor Cyan
try {
  $commit = (Invoke-RestMethod -Uri "https://api.github.com/repos/chdnl0420-svg/Harness/commits/main" -UseBasicParsing).sha
  $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  @"
commit: $commit
installed: $now
source: https://github.com/chdnl0420-svg/Harness
branch: main
"@ | Set-Content -Path "$claude\skills\harness\.version" -Encoding utf8
  Write-Host "    SHA: $($commit.Substring(0,7))" -ForegroundColor DarkGray
} catch {
  Write-Host "    (skip — GitHub API 호출 실패, /harness-setup 시 자동 표시)" -ForegroundColor DarkGray
}

Write-Host "🧹 Cleanup..." -ForegroundColor Cyan
Remove-Item -Path $zip,$tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "✅ 파일 설치 완료" -ForegroundColor Green
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "  1. WSL + Ubuntu 미설치 시 (관리자 PowerShell): wsl --install -d Ubuntu  → 재부팅"
Write-Host "  2. Claude Code 재시작"
Write-Host "  3. Claude Code에서: /harness-setup"
Write-Host "     → 9개 prereq 검진. 누락 항목은 화면 안내대로 처리."
```

**필요 조건**: PowerShell 5.0+ (Windows 10/11 기본 포함) + 인터넷. git/WSL 없어도 됨.

### 방법 2: WSL bash 한 줄 (이미 WSL 사용 중인 경우)

WSL Ubuntu 터미널 또는 Git Bash에서:

```bash
git clone https://github.com/chdnl0420-svg/Harness.git /tmp/h && \
W=$(cmd.exe /c "echo %USERNAME%" | tr -d '\r\n') && \
SKILL="/mnt/c/Users/$W/.claude/skills/harness" && \
mkdir -p "/mnt/c/Users/$W/.claude/skills" "/mnt/c/Users/$W/.claude/commands" && \
cp -r /tmp/h/skills/harness "/mnt/c/Users/$W/.claude/skills/" && \
cp /tmp/h/commands/harness-setup.md /tmp/h/commands/harness-review.md \
   "/mnt/c/Users/$W/.claude/commands/" 2>/dev/null && \
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
├── skills/harness/           → %USERPROFILE%\.claude\skills\harness\
└── commands/harness-setup.md → %USERPROFILE%\.claude\commands\harness-setup.md
```

---

### 설치 후 다음 단계

1. **WSL + Ubuntu 미설치 시** (관리자 PowerShell):
   ```powershell
   wsl --install -d Ubuntu
   ```
   재부팅 → Ubuntu 첫 실행 (사용자명/비밀번호 설정).

2. **Claude Code 재시작** (skill 목록 갱신).

3. **Claude Code에서**:
   ```
   /harness-setup
   ```
   → 9/9 ✅ 통과해야 사용 가능. 누락 항목(Codex 로그인, Gemini API key 등)은 화면 안내대로 처리.

### Gemini API key 빠른 등록 (한 줄)

[aistudio.google.com/apikey](https://aistudio.google.com/apikey) 에서 키 발급 후, **WSL 터미널**에 아래 줄을 붙여넣고 따옴표 안만 실제 키로 교체:

```bash
bash ~/.claude/skills/harness/core/setup-gemini-key.sh "AIzaSy_여기에_키_붙여넣기"
```

→ 자동으로:
- 형식 검증 (`AIzaSy` 시작 + 39자)
- `~/.bashrc` 백업 후 안전하게 갱신 (기존 라인 교체 또는 새로 추가)
- 현재 셸에도 즉시 export 적용 (다음 호출부터 사용 가능)

확인: Claude Code에서 `/harness-setup` 다시 실행 → `[9/9] Gemini API key ✅`

---

## 🎯 사용법

### 새 워크플로우 시작
```
/harness <자연어 요청>
```
예시:
- `/harness "OWASP 2025 권장값으로 Argon2id 패스워드 해시 함수 추가"`
- `/harness "Bun과 Node 22 cold start 비교 후 더 빠른 런타임으로 greet CLI"`

### 그 외 명령
| 명령 | 동작 |
|------|------|
| `/harness resume [id]` | 중단된 작업 재개 (마지막 또는 지정 ID) |
| `/harness status` | in_progress 작업 리스트 |
| `/harness list` | 모든 작업 (최근 20) |
| `/harness sync` | 마스터 wrapper → 프로젝트 `.harness/` 동기화 |
| `/harness-setup` | 의존성 검진 + npm 자동 설치 + **GitHub 버전 자동 확인** |
| `/harness-setup --update` | GitHub 최신으로 즉시 업데이트 (백업 자동 생성) |
| `/harness-review` | Codex로 즉석 리뷰 (자연어로 파일·focus 자동 해석) |

### 환경변수

| 변수 | 기본값 | 용도 |
|------|--------|------|
| `HARNESS_IDLE_LIMIT` | `180` | Codex/Gemini stdout 무응답 N초 시 abort. Codex가 계속 출력하면 무한 대기 |
| `HARNESS_HARD_LIMIT` | `3600` | runaway 안전망 (절대 상한, 1시간) |
| `HARNESS_WAIT_LIMIT` | (deprecated) | 설정 시 `HARNESS_HARD_LIMIT`으로 매핑 (하위호환) |
| `HARNESS_NO_VISIBLE` | (unset) | `1` 설정 시 별창 모드 비활성 (인라인 fallback) |
| `HARNESS_GEMINI_MODEL` | (auto) | Gemini CLI 모델 override (예: `gemini-3-flash-preview`) |
| `HARNESS_SKIP_DRIFT_CHECK` | (unset) | `1` 설정 시 drift 검사 skip (CI/자동화) |
| `HARNESS_REPO_URL` | (default) | 업데이트 대상 GitHub URL override |
| `HARNESS_REPO_API` | (default) | 업데이트 대상 GitHub API URL override |

**중요**: `HARNESS_IDLE_LIMIT`이 wall-clock 타임아웃을 대체합니다. Codex가 깊은 코드 분석/도구 호출로 5-10분씩 작업해도 stdout으로 reasoning 로그가 계속 흐르면 멈추지 않고 끝까지 기다림. 진짜 hang(N초 동안 0 byte도 안 늘어남)일 때만 abort.

### Drift 검사 (자동)

`/harness <task>` 호출 시 Step 0에서 **마스터 (`~/.claude/skills/harness/{core,wrappers}/*.sh`) vs 프로젝트 (`<PROJECT>/.harness/{core,wrappers}/*.sh`)** sha256 해시 비교. 차이 있으면 사용자에게 4지선다:

```
⚠️ N건의 .sh 파일이 마스터와 다릅니다:
   - wrappers/codex-review.sh (modified)
   - core/run-interactive.sh (modified)

[A] 마스터로 최신화 (백업 후 덮어쓰기)        ← 권장
[B] 이번 task만 skip (다음 호출 시 다시 물음)
[C] 영구 무시 (~/.harness/.skip-drift-check 마커)
[D] 작업 취소
```

A 선택 시: `<PROJECT>/.harness/backups/<file>.bak-<ts>` 자동 백업 + 마스터 파일로 교체.

**우회/제어**:
- `HARNESS_SKIP_DRIFT_CHECK=1` env — 자동화/CI용
- `~/.harness/.skip-drift-check` 파일 — 영구 비활성 (옵션 C가 만들기도 함)
- `<PROJECT>/.harness/.skip-drift-this-task` — one-shot skip (옵션 B가 만들고 사용 후 자동 삭제)

수동 검사:
```bash
bash ~/.claude/skills/harness/core/check-drift.sh <PROJECT_DIR>
bash ~/.claude/skills/harness/core/sync-from-master.sh <PROJECT_DIR>  # 동기화
```

### 업데이트 흐름 (`/harness-setup --update`)

설치된 Harness가 GitHub의 main 브랜치보다 오래된 경우:

```
/harness-setup                # → 9/9 통과 + "⬆ 업데이트 가능: 현재 abc1234 → 최신 def5678"
/harness-setup --update       # → 백업 + tarball 다운로드 + 적용 + .version 갱신
```

자동 처리:
- ✅ 업데이트 전 `~/.claude/skills/harness.bak-<timestamp>` 자동 백업 (롤백 가능)
- ✅ 로컬 수정 파일 감지 시 경고 (`.version`보다 새로운 파일 명단)
- ✅ `.version` 갱신 (commit SHA + ISO 타임스탬프)
- ✅ `.doctor-passed` 마커 초기화 → 다음 `/harness-setup`에서 재검진
- ✅ 캐시 무효화 (즉시 새 버전 확인 가능)

GitHub 조회 캐시: `~/.harness/.last-github-check` (1시간 TTL, rate limit 60/hr 방어).

오프라인일 때:
```
/harness-setup --no-version-check    # GitHub 호출 건너뜀
```

### `/harness-review` 사용 예시

전체 Plan→Review 워크플로우(`/harness`)와 별개로, 가벼운 즉석 리뷰가 필요할 때:

```
/harness-review src/auth.ts 보안 위주로
/harness-review 이 두 파일 타입 안전성 평가: src/api.ts src/types.ts
/harness-review --paste TypeScript 코드 한 덩어리 리뷰
/harness-review --mode plan-critique docs/rfc.md 비판적으로
```

- 자연어 + 파일 경로를 자동 분리 (Claude가 파싱)
- 결과는 채팅에 verbatim 출력 + `.harness/reviews/adhoc-<timestamp>.md`에 자동 저장
- `--paste`: 파일 대신 채팅에서 paste 받기
- `--mode plan-critique`: 코드가 아닌 계획서/RFC 등 문서 비판
- 인자 없이 호출하면 사용법만 출력 (의도치 않은 자동 동작 방지)

---

## 📐 워크플로우

```
사용자: /harness <task>
    ↓
Step 0: Init (PROJECT_ROOT, REQUEST_ID, doctor 통과 확인, .harness/ bootstrap)
    ↓
Phase 1: Plan (6 sub-phases)
  1.0 Initial Draft        → plan.md v1
  1.1 Self-Review (10pt)   → checklist 결과
  1.2 Codex Critique 🚨    → MANDATORY 외부 호출
  1.3 User Approval        → 진행 / 수정 / 다시 / 취소
  1.4 Revision (≤3)        → critique·feedback 반영
  1.5 Finalize             → progress.md 초기화
    ↓
Phase 2: Research (선택)    → Gemini 호출, research/research-N.md
    ↓
Phase 3: Implement          → Edit/Write로 직접 구현
    ↓
Phase 4: Review Loop (≤3 iter)
  Codex 리뷰 → LGTM?
    NO + Critical/High → improvement.md → 재구현 → ITER++
    YES               → break
    ↓
Phase 5: Complete           → result.md, plan/progress status=completed
```

산출물 트리:
```
<project>/.harness/
├── plans/plan-<id>.md
├── progress/progress-<id>.md
├── research/research-<id>-NN-<slug>.md
├── reviews/review-<id>-iter-N.md
├── improvements/improvement-<id>-iter-N.md
├── results/result-<id>.md
├── wrappers/       # 마스터에서 첫 호출 시 자동 복제
└── core/           # 마스터에서 첫 호출 시 자동 복제
```

---

## 🪟 Interactive Command Policy

sudo·OAuth 로그인·비밀번호 입력이 필요한 명령은 **반드시 `core/run-interactive.sh` 헬퍼**로 wt.exe 별창에서 실행. Claude Code Bash 도구의 inline 실행은 stdin 입력 불가라 좀비 프로세스 됨.

```bash
bash "$HOME/.claude/skills/harness/core/run-interactive.sh" \
  "🔓 codex login" "codex login"
```

→ 새 Windows Terminal 창에서 명령 실행, 사용자 직접 입력, Enter로 닫기.

---

## 🩺 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `Gemini CLI is not running in a trusted directory` | Gemini 워크스페이스 신뢰 안 됨 | wrapper에 `--skip-trust` 이미 포함됨 |
| `You have exhausted your capacity on this model` | Free tier RPM 소진 | wrapper가 4회 retry 실패 감지 후 exit 3, Claude fallback |
| `you must specify the GEMINI_API_KEY environment variable` | `~/.bashrc`에 키 있으나 wrapper에서 못 찾음 | wrapper가 grep+eval로 interactive-guard 우회 (자동 처리) |
| `API key expired. Please renew the API key` | Google이 노출된 키 자동 회수 | 새 키 발급 → `~/.bashrc` 갱신. **절대 채팅·공개 위치에 키 노출 금지** |
| `This command must run inside a Git repository` (`/codex:review`) | 별개 issue — Codex CLI가 git 강제 요구 | `git init` 후 재시도, 또는 `codex-reviewer` agent 직접 호출 |
| `warning: Codex could not find bubblewrap on PATH ... Codex will use the bundled bubblewrap` | WSL에 bubblewrap 미설치, Codex가 번들 fallback 사용 중 | **무시 가능 (동작·보안 영향 없음)**. 깔끔히 없애려면: `sudo apt install -y bubblewrap` (또는 `bash ~/.claude/skills/harness/core/run-interactive.sh "📦 bubblewrap" "sudo apt install -y bubblewrap"`) |

상세: [skills/harness/docs/setup.md](skills/harness/docs/setup.md)

---

## 📂 디렉토리 구조

```
Harness/
├── README.md                      # 이 문서
├── commands/
│   └── harness-setup.md           # /harness-setup 슬래시 커맨드
└── skills/harness/
    ├── SKILL.md                   # 메인 skill 정의 (워크플로우 명세)
    ├── core/                      # 인프라 스크립트
    │   ├── bootstrap-runtime.sh   # 마스터→프로젝트 복제 + CRLF/+x 보정
    │   ├── harness-doctor.sh      # 9개 prereq 검진 + --fix 옵션
    │   ├── run-interactive.sh     # 별창 실행 헬퍼
    │   └── sync-creds.sh          # 자격 증명 동기화
    ├── wrappers/                  # 외부 CLI 호출 wrapper
    │   ├── codex-review.sh        # Codex critique/review (exit 0/2/3 분기)
    │   ├── gemini-research.sh     # Gemini research (retry-storm watcher + fail-fast)
    │   └── auth-helper.sh         # codex login / gemini /auth 별창
    ├── templates/                 # 산출물 템플릿
    │   ├── plan.md
    │   ├── progress.md
    │   ├── research.md
    │   ├── review.md
    │   ├── improvement.md
    │   └── result.md
    ├── agents/                    # 관련 sub-agent (선택 사용)
    │   ├── codex-reviewer.md
    │   └── gemini-researcher.md
    └── docs/                      # 가이드 문서
        ├── setup.md
        ├── workflow.md
        ├── file-formats.md
        └── examples.md
```

---

## 🤝 기여

- 이슈/PR 환영. wrapper 동작이나 새 환경에서 마주친 트랩 등을 setup.md에 추가하면 다른 사용자에게도 도움됨.
- Mac/Linux 네이티브 지원은 별도 fork 권장 (현재 코드는 WSL `wsl.exe`/`wt.exe` 직접 호출 가정).

---

## 📄 라이선스

MIT — 자유롭게 사용·수정·재배포. 사용자 책임.

---

## 🙏 Credits

- [Claude Code](https://docs.claude.com/claude-code) — 호스트 환경
- [OpenAI Codex CLI](https://github.com/openai/codex) — primary reviewer
- [Google Gemini CLI](https://github.com/google/generative-ai-cli) — research backend
