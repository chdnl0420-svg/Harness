---
name: harness
description: 'DO NOT AUTO-TRIGGER. SLASH-COMMAND-ONLY. 본 skill 은 사용자가 명시적으로 `/harness <자연어>` (또는 `/harness-ask <자연어>`) 슬래시 커맨드를 *직접 타이핑* 했을 때만 로드. "워크플로우 / 워크플로우 시작 / 도메인 설계 / 구현 계획 / QA 테스트 / Codex 리뷰 / commit / push" 같은 *키워드만으로는 자동 트리거 금지*. SKILL.md 본문의 입력 게이트가 슬래시 커맨드 호출 컨텍스트 부재 시 즉시 거부하고 한 줄 안내 후 종료. 슬래시 호출이 확인된 경우에만 본문 내용 (8단계 자동 워크플로우 step1~complete + noask 기본 정책 + 페르소나 3개 Task subagent + Skill 도구 통합) 진행. ※ 다음 인접 skill 과 무관 (이름만 비슷): autonomous-agent-harness, gan-style-harness, eval-harness, healthcare-eval-harness, agent-harness-construction.'
---

## CRITICAL: 입력 게이트 — 슬래시 커맨드 호출 컨텍스트 확인 (자동 트리거 차단)

> **본 skill 은 `/harness` (또는 `/harness-ask`) 슬래시 커맨드 명시 호출이 *유일한* 진입 경로다. 다른 모든 자동 트리거 경로는 거부한다.**

본 SKILL.md 가 메인 Claude 의 컨텍스트에 로드된 직후, **본문 어떤 절차도 실행하기 전에** 다음을 자체 검증한다:

1. **호출 컨텍스트 확인** — 본 skill 로드 직전 사용자 메시지가 다음 중 *하나* 인지 확인:
   - `/harness <자연어>` 슬래시 커맨드 (직접 타이핑)
   - `/harness-ask <자연어>` 슬래시 커맨드 (interactive 모드)
   - 명시적으로 *"/harness 워크플로우 시작해줘"* / *"harness 슬래시 커맨드로"* 와 같이 슬래시 커맨드를 단어로 *직접 가리킴*

2. **위 셋 중 하나도 아니면 = 자동 트리거 시도 = 즉시 거부**:
   - 채팅에 한 줄 출력: `[harness] 본 skill 은 /harness 또는 /harness-ask 슬래시 커맨드 명시 호출 전용입니다. 작업을 시작하려면 /harness <자연어> 형태로 직접 호출하세요.`
   - 본문의 step1~complete 절차 진행 **금지**.
   - `.harness/` 폴더 생성·수정 금지.
   - `bootstrap-runtime.sh` 호출 금지.

3. **거부 사유 enum** (자체 분류 — progress 파일 작성 안 함, 채팅에만 보고):
   - `KEYWORD_MATCH_ONLY` — 메인 Claude 가 사용자 일반 대화 키워드("워크플로우", "QA" 등) 만 보고 본 skill 을 자동 로드 시도
   - `RELATED_HARNESS_CONFUSION` — autonomous-agent-harness, gan-style-harness 등 인접 skill 과 혼동되어 로드 시도
   - `IMPLICIT_INVOCATION` — 사용자가 슬래시 커맨드 없이 *"하네스로 작업"* 같은 모호한 표현으로 시도

4. **검증 통과** (= 슬래시 커맨드 명시 호출 확인) 시에만 아래 본문 절차 진행.

이 게이트는 워크플로우 본문의 어떤 *자동 결정 매핑* 으로도 우회 불가. SKILL.md 가 로드되는 순간 *맨 처음* 동작이다.

---

## CRITICAL: [docs/donot.md](docs/donot.md) — 반드시 지켜야 하는 행동 규약

> **본 SKILL.md 의 어떤 절차·결정 매핑·기본값보다 [`docs/donot.md`](docs/donot.md) 가 우선한다.** 입력 게이트 통과 직후, step1 진입 *전에* 반드시 Read 로 전문을 로드해 컨텍스트에 올린다.

**의무**:

1. SKILL.md 가 로드되면 입력 게이트 통과 직후 즉시 [`docs/donot.md`](docs/donot.md) 를 Read 로 읽는다. "기억"이나 "요약"으로 대체 금지 — 매 호출마다 본문 전체를 다시 Read.
2. 모든 step (step1~complete), 모든 chunk 전환, 모든 서브에이전트·skill 호출 *직전* 에 donot.md 의 9개 섹션을 자가 점검:
   - §1 사용자 의도·범위 / §2 Step 스킵·통합·생략 / §3 Step 간 입력 누락 / §4 추측 구현 / §5 가짜 완료 / §6 Worktree·격리 함정 / §7 권한 정책 위반 / §8 리뷰·테스트 형식화 / **§9 작업 규모 임의 축소·선제 중단**
3. **§9 (작업 규모 임의 축소·선제 중단)** 는 본 SKILL.md 의 noask 자동 결정 매핑·산출물 형식 규칙보다 우선한다. §9 의 5가지 금지 패턴 (한 세션 한계 투영해 임의 일시정지 / Codex → self-review 대체 / QA 면제 / chunk 묶음 commit / 선의의 가부장주의) + 3가지 인지 편향 (컨텍스트 보호 본능 / 효율 강박 / 선의의 가부장주의) 중 하나라도 발동되면 즉시 정석 절차로 복귀.
4. donot.md 위반 발견 시 즉시 워크플로우 중단. **본 문서 기밀 처리 규약 (donot.md 최상단) 준수**: 사용자 노출 산출물 (`report-<slug>.html`, 채팅 메시지) 에는 본 문서명·조항 번호·"정책 N" 인용 금지. 사용자 노출은 "내부 검증 실패로 중단합니다" 수준의 추상 메시지만. 내부 progress 파일에만 패턴 식별 코드 기록. 위반 결과 산출물은 사용자 명시 결정 전까지 추가 행동 금지.

**우선순위 (충돌 시)**:

```
docs/donot.md  >  CLAUDE.md §6.3.1 (HTML 출력 규칙)  >  SKILL.md noask 자동 결정 매핑  >  docs/workflow.md  >  docs/steps/*.md
```

donot.md 와 다른 문서가 충돌하면 *항상* donot.md 를 따른다. 다른 문서가 donot.md 와 다른 행동을 지시하더라도 그 지시를 무시한다.

---

## CRITICAL: workflow.md 범위 외 내용 언급 금지

> **본 워크플로우 진행 중 메인 Claude 는 [`docs/workflow.md`](docs/workflow.md) 가 정의한 단계·절차·산출물·결정 매핑과 *직접 관련 있는 내용만* 사용자에게 출력한다.** workflow.md 와 무관한 주제·정보·제안·여담은 채팅·progress·report 어디에도 노출 금지.

**의무**:

1. 출력 직전 자가 점검: "이 문장이 workflow.md 의 어떤 단계/조항/산출물과 직접 연결되는가?" 답을 못 찾으면 그 문장은 *삭제*.
2. 사용자 질문이 workflow.md 범위 밖이면 **한 줄로 거절** 후 워크플로우 본 흐름 복귀: 예) `[harness] 현재 워크플로우 범위 밖 질문입니다. 워크플로우 종료 후 별도로 문의 부탁드립니다.` 메인 Claude 가 자체 판단으로 답하지 않는다.
3. 다음은 항상 *범위 외* 로 간주 — 언급 금지:
   - workflow.md 에 없는 도구·skill·기법 추천 (예: "이건 X skill 로도 할 수 있어요" 같은 사이드 제안)
   - 사용자의 다른 프로젝트·다른 작업에 대한 의견
   - 일반 코딩 팁·모범 사례 (단, 현재 step 의 산출물에 직접 들어가는 내용은 예외)
   - LLM·Claude Code 자체에 대한 메타 코멘트 (단, 입력 게이트·정책 위반 보고는 예외)
   - 본 SKILL.md 외 다른 skill 의 내부 동작 설명
4. 범위 판정 기준 — workflow.md 의 step1~complete + 자동 결정 매핑 표 + Learning Prepend 계약 + 산출물 형식 규칙 + donot.md 9개 섹션 안에 *직접 매핑되는* 내용만 in-scope.

**충돌 시**: 본 규칙은 SKILL.md 의 다른 절차 안내·진행 보고와 충돌할 수 있다. 충돌하면 *간결한 진행 보고 + 범위 내 내용* 을 택한다. 길어지는 부연 설명은 자른다.

**예외 (사용자 명시 요청 시만)**: 사용자가 *그 작업에 한정해* 워크플로우 외 정보를 명시적으로 요청한 경우만 노출 허용. 그 외 자체 판단의 범위 확장 금지.

---

## 산출물 형식 규칙 (CRITICAL — 최우선 적용, 다른 모든 기본값 위)

> `/harness` · `/harness-*` 모든 커맨드 · 모든 `harness-*` skill 이 만드는 모든 산출물 파일에 적용된다. 예외 없음.

**원칙 4가지** (전체 규칙은 [docs/html-output-rule.md](docs/html-output-rule.md), 정본은 `~/.claude/CLAUDE.md` §6 + §6.3.1):

1. **분류별 분기**:
   - **HTML** (단일 파일 + 탭 + 1뷰포트 + 첫 탭=요약): `domain-<slug>` (도메인 계획) · `implementation-<slug>` (구현 계획) · `report-<slug>` (complete 종합 보고서). 사람이 작업 전/후 *읽고 결정* 하는 풍부한 시각 문서.
   - **MD** (일반 markdown — 헤더 + 표 + 코드블록 + 회차 누적): `progress-<slug>` · `research-*` · `review-<slug>` · `qa-<slug>` · `customer-<slug>` · `test-guide-<slug>`. 운영 로그·중간 결과·기계 가이드 성격.
   - 예외 (`README.md` · `CLAUDE.md` · 외부 라이브러리 .md · 사용자가 *그 작업에 한정* 명시적으로 다른 형식 요청) 는 그대로 유지.
2. **HTML 산출물 UI 룰**: `role="tablist"` + `aria-selected`. **첫 번째 탭은 항상 "요약" 탭**(Summary/한눈에/Overview/TL;DR), 결론·핵심 지표 카드 3-5개 배치, 페이지 로드 시 기본 활성화. MD 산출물에는 적용 안 됨.
3. **HTML 산출물 레이아웃**: 1440×900 기준 첫 화면 완결, 정보 많으면 서브탭·아코디언·모달로 분할, 표는 카드 내부 스크롤만 허용 (페이지 전체 스크롤 금지). MD 산출물은 일반 markdown 흐름 그대로.
4. **저장 직후 채팅에 절대경로 한 줄 보고** (HTML/MD 공통): 형식 `저장 완료: \`<절대경로>\``. `file://` 마크다운 링크 사용 금지 (환경상 클릭 안 됨). **자동 `Start-Process` 호출 금지** — 사용자가 "지금 열어줘" 명시 요청 시에만. 환경 hook (`open-report.js` 등) 이 자동 열기 수행 시 정책 위반 — 비활성화 권고.

**서브에이전트 호출 시 의무**: 메인 Claude 가 `Task(subagent_type="harness-*")` 또는 다른 스킬을 호출할 때 프롬프트에 *"산출물은 CLAUDE.md §6.3.1 + harness/docs/html-output-rule.md 를 따른다 — 분류별 HTML/MD 분기 (domain/impl/report = HTML, 나머지 = MD), HTML 은 단일 파일 + 탭(첫 탭=요약) + 1뷰포트, 저장 직후 채팅에 절대경로 한 줄 보고 (자동 브라우저 열기 금지, file:// 링크 금지)."* 를 **명시 전달**.

**옛 문서와의 충돌**: `docs/workflow.md`, `docs/steps/*.md`, `templates/*.md` 가 *다른* 확장자를 지시하더라도 이 분류 규칙이 우선한다.

---

## 폴더 생성 규칙

구현단계에서 새 폴더를 만들어야 할 때는 다음 규칙을 따릅니다:
- root폴더에 파일을 직접 만들지 말고 폴더를 만들어서 그 안에 파일을 넣는다.

## 학습파일 자동 Fallback (CRITICAL — 페르소나 3개 호출 공통)

페르소나 도우미 호출 시 **공용 학습파일을 반드시 컨텍스트에 prepend** 한다 (2026-05-20 정합화 — 프로젝트 learning 폐기, 공용만 사용).

**경로**: `~/.claude/skills/harness/agents/learning/<agent-name>.md` (공용)

**규칙**:
- 공용 학습파일을 **항상** Read 해 prompt 에 prepend.
- 파일이 비어 있으면 본문에 `(빈 파일)` 으로 명시. 공용은 마스터 install 시 항상 존재.
- 누락된 경우 (마스터 자체에 없음) → `harness-setup` 으로 마스터 재install 권고 후 `(빈 파일)` 명시하고 진행.

**적용 범위**: 페르소나 3개 — `harness-customer-user`, `harness-qa-engineer`, `harness-deep-researcher`. 메인 Claude 가 skill/agent 호출 직전 공용 파일을 Read 해 본인 컨텍스트에 prepend.

**일반 skill/agent 는 본 계약 대상 아님** — `plan`, `code-review`, `security-review`, `tdd`, `build-fix`, `architect`, `code-reviewer` 등 일반 도구는 harness 전용이 아니므로 별도 learning prepend 없음.

상세 계약: [docs/workflow.md](docs/workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통)

## 실행 옵션 (2026-05-20 단순화 — agent → skill 부분 전환)

`/harness` 는 별도 플래그 없이 *통합 모드* 로 동작. 이전 `--noagent` 플래그는 폐기.

**호출 주체 분리 (CRITICAL — 자체 모순 방지)**:
- **페르소나 의존성이 없는 단위** (`harness-plan`, `harness-review`, 그 외 일반 `plan`/`code-review`/`tdd`/`build-fix` 등) → **Skill 도구** 로 메인 Claude 가 직접 호출. 별도 subagent 컨텍스트 없음.
- **페르소나 객관성이 필수인 3개** (`harness-qa-engineer`, `harness-customer-user`, `harness-deep-researcher`) → **Task 도구 subagent 호출 유지.** 같은 모델의 self-PASS bias 차단이 진짜 외부 게이트 역할을 하므로 subagent 컨텍스트 보존 필요.
- 본 SKILL.md 의 "자동 결정 매핑" 표(아래) · `docs/workflow.md` · `docs/steps/*` 가 명시한 "agent" 호출은 위 3개 한정으로 유효. 그 외 단위는 모두 skill 통합.

workflow 본문은 step1~complete 동일.

대체 옵션:
- 사용자 결정 분기를 활성화하려면 `/harness-ask` 사용 (noask 기본 정책의 반대 — `AskUserQuestion` 도구 호출 허용).

---

## 기본 정책: 사용자 질문 금지 (noask 기본)

> `/harness` 의 **기본 동작은 noask 모드**다. 사용자에게 어떤 질문도 하지 않고 모든 결정 지점을 자동 진행한다. `AskUserQuestion` 도구 호출 금지.
> 결정 지점에서 사용자 확인을 받고 싶으면 **`/harness-ask`** 를 사용한다 ([commands/harness-ask.md](~/.claude/commands/harness-ask.md)).

**옛 docs 와의 충돌**: `docs/workflow.md` · `docs/steps/*.md` 가 `AskUserQuestion` 호출이나 사용자 확인 분기를 지시하더라도 **이 정책이 우선**한다. 결정 지점은 아래 표의 기본값으로 자동 진행한다. (`/harness-ask` 로 명시 호출된 경우만 docs 의 결정 지점이 다시 활성화)

### 전제

- 사용자가 `/harness` 를 호출했다 = "끝까지 자동으로 돌려라" 라는 명시적 위임. 이 위임 자체가 모든 자동 결정의 사용자 승인이다.
- 결정 지점에서 막혀도 사용자에게 묻지 않는다. 아래 표의 기본값으로 진행하거나, 정의된 중단 사유면 워크플로우를 종료하고 `report-<slug>.md` 에 사유를 명시한다.

### 자동 결정 매핑 (CRITICAL — 이 표가 noask 기본 정책의 본질)

| 결정 지점 | 위치 | 기본 동작 | 비고 |
|----------|------|----------|------|
| **도메인 설계 skill 선택** | step2 1번 (skill 호출) | **`harness-plan` skill 사용** (noask 동작 — 질문 없이 6 카테고리 합리적 가정 + Open Questions 누적) | `/harness-ask` 모드는 자매 skill `harness-plan-ask` 사용 (AskUserQuestion 인터랙티브). 두 skill 은 Phase 3·4·5 공유, Phase 1 입력 방식만 다름. 자세히: [docs/steps/step2-domain.md](docs/steps/step2-domain.md) |
| **Chunks 모드 판정** | step3 첫 진입 (모드 결정) | **자동 판정** — 도메인 plan 의 4개 신호 (시나리오 수·변경 파일 수·의존성 레이어·UX 시나리오) 중 2개 이상 임계값 통과 시 Chunks 모드 | Chunks 모드면 vertical slice 로 분해 → step4~6 사이클 반복. 자세히: [docs/steps/step3-impl-plan.md Chunks 분해 절차](docs/steps/step3-impl-plan.md#chunks-분해-절차-critical--2026-05-20-신규) |
| **Chunks 사이 전환** | chunk_i 의 step6 PASS 직후 | **자동 진입 (다음 chunk_i+1)** | git commit 자동 (push 는 `.harness/.auto-push` 마커 존재 시에만 — 아래 변경 참조) → chunks-overview 상태 갱신 → step3 의 다음 chunk plan 작성 → step4 진입. last chunk PASS 시 step7 로 |
| **Chunks 회송 카운터** | step5 LGTM:NO / step6 FAIL 시 | **chunk 별 독립 카운터 — *동일* 문제·결함이 5회 반복될 때만 중단** (현 chunk 의 plan 만 재작성, 다른 chunk 영향 없음. *서로 다른* 문제가 5회 발생해도 중단되지 않음) | 한 chunk 가 동일 문제·결함 5회 초과 시 워크플로우 *전체* 자동 중단. 동일성 판정 = `(유형 enum, 파일경로 normalized)` 튜플 일치 |
| **Chunks 별 commit** | chunk_i 의 step6 PASS 직후 | **자동 incremental commit (local only)** | commit 메시지: `feat(<slug>): chunk <i>/<N> — <title>`. **push 는 기본 비활성** — `.harness/.auto-push` 마커 존재 시에만 push 시도. push 실패 시 재시도 1회 → 로컬 commit only |
| **도메인 설계 승인** | step2 4번 (`AskUserQuestion` "1.승인/2.수정/3.취소") | **자동 승인** (옵션 1 선택과 동일) | Codex 리뷰 결과를 1회 반영한 본문으로 바로 `.harness/domain-<slug>.html` 작성 → step3 |
| **step5 *동일 문제* LGTM:NO 5회 반복** | step5 → step3 루프 카운터 + 동일 문제 라벨 (`(유형 enum, 파일경로)` 튜플) | **워크플로우 자동 중단** (※ *서로 다른* 문제로 5회 LGTM:NO 가 누적되는 경우는 **중단하지 않음** — 각각 다른 결함을 해결 중이라는 신호) | `report-<slug>.md` 에 "동일 문제 5회 반복으로 자동 중단 (noask 기본 정책)" 명시. 사용자 알림 메시지 박스 띄우지 않음. 동일성 판정 자세히: [docs/workflow.md "(5) 결함 유형 enum"](docs/workflow.md#5-결함-유형-enum--라벨-회피-차단-critical) |
| **step6 *동일 결함* FAIL 5회 반복** | step6 → step3 루프 카운터 + 동일 결함 라벨 | **워크플로우 자동 중단** (※ *서로 다른* 결함으로 5회 FAIL 누적은 **중단하지 않음**) | 동일. report 에 사유 기록 |
| **step6 BLOCKED (단발)** | 자동화 도구 부재 / 환경 접근 불가 / 산출물 게이트 1축 NO 등 | **자동 결정 분기 — 사용자에게 묻지 않음** | 1차: 자동 재시도 1회 (의존성·환경 재점검 + 도우미 재호출). 재시도 fail + 다중 슬러그 → 자동 (D) `paused-by-blocked` + 다음 슬러그. 재시도 fail + 단일 슬러그 → 자동 (C) 중단. progress 에 BLOCKED 사유 enum 기록 (DEPENDENCY_MISSING / EVIDENCE_GATE_FAIL / PERMISSION_DENIED / GUIDE_MISSING / ENV_UNREACHABLE / OTHER) |
| **step6 *동일 사유* BLOCKED 5회 누적** | 같은 사유 enum 으로 5회 반복 발생 | **`AskUserQuestion` 호출 (noask 정책 2번째 예외)** | (A) 환경 수정 후 재시도 / (B) 사용자 명시 동의 스킵 / (C) 워크플로우 중단 3선택지. *서로 다른* 사유로 5회 누적은 트리거 아님 — 각각 다른 환경 문제를 거치는 정상 진행. complete 진입 게이트와 함께 noask 정책의 *유일한 2 예외* |
| **step6 UNKNOWN (self-PASS bias 강등)** | `fallback=manual self-test` AND `PASS` 라벨 / `qa-engineer 호출 0회` AND `PASS` 라벨 | **자동 강등 + 슬러그 `paused-by-unknown` 마킹** | 같은 Claude 모델의 self-PASS 판정 신뢰 불가 (arXiv 2508.06225 ECE 39–74%). 다음 step 진입 금지. report 에 사유 기록. 무인 모드면 다음 슬러그 자동 시작 |
| **step8 commit/push 정책** | step8 진입 시 | **commit 은 자동, push 는 옵트인** — `.harness/.auto-push` 마커 존재 시에만 원격 push 시도 (없으면 로컬 commit only). | 사용자가 `/harness --push` 또는 `touch .harness/.auto-push` 로 명시 opt-in 해야 원격 반영. 기본은 검증 워크플로우의 본질에 맞춰 *배포성 부작용 차단* |
| **step8 push 실패 (opt-in 모드에서)** | git push 실패 | **재시도 1회 → 그래도 실패면 로컬 commit 만 완료로 처리** | report 에 "원격 push 실패, 로컬 commit 만 완료" 기록. 사용자에게 묻지 않음 |
| **Codex 인증 실패 / quota 소진** | step5 등 | **Codex fallback (code-review skill) 로 자동 전환** | 기본 fallback 동작과 동일하되, "Claude 자기리뷰 편향 안내 후 사용자 의사 확인" 절차는 생략. 그대로 진행하고 report 에 "Codex fallback 사용" 명시 |
| **complete 진입 전 step7 결과 처리 확인** | step8 완료 직후, complete.md 입력 게이트 | **AskUserQuestion 호출 허용 (단 1곳 예외)** | 3선택지 — A: 그대로 complete 진행 (개선안 report 요약) / B: 일시정지 (.harness/.pending-step7-review 마커, 사용자 재호출) / C: 개선안으로 신규 워크플로우 자동 시작 (auto_triggered_from 필드 + 무한 chain 차단). 자세히: [docs/steps/complete.md](docs/steps/complete.md) |
| **기타 모든 `AskUserQuestion` 호출 후보** | 어디든 (위 complete 예외 외) | **호출 자체 금지** | 메인 Claude 가 합리적 기본값으로 결정하고 결정 내용을 `progress-<slug>.md` 에 1줄 로깅 |

### 금지 사항 (자체 검증 게이트)

`/harness` 실행 중 (= `/harness-ask` 가 아닌 한) 다음을 발견하면 즉시 위반으로 간주하고 `report-<slug>.md` 에 "정책 위반" 으로 기록한 뒤 중단한다:

- `AskUserQuestion` 도구 호출 (어떤 step 에서든 — 단 **2 곳만 허용 예외**):
  1. complete 진입 전 step7 결과 처리 확인 (3선택지 A/B/C)
  2. step6 *동일 사유* BLOCKED 5회 누적 시 (3선택지 A/B/C)
  - 위 2 곳 외 호출은 모두 정책 위반
- "사용자에게 확인 부탁드립니다" / "어떻게 진행할까요" / "승인 부탁드립니다" 등 사용자 의사 묻는 출력 텍스트
- step6 BLOCKED **단발** 시 (B) "사용자 명시 스킵" 분기 사용 — 5회 누적 전까지는 사용자에게 묻지 않고 자동 결정. 5회 누적 시에만 AskUserQuestion 호출이 활성됨.

### 진행 로그 의무

매 자동 결정 시 `<PROJECT>/.harness/progress/progress-<slug>.md` 에 한 줄 append:

```
[<UTC timestamp>] AUTO-DECISION: <결정 지점 이름> → <선택한 기본값> (이유: noask 기본 정책)
```

complete 단계의 `report-<slug>.md` 에는 모든 자동 결정 목록을 한 섹션 (`## 자동 결정 기록 (noask 기본 정책)`) 으로 정리해 사람이 사후 검토 가능하게 한다.

### step1 부트스트랩 시 noask 플래그 기록

step1 초기화에서 `.harness/.noask` 빈 파일 생성 (그리고 `.harness/.ask` 가 있으면 삭제). 이후 step 들은 매번 이 파일 존재 여부로 noask 모드 분기. (`.harness/.noagent` 는 2026-05-20 폐기 — step1 cleanup 으로 자동 삭제됨.)

각 step 시작 시 `.harness/.noask` 가 보이면 메인 Claude 는 "이 step 에서 사용자에게 어떤 질문도 하지 않는다 (noask 기본 정책)" 를 컨텍스트 첫 줄에 명시하고 진행.

호출 종료 시 (`complete` 단계 끝) `.harness/.noask` 파일은 삭제.

### 호출 직후 1회 보고 (질문 아님)

`/harness` 호출 직후 메인 Claude 는 다음을 **단순 통보**로 1회 출력한 뒤 step1 로 진입한다 (질문 아님, 응답 대기 안 함):

```
[noask 기본 정책] 모든 사용자 결정을 자동 진행합니다.
- 도메인 설계 → 자동 승인
- *동일 문제·결함* 5회 반복 게이트 → 자동 중단 (서로 다른 문제로 5회 발생 시는 중단 아님)
- step6 BLOCKED 단발 → 자동 재시도 1회 → (D) paused-by-blocked 또는 (C) 중단
- step6 *동일 사유* BLOCKED 5회 누적 → 사용자 결정 요청 (noask 2번째 예외)
- push 실패 → 로컬 commit 으로 완료
모든 자동 결정은 progress-<slug>.md 와 report-<slug>.md 에 기록됩니다.
결정 지점에 사용자 확인이 필요하면 다음번에 /harness-ask 를 사용하세요.
```

---

## docs/ 안내판

> **2026-05-20 정리**: 본문이 있는 활성 문서만 안내. 0바이트 placeholder (`context-layer.md`, `examples.md`, `file-formats.md`, `phases.md`, `setup.md`, `stop-report.md`) 는 안내판에서 제거. 필요 시 별도 작업으로 본문 작성 후 재등재.

| 파일 | 무엇을 다루나 |
|------|--------------|
| **[donot.md](docs/donot.md)** | **CRITICAL — 반드시 지켜야 하는 행동 규약. 본 SKILL.md 의 모든 절차·결정 매핑보다 우선. 매 호출마다 Read 로 전문 로드 필수.** |
| [workflow.md](docs/workflow.md) | `/harness` 전체 흐름 — 어떤 순서로 무엇이 일어나는지 사람-친화 설명 |
| [steps/](docs/steps/) | step1 ~ step8 + complete 각 단계의 상세 절차 (한 step 당 한 파일) |
| [procedures/](docs/procedures/) | 단위 절차 정본 (codex-review / customer-test / deep-research) |
| [test-guide-format.md](docs/test-guide-format.md) | step6/step7 테스트 진행 전 작성하는 `test-guide-<slug>.md` 의 양식·재료·갱신 규칙 |
| [html-output-rule.md](docs/html-output-rule.md) | 산출물 HTML 양식 규칙 (CLAUDE.md §6 정본 미러) |

**미작성 (placeholder)** — 필요할 때 작성:
- `setup.md` — 설치/환경 가이드 (현재는 README + `/harness-setup` 슬래시 커맨드로 대체)
- `context-layer.md` — 장기 메모리 / 사양 문서 구조
- `phases.md` — 단계별 Phase 분해 (현재는 `steps/` 가 대체)
- `file-formats.md` — 산출물 파일 형식 표준 (현재는 `html-output-rule.md` + `test-guide-format.md` 가 부분 대체)
- `stop-report.md` — 중단 보고서 양식
- `examples.md` — 실제 시나리오 예시
