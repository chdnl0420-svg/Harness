---
description: harness 관련 모든 명령·skill·agent 의 사용법을 한 곳에서 보여주는 도움말. 처음 쓸 때, 잊었을 때, 어떤 명령을 써야 할지 막힐 때 호출.
---

# /harness-help

harness 워크플로우 + 관련 도구 전체 안내. 이 명령은 코드를 건드리지 않고 **읽기만** 한다.

> **2026-05-20 정합화**: master-only 구조로 슬림화. `--noagent` 옵션·`harness-sync` 명령·WSL/tmux/wt.exe 의존성 모두 폐기. 모든 단위가 Skill 도구로 통합되었고, 페르소나 가치가 큰 3개 (`harness-qa-engineer`, `harness-customer-user`, `harness-deep-researcher`) 만 subagent 유지.

## Usage

```
/harness-help                  # 전체 개요
/harness-help <topic>          # 특정 주제만
```

`<topic>` 예시:
- `setup` / `install` — 설치·검진
- `workflow` / `flow` — `/harness` 전체 step 흐름
- `agents` — 페르소나 subagent 와 learning protocol
- `commands` — 슬래시 명령 전체 목록
- `troubleshoot` / `오류` — 자주 나는 에러와 해결
- `files` / `artifacts` — `.harness/` 폴더 구조

---

## 동작

Claude 는 이 명령을 받으면 **순서대로**:

1. 사용자가 topic 인자를 줬으면 그 섹션만, 안 줬으면 전체 출력.
2. 각 섹션 끝에 "관련 파일" 경로 명시.
3. 코드 변경 없음. 마지막에 다음 행동 제안 1줄.

---

## 출력 템플릿

### 📦 Harness 가족 (한눈에)

| 분류 | 이름 | 용도 |
|------|------|------|
| **슬래시 명령** | `/harness` | 본 워크플로우 시작 (noask 기본) |
| | `/harness-ask` | 본 워크플로우 (인터랙티브 — 결정 지점에서 질의) |
| | `/harness-resume <slug>` | 진행 중 워크플로우 재개 — progress-<slug>.md 의 마지막 step 식별 후 그 다음부터 자동 진입 |
| | `/harness-setup` | 의존성 검진 + Codex CLI 자동 설치 + GitHub 버전 확인 |
| | `/harness-spec` | 프로젝트 사양 (PRD/ARCH/ADR/UI) + 헌법 작성 |
| | `/harness-review` | 즉석 코드/문서 리뷰 (Codex 직접 호출) |
| | `/harness-audit` | 저장소 audit 점수표 |
| | `/harness-distill` | agent learning 파일 압축 |
| | `/harness-help` | 이 도움말 |
| | `/harness-customer-user` | 일반인 시점 production 설치본 테스트 (subagent 단독 호출) |
| | `/harness-deep-researcher` | 외부 출처 다중검증 deep research (subagent 단독 호출, 항상 deep tier) |
| **Skill** | `harness` | `/harness` 가 실행하는 워크플로우 정의 |
| | `harness-plan` | step2 도메인 plan (noask) |
| | `harness-plan-ask` | step2 도메인 plan (인터랙티브) |
| | `harness-review` | step5 Codex 리뷰 wrapper |
| | `harness-customer-user` | step7 wrapper |
| | `harness-deep-researcher` | 외부 리서치 wrapper |
| **Subagent** | **`harness-qa-engineer`** | **step6 QA (스크린샷+클릭)** |
| | **`harness-customer-user`** | **step7 일반인 시점 production 테스트** |
| | **`harness-deep-researcher`** | **외부 출처 다중검증 deep research** |
| | `codex-reviewer` | Codex 호출 정의 agent (subagent 라기보다 호출 명세) |

---

### 🚀 처음 쓰는 사람을 위한 5분 가이드

1. **설치 확인**: `/harness-setup` → 항목 ✅ 확인. 누락 항목은 화면 안내대로.
2. **첫 호출**: `/harness <자연어로 무엇을 만들지>` 예) `/harness src/util/discount.js 에 discount(price, percent) 추가, percent 0~100 검증`
3. **단계 진행**: step1 초기화 → step2 도메인 → step3 구현계획 → step4 구현 → step5 리뷰 → step6 QA → step7 customer → step8 commit → complete.
4. **결과 확인**: `<프로젝트>/.harness/results/report-<slug>.html` (종합 보고서).

---

### 🔄 `/harness` 워크플로우 (step 흐름)

```
step1: harness 초기화      — REQUEST_ID 생성, .harness/ 폴더 부트스트랩, 페르소나 agent 등록
step2: 도메인 설계         — harness-plan(-ask) skill + 외부 리서치(필요 시) + Codex 리뷰
                            산출물: domain-<slug>.html
step3: 구현 계획           — plan skill + Codex 리뷰. Chunks 모드 자동 판정
                            산출물: implementation-<slug>.html
step4: 구현                — 메인 Claude 가 직접 코드 작성
step5: 리뷰                — Codex 직접 호출 (인증/quota 실패 시 code-review skill fallback)
                            ├─ LGTM YES → step6
                            └─ LGTM NO → step3 으로 루프 (동일 문제 5회 시 중단)
step6: QA 테스트           — test-guide 작성 + harness-qa-engineer (스크린샷·클릭)
                            ├─ PASS → step7 (last chunk 인 경우)
                            ├─ FAIL → step3 으로 루프
                            └─ BLOCKED → 자동 결정 (재시도 → paused-by-blocked / 중단)
step7: 커스터머 유저 테스트 — production 설치본 빌드/설치/실행 후 harness-customer-user 호출
step8: git commit / push   — git remote 있을 때만 (없으면 complete 로 직행)
complete                   — report-<slug>.html (종합 보고서) + ADR append
```

**중단/한계 시**: 어디서 멈췄든 항상 `report-<slug>.html` 작성됨.

**관련 파일**: `~/.claude/skills/harness/skills/harness/SKILL.md`, `~/.claude/skills/harness/skills/harness/docs/workflow.md`, `~/.claude/skills/harness/skills/harness/docs/steps/`

---

### 📚 Project Spec Layer (장기 컨텍스트)

매 `/harness` 호출 시 자동으로 참조되는 **장기 사양 문서**.

| 파일 | 용도 |
|------|------|
| `<PROJECT>/CLAUDE.md` | 프로젝트 헌법 (컨벤션·금지·자율 권한) |
| `<PROJECT>/docs/PRD.md` | 뭘 만드는지 (목표·핵심 기능·MVP 제외) |
| `<PROJECT>/docs/ARCHITECTURE.md` | 어떻게 만드는지 (디렉토리·패턴·데이터 흐름) |
| `<PROJECT>/docs/ADR.md` | 왜 이렇게 만드는지 (결정 누적, complete 단계가 자동 append) |
| `<PROJECT>/docs/UI_GUIDE.md` | 어떻게 보여야 하는지 (선택) |

부트스트랩 시 빈 템플릿 자동 시드. **이미 있는 파일은 보호**.

작성: `/harness-spec init` → `/harness-spec prd` → `/harness-spec architecture` → ...

**관련 파일**: `~/.claude/skills/harness/skills/harness/templates/doc-*.md`, `project-claude.md`

---

### 🧠 Agent Learning Protocol (페르소나 3개 공용)

페르소나 subagent 3개가 누적 학습 — 매 호출 시 메인 Claude 가 공용 학습파일을 prompt 앞에 prepend.

- **저장 위치 (마스터 단일 원천 — 2026-05-20)**: `~/.claude/skills/harness/skills/harness/agents/learning/<agent>.md`
- **갱신 방식**: agent 가 응답 끝에 `## Learning Proposals` 출력 → 메인 Claude 가 검증(중복/형식/민감정보/사이즈/모순) 후 반영.
- **로드**: 메인 Claude 가 페르소나 호출 직전 공용 파일 Read 해 prompt 앞에 prepend. 파일 비어있으면 본문에 `(빈 파일)` 명시.
- **사이즈 캡**: 800줄. 초과 시 `/harness-distill <agent>` 권고.

**적용 범위**: `harness-qa-engineer`, `harness-customer-user`, `harness-deep-researcher` 만. 일반 skill (plan/code-review/security-review/tdd/build-fix 등) 은 별도 learning 없음.

**관련 파일**:
- 스키마: `~/.claude/skills/harness/skills/harness/agents/learning/README.md`
- 템플릿: `~/.claude/skills/harness/skills/harness/templates/learning-proposal.md`

---

### 🛠️ 슬래시 명령 상세

#### `/harness <요청>`
새 워크플로우 시작 (noask 기본). 자연어로 무엇을 만들지 적으면 됨.

- 자동 결정 분기는 `SKILL.md` 의 자동 결정 매핑 표 참고.
- 결정 지점에서 사용자 확인을 받고 싶으면 `/harness-ask` 사용.

#### `/harness-ask <요청>`
`/harness` 의 인터랙티브 변형. `AskUserQuestion` 도구 호출이 허용됨.

#### `/harness-resume <slug>`
중단·일시정지된 워크플로우 재개. 새 progress 를 만들지 않고 기존 `progress-<slug>.md` 의 마지막 도달 step 을 식별해 *그 다음 단계부터* SKILL.md 절차 재진입.

- **인자**: slug 1개 (자연어 아님)
- **모드 보존**: progress 의 `모드:` 필드 (`noask` / `ask`) 기준 마커 복원
- **Loop Counter 보존**: step5 LGTM:NO / step6 FAIL / step6 BLOCKED 누적 그대로 이어짐
- **chunks 무결성**: 마지막 PASS chunk 까지 commit 검증 (미commit 시 재시도)
- **차단 조건**: report 이미 존재 / progress 없음 / resume 5회 누적 → 안내 후 종료

예시: 어제 step6 BLOCKED 로 멈춘 `jwt-middleware` 재개:
```
/harness-resume jwt-middleware
```

**관련 파일**: `~/.claude/commands/harness-resume.md`, `~/.claude/skills/harness/SKILL.md` (입력 게이트가 본 명령도 진입 경로로 인정)

#### `/harness-setup [--update | --no-version-check]`
**언제**: 처음 설치 후 / 의존성 누락 메시지 본 후 / GitHub 업데이트 반영하려고.

**검사 항목**:
1. Node ≥ 20
2. Codex CLI (`@openai/codex`)
3. Codex 로그인 (`~/.codex/auth.json`)
4. 페르소나 agent 3개 (`~/.claude/agents/harness-{qa-engineer,customer-user,deep-researcher}.md`)
5. Master skill 폴더 + agents/learning/
6. GitHub 버전 비교

옵션:
- `--update` — GitHub 최신본 재설치 (force).
- `--no-version-check` — GitHub 호출 skip (오프라인용).

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
/harness-review --mode plan-critique docs/rfc-001.md 비판적으로
```

결과: `.harness/reviews/adhoc-<timestamp>.md`

#### `/harness-audit [scope]`
저장소 health 점수표.

scope: `repo` (기본) / `hooks` / `skills` / `commands` / `agents`
format: `--format text` (기본) / `--format json`

#### `/harness-distill <agent-name> [--all]`
agent 의 learning 파일 정리·압축.

- 자동 트리거: 800줄 초과 시 메인 Claude 가 권고.
- 수동 트리거: 주기적 정리, 노후화된 entry 제거.
- 대상은 페르소나 3개 만.

#### `/harness-customer-user <자연어>`
`harness-customer-user` subagent 단독 호출. `/harness` step7 외에도 독립 사용 가능.

#### `/harness-deep-researcher <자연어 주제>`
`harness-deep-researcher` subagent 단독 호출. 외부 출처 다중검증 deep research (항상 deep tier).

**관련 파일**: `~/.claude/commands/harness-{ask,audit,customer-user,deep-researcher,distill,help,review,setup,spec}.md`

---

### 🤖 Subagent 역할표

페르소나 가치 (객관성·도메인 전문성) 때문에 *반드시* subagent 로 유지하는 3개.

| Subagent | 호출 시점 | 모델 | 핵심 책임 |
|----------|----------|------|----------|
| **`harness-qa-engineer`** | step6 | sonnet | 사양 일치 QA (스크린샷+클릭) — 메인 Claude self-PASS 편향 회피 |
| **`harness-customer-user`** | step7 | sonnet | 일반인 시점 production 설치본 테스트 — 제품 전문 용어 미인지 페르소나 |
| **`harness-deep-researcher`** | step2 Phase 2 / step3 외부 리서치 / 단독 호출 | opus (deep tier 강제) | Plan-Act-Verify 루프, 다중 출처 교차검증, 환각 차단 4규칙 |

**옛 6개 agent 는 폐기됨** (2026-05-20):
- `harness-planner` → `plan` skill
- `harness-architect` → `plan` skill
- `harness-code-reviewer` → `code-review` skill (step5 Codex fallback)
- `harness-security-reviewer` → `security-review` skill
- `harness-tdd-guide` → `tdd` skill
- `harness-build-resolver` → `build-fix` skill

**관련 파일**: `~/.claude/skills/harness/skills/harness/agents/harness-*.md`, [workflow.md](~/.claude/skills/harness/skills/harness/docs/workflow.md)

---

### 📂 `.harness/` 폴더 구조

워크플로우 1회당 생성되는 산출물:

```
<PROJECT>/.harness/
├── domain-<slug>.html              — step2 도메인 설계 (HTML, 탭+1뷰포트)
├── implementation-<slug>.html      — step3 구현 계획 (HTML, 탭+1뷰포트)
├── test-guide-<slug>.md            — step6/step7 공용 테스트 가이드
├── research/research-<NN>.html     — deep-researcher 또는 메인 Claude 직접 리서치
├── reviews/review-<slug>.md        — step5 Codex 리뷰 (누적)
├── reviews/adhoc-<ts>.md           — /harness-review 즉석 리뷰
├── results/qa-<slug>.md            — step6 QA 보고서
├── results/customer-<slug>.md      — step7 커스터머 테스트 보고서
├── results/report-<slug>.html      — complete 종합 보고서 (HTML)
└── progress/progress-<slug>.md     — 실시간 상태 + 자동 결정 로그
```

`slug` 는 사용자 요청에서 메인 Claude 가 도출 (예: `jwt-middleware`).

> **2026-05-20 master-only 구조**: 프로젝트 측 `wrappers/`, `core/`, `backups/`, `agents/learning/`, `.noagent` 모두 폐기. 마스터 (`~/.claude/skills/harness/`) 가 단일 진실 원천. 프로젝트엔 산출물만.

**산출물 분류 (HTML vs MD)**: `SKILL.md` 상단 4규칙 참고.
- HTML: `domain-`, `implementation-`, `report-` (사람이 읽고 결정하는 풍부한 시각 문서)
- MD: `progress-`, `research-` (선택), `review-`, `qa-`, `customer-`, `test-guide-`

---

### 🚑 자주 나는 오류

| 증상 | 원인 | 해결 |
|------|------|------|
| `Codex 로그인 필요` (exit 2) | Codex CLI 인증 만료 | 터미널에서 `codex login` 완료 후 메인 채팅에 "완료" |
| `Codex quota 소진` (exit 3) | ChatGPT Plus 한도 도달 | `code-review` skill / Claude self critique 로 자동 fallback. 그대로 진행됨 |
| `Codex CLI 내부 에러` (exit 4) | codex_core::tools::router stdin closed | `npm i -g @openai/codex@latest` 후 재시도 |
| `Argument list too long` | 큰 prompt 가 ARG_MAX 초과 | file-list MD + `codex exec` 짧은 프롬프트 패턴 사용 (`agents/codex-reviewer.md`) |
| `harness-* agent not found` | Claude Code 세션 시작 후 추가된 agent | Claude Code 재시작. agent registry 는 시작 시만 스캔 |
| Worktree 에서 `git init` 시도 | 옛 wrapper 잔재 | `/harness-setup --update` 로 최신본 받기 |

---

### 🔗 추가 자료 경로

- 본문 정의: `~/.claude/skills/harness/skills/harness/SKILL.md`
- README (GitHub): https://github.com/chdnl0420-svg/Harness
- 도구 동작 상세: `~/.claude/skills/harness/skills/harness/docs/{setup,workflow,file-formats,examples}.md`
- step 별 상세: `~/.claude/skills/harness/skills/harness/docs/steps/`

---

## 마무리 1줄

도움말 끝에 다음 행동 1줄 제안:
- 처음이면: "👉 `/harness-setup` 으로 검진부터 시작하세요."
- 설치 끝났으면: "👉 `/harness <만들고 싶은 것>` 한 줄로 시작."
- 막혔으면: "👉 `/harness-help troubleshoot` 으로 자주 나는 오류 보세요."
