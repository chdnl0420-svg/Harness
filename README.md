# Harness

Claude Code 안에서 *한 줄 목표* 를 *production 검증된 commit/push* 까지 자동으로 끌고 가는 워크플로우 skill.

```
/harness <자연어로 만들 것>
  └─ step1 init → step2 도메인 → step3 구현계획 → step4 구현 → step5 리뷰 →
     step6 QA → step7 일반인 테스트 → step8 commit → complete (report-<slug>.html)
```

기본은 **사용자 질문 없이 (noask) 끝까지 자동 진행**. 결정 분기마다 합리적 기본값을 자동 선택하고 사유를 `progress-<slug>.md` 에 로깅한다. 사용자 결정이 필요한 *유일한 2 곳* 외에는 묻지 않는다.

---

## 빠른 시작

```
# 1. install (한 번)
/harness-setup
  → ~/.claude/skills/harness/ 마스터 install 검증
  → ~/.claude/agents/ 에 페르소나 3개 등록 (customer-user / qa-engineer / deep-researcher)

# 2. 워크플로우 시작
/harness src/util/discount.js 에 discount(price, percent) 추가, percent 0~100 검증
  → step1 ~ complete 자동 진행
  → 결과: <PROJECT>/.harness/report-<slug>.html (단일 HTML, 1뷰포트 무스크롤, 첫 탭=요약)

# 3. 사용자 결정 모드가 필요할 때
/harness-ask <목표>
  → 모든 결정 지점에서 AskUserQuestion 으로 사용자 의사 확인
```

---

## 아키텍처 (2026-05-20 정합화)

### 마스터-only 구조

진실 원천은 **`~/.claude/skills/harness/`** (이 repo) 단 하나. 프로젝트(`<PROJECT>/.harness/`) 에는 워크플로우가 만드는 **산출물 (md/html) 만** 존재.

```
~/.claude/skills/harness/          ← 진실 원천 (이 repo)
├── SKILL.md                       워크플로우 진입점 + noask 정책 표
├── core/
│   └── bootstrap-runtime.sh       산출물 폴더 mkdir + 페르소나 agent 등록 (67 lines)
├── agents/                        페르소나 3개 + codex-reviewer
│   ├── harness-customer-user.md
│   ├── harness-qa-engineer.md
│   ├── harness-deep-researcher.md
│   ├── codex-reviewer.md
│   └── learning/                  공용 누적 학습 (HarnessRepo 에 push)
│       ├── harness-customer-user.md     (Don Norman, Hick's Law, UXAgent CHI 2025, ...)
│       ├── harness-qa-engineer.md       (ISTQB, Oracle 강도 Tier, CWV 임계값, ...)
│       └── harness-deep-researcher.md   (리서치 방법론, 인용 규칙, ...)
├── docs/
│   ├── workflow.md                step 흐름 + Learning Prepend 계약 + 회송 5메커니즘
│   ├── donot.md                   anti-pattern 목록
│   ├── html-output-rule.md        산출물 형식 규칙 (HTML/MD 분기)
│   ├── steps/                     step1 ~ step8 + complete 상세 절차
│   └── procedures/                single-source procedure 3종
│       ├── codex-review-procedure.md      (step5 codex 호출)
│       ├── deep-research-procedure.md     (step2/3 외부 리서치)
│       └── customer-test-procedure.md     (step7 페르소나 테스트)
└── templates/                     산출물 양식 (doc-prd / doc-architecture / progress / review / result / ...)

<PROJECT>/.harness/                ← 워크플로우가 만드는 산출물만
├── progress/progress-<slug>.md    slug 상태, Loop Counter, step4_commit_sha, auto_triggered_from
├── domain-<slug>.html             step2 도메인 설계
├── implementation-<slug>.html     step3 구현 계획 (Chunks 모드면 *-chunks-overview.html + *-chunk-N.html)
├── reviews/review-<slug>.md       step5 회차 누적
├── results/qa-<slug>.md           step6 회차 누적
├── results/customer-<slug>.html   step7 페르소나 테스트
├── research/research-*.html       외부 리서치 결과
├── test-guide-<slug>.md           step6 입력
├── report-<slug>.html             complete 종합 보고서
└── 마커: .noask | .ask | .pending-step7-review
```

### 정책

| 항목 | 기본값 |
|---|---|
| 사용자 질문 | **금지** (`AskUserQuestion` 호출 금지) — 단 *2 곳 예외* (아래) |
| 결정 분기 | 모두 자동. 사유는 `progress-<slug>.md` 의 `## 자동 결정 기록` 에 로깅 |
| 도메인 설계 승인 | 자동 승인 (`harness-plan` skill 의 노ask 출력 + Codex 리뷰 결과 1회 반영) |
| step5 동일 문제 LGTM:NO 5회 누적 | 자동 워크플로우 중단 (서로 다른 문제로 5회 누적은 *정상 진행*) |
| step6 동일 결함 FAIL 5회 누적 | 자동 워크플로우 중단 (동일 규칙) |
| step6 BLOCKED 단발 | 자동 재시도 1회 → fail 시 다중 슬러그면 (D) paused-by-blocked, 단일 슬러그면 (C) 중단 |
| step6 *동일 사유* BLOCKED 5회 누적 | **사용자 결정 (`AskUserQuestion`)** ← noask 예외 1 |
| step7 결과 처리 (complete 진입) | **사용자 결정 (`AskUserQuestion`)** ← noask 예외 2 (A/B/C — C: 신규 워크플로우 자동 트리거) |

### 회송 / 5회 게이트 — *동일* (유형 enum, 파일경로) 만 트리거

step5 LGTM:NO 또는 step6 FAIL 발생 시 회송. 5회 자동 중단 게이트는 **동일 (유형 enum, 파일경로 normalized) 튜플** 이 5회 누적될 때만 발동. *매 회차마다 다른 결함* 을 해결 중이면 무제한 반복 가능 (정상 진행).

- 유형 enum 13종: `TYPE_ERROR | NULL_REFERENCE | PERMISSION_DENIED | RESOURCE_NOT_FOUND | RACE_CONDITION | LOGIC_ERROR | IO_FAILURE | TIMEOUT | API_CONTRACT | SECURITY | TEST_COVERAGE | BUILD_FAILURE | OTHER`
- BLOCKED 사유 enum 6종: `DEPENDENCY_MISSING | EVIDENCE_GATE_FAIL | PERMISSION_DENIED | GUIDE_MISSING | ENV_UNREACHABLE | OTHER`
- step5·step6·step6-BLOCKED 카운터는 **각각 독립**

---

## 도구 분류

### 페르소나 도우미 (harness-* — Task / Skill 호출)

`harness-*` prefix 는 **페르소나 객관성** 이 필요한 3개만 보존. 모두 공용 learning 누적 + 매 호출 시 Learning Prepend 계약.

| 페르소나 | 사용처 | 본질 |
|---|---|---|
| `harness-customer-user` | step7 | 일반인 시점 production-install 테스트. 5초 테스트 + Cognitive Walkthrough + TTFV/SUS/SEQ 측정 + LLM 페르소나 함정 6종 차단 |
| `harness-qa-engineer` | step6 | 전문 QA 시점 런타임 행동 검증. 스크린샷 + 클릭 + Plan-Act-Verify + Oracle 강도 Tier |
| `harness-deep-researcher` | step2/3 외부 리서치 | Plan-Act-Verify-Iterate-Synthesize 5단계 + 환각 차단 4규칙 + 다중 출처 교차검증 |

### 일반 skill/agent (harness 가 호출)

워크플로우의 일반 도구는 **`harness-*` prefix 없는 일반 도구를 그대로 재사용**. 별도 페르소나 누적 없음.

| 도구 | 사용처 | 호출 방식 |
|---|---|---|
| `harness-plan` / `harness-plan-ask` skill | step2 (noask / ask) | Skill 도구 |
| `plan` skill | step3 구현 계획 | Skill 도구 |
| `architect` agent | step3 시스템 차원 검토 (필요 시) | Task 도구 |
| `tdd` skill / `tdd-guide` agent | step3·4 TDD 사이클 (필요 시) | Skill/Task |
| `build-fix` skill / 언어별 `*-build-resolver` agent | step4 빌드 실패 시 | Skill/Task |
| Codex CLI (`codex exec`) | step5 외부 verifier | shell |
| `code-review` skill / `code-reviewer` agent | step5 Codex fallback | Skill/Task |
| `security-review` skill / `security-reviewer` agent | step5 보안 게이트 (보안 민감 코드 시) | Skill/Task |
| `harness-review` skill | step5 codex 호출 wrapper | Skill |

### 폐기된 도우미 (2026-05-20)

다음 `harness-*` agent 6개는 일반 skill 로 대체 폐기:
- `harness-planner` → `plan` skill
- `harness-architect` → `architect` agent (일반)
- `harness-code-reviewer` → `code-review` skill + `code-reviewer` agent
- `harness-security-reviewer` → `security-review` skill + `security-reviewer` agent
- `harness-tdd-guide` → `tdd` skill + `tdd-guide` agent
- `harness-build-resolver` → `build-fix` skill + 언어별 `*-build-resolver` agent

---

## 슬래시 명령

| 명령 | 역할 |
|---|---|
| `/harness <목표>` | 메인 워크플로우 (noask 기본) |
| `/harness-ask <목표>` | 사용자 결정 모드 (모든 결정 지점에서 AskUserQuestion) |
| `/harness-setup` | install 검증 + 페르소나 agent 등록 |
| `/harness-spec` | 프로젝트 사양 (PRD/ARCHITECTURE/ADR/UI_GUIDE) + 헌법(CLAUDE.md) 작성·갱신 |
| `/harness-review` | 즉석 코드/문서 리뷰 (Codex 호출) |
| `/harness-customer-user` | step7 단독 호출 (페르소나 테스트) |
| `/harness-deep-researcher` | 외부 리서치 단독 호출 |
| `/harness-distill <agent>` | 공용 learning 파일 압축 (800 lines 초과 시 권고) |
| `/harness-audit` | 저장소 audit 점수표 |
| `/harness-help` | 도움말 |

### 폐기된 명령 (2026-05-20)

`/harness-sync` — 마스터→프로젝트 코드 복사 자체가 없어졌다 (마스터-only 아키텍처). 동기화 대상 0 파일.

---

## step6 QA 강화 게이트 (self-PASS bias 차단)

step6 가 *형식적으로만 작동하는 것* 을 막기 위해 5개 게이트를 step6-qa.md 에 신설:

1. **PASS/FAIL/BLOCKED/UNKNOWN 라벨 추출 규칙** — 보고서에 명시 라벨만 인정. 임의 해석 금지. 우선순위: `BLOCKED > FAIL > UNKNOWN > PASS`
2. **객관 산출물 게이트 (5b)** — 3축 검증:
   - `evidence_exists` — 스크린샷·trace 파일이 디스크에 실재
   - `coverage_full` — test-guide 의 모든 시나리오가 보고서 실행 목록에 매칭
   - `regression_reproduced` — 회송 첫 PASS 회차에 직전 fail 시나리오 키워드가 본문에 grep 가능
3. **self-PASS 강등 → UNKNOWN** — `fallback=manual self-test` + `PASS` / `qa-engineer 호출 0회` + `PASS` → 자동 UNKNOWN (slug `paused-by-unknown` 마킹)
4. **11필드 결정 보고 양식** — 판정·근거·다음 step·FAIL 카운터·BLOCKED 카운터·자기 점검·fallback·의존성·산출물 게이트·라벨 검증·자동 결정 결과
5. **BLOCKED 자동 결정 분기** — 1차 자동 재시도 → 다중 슬러그면 (D) paused-by-blocked, 단일이면 (C) 중단. 동일 사유 5회 누적 시에만 `AskUserQuestion`.

근거: arXiv 2508.06225 *self-LGTM bias* (ECE 39–74%). 같은 Claude 모델의 self-PASS 판정 신뢰 불가.

---

## Chunks 모드 (큰 작업 자동 분해)

step2 도메인 설계의 *4개 신호* (시나리오 수·변경 파일 수·의존성 레이어·UX 시나리오) 중 2개 이상이 임계값 통과 시 자동으로 Chunks 모드 진입:

```
대형 도메인 plan
  → vertical slice N 개로 분해
  → chunks-overview.html (전체 상태) + chunk-1.html ~ chunk-N.html (각 chunk 상세 plan)
  → 각 chunk 별 step4 ~ step6 사이클 반복
  → chunk PASS → 자동 incremental commit + push → 다음 chunk 진입
  → last chunk PASS → step7 (전체 production install 테스트, 1회)
```

회송 카운터는 **chunk 별 독립 5회**. 한 chunk 가 동일 문제 5회 초과 시 워크플로우 전체 자동 중단.

---

## Learning Prepend 계약

페르소나 3개 호출 시 메인 Claude 가 **공용 학습 파일 본문 전체** 를 prompt 에 prepend (4단계 의무):

1. 경로 식별: `~/.claude/skills/harness/agents/learning/<agent-name>.md`
2. Read 도구로 본문 실제로 읽음 (기억·요약·추측 금지)
3. Required Header 양식 그대로 prepend (`## Prior Learning (READ FIRST — DO NOT SKIP)`)
4. 본문 끝에 본 작업 prepend

도우미 측 *자체 거부 게이트*: prompt 첫 200줄 안에 헤더 없으면 즉시 `[BLOCKED] Prior Learning header 누락` 으로 거부, 작업 일체 금지.

2026-05-20 정합화로 **프로젝트 learning 폐기**, 공용만 prepend. 일반 skill/agent (`plan`, `code-review`, `tdd` 등) 는 본 계약 대상 아님.

상세: `docs/workflow.md` → `CRITICAL: Learning Prepend 계약`

---

## 산출물 형식 규칙

| 분류 | 확장자 | 내용 |
|---|---|---|
| 사람이 *읽고 결정* 하는 문서 | **HTML** (단일 파일, 탭, 1뷰포트, 첫 탭=요약) | domain-`<slug>` / implementation-`<slug>` / report-`<slug>` |
| 회차 누적·운영 로그·기계 가이드 | **MD** (일반 markdown) | progress / research / review / qa / customer-`<slug>` / test-guide |

HTML 산출물 UI 룰:
- `role="tablist"` + `aria-selected`
- **첫 번째 탭은 항상 "요약"** (Summary/한눈에/Overview/TL;DR) — 페이지 로드 시 기본 활성화
- 1440×900 기준 1뷰포트 무스크롤. 정보 많으면 서브탭·아코디언·모달로 분할.
- 저장 직후 채팅에 절대경로 한 줄 보고. `file://` 마크다운 링크 금지 (환경상 클릭 안 됨). 자동 브라우저 열기 금지.

정본: 사용자 `~/.claude/CLAUDE.md` §6 + §6.3.1, harness 측 `docs/html-output-rule.md`.

---

## 설치 (다른 머신)

```bash
# 1. clone
git clone https://github.com/chdnl0420-svg/Harness.git ~/.claude/skills/harness

# 2. 보조 skill 5개 (페르소나 + plan + plan-ask + review)
git clone https://github.com/chdnl0420-svg/Harness.git ~/.claude/skills/harness-customer-user
# (별도 skill 폴더 — 또는 본 repo 의 agents/*.md 를 ~/.claude/agents/ 로 복사)

# 3. install 검증
/harness-setup

# 4. 첫 호출
/harness <한 줄 목표>
```

상세 install 가이드: `~/.claude/commands/harness-setup.md`

---

## 변경 이력

- **2026-05-20** — 마스터-only 아키텍처 정합화. harness-sync / drift check 폐기. bootstrap-runtime.sh 60% 슬림화. 6개 일반 agent → 일반 skill 대체. 프로젝트 learning 폐기, 공용만 사용. step6 QA 5개 게이트 강화 (self-PASS bias 차단). BLOCKED 자동 결정 + 동일 사유 5회 누적 시 사용자 결정. step7→complete 진입 게이트 3선택지 (C: 신규 워크플로우 자동 트리거). docs/procedures/ single-source 3종 신설.
- **2026-05-18** — step5/6 self-LGTM bias 차단 게이트 + 회송 경로 5메커니즘 강화 (7필드 결정 보고, 객관 git diff 검증, 결함 enum 13종, BLOCKED (D) 분기, 의존성 사전 점검).
- **2026-05-17 이전** — 초기 harness skill 개발, deep research 누적, 페르소나 도우미 자체 시드.

---

## 외부 의존성

| 도구 | 사용처 | 부재 시 |
|---|---|---|
| Codex CLI (`codex exec`) | step5 외부 verifier | `code-review` skill (self-review) 로 자동 fallback. self-LGTM 강등 룰 작동 |
| MCP Chrome / Preview | step6/7 자동화 도구 | 셋 다 없으면 step6 BLOCKED (DEPENDENCY_MISSING) |
| 프로젝트 Playwright (기존) | step6 fallback | 없어도 MCP 가용하면 진행 |

---

## License

(미정 — 사용자 결정 시 추가)
