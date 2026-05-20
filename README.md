# Harness — Step-Based Multi-Agent Development Workflow for Claude Code

> Claude · Codex 를 **하나의 워크플로우**로 묶어 도메인 설계·구현·리뷰·QA·커스터머 테스트를 자동화하는 Claude Code skill.

`/harness <task>` 한 번 호출로 **step1 (초기화) → step2 (도메인) → step3 (구현 계획) → step4 (구현) → step5 (Codex 리뷰) → step6 (QA) → step7 (커스터머 테스트, production 설치본) → step8 (commit) → complete** 전 과정을 진행하고, 모든 산출물을 `<project>/.harness/` 아래 HTML/MD 로 보존합니다.

---

## ✨ 무엇이 다른가

- **Step 기반 워크플로우**: step1~complete 까지 step 자체 규칙(워크플로우 다이어그램의 조건 분기)에 의한 것이 아니면 **어떤 step 도 스킵·통합·무시 금지**. 실수로 빠지는 단계 없음.
- **Master-only 슬림 구조** *(2026-05-20)*: 마스터 (`~/.claude/skills/harness/`) 가 단일 진실 원천. 프로젝트 측에는 산출물 (HTML/MD) 만 남는다. wrapper 코드 복사·drift sync 모두 폐기.
- **모든 단위가 Skill 도구로 통합** *(2026-05-20)*: 옛 `harness-*` 서브에이전트 6개 (planner/architect/code-reviewer/security-reviewer/tdd-guide/build-resolver) 는 일반 skill (`plan`, `code-review`, `security-review`, `tdd`, `build-fix`, `architect`, `code-reviewer`) 로 대체. 페르소나 가치가 큰 3개만 subagent 유지 — `harness-qa-engineer`, `harness-customer-user`, `harness-deep-researcher`.
- **Plan-first**: step2 에서 `harness-plan` skill (noask) 또는 `harness-plan-ask` (인터랙티브) 로 도메인 설계 → Codex critique → 자동/명시 승인.
- **Codex 가 코드 리뷰**: step5 에서 Codex 가 LGTM/이슈 분석. LGTM:NO 면 **반드시 step3 (구현 계획 수정) 로 되돌아감**.
- **QA + 일반인 시점 검증 2단**: step6 `harness-qa-engineer` 가 사양 일치 QA → step7 `harness-customer-user` 가 **실제 production 설치본** 으로 일반인 시점 테스트.
- **`--noagent` 옵션 폐기**: 모든 단위가 skill 로 통합되어 별도 컨텍스트가 사라졌으므로 더 이상 의미 없음. `/harness` 가 곧 통합 모드, 사용자 결정 분기는 `/harness-ask` 사용.
- **리서치는 메인 Claude 직접 또는 `harness-deep-researcher` subagent**: 결과는 `.harness/research/research-<NN>.html` 로 저장.
- **모든 산출물 영구 보존**: `.harness/` 아래. 분류별 HTML/MD 분기 (자세히는 SKILL.md 상단 4규칙).
- **fail-fast 정책**: Codex 인증 실패(exit 2) → 즉시 중단 + 로그인 안내. Quota 소진(exit 3) → `code-review` skill fallback.

---

## 📋 Prereq (Windows native — WSL 불필요)

`/harness-setup` 한 번으로 자동 검진 + npm 패키지 설치:

| # | 항목 | 필수/선택 | 자동 설치? |
|---|------|----------|----------|
| 1 | Claude Code (PowerShell 또는 Bash tool 사용 가능) | 필수 | — |
| 2 | Node ≥ 20 | 필수 | 가이드 (winget / nodejs.org) |
| 3 | Codex CLI (`@openai/codex`) | 필수 | ✅ 자동 (npm) |
| 4 | Codex 로그인 | 필수 | 가이드 (interactive — `codex login`) |
| 5 | Bash (Claude Code Bash tool 또는 Git Bash) — `core/bootstrap-runtime.sh` 실행용 | 필수 | Git for Windows 설치 시 자동 포함 |
| 6 | 페르소나 agent 3개 (`harness-qa-engineer`, `harness-customer-user`, `harness-deep-researcher`) 가 `~/.claude/agents/` 에 등록되어 있는지 | 필수 | ✅ bootstrap-runtime.sh 가 자동 등록 |

> **WSL / wt.exe / tmux 의존성은 2026-05-20 폐기되었습니다.** 모든 외부 CLI 호출은 `codex exec` 단순 호출 패턴으로 통일. macOS/Linux 네이티브도 동작 가능 (Bash 만 있으면 됨).

---

## 🚀 설치

세 가지 방법 중 환경에 맞는 것 선택. **방법 1(PowerShell)** 이 가장 간단합니다.

### 방법 1: PowerShell 한 줄 (⭐ 추천)

PowerShell 열고 그대로 붙여넣기:

```powershell
$ErrorActionPreference = "Stop"
$url = "https://github.com/chdnl0420-svg/Harness/archive/refs/heads/main.zip"
$tmp = "$env:TEMP\harness-install-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
$zip = "$tmp.zip"
$claude = "$env:USERPROFILE\.claude"

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
1. Claude Code 재시작 (skill·command·agent 등록 새로고침)
2. Claude Code 에서 `/harness-setup` → prereq 검진. Codex 미설치/미로그인 항목은 화면 안내대로 처리.

**필요 조건**: PowerShell 5.0+ (Windows 10/11 기본 포함) + 인터넷. git 없어도 됨.

### 방법 2: Git Bash / Bash (macOS/Linux/Windows 공통)

Git Bash 또는 임의 Bash 환경에서:

```bash
git clone https://github.com/chdnl0420-svg/Harness.git /tmp/h && \
CLAUDE_HOME="${USERPROFILE:-$HOME}/.claude" && \
CLAUDE_HOME=$(echo "$CLAUDE_HOME" | sed 's|\\|/|g') && \
mkdir -p "$CLAUDE_HOME/skills" "$CLAUDE_HOME/commands" && \
cp -r /tmp/h/skills/harness "$CLAUDE_HOME/skills/" && \
cp /tmp/h/commands/harness-*.md "$CLAUDE_HOME/commands/" 2>/dev/null && \
SHA=$(git -C /tmp/h rev-parse HEAD) && \
printf 'commit: %s\ninstalled: %s\nsource: https://github.com/chdnl0420-svg/Harness\nbranch: main\n' \
   "$SHA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$CLAUDE_HOME/skills/harness/.version" && \
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

1. **Claude Code 재시작** (skill 목록 갱신).
2. **Claude Code 에서**:
   ```
   /harness-setup
   ```
   → 모든 항목 ✅ 통과해야 사용 가능. 누락 항목(Codex 로그인 등)은 화면 안내대로 처리.

---

## 🎯 사용법

### 새 워크플로우 시작
```
/harness <자연어 요청>          # noask 기본 — 질문 없이 자동 진행
/harness-ask <자연어 요청>      # 결정 지점에서 AskUserQuestion 활성 (인터랙티브)
```

예시:
- `/harness "OWASP 2025 권장값으로 Argon2id 패스워드 해시 함수 추가"`
- `/harness-ask "src/util/discount.js 에 discount(price, percent) 추가"`

### 명령 목록

| 명령 | 동작 |
|------|------|
| `/harness` | 메인 워크플로우 (noask 기본) |
| `/harness-ask` | 메인 워크플로우 (인터랙티브 — 결정 지점에서 사용자 질의) |
| `/harness-setup` | 의존성 검진 + npm 자동 설치 + GitHub 버전 확인 |
| `/harness-setup --update` | GitHub 최신으로 즉시 업데이트 |
| `/harness-review` | Codex CLI 로 즉석 리뷰 (file-list 작성 → codex exec → 결과 확인) |
| `/harness-spec` | 프로젝트 사양 문서 (PRD/ARCHITECTURE/ADR/UI_GUIDE) + CLAUDE.md 작성 |
| `/harness-audit` | repo health 점수표 |
| `/harness-distill` | agent learning 파일 정리·압축 |
| `/harness-help` | 전체 도움말 (워크플로우, agent, 폴더 구조 등) |
| `/harness-customer-user` | 일반인 시점 production 설치본 테스트 (subagent) |
| `/harness-deep-researcher` | 외부 출처 다중검증 deep research (subagent) |

### 페르소나 subagent 단독 호출

`/harness` 워크플로우 외에도 다음 3개는 Skill 도구·슬래시 커맨드로 단독 호출 가능:

- `harness-qa-engineer` — 사양 일치 QA (스크린샷 + 클릭)
- `harness-customer-user` — production 설치본 일반인 시점 테스트
- `harness-deep-researcher` — 외부 출처 다중검증 deep research (항상 deep tier)

---

## 📐 워크플로우

```
사용자: /harness <task>   (또는 /harness-ask)
    ↓
step1: harness 초기화
       (REQUEST_ID, .harness/ 폴더, 페르소나 agent 등록)
    ↓
step2: 도메인 설계 (harness-plan / harness-plan-ask skill + 외부 리서치 + Codex 리뷰)
       산출물: domain-<slug>.html
    ↓
step3: 구현 계획 (plan skill + Codex 리뷰)
       산출물: implementation-<slug>.html
       [Chunks 모드 자동 판정 — 큰 작업은 vertical slice 로 분해]
    ↓
step4: 구현 (메인 Claude 직접 코드 작성)
       산출물: 프로젝트 코드 + progress 기록
    ↓
step5: 리뷰 (Codex CLI; 인증/quota 실패 시 code-review skill fallback)
       산출물: reviews/review-<slug>.md (누적)
       ├─ LGTM YES → step6
       └─ LGTM NO → step3 으로 루프 (동일 문제 5회 시 중단)
    ↓
step6: QA 테스트 (test-guide 작성 + harness-qa-engineer 스크린샷·클릭)
       산출물: test-guide-<slug>.md, results/qa-<slug>.md
       ├─ PASS → step7 (last chunk 인 경우)
       ├─ FAIL → step3 으로 루프
       └─ BLOCKED → 자동 결정 분기 (재시도 → paused-by-blocked / 중단)
    ↓
step7: 커스터머 유저 테스트 (production 설치본 빌드/설치/실행 후
                          harness-customer-user 가 일반인 시점 테스트)
       산출물: results/customer-<slug>.md
    ↓
step8: git commit / push (git remote 있을 때만; 없으면 complete 로 직행)
    ↓
complete: results/report-<slug>.html (사람 가독 종합 보고서) + ADR append
```

### 산출물 트리

```
<project>/.harness/
├── domain-<slug>.html                  # step2 도메인 설계 (HTML, 탭 + 1뷰포트)
├── implementation-<slug>.html          # step3 구현 계획 (HTML, 탭 + 1뷰포트)
├── test-guide-<slug>.md                # step6/step7 공용 테스트 가이드
├── research/research-<NN>.html         # deep-researcher 또는 메인 Claude 직접 리서치
├── reviews/review-<slug>.md            # step5 Codex 리뷰 (누적)
├── results/qa-<slug>.md                # step6 QA 보고서
├── results/customer-<slug>.md          # step7 커스터머 테스트 보고서
├── results/report-<slug>.html          # complete 종합 보고서 (HTML, 탭 + 1뷰포트)
└── progress/progress-<slug>.md         # 실시간 상태
```

> **산출물 분류 규칙** (SKILL.md §산출물 형식 규칙 + `~/.claude/CLAUDE.md` §6 참조):
> - **HTML** (단일 파일 + 탭 + 1뷰포트 + 첫 탭=요약): `domain-` / `implementation-` / `report-` — 사람이 작업 전/후 *읽고 결정* 하는 풍부한 시각 문서
> - **MD**: `progress-` / `research-` (선택) / `review-` / `qa-` / `customer-` / `test-guide-` — 운영 로그·중간 결과·기계 가이드 성격

---

## 🧱 폴더 생성 규칙 (구현 시)

step4 구현 단계에서 새 폴더를 만들 때:
- **root 폴더에 파일을 직접 만들지 않는다.** 폴더를 먼저 만들고 그 안에 파일을 넣는다.

---

## 🩺 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| Codex 로그인 필요 | Codex CLI 인증 만료 | 터미널에서 `codex login` 완료 후 메인 채팅에 "완료" |
| Codex quota 소진 (exit 3) | ChatGPT Plus 한도 도달 | `code-review` skill 또는 Claude self critique 로 자동 fallback. 그대로 진행됨 |
| `codex_core::tools::router: error=write_stdin failed` (exit 4) | Codex CLI 버그 — tool router 가 닫힌 subprocess stdin 에 write | `npm i -g @openai/codex@latest` 후 재시도 |
| `Argument list too long` | code review prompt 가 ARG_MAX 초과 | `--prompt-file` 패턴 사용 (step5 Codex 리뷰 호출 시) |
| `This command must run inside a Git repository` | Codex CLI 가 git 강제 요구 | 워크플로우가 자동 `git init -q -b main` 수행. 안내 메시지 출력 |
| `harness-* agent not found` | Claude Code 세션 시작 후 추가된 agent | Claude Code 재시작. agent registry 는 시작 시만 스캔 |

상세: [skills/harness/docs/setup.md](skills/harness/docs/setup.md)

---

## 📂 디렉토리 구조

```
Harness/
├── README.md                      # 이 문서
├── LICENSE
├── commands/
│   ├── harness-ask.md             # /harness-ask (인터랙티브)
│   ├── harness-audit.md           # /harness-audit
│   ├── harness-customer-user.md   # /harness-customer-user (subagent 호출)
│   ├── harness-deep-researcher.md # /harness-deep-researcher (subagent 호출)
│   ├── harness-distill.md         # /harness-distill
│   ├── harness-help.md            # /harness-help
│   ├── harness-review.md          # /harness-review (Codex 즉석 리뷰)
│   ├── harness-setup.md           # /harness-setup
│   └── harness-spec.md            # /harness-spec
└── skills/harness/
    ├── SKILL.md                   # 메인 skill 정의 (워크플로우 명세 + CRITICAL 규칙)
    ├── core/
    │   └── bootstrap-runtime.sh   # 프로젝트 .harness/ 폴더 초기화 + 페르소나 agent 등록 (단 1개)
    ├── templates/                 # 산출물 템플릿 (plan, result, review, progress, project-claude 등)
    ├── agents/                    # 페르소나 3개 (qa-engineer / customer-user / deep-researcher)
    │   │                          # + codex-reviewer (Codex 호출 정의)
    │   └── learning/              # 페르소나 공용 학습 데이터 (마스터 단일 원천)
    └── docs/
        ├── workflow.md            # 전체 흐름 + CRITICAL Step 스킵 금지
        ├── steps/                 # step1 ~ step8 + complete 각 단계 상세
        ├── procedures/            # codex-review-procedure / customer-test-procedure / deep-research-procedure
        ├── test-guide-format.md   # step6/step7 테스트 가이드 양식
        ├── html-output-rule.md    # HTML 산출물 UI 룰 (CLAUDE.md §6 ↔ harness 정합)
        ├── setup.md               # 설치·환경 상세 (Windows native, WSL 불필요)
        └── ...
```

---

## 🤝 기여

- 이슈/PR 환영.
- WSL 의존성을 폐기하면서 macOS/Linux 네이티브도 동작 가능해졌습니다 (Bash + Node + Codex CLI 만 있으면 됨). 환경별 트랩을 발견하면 `docs/setup.md` 에 추가해주세요.

---

## 📄 라이선스

MIT — 자유롭게 사용·수정·재배포. 사용자 책임.

---

## 🙏 Credits

- [Claude Code](https://docs.claude.com/claude-code) — 호스트 환경
- [OpenAI Codex CLI](https://github.com/openai/codex) — primary reviewer
