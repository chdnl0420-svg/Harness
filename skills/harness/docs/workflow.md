# /harness Workflow

---

## 실행 옵션

모든 harness-* 단위가 *skill* 로 통합. 메인 Claude 가 `Skill` 도구로 각 단위 호출 — Task subagent 별도 컨텍스트 가치는 *외부 CLI (codex exec)* 와 *MCP 브라우저 도구* 만 유지.

### 통합 모드 (default)

| step | 수행 주체 | 비고 |
|------|----------|------|
| step2 도메인 설계 | `harness-plan` skill (noask 동작) | 한 줄 목표 → 입력 가정 + Open Questions → 딥 리서치 필요 여부 판정 → DDD 도메인 모델(공통 업무 언어, bounded context, aggregate/invariant, context map). 필요 시 `harness-deep-researcher` 호출 후 결과 반영. `/harness-ask` 는 `harness-plan-ask` (인터랙티브) |
| step3 구현 계획 | `plan` skill — 코드베이스 설계 리서치 + DDD 코드 매핑 + DDD 마이그레이션 계획 후 Chunks 임계값 통과 시 vertical slice 분해 + chunk loop | step2 의 DDD 목표 모델을 실제 모듈·파일·테스트로 강제 적용한다. 기존 구조와 충돌하면 DDD 목표 구조 우선. 저장 직후 `core/validate-ddd-codebase.py` PASS 필요. [steps/step3-impl-plan.md Chunks 분해](steps/step3-impl-plan.md) |
| step4 구현 | 메인 Claude 직접. 빌드 실패 시 `build-fix` skill 또는 언어별 `*-build-resolver` agent | TDD 모드면 `tdd` skill / `tdd-guide` agent |
| step5 리뷰 | **Codex CLI** (`codex exec` 외부) + 보조: `code-review` / `code-reviewer` (fallback), `security-review` / `security-reviewer` (보안 민감 코드) | Codex 외부 CLI 그대로. self-review bias 차단 외부 verifier 유일 보존 |
| step6 QA | `harness-qa-engineer` agent (Task 도구) | 페르소나 객관성 보존 위해 subagent 유지. MCP 브라우저 가용성이 객관 게이트 |
| step7 커스터머 | `harness-customer-user` skill 또는 agent | [steps/step7-customer.md](steps/step7-customer.md) |
| step8 commit | 메인 Claude 직접 + Chunks 모드면 chunk 별 incremental commit | — |

**외부 의존성 (subagent 가치 유지 영역)**:
- **`harness-deep-researcher`** — step2/step3 에서 DDD 적용, 코드베이스 설계, 라이브러리/API, 보안, migration 리서치가 필요할 때 호출. 절차와 저장 형식은 [docs/procedures/deep-research-procedure.md](docs/procedures/deep-research-procedure.md) 를 따른다.
- **Codex CLI** (`codex exec`) — step5 외부 verifier. self-review bias 차단 유일 외부 단위.
- **MCP 브라우저 도구** (`mcp__Claude_in_Chrome__*`, `mcp__Claude_Preview__*`) — step6/step7 자동화 객관 게이트.

---

## CRITICAL: Learning Prepend 계약 (모든 `harness-*` agent 공통)

메인 Claude 가 `harness-*` subagent 를 **Task 도구로 호출하기 직전** 4단계를 **반드시 순서대로** 수행. 하나라도 누락 시 호출 자체 금지 (도우미가 학습을 못 본 채 작동 = 학습 시스템 무력화).

### 단계

1. **학습 파일 경로 식별** (공용 only): `~/.claude/skills/harness/agents/learning/<agent-name>.md`
2. **Read 도구로 실제 본문 읽기**. 기억·요약·추측 금지. 파일 없으면 "(빈 파일)" 명시.
3. **호출 prompt 의 맨 앞에 아래 `Required Header` 양식 그대로 prepend**. 본문 통째로 붙임 — 잘라내지 않음.
4. **본문 끝에 본 작업 요청 붙임.** 도우미 prompt 순서: `Required Header → 본 작업`.

### Required Header 양식

```
## Prior Learning (READ FIRST — DO NOT SKIP)

**학습 파일 (공용)**: <절대경로>/agents/learning/<agent-name>.md

### 공용 학습 본문
<위 공용 파일을 Read 한 본문 전체 — 빈 파일이면 "(빈 파일)" 명시>

### 적용 의무
- 본 작업 시작 전 위 본문을 처음부터 끝까지 읽고, 본 작업에 적용 가능한 항목을 머릿속에 정리한다.
- 작업 중 학습과 충돌하는 결정을 내리면, 응답 본문에 "기존 학습 X 와 충돌. 이유: ..." 명시.
- 응답 마지막에 `## Learning Proposals` 섹션 (변경 없으면 생략 — templates/learning-proposal.md 형식).
- 학습 파일을 직접 Edit/Write 하지 않는다. 제안만 한다.

---

## 본 작업
<원 요청 본문>
```

### 도우미 측 검증 (자체 거부 게이트)

각 `harness-*` agent 는 prompt 첫 200줄 안에 `## Prior Learning (READ FIRST` 헤더 부재 시 즉시 한 줄 거부: `[BLOCKED] Prior Learning header 누락 — workflow.md "Learning Prepend 계약" 위반.` 그 외 작업 일체 금지.

### 메인 Claude 직접 수행 시

subagent 호출 없이 메인 Claude 가 페르소나 작업을 직접 수행할 때도 **그 step 수행 직전 동일하게 공용 학습 파일을 Read** 해 본인 컨텍스트에 올림. 누락 = 위반.

### 적용 범위

`harness-deep-researcher` · `harness-qa-engineer` · `harness-customer-user` 3개 페르소나 도우미만 적용. 일반 skill/agent (`plan`, `tdd`, `code-review`, `security-review`, `build-fix` 등) 는 harness 전용이 아니므로 본 계약 비대상. 외부 CLI(Codex) 도 subagent 아니므로 적용 안 됨.

---

## CRITICAL: noask 정책 문구 가공 금지

메인 Claude 가 BLOCKED·FAIL·UNKNOWN 처리 시 다음 표현으로 "완료" 처럼 윤색하는 것 **금지**. 위반 시 즉시 워크플로우 중단 + `report-<slug>.html` 에 위반 기록 (사용자 노출은 donot.md 기밀 처리 규약 준수).

**금지어 (정확 일치 + 의미 일치 모두 차단)**:
- `완료 처리` / `약식 완료` / `정상 종료 처리`
- `스킵 처리` / `이번엔 스킵` / `간단하니 생략`
- `통과 가정` / `통과로 간주` / `사실상 통과`
- `자체 판단으로 진행` / `메인이 직접 확인했으므로 OK`

BLOCKED 자동 처리 결과는 다음 4개 중 **하나뿐** (SKILL.md 자동 결정 매핑 표 참조):

1. **자동 재시도 1회 → 성공 (PASS)** — `qa-<slug>.md` 에 재시도 증거 4필드 (`retry_attempted` / `retry_enum_diagnosed` / `retry_action` / `retry_result`) 첨부.
2. **재시도 fail + 다중 슬러그 → (D) `paused-by-blocked`** — progress 마킹 + 다음 슬러그 자동 시작.
3. **재시도 fail + 단일 슬러그 → (C) 워크플로우 중단** — progress 마킹 + report 사유 기록 후 종료. **commit/push/complete 진입 절대 금지.**
4. **동일 사유 5회 누적 → AskUserQuestion** (noask 정책 2번째 예외).

"완료 처리" / "약식 완료" 라는 옵션은 워크플로우에 정의되어 있지 않음. (C) 중단을 "완료" 로 라벨링하는 모든 시도 = 정책 위반.

자체 검증: 매 BLOCKED 회차 보고 직후 `progress-<slug>.md` grep:
```
grep -nE "완료 처리|약식 완료|스킵 처리|통과 가정|간단하니 생략|자체 판단으로 진행" .harness/progress/progress-<slug>.md
```
1건 매치 시 즉시 워크플로우 중단 + 내부 progress 에 매치 줄 인용 (사용자 노출은 추상 메시지).

---

## CRITICAL: Step 스킵·무시 금지

**Step 자체에 정의된 규칙(워크플로우 다이어그램 명시 조건 분기)에 의한 것이 아니면, 어떤 step 도 스킵·통합·무시 금지.**

- 허용되는 step 내장 규칙:
  - step5 LGTM:NO → step3 루프
  - step6 FAIL → step3 루프, BLOCKED → 사용자 결정 (A/B/C)
  - step6 BLOCKED (B) "사용자 명시 동의 스킵" — *사용자 자율 스킵의 유일한 예외 경로*. 사용자가 환경 한계 인지 상태에서 명시 승인 시에만 적용.
  - step7 "전체 1회만 실행" 규칙 (github/commit 직전 게이트)
  - step8 commit/push 실패 → 사용자 결정 (재시도 / 브랜치 수정 / 로컬 commit 만 완료)
  - "git remote 없으면 complete 로" 분기
- 임의 판단("간단하니 생략", "이전에 했으니 패스", "한 번에 합치자", "사용자가 급하다고 했으니 점프") 모두 위반.
- 사용자가 step 규칙 외 스킵 요청 시 거절, 워크플로우 규칙 준수 (위 step6 BLOCKED (B) 경로는 내부 정의 분기이므로 거절 대상 아님).
- 위반 시 즉시 중단 + 내부 progress 에 "step{N} 누락" 기록 (사용자 노출은 추상 메시지).

---

## 흐름

```
step1. harness 초기화
   ↓
step2. 도메인 설계
   ↓
step3. 구현 계획 (Chunks 임계값 판정 — 통과 시 chunks-overview + chunk-1 plan, 미통과 시 단일 plan)
   ↓
step4. 구현 (Chunks 모드면 현 chunk_i 만)
   ↓
step5. 리뷰 (chunks 모드면 chunk_i 변경 파일만, 회송 카운터 chunk 별 독립 5회)
   │
   ├─ LGTM:NO ──> step3 (구현 계획 수정)
   │              * 무제한 반복 — 서로 다른 문제로 LGTM:NO 가 누적되는 한 계속 진행
   │              * **동일 문제** (같은 (유형 enum, 파일경로) 튜플) 5회 반복 시에만 → 중단
   │              * 매번 다른 결함 해결 중이면 중단 안 됨
   │
   └─ LGTM:YES
        ↓
step6. QA 테스트
   * **선행**: test-guide-<slug>.md 작성/갱신 후 도우미에 참조시킴
   │
   ├─ FAIL ──> step3 (구현 계획 수정)
   │           * 무제한 반복 — 서로 다른 결함 누적 가능
   │           * **동일 결함** (같은 (유형 enum, 파일경로) 튜플) 5회 반복 시에만 → 중단
   │
   ├─ BLOCKED ──> **자동 결정 분기** (사용자에게 묻지 않음)
   │              * 1차: 자동 재시도 1회 (의존성·환경 재점검 + 도우미 재호출)
   │              * 재시도 fail + 다중 슬러그 → (D) paused-by-blocked + 다음 슬러그
   │              * 재시도 fail + 단일 슬러그 → (C) 자동 중단
   │              * 매 BLOCKED 회차마다 progress 의 step6 BLOCKED 누적 카운터 + 사유 enum 기록
   │              * **동일 사유 BLOCKED 5회 누적 시에만 → AskUserQuestion** (noask 정책 2번째 예외)
   │                · (A) 환경 수정 후 재시도 / (B) 사용자 명시 동의 스킵 / (C) 워크플로우 중단
   │              * 산출물 게이트 (5b) 1축 NO 시 자동 BLOCKED 강등 — 사유 enum = EVIDENCE_GATE_FAIL
   │              * BLOCKED 사유 enum 6종: DEPENDENCY_MISSING | EVIDENCE_GATE_FAIL | PERMISSION_DENIED | GUIDE_MISSING | ENV_UNREACHABLE | OTHER
   │
   ├─ UNKNOWN ──> 슬러그 `paused-by-unknown` 마킹 + report 사유 기록
   │              * fallback = manual self-test + PASS 라벨 시 자동 강등
   │              * harness-qa-engineer 호출 0회 + PASS 라벨 시 자동 강등
   │              * noask 무인 모드면 다음 슬러그 자동 시작
   │
   └─ PASS (라벨 추출 규칙 충족 + 산출물 게이트 3축 YES + self-PASS 아닐 때만 인정)
        ↓
   ┌─ Chunks 모드 분기 (step3 임계값 통과 시):
   │   chunk_i git commit + push 자동 (step8 절차) → chunks-overview 의 chunk_i 상태 `done`
   │   if chunk_i < N: chunk_i += 1 → step3 의 *다음 chunk plan 작성* → step4 (chunk_i+1) ... 반복
   │   if chunk_i == N: 아래 step7 진입
   │
   └─ 단일 모드 또는 Chunks last chunk PASS:
        ↓
step7. 커스터머 유저 테스트
   * 전체 워크플로우 중 **단 1회만** 실행 — github/commit 직전 마지막 게이트
   * step3 ↔ step6 루프 횟수와 무관. 모든 구현 끝난 시점에 1회만 도달
   * **선행**: 동일한 test-guide-<slug>.md 참조 (step6 갱신 최신본)
   * 게이트 아님 — 결과 보고만 하고 다음 단계로
        ↓
step8. git remote 있나?
        │
        ├─ YES → step8. commit / push
        │          ├─ 성공 → complete 진입 전 사용자 확인 → complete
        │          └─ 실패 → 사용자 결정 요청 (재시도 / 브랜치 수정 / 로컬 commit 만 완료)
        │
        └─ NO  ───────────────────────→ complete 진입 전 사용자 확인 → complete

noask 예외 — 단 2곳 (그 외 모두 자동 결정):

(예외 1) complete 진입 전 step7 결과 처리 확인:
   메인 Claude 가 AskUserQuestion 호출.
   ├─ A. 그대로 complete 진행 (개선안 report 에 요약)
   ├─ B. 일시정지 (.harness/.pending-step7-review 마커, 사용자가 재호출)
   └─ C. 개선안으로 신규 워크플로우 자동 시작
        ├─ 현 워크플로우는 complete 완료 처리 (report 작성 + 종료)
        ├─ customer-<slug>.md 의 권고/있었으면/없었으면 합성 → 신규 한 줄 목표
        ├─ 신규 progress 에 auto_triggered_from: <원본 slug> 기록
        └─ 무한 chain 차단: 신규 워크플로우 step7 게이트에선 C 비활성 (A/B 만)

(예외 2) step6 *동일 사유* BLOCKED 5회 누적:
   매 BLOCKED 회차마다 progress 의 `step6 BLOCKED 누적` 카운터 + 사유 enum 누적.
   같은 사유 enum 5회째 발생 시에만 AskUserQuestion 호출.
   ├─ A. 환경 수정 후 재시도
   ├─ B. 사용자 명시 동의 스킵
   └─ C. 워크플로우 중단
   * 4회까지는 자동 결정 — 재시도 1회 → 다중 슬러그면 (D) paused-by-blocked, 단일 슬러그면 (C) 자동 중단
   * 서로 다른 사유로 5회 누적은 트리거 아님
```

**"동일 문제 / 동일 결함" 판정 (CRITICAL):** 동일 파일 경로 + 동일 오류 유형(13종 enum). 표현이 달라도 유형·위치 동일 시 동일. step5 와 step6 카운터 독립.

**중단 조건 (CRITICAL — 흔히 오해되는 부분)**:
- "5회 LGTM:NO" / "5회 FAIL" *자체* 로는 중단되지 **않음**.
- 중단 조건은 **"동일 (유형 enum, 파일경로) 튜플의 LGTM:NO / FAIL 누적 5회"**.
- 매 회차마다 *다른 결함* 해결 중이면 무한 반복 가능 (예: TYPE_ERROR @ a.ts, NULL_REFERENCE @ b.ts ...) — *각 회차마다 진척 중* 이라는 신호.
- 같은 (유형, 파일) 조합이 5회째 등장 시 중단. *동일 접근의 한계* 신호.
- 동일 문제 판정은 progress 파일 `## Loop Counter` 섹션 매 회차 라벨로 갱신, step5/6 결정 보고의 "이번 루프 회차" 필드에 *동일 문제 유형 enum = YES | NO* 명시 필수.

**"5회" 임계값 선택 이유:** 비용 보수성 — 1 루프당 Codex 호출 + 컨텍스트 재처리 비용 누적. 일반 LLM tool-call 산업 상한(약 15회) 대비 보수적 5회. *같은 문제로* 5회 실패 = *동일 접근의 한계*.

---

## CRITICAL: 회송 경로 실행 보장 (step5 LGTM:NO / step6 FAIL → step3)

분기 라벨이 다이어그램에 있어도 메인 Claude 가 자율 판단으로 우회하면 회송 미발동. 다음 4개 메커니즘이 *모두* 작동해야 회송 실제 발동.

### (1) 다음 step 결정 보고 — 게이트

step5/step6 종료 직후 메인 Claude 가 채팅에 5필드 결정 보고 출력. 출력 없이 다음 step 호출 시 step 스킵 위반. 양식: [steps/step5-review.md](steps/step5-review.md#critical-다음-step-결정-보고-게이트--출력-없이-다음-step-진입-금지) / [steps/step6-qa.md](steps/step6-qa.md#critical-다음-step-결정-보고-게이트--출력-없이-다음-step-진입-금지).

### (2) 루프 카운터 누적 — progress 파일 표준화

`progress-<slug>.md` 에 다음 `## Loop Counter` 섹션 누적. step5/6 fail 보고 시 카운터 증가, 다음 step 결정 보고의 "이번 루프 회차" 필드에 그 값 인용. 누락 시 5회 자동 중단 게이트 미발동 = 정책 위반.

```markdown
## Loop Counter
- step5 LGTM:NO 누적: <N>회
  - 직전 회차 결함 유형·파일: <유형 enum> @ <파일경로>
  - 동일 문제 여부 판정: 직전 회차와 (유형 + 파일경로) 조합이 동일 = YES, 다르면 NO
- step6 FAIL 누적: <M>회
  - 직전 회차 결함 유형·파일: <유형 enum> @ <파일경로>
  - 동일 결함 여부 판정: ...
- step6 BLOCKED 누적: <B>회
  - 직전 회차 BLOCKED 사유: <사유 enum>
  - 동일 사유 여부 판정: 직전 회차와 사유 enum 일치 = YES, 다르면 NO
  - 동일 사유 5회 누적 시 → AskUserQuestion (noask 2번째 예외)
```

세 카운터 모두 독립. 서로 공유 안 함.

### (3) 자체 수정 우회 차단

step5/6 결정 보고의 자기 점검 항목 ("이번 fail 후 메인 Claude 가 코드/구현 파일을 직접 수정했는가?") 이 YES 면 즉시 워크플로우 중단. fail 후 메인 Claude 가 코드 직접 고치고 LGTM:YES / PASS 처리하는 anti-pattern 차단. 수정 의도 시 반드시 step3 회송 → 정식 plan 반영.

**자기 점검의 객관 검증 (git diff 게이트, CRITICAL — 정직성 의존 제거)**: 자기 점검 항목 값을 메인 Claude 자체 답에 의존하지 않음. step5/6 결정 보고 출력 직전 자동 실행:

```bash
git diff <step4_commit_sha>..HEAD -- <step4 변경 파일 목록>
```

- `<step4_commit_sha>` = step4 진입 시 `git rev-parse HEAD` 결과를 `progress-<slug>.md` 에 자동 기록한 값.
- diff 가 비어 있지 않으면 **자체 수정 = YES 자동 라벨**. 메인 Claude 자기 점검 값 NO 면 *불일치* — 즉시 워크플로우 중단 + 내부 progress 에 "정책 위반: git diff 와 자기 점검 불일치" 기록.
- diff 비어 있으면 자체 수정 = NO 확정.

이로써 정직성 의존 없이 객관 게이트만으로 자체 수정 우회 차단.

### (4) 회송 시 결함 전달 양식 — step3 의 입력

step5/6 → step3 회송 시 직전 회차 결함 본문을 step3 의 plan skill 호출 prompt 에 prepend. 양식·절차: [steps/step3-impl-plan.md](steps/step3-impl-plan.md#회송-진입-모드-절차-critical--no-op-회송-차단) "회송 진입 모드 절차". 결함 항목이 새 plan 의 변경 대상에 실제 차이로 반영되어야 step4 진입 허용 — *no-op 회송* 최종 차단선.

### (5) 결함 유형 enum — 라벨 회피 차단 (CRITICAL)

"동일 문제 여부" 판정의 *유형* 라벨이 메인 Claude free-form 이면 같은 결함을 다른 유형으로 적어 5회 임계 우회 가능. 다음 13종 enum 중 하나로만 라벨링:

```
TYPE_ERROR | NULL_REFERENCE | PERMISSION_DENIED |
RESOURCE_NOT_FOUND | RACE_CONDITION | LOGIC_ERROR |
IO_FAILURE | TIMEOUT | API_CONTRACT | SECURITY |
TEST_COVERAGE | BUILD_FAILURE | OTHER
```

규칙:
- enum 외 값 거부 (progress 파일 검증 시 즉시 정책 위반 기록).
- 동일 문제 판정: `(유형 enum, 파일경로 normalized)` 튜플 동일 시 YES. `파일경로 normalized = repo 상대경로 + 소문자`.
- **OTHER 5회 누적 시 자동 사용자 alert** — OTHER 는 매번 새 fingerprint 로 분리되지 않으므로 라벨링 실패 신호. report 에 "OTHER 누적으로 라벨링 정밀도 부족" 기록.
- step5 와 step6 enum 카운터 독립.

### 적용 검증

위 5개 메커니즘이 모두 작동하면 다음 5개 시나리오가 통과 (자체 회귀 검증):

1. LGTM:NO 1회 → step5 결정 보고 출력 → step3 회송 → plan prompt 에 직전 review 본문 prepend → 새 implementation 변경분 생성 → step4 진입.
2. FAIL 1회 → step6 결정 보고 + Loop Counter 1회 누적 → step3 회송 → plan prompt 에 직전 qa fail 본문 prepend.
3. 동일 문제 5회 반복 → 자동 중단 + report 사유 기록.
4. 자체 수정 우회 시도 → 자기 점검 YES → 워크플로우 중단.
5. no-op 회송 시도 → step3 "변경분 검증 게이트" 차단 → 결함 반영 요구.

## Step 이름 + 상세 절차 링크

| step | 한 줄 | 상세 |
|------|------|------|
| step1 | harness 초기화 | [steps/step1-init.md](steps/step1-init.md) |
| step2 | 사용자 요청을 구체적 전문적 계획으로 (architecture 가 보고 구현 계획 가능하도록) | [steps/step2-domain.md](steps/step2-domain.md) |
| step3 | 구현 계획 작성 | [steps/step3-impl-plan.md](steps/step3-impl-plan.md) |
| step4 | 구현 | [steps/step4-impl.md](steps/step4-impl.md) |
| step5 | 리뷰 + LGTM 판정 | [steps/step5-review.md](steps/step5-review.md) |
| step6 | QA 테스트 (PASS / FAIL 게이트) | [steps/step6-qa.md](steps/step6-qa.md) |
| step7 | 커스터머 유저 테스트 (전체 1회) | [steps/step7-customer.md](steps/step7-customer.md) |
| step8 | git commit / push (remote 있을 때만) | [steps/step8-commit.md](steps/step8-commit.md) |
| complete | 결과 정리 | [steps/complete.md](steps/complete.md) |

---

## 테스트 가이드 문서 (`.harness/test-guide-<slug>.md`)

step6 / step7 두 도우미가 동일 기준으로 테스트하도록 메인 Claude 가 step6 의 1단계로 작성하는 입력 문서.

양식·작성 재료·갱신 규칙: [test-guide-format.md](test-guide-format.md)

---

## 부록: Codex 리뷰 방법

`codex` CLI 는 Windows native (npm-installed) 라 Bash 에서 직접 호출. 자세히: [`/harness-review`](~/.claude/commands/harness-review.md) · [`agents/codex-reviewer.md`](../agents/codex-reviewer.md).

**4단계 흐름**:

1. **리뷰 대상 파일 경로 목록을 file-list MD 로 저장**:
   ```
   .harness/reviews/review-<slug>-file-list.md
   ```
   *경로만* (각 줄 `- <path>`). focus·instructions·코드 본문 일체 금지.

2. **`codex exec` 직접 호출** (Bash):
   ```bash
   codex exec --sandbox workspace-write \
     ".harness/reviews/review-<slug>-file-list.md 에 적힌 파일들 전부 리뷰해줘. 리뷰 결과는 .harness/reviews/codex-review-<slug>-result.md 에 작성해줘."
   ```
   **위 한 줄 프롬프트 외 추가 텍스트 절대 금지.** Codex 가 file-list.md 를 자체 file-read 로 읽고 자체 형식으로 result 작성.

3. **결과 파일 Read**: `.harness/reviews/codex-review-<slug>-result.md`. 비어 있거나 *"리뷰 못 함"* 이면 STOP, 호출자/사용자 보고. fake 응답 생성 금지.

4. **호출자에게 verbatim 반환** + result 절대경로 한 줄 보고.

**Codex fallback 시 주의:** Codex 인증 실패(exit 2) 또는 quota 소진(exit 3) 시 `code-review` skill 또는 `code-reviewer` agent 로 전환. 이 경우 **Claude 가 구현·리뷰 모두 수행** → self-review bias 제거 효과 사라짐. 메인 Claude 는 `fallback_used` 필드 명시 (workflow.md "회송 경로 실행 보장" 7필드 양식 참조), self-review LGTM:YES 는 자동으로 `LGTM:UNKNOWN` 강등.
