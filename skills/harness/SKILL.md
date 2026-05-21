---
name: harness
description: 'DO NOT AUTO-TRIGGER. SLASH-COMMAND-ONLY. `/harness <자연어>` 또는 `/harness-ask <자연어>` 슬래시 커맨드가 *명시 호출* 된 경우에만 로드. "워크플로우 / 도메인 설계 / 구현 계획 / QA / Codex 리뷰 / commit / push" 같은 *키워드만으로 자동 트리거 금지*. 입력 게이트가 슬래시 호출 컨텍스트 부재 시 즉시 거부 + 한 줄 안내 후 종료. 슬래시 호출 확인 시에만 8단계 자동 워크플로우(step1~complete) + noask 기본 정책 + 페르소나 3개 Task subagent + Skill 도구 통합 진행. ※ 다음 인접 skill 과 무관: autonomous-agent-harness, gan-style-harness, eval-harness, healthcare-eval-harness, agent-harness-construction.'
---

## CRITICAL: 입력 게이트 — 슬래시 호출 컨텍스트 확인

> 본 skill 은 `/harness` 또는 `/harness-ask` 슬래시 커맨드 *명시 호출* 만 유일한 진입 경로. 본문 어떤 절차도 시작 전에 자체 검증 (SKILL.md 로드 직후 *맨 처음* 동작, 본문 자동 결정 매핑으로도 우회 불가).

**검증 절차**:

1. **호출 컨텍스트 확인** — 직전 사용자 메시지가 다음 중 하나인지 확인:
   - `/harness <자연어>` 슬래시 커맨드
   - `/harness-ask <자연어>` 슬래시 커맨드 (interactive 모드)
   - `/harness-resume <slug>` 슬래시 커맨드 (재개 모드 — step1 부트스트랩 skip, 마지막 step 이후 재진입)
   - *"/harness 워크플로우 시작해줘"* 처럼 위 3개 슬래시 커맨드 중 하나를 단어로 가리킴
2. **모두 아니면 = 자동 트리거 시도 = 즉시 거부**:
   - 채팅 한 줄: `[harness] 본 skill 은 /harness, /harness-ask, /harness-resume 슬래시 커맨드 명시 호출 전용입니다. 새 작업은 /harness <자연어>, 진행중 작업 재개는 /harness-resume <slug> 형태로 호출하세요.`
   - step1~complete 절차 진행 금지 / `.harness/` 폴더 생성 금지 / `bootstrap-runtime.sh` 호출 금지
3. **거부 사유 enum** (자체 분류, 채팅에만 보고, progress 파일 작성 안 함):
   - `KEYWORD_MATCH_ONLY` — 일반 대화 키워드만 보고 자동 로드 시도
   - `RELATED_HARNESS_CONFUSION` — autonomous-agent-harness, gan-style-harness 등 인접 skill 혼동
   - `IMPLICIT_INVOCATION` — 슬래시 커맨드 없이 *"하네스로 작업"* 같은 모호한 표현
4. **검증 통과 시에만 본문 진행**.

---

## CRITICAL: [docs/donot.md](docs/donot.md) — 행동 규약 (최우선)

> 우선순위: `donot.md > CLAUDE.md §6.3.1 > SKILL.md noask 매핑 > workflow.md > steps/*`. 입력 게이트 통과 후 step1 진입 전 매 호출 Read 필수 ("기억"·"요약" 대체 금지).

**자가 점검 시점**: 모든 step / chunk 전환 / 서브에이전트·skill 호출 *직전* → donot.md 9 섹션 (§1 사용자 의도 / §2 step 스킵 / §3 입력 누락 / §4 추측 구현 / §5 가짜 완료 / §6 Worktree 격리 / §7 권한 / §8 리뷰·테스트 / **§9 작업 규모 임의 축소**).

**§9 의 추가 게이트** (noask 매핑·출력 규칙보다도 우선): 5 금지 패턴(한 세션 한계 투영 임의 일시정지 · Codex→self-review 대체 · QA 면제 · chunk 묶음 commit · 선의의 가부장주의) + 3 인지 편향(컨텍스트 보호 본능 · 효율 강박 · 선의의 가부장주의) 중 하나라도 발동 → 즉시 정석 절차 복귀.

**위반 시**: 즉시 중단 + 기밀 처리 규약(donot.md 최상단) 준수 — 사용자 노출(`report-<slug>.html`·채팅)은 본 문서명·조항 번호 인용 금지, "내부 검증 실패로 중단" 추상 메시지만, 내부 progress 에만 패턴 코드 기록. 위반 산출물은 사용자 명시 결정 전까지 추가 행동 금지.

---

## CRITICAL: 산출물 형식 규칙 (최우선 적용)

> `/harness` · `/harness-*` · `harness-*` skill 모든 산출물에 예외 없이 적용. 전체 규칙: [docs/html-output-rule.md](docs/html-output-rule.md), 정본: `~/.claude/CLAUDE.md` §6 + §6.3.1.

**원칙 4**:

1. **분류별 분기**:
   - **HTML** (단일 파일 + 탭 + 1뷰포트 + 첫 탭=요약): `domain-<slug>` · `implementation-<slug>` · `report-<slug>`.
   - **MD** (헤더·표·코드블록·회차 누적): `progress-<slug>` · `research-*` · `review-<slug>` · `qa-<slug>` · `customer-<slug>` · `test-guide-<slug>`.
   - 예외 (`README.md` · `CLAUDE.md` · 외부 라이브러리 · 사용자 명시 요청) 유지.
2. **HTML UI**: `role="tablist"` + `aria-selected`. **첫 탭 = "요약"** (Summary/한눈에/Overview/TL;DR), 결론·핵심 지표 카드 3–5개, 페이지 로드 시 기본 활성화. MD 비적용.
3. **HTML 레이아웃**: 1440×900 첫 화면 완결. 정보 많으면 서브탭·아코디언·모달 분할. 표는 카드 내부 스크롤만 (페이지 전체 스크롤 금지). MD 일반 markdown.
4. **저장 직후 채팅 한 줄 보고** (HTML/MD 공통): 형식 `저장 완료: \`<절대경로>\``. `file://` 마크다운 링크 금지 (환경상 클릭 안 됨). **자동 `Start-Process` 금지** — 사용자 "지금 열어줘" 명시 요청 시에만.

**서브에이전트·skill 호출 시 의무**: 프롬프트에 *"산출물은 CLAUDE.md §6.3.1 + harness/docs/html-output-rule.md 를 따른다 — 분류별 HTML/MD 분기 (domain/impl/report = HTML, 나머지 = MD), HTML 은 단일 파일 + 탭(첫 탭=요약) + 1뷰포트, 저장 직후 채팅에 절대경로 한 줄 보고 (자동 브라우저 열기 금지, file:// 링크 금지)."* 명시 전달.

**옛 문서 충돌**: `docs/workflow.md`, `docs/steps/*.md`, `templates/*.md` 가 다른 확장자를 지시해도 본 분류 규칙이 우선.

---

## 폴더 생성 규칙

구현 단계에서 새 폴더가 필요하면: root 에 파일 직접 생성 금지 — 폴더를 만들고 그 안에 파일 배치.

## CRITICAL: 학습 파일 자동 prepend (페르소나 3개 호출 공통)

페르소나 도우미(`harness-customer-user` · `harness-qa-engineer` · `harness-deep-researcher`) 호출 시 **공용 학습 파일 prepend 필수** (2026-05-20 정합화 — 프로젝트 learning 폐기).

- **경로**: `~/.claude/skills/harness/agents/learning/<agent-name>.md` (공용)
- 매 호출 시 메인 Claude 가 Read 해 prompt 에 prepend. 파일이 비어 있으면 `(빈 파일)` 명시. 마스터 누락 시 `harness-setup` 으로 재install 권고 후 `(빈 파일)` 로 진행.
- 메인 Claude 가 페르소나 자리를 직접 수행(통합 모드)할 때도 동일 적용.
- 일반 skill/agent(`plan`·`code-review`·`security-review`·`tdd`·`build-fix`·`architect`·`code-reviewer` 등 harness 전용 아닌 도구)는 본 계약 비대상.

상세: [docs/workflow.md](docs/workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통)

## 기본 정책: 사용자 질문 금지 (noask 기본)

> `/harness` 기본 = **noask** — 모든 결정 지점 자동 진행, `AskUserQuestion` 호출 금지. 사용자 확인이 필요하면 [`/harness-ask`](~/.claude/commands/harness-ask.md) 사용.

**docs 충돌 시 본 정책 우선**: `docs/workflow.md` · `docs/steps/*.md` 의 `AskUserQuestion` 호출·사용자 확인 분기는 *`/harness-ask` 호출 시에만* 활성. noask 모드에서는 아래 표 기본값으로 자동 진행.

**전제**: `/harness` 호출 = "끝까지 자동으로 돌려라" 명시 위임 = 모든 자동 결정의 사용자 승인. 결정 지점에서 막혀도 묻지 않음 — 아래 표 기본값 진행 또는 정의된 중단 사유 시 종료 + `report-<slug>.html` 사유 명시.

### 자동 결정 매핑 (CRITICAL — noask 정책 본질)

| 결정 지점 | 위치 | 기본 동작 | 비고 |
|----------|------|----------|------|
| 도메인 설계 skill 선택 | step2 1번 | `harness-plan` skill (noask — 입력 가정 + Open Questions + 딥 리서치 게이트 + DDD 도메인 모델 누적) | `/harness-ask` 모드는 `harness-plan-ask`. DDD 모델은 공통 업무 언어 / bounded context / aggregate·invariant / context map 을 포함. [step2-domain.md](docs/steps/step2-domain.md) |
| Chunks 모드 판정 | step3 첫 진입 | **자동** — 도메인 plan 4 신호(시나리오 수·변경 파일·의존성 레이어·UX) 중 2+ 임계값 통과 시 Chunks | vertical slice 분해 → step4~6 사이클. [Chunks 분해](docs/steps/step3-impl-plan.md#chunks-분해-절차-critical--2026-05-20-신규) |
| Chunks 사이 전환 | chunk_i step6 PASS 직후 | **자동** (다음 chunk_i+1) | commit 자동 (push 는 `.harness/.auto-push` 시) → chunks-overview 갱신 → 다음 chunk plan → step4. last chunk PASS 시 step7 |
| Chunks 회송 카운터 | step5 LGTM:NO / step6 FAIL | **chunk 별 독립 — *동일* 문제·결함 5회 시에만 중단** (서로 다른 문제 5회는 중단 아님) | 동일성 판정 = `(유형 enum, 파일경로 normalized)` 튜플 일치 |
| Chunks 별 commit | chunk_i step6 PASS 직후 | 자동 incremental commit (local only) | 메시지: `feat(<slug>): chunk <i>/<N> — <title>`. push 는 `.harness/.auto-push` 시. 실패 시 재시도 1회 → 로컬 only |
| 도메인 설계 승인 | step2 6번 | **자동 승인** | 딥 리서치와 DDD 게이트, Codex 리뷰 1회 반영 후 `domain-<slug>.html` 작성 → step3 |
| step5 *동일 문제* LGTM:NO 5회 | step5→step3 루프 | **자동 중단** (서로 다른 문제 5회 누적은 중단 아님) | report 사유 기록. [동일성 판정](docs/workflow.md#5-결함-유형-enum--라벨-회피-차단-critical) |
| step6 *동일 결함* FAIL 5회 | step6→step3 루프 | **자동 중단** (서로 다른 결함 5회 누적은 중단 아님) | 동일 |
| step6 BLOCKED (단발) | 도구 부재 / 환경 / 게이트 NO 등 | **자동 분기 — 묻지 않음** | 재시도 1회 → fail + 다중 슬러그 → (D) `paused-by-blocked` + 다음 슬러그. 단일 슬러그 → (C) 중단. BLOCKED 사유 enum: `DEPENDENCY_MISSING / EVIDENCE_GATE_FAIL / PERMISSION_DENIED / GUIDE_MISSING / ENV_UNREACHABLE / OTHER` |
| step6 *동일 사유* BLOCKED 5회 | 같은 enum 5회 누적 | **`AskUserQuestion` 호출 (noask 2번째 예외)** | (A) 환경 수정 후 재시도 / (B) 사용자 명시 동의 스킵 / (C) 중단 |
| step6 UNKNOWN (self-PASS bias 강등) | `fallback=manual self-test AND PASS` 또는 `qa-engineer 호출 0회 AND PASS` | **자동 강등 + `paused-by-unknown` 마킹** | 같은 모델 self-PASS 신뢰 불가 (arXiv 2508.06225 ECE 39–74%). 다음 step 진입 금지. 무인 모드는 다음 슬러그 자동 시작 |
| step8 commit/push 정책 | step8 진입 | **commit 자동, push 옵트인** — `.harness/.auto-push` 시에만 push | `/harness --push` 또는 `touch .harness/.auto-push` 로 opt-in. 기본은 *배포성 부작용 차단* |
| step8 push 실패 (opt-in) | git push 실패 | 재시도 1회 → 실패 시 로컬 commit 만 완료 | report 기록, 묻지 않음 |
| Codex 인증 실패 / quota 소진 | step5 등 | **자동 fallback** (`code-review` skill) | 자기리뷰 편향 안내·사용자 의사 확인 생략. report 에 "Codex fallback 사용" 명시 |
| complete 진입 전 step7 결과 처리 | step8 완료 직후 / complete 게이트 | **`AskUserQuestion` 호출 (1곳 예외)** | A: 그대로 complete (개선안 report 요약) / B: 일시정지 (`.harness/.pending-step7-review` 마커, 사용자 재호출) / C: 개선안으로 신규 워크플로우 자동 시작 (`auto_triggered_from` + 무한 chain 차단). [complete.md](docs/steps/complete.md) |
| 기타 `AskUserQuestion` 호출 후보 | 어디든 (위 2 예외 외) | **호출 자체 금지** | 합리적 기본값 결정 + `progress-<slug>.md` 1줄 로깅 |

### 금지 사항 (자체 검증)

`/harness` 실행 중 (= `/harness-ask` 아닌 한) 다음 발견 시 즉시 위반·중단 + 내부 progress 기록 (사용자 노출은 추상 메시지만 — donot.md 기밀 처리 규약 준수):

- `AskUserQuestion` 호출 — **2 예외만 허용**: ① complete 진입 전 step7 결과 처리, ② step6 *동일 사유* BLOCKED 5회 누적. 그 외 모두 위반.
- "사용자에게 확인 부탁드립니다" / "어떻게 진행할까요" / "승인 부탁드립니다" 등 사용자 의사 묻는 출력 텍스트.
- step6 BLOCKED **단발** 시 (B) "사용자 명시 스킵" 분기 사용 — 5회 누적 전까지는 자동 결정.

### 진행 로그 의무

매 자동 결정 시 `<PROJECT>/.harness/progress/progress-<slug>.md` 한 줄 append:

```
[<UTC timestamp>] AUTO-DECISION: <결정 지점 이름> → <선택한 기본값> (이유: noask 기본 정책)
```

complete 단계의 `report-<slug>.html` 에 모든 자동 결정 목록을 `## 자동 결정 기록 (noask 기본 정책)` 섹션으로 정리.

### step1 부트스트랩 — noask 플래그

step1 초기화: `.harness/.noask` 빈 파일 생성 (`.harness/.ask` 가 있으면 삭제). 이후 각 step 시작 시 이 파일 존재 여부로 noask 모드 분기 → 컨텍스트 첫 줄에 "이 step 에서 사용자에게 어떤 질문도 하지 않는다 (noask 기본 정책)" 명시.

`complete` 끝 시 `.harness/.noask` 삭제.

### 호출 직후 1회 통보 (질문 아님)

`/harness` 호출 직후 step1 진입 전 단순 통보 1회 출력 (응답 대기 안 함):

```
[noask 기본 정책] 모든 사용자 결정을 자동 진행합니다.
- 도메인 설계 → 자동 승인
- *동일* 문제·결함 5회 게이트 → 자동 중단 (서로 다른 문제 5회는 중단 아님)
- step6 BLOCKED 단발 → 자동 재시도 1회 → (D) paused-by-blocked 또는 (C) 중단
- step6 *동일* 사유 BLOCKED 5회 → 사용자 결정 요청 (noask 2번째 예외)
- push 실패 → 로컬 commit 으로 완료
모든 자동 결정은 progress-<slug>.md 와 report-<slug>.html 에 기록됩니다.
결정 지점에 사용자 확인이 필요하면 다음번에 /harness-ask 를 사용하세요.
```

---

## docs/ 안내판

| 파일 | 내용 |
|------|------|
| **[donot.md](docs/donot.md)** | **CRITICAL — 행동 규약. SKILL.md 의 모든 절차·결정 매핑보다 우선. 매 호출 Read 필수.** |
| [workflow.md](docs/workflow.md) | `/harness` 전체 흐름 — 순서·동작 사람-친화 설명 |
| [steps/](docs/steps/) | step1 ~ step8 + complete 상세 절차 (단계당 1 파일) |
| [procedures/](docs/procedures/) | 단위 절차 정본 (codex-review / customer-test / deep-research) |
| [test-guide-format.md](docs/test-guide-format.md) | step6/step7 `test-guide-<slug>.md` 양식·재료·갱신 규칙 |
| [html-output-rule.md](docs/html-output-rule.md) | 산출물 HTML 양식 규칙 (CLAUDE.md §6 정본 미러) |
