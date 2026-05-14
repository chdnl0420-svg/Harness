---
description: harness 관련 모든 명령·skill·agent 의 사용법을 한 곳에서 보여주는 도움말. 처음 쓸 때, 잊었을 때, 어떤 명령을 써야 할지 막힐 때 호출.
---

# /harness-help

harness 워크플로우 + 관련 도구 전체 안내. 이 명령은 코드를 건드리지 않고 **읽기만** 한다.

## Usage

```
/harness-help                  # 전체 개요
/harness-help <topic>          # 특정 주제만
```

`<topic>` 예시:
- `setup` / `install` — 설치·검진
- `workflow` / `flow` — `/harness` 전체 phase 흐름
- `agents` — harness-* agent 와 learning protocol
- `commands` — 슬래시 명령 전체 목록
- `wrappers` — codex wrapper 와 환경변수
- `troubleshoot` / `오류` — 자주 나는 에러와 해결
- `files` / `artifacts` — `.harness/` 폴더 구조

---

## 동작

Claude는 이 명령 받으면 **순서대로**:

1. 사용자가 topic 인자를 줬으면 그 섹션만, 안 줬으면 전체 출력.
2. 각 섹션 끝에 "관련 파일" 경로 명시 (사용자가 직접 더 깊이 볼 수 있게).
3. 코드 변경 없음. 마지막에 다음 행동 제안 1줄.

---

## 출력 템플릿

### 📦 Harness 가족 (한눈에)

| 분류 | 이름 | 용도 |
|------|------|------|
| **슬래시 명령** | `/harness` | 본 워크플로우 시작·재개·상태 조회 |
| | `/harness-setup` | 의존성 10개 항목 검진 + 자동 설치 |
| | `/harness-spec` | 프로젝트 사양 (PRD/ARCH/ADR/UI) + 헌법 작성 |
| | `/harness-review` | 즉석 코드/문서 리뷰 (Codex) |
| | `/harness-audit` | 저장소 audit 점수표 |
| | `/harness-distill` | agent learning 파일 압축 |
| | `/harness-help` | 이 도움말 |
| **Skill** | `harness` | `/harness` 명령이 실제로 실행하는 워크플로우 정의 |
| **Agent** | `harness-planner` | step2·step3 plan 작성 (기본 모드는 `plan` skill 로 대체) |
| | `harness-architect` | 시스템 차원 검토 (기본 모드는 `plan` skill 로 대체) |
| | `harness-code-reviewer` | step5 Codex fallback (기본 모드는 `code-review` skill) |
| | `harness-security-reviewer` | 보안 게이트 (기본 모드는 `security-review` skill) |
| | `harness-tdd-guide` | TDD 사이클 안내 (기본 모드는 `tdd` skill) |
| | `harness-build-resolver` | step4 빌드 에러 해결 (기본 모드는 `build-fix` skill) |
| | `codex-reviewer` | 외부 LLM(Codex) 래퍼 호환 agent |
| | **`harness-qa-engineer`** | **step6 QA 테스트 (스크린샷+클릭) — 기본 모드 subagent 유지** |
| | **`harness-customer-user`** | **step7 일반인 시점 테스트 (production 설치본) — 기본 모드 subagent 유지** |

---

### 🚀 처음 쓰는 사람을 위한 5분 가이드

1. **설치 확인**: `/harness-setup` → 10개 항목 ✅ 확인. 누락 항목은 화면 안내대로.
2. **첫 호출**: `/harness <자연어로 무엇을 만들지>` 예) `/harness src/util/discount.js 에 discount(price, percent) 추가, percent 0~100 검증`
3. **단계 진행**: step1 초기화 → step2 도메인 → step3 구현계획 → step4 구현 → step5 리뷰 → step6 QA → step7 customer → step8 commit → complete.
4. **결과 확인**: `<프로젝트>/.harness/results/report-<id>.md` (중학생 가독성 보고서).
5. **재개**: 중간에 멈췄으면 `/harness resume <REQUEST_ID>`.

---

### 🔄 `/harness` 워크플로우 (step 흐름)

```
step1: harness 초기화      — REQUEST_ID 생성, .harness/ 폴더·wrapper 동기화, --noagent 플래그 처리
step2: 도메인 설계         — plan skill 호출 + 메인 Claude 가 직접 리서치(필요 시, 결과는 파일 저장) + Codex 리뷰 + 사용자 승인
step3: 구현 계획           — plan skill 호출 + Codex 리뷰 (사용자 승인 없이 자동)
step4: 구현                — 메인 Claude 가 직접 코드 작성
step5: 리뷰                — Codex 코드 리뷰
                            ├─ LGTM YES → step6
                            └─ LGTM NO → step3 으로 루프 (동일 문제 5회 시 중단)
step6: QA 테스트           — test-guide 작성 + harness-qa-engineer (스크린샷·클릭)
                            ├─ PASS → step7
                            ├─ FAIL → step3 으로 루프
                            └─ BLOCKED → 사용자 결정
step7: 커스터머 유저 테스트 — 전체 워크플로우 중 1회.
                            production 설치본 빌드/설치/실행 후 harness-customer-user 호출
step8: git commit / push   — git remote 있을 때만 (없으면 complete 로 직행)
complete                   — report-<slug>.md 작성
```

**`--noagent` 모드**: subagent 호출 전부 비활성. step6/step7 도 skill 또는 메인 직접. 자세한 흐름은 [workflow.md](~/.claude/skills/harness/docs/workflow.md).

**중단/한계 시**: 어디서 멈췄든 항상 `report-<id>.md` 작성됨.

**관련 파일**: `~/.claude/skills/harness/SKILL.md`, `~/.claude/skills/harness/docs/workflow.md`, `~/.claude/skills/harness/docs/steps/`

---

### 📚 Project Spec Layer (장기 컨텍스트)

매 `/harness` 호출 시 자동으로 참조되는 **장기 사양 문서**.

| 파일 | 용도 |
|------|------|
| `<PROJECT>/CLAUDE.md` | 프로젝트 헌법 (컨벤션·금지·자율 권한) |
| `<PROJECT>/docs/PRD.md` | 뭘 만드는지 (목표·핵심 기능·MVP 제외) |
| `<PROJECT>/docs/ARCHITECTURE.md` | 어떻게 만드는지 (디렉토리·패턴·데이터 흐름) |
| `<PROJECT>/docs/ADR.md` | 왜 이렇게 만드는지 (결정 누적, complete 단계가 자동 append) |
| `<PROJECT>/docs/UI_GUIDE.md` | 어떻게 보여야 하는지 (선택, 비워둬도 OK) |

부트스트랩 시 빈 템플릿 자동 시드. **이미 있는 파일은 보호**.

작성: `/harness-spec init` → `/harness-spec prd` → `/harness-spec architecture` → ...
사양이 채워질수록 plan 정확도 ↑.

**관련 파일**: `~/.claude/skills/harness/templates/doc-*.md`, `project-claude.md`

---

### 🧠 Agent Learning Protocol

각 agent 는 자기 학습 파일을 가지고 점점 똑똑해진다.

- **저장 위치 (하이브리드)**:
  - 공용: `~/.claude/skills/harness/agents/learning/<agent>.md` (모든 프로젝트 공유)
  - 프로젝트: `<PROJECT>/.harness/agents/learning/<agent>.md` (로컬 컨벤션)
- **갱신 방식**: agent 가 응답 끝에 `## Learning Proposals` 출력 → 메인 Claude 가 검증(중복/형식/민감정보/사이즈/모순) 후 반영.
- **로드**: agent 호출 직전 메인 Claude 가 두 파일 머지 후 prompt 앞에 prepend.
- **사이즈 캡**: 800줄. 초과 시 `/harness-distill <agent>` 권고.

**관련 파일**:
- 스키마: `~/.claude/skills/harness/agents/learning/README.md`
- 템플릿: `~/.claude/skills/harness/templates/learning-{file,proposal}.md`

---

### 🛠️ 슬래시 명령 상세

#### `/harness <요청>`
새 워크플로우 시작. 자연어로 무엇을 만들지 적으면 됨.

옵션:
- `/harness --noagent <요청>` — subagent 호출 전부 비활성. skill/메인 Claude 직접으로 워크플로우 진행 (step6/step7 페르소나 가치 잃음 — 토큰 절감 트레이드오프).
- `/harness resume [REQUEST_ID]` — 중단된 작업 재개. id 생략 시 가장 최근.
- `/harness status` — 진행 중 작업 리스트.
- `/harness list` — 모든 작업 (최근 20개).
- `/harness sync` — wrapper 마스터 → 프로젝트 강제 동기화.

#### `/harness-setup`
**언제**: 처음 설치 후 / 의존성 누락 메시지 본 후 / GitHub 업데이트 반영하려고.

**검사 항목**:
1. WSL 환경
2. Windows Terminal (`wt.exe`) — 선택
3. 기본 도구 (`bash`/`git`/`curl`/`stdbuf`)
4. NVM
5. Node ≥ 20
6. Codex CLI (`@openai/codex`)
7. Codex 로그인 (`~/.codex/`)
8. Agent learning 구조 (harness-* agents + learning + templates)

옵션:
- `--fix` — 누락 항목 자동 처리 시도.
- `--update` — GitHub 최신본 재설치.

#### `/harness-spec <subcommand>`
프로젝트 사양 문서 작성·갱신. 매 `/harness` 호출 시 자동 참조됨.

```
/harness-spec                # 5개 파일 상태 보기
/harness-spec init           # 빈 템플릿 5개 시드 (있는 것은 건너뜀)
/harness-spec prd            # PRD 작성 (대화형)
/harness-spec architecture   # ARCHITECTURE 작성 (대화형)
/harness-spec adr add        # 새 ADR entry 추가
/harness-spec adr list       # 기존 ADR 목록
/harness-spec ui             # UI_GUIDE 작성 (선택)
/harness-spec claude         # 프로젝트 CLAUDE.md 작성
```

#### `/harness-review <자연어로 무엇을 리뷰할지>`
plan/code/문서를 Codex 로 즉석 리뷰. `/harness` 워크플로우 안 쓰고 가볍게 의견만 받을 때.

예시:
```
/harness-review src/auth/login.ts 보안 관점에서 검토
/harness-review CHANGELOG.md 최근 항목 표현 다듬어줘
```

결과: `.harness/reviews/review-<timestamp>-<slug>.md`

#### `/harness-audit [scope]`
저장소 health 점수표.

scope: `repo` (기본) / `hooks` / `skills` / `commands` / `agents`
format: `--format text` (기본) / `--format json`

#### `/harness-distill <agent-name> [--project] [--all]`
agent 의 learning 파일 정리·압축.

언제 자동 트리거: 800줄 초과 시 메인 Claude 가 권고.
수동 트리거: 주기적 정리, 노후화된 entry 제거.

**관련 파일**: `~/.claude/commands/harness-{audit,distill,help,review,setup}.md`

---

### 🤖 Agent 역할표

기본 모드: 표의 step 에서 활성화. **단, step2/3/5/8 은 subagent 대신 skill(plan / code-review)·메인 Claude 직접으로 동작** (토큰 절감). step6/step7 은 페르소나 객관성 위해 subagent 유지.

| Agent | step | 모델 | 핵심 책임 | 기본 모드 사용 |
|-------|------|------|----------|---------------|
| `harness-planner` | step2, step3 | opus | 요구사항 → 단계 분해, 리스크 식별 | ❌ (skill `plan` 으로 대체) |
| `harness-architect` | step2, step3 보조 | opus | 시스템 경계·일관성·확장성 | ❌ (skill `plan` 으로 대체) |
| `harness-code-reviewer` | step5 Codex fallback | sonnet | 라인 단위 결함, edge case | ❌ (skill `code-review` 으로 대체) |
| `harness-security-reviewer` | step5 보조 | sonnet | OWASP, secret, 인증·인가 | ❌ (skill `security-review` 으로 대체) |
| `harness-tdd-guide` | step3·step4 (TDD 모드) | sonnet | RED → GREEN → REFACTOR 사이클 | ❌ (skill `tdd` 으로 대체) |
| `harness-build-resolver` | step4 빌드 실패 시 | sonnet | 최소 변경으로 빌드 그린 | ❌ (skill `build-fix` 으로 대체) |
| **`harness-qa-engineer`** | **step6** | sonnet | 사양 일치 QA (스크린샷+클릭) | ✅ **subagent 유지** |
| **`harness-customer-user`** | **step7** | sonnet | 일반인 시점 production 설치본 테스트 | ✅ **subagent 유지** |

**관련 파일**: `~/.claude/skills/harness/agents/harness-*.md`, [workflow.md `기본 모드` 표](~/.claude/skills/harness/docs/workflow.md)

---

### 🪟 환경변수 (wrapper 동작 조정)

| 변수 | 기본 | 설명 |
|------|------|------|
| `HARNESS_NO_VISIBLE` | (off) | wt.exe 별창 비활성 → 인라인 모드 |
| `HARNESS_WAIT_LIMIT` | 600 | Codex 응답 hard timeout (초) |
| `HARNESS_IDLE_LIMIT` | 180 | idle 감지 한도 (초). 0 = 비활성 |
| `HARNESS_TMUX_READY_TIMEOUT` | 30 | tmux 로딩 대기 (초) |
| `HARNESS_LARGE_PROMPT_BYTES` | 10240 | prompt 크기 기반 paste 임계 |
| `HARNESS_SKIP_DRIFT_CHECK` | (off) | drift 검사 영구 비활성 |

**관련 파일**: `~/.claude/skills/harness/wrappers/codex-review.sh` (line 150 부근 변수 선언)

---

### 📂 `.harness/` 폴더 구조

워크플로우 1회당 생성되는 산출물:

```
<PROJECT>/.harness/
├── .noagent                         — --noagent 플래그 상태 (있으면 모드 ON)
├── domain-<slug>.md                  — step2 도메인 설계
├── implementation-<slug>.md          — step3 구현 계획
├── test-guide-<slug>.md              — step6/step7 공용 테스트 가이드
├── research/research-<slug>-NN-*.md  — 메인 Claude 가 직접 수행한 리서치 결과 (선택)
├── reviews/review-<slug>.md          — step5 Codex 리뷰 (누적)
├── results/qa-<slug>.md              — step6 QA 보고서
├── results/customer-<slug>.md        — step7 커스터머 테스트 보고서
├── results/report-<slug>.md          — complete 사람 가독 보고서
├── progress/progress-<slug>.md       — 실시간 상태
├── wrappers/                         — 마스터에서 부트스트랩
├── core/                             — 마스터에서 부트스트랩
├── agents/learning/                  — 프로젝트 학습 데이터 (gitignore 권장)
└── backups/                          — drift sync 시 백업
```

`slug` 는 사용자 요청에서 메인 Claude 가 도출 (예: `jwt-middleware`).

---

### 🚑 자주 나는 오류

| 증상 | 원인 | 해결 |
|------|------|------|
| `Codex 로그인 필요` | Codex CLI 인증 만료 | wt.exe 별창에서 `codex login` 완료 후 메인 채팅에 "완료" |
| `Codex quota 소진 (exit 3)` | ChatGPT Plus 한도 도달 | Claude self critique 로 자동 fallback. 그대로 진행됨 |
| `Codex CLI 내부 에러 (exit 4)` | codex_core::tools::router stdin closed | `npm i -g @openai/codex@latest` 후 재시도 |
| `Argument list too long` | code review prompt 가 ARG_MAX 초과 | `--prompt-file` 패턴 사용 (step5 Codex 리뷰 호출 시) |
| Worktree 에서 `git init` 시도 | 옛 버전 wrapper | `/harness-setup --update` 로 최신 wrapper 받기 |
| `harness-* agent not found` | Claude Code 세션 시작 후 추가된 agent | Claude Code 재시작. registry 는 시작 시만 스캔 |
| Drift 4건 감지 | 마스터 wrapper 가 갱신됨 | `/harness sync` 또는 다음 `/harness` 호출 시 A 선택 |

---

### 🔗 추가 자료 경로

- 본문 정의: `~/.claude/skills/harness/SKILL.md`
- README (GitHub): https://github.com/chdnl0420-svg/Harness
- 도구 동작 상세: `~/.claude/skills/harness/docs/{setup,workflow,file-formats,examples}.md`

---

## 마무리 1줄

도움말 끝에 다음 행동 1줄 제안:
- 처음이면: "👉 `/harness-setup` 으로 10개 항목 확인부터 시작하세요."
- 설치 끝났으면: "👉 `/harness <만들고 싶은 것>` 한 줄로 시작."
- 막혔으면: "👉 `/harness-help troubleshoot` 으로 자주 나는 오류 보세요."
