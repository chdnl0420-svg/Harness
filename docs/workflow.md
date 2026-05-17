# /harness Workflow

---

## 실행 옵션

### 기본 모드 (옵션 없음)

| step | 수행 주체 | 비고 |
|------|----------|------|
| step2 도메인 설계 | `plan` skill (메인 Claude 가 직접 수행) | 사용자 의도 정확 이해·연속성 |
| step3 구현 계획 | `plan` skill (메인 Claude) | step2 연속성 |
| step4 구현 | 메인 Claude 직접 | — |
| step5 리뷰 | **Codex CLI** (subagent 아님, 그대로 유지) | Codex 불가 시 fallback: `code-review` skill |
| step6 QA | **`harness-qa-engineer` subagent** | 테스터 페르소나 — 결과 품질 위해 subagent 유지 |
| step7 커스터머 | **`harness-customer-user` subagent** | 일반인 페르소나 — subagent 유지 |
| step8 commit | 메인 Claude 직접 | 변경 맥락 직접 봄 |

요약: **QA / 커스터머 step 만 subagent, 나머지는 skill 또는 메인 Claude 직접.** Codex 리뷰는 외부 CLI 이므로 그대로.

### `--noagent` 모드

`/harness --noagent ...` 로 호출되면 **모든 harness-* subagent(Task tool 위임)을 일절 사용하지 않는다 — 기본 모드에서 subagent 로 돌던 step6/step7 까지 포함.** Workflow 자체는 step1 → complete 까지 동일하게 진행하되, subagent 자리는 **대체 가능한 skill 이 있으면 그 skill 을 호출**하고, 없으면 메인 Claude 가 직접 수행한다.

규칙:
- `harness-planner`, `harness-architect`, `harness-tdd-guide`, `harness-code-reviewer`, `harness-security-reviewer`, `harness-build-resolver`, `harness-qa-engineer`, `harness-customer-user` 등 모든 harness subagent 호출 금지.
- 외부 CLI(Codex wrapper) 은 subagent 가 아니므로 그대로 사용.
- Step 자체 규칙(CRITICAL 섹션 참고) 은 모두 그대로 — `--noagent` 는 "어떻게 수행하는가" 만 바꿀 뿐 "어떤 step 을 거치는가" 는 바꾸지 않는다.
- 학습 데이터(`.harness/agents/learning/*.md`) 는 subagent 가 호출되지 않으므로 자동 prepend 가 일어나지 않음 → 메인 Claude 가 해당 step 시작 전 **"Learning Prepend 계약"** 의 1·2단계 (파일 경로 식별 + Read) 를 본인이 직접 수행해 본문을 컨텍스트에 올린다. 예: step6 은 `harness-qa-engineer.md`, step7 은 `harness-customer-user.md`.

#### `--noagent` 모드의 step6 / step7 처리

기본 모드와 달라지는 곳은 step6, step7 뿐이다 (나머지는 기본 모드도 이미 skill / 메인 직접).

| step | `--noagent` 시 수행 | 비고 |
|------|--------------------|------|
| step6 QA | `browser-qa` skill (없으면 `e2e`, 그것도 없으면 `verify`, 다 없으면 메인 직접 수동 테스트 보고) | 페르소나 가치 잃음 — 결과 품질 저하 가능 |
| step7 커스터머 | `browser-qa` skill (페르소나 입혀서, 없으면 메인이 일반인 흉내) | 동일 |

플래그 파싱:
- `--noagent` 가 사용자 입력 어디든 포함되어 있으면 켜진다.
- step1 에서 `.harness/.noagent` 파일로 상태를 기록해 두고, 이후 step 에서 매번 참조.

---

## CRITICAL: Learning Prepend 계약 (모든 `harness-*` agent 공통)

메인 Claude 가 `harness-*` subagent 를 **Task 도구로 호출하기 직전**에 다음 4단계를 **반드시 순서대로** 수행한다. 하나라도 빠지면 호출 자체를 하지 않는다 (도우미가 학습을 못 본 채 작동 = 학습 시스템 무력화).

### 단계 (모든 호출 공통)

1. **학습 파일 경로 식별 (Hybrid)**
   - 공용: `~/.claude/skills/harness/agents/learning/<agent-name>.md`
   - 프로젝트: `<PROJECT_ROOT>/.harness/agents/learning/<agent-name>.md` (있을 때만)
   - `<PROJECT_ROOT>` 는 메인 repo 루트. worktree 안이면 `git rev-parse --git-common-dir` 의 부모.
2. **Read 도구로 두 파일 본문을 실제로 읽는다.** 기억·요약·추측 금지. 파일 없으면 "(없음)" 으로 명시.
3. **호출 prompt 의 맨 앞에 아래 `Required Header` 양식 그대로 prepend.** 본문 통째로 붙이며, 절대 잘라내지 않는다.
4. **본문 끝에 본 작업 요청을 붙인다.** 즉 도우미가 받는 prompt 순서는 `Required Header → 본 작업` 이다.

### Required Header 양식

```
## Prior Learning (READ FIRST — DO NOT SKIP)

**학습 파일 (공용)**: <절대경로>/agents/learning/<agent-name>.md
**학습 파일 (프로젝트)**: <PROJECT_ROOT>/.harness/agents/learning/<agent-name>.md  (없으면 "(없음)")

### 공용 학습 본문
<위 공용 파일을 Read 한 본문 전체 — 빈 파일이면 "(빈 파일)" 명시>

### 프로젝트 학습 본문
<위 프로젝트 파일을 Read 한 본문 전체 — 없으면 "(없음)">

### 적용 의무
- 본 작업 시작 전 위 두 본문을 처음부터 끝까지 읽고, 본 작업에 적용 가능한 항목을 머릿속에 정리한다.
- 작업 중 학습과 충돌하는 결정을 내리면, 응답 본문에 "기존 학습 X 와 충돌. 이유: ..." 명시.
- 응답 마지막에 `## Learning Proposals` 섹션 (변경 없으면 생략 — templates/learning-proposal.md 형식).
- 학습 파일을 직접 Edit/Write 하지 않는다. 제안만 한다.

---

## 본 작업
<원 요청 본문>
```

### 도우미 측 검증 (자체 거부 게이트)

각 `harness-*` agent 는 prompt 첫 200줄 안에 `## Prior Learning (READ FIRST` 헤더가 **없으면** 즉시 한 줄로 거부하고 종료한다: `[BLOCKED] Prior Learning header 누락 — workflow.md "Learning Prepend 계약" 위반.` 그 외 작업 일체 금지.

### `.harness/.noagent` 모드일 때

subagent 를 호출하지 않으므로 위 prepend 가 의미 없어 보이지만, **메인 Claude 자신이 그 step 을 수행하기 직전에 동일하게 두 학습 파일을 Read** 하고 본문을 본인 컨텍스트에 올린다. 누락하면 학습이 반영 안 됨 = 위반.

### 적용 범위

`harness-planner`, `harness-architect`, `harness-tdd-guide`, `harness-code-reviewer`, `harness-security-reviewer`, `harness-build-resolver`, `harness-deep-researcher`, `harness-qa-engineer`, `harness-customer-user` — **모두 동일.** 외부 CLI(Codex) 는 subagent 가 아니므로 적용 안 됨.

---

## CRITICAL: Step 스킵·무시 금지

**Step 자체에 정의된 규칙(워크플로우 다이어그램에 명시된 조건 분기)에 의한 것이 아니면, 어떤 step 도 스킵·통합·무시할 수 없다.**

- 허용되는 것은 step 자체에 명시된 규칙뿐이다. 예:
  - step5 의 LGTM NO → step3 루프
  - step6 의 FAIL → step3 루프, BLOCKED → 사용자 결정 (A/B/C)
  - step6 BLOCKED 분기 (B) "사용자 명시적 동의 스킵 승인" — **사용자 자율 스킵의 유일한 예외 경로**. 사용자가 환경 한계를 인지한 상태에서 명시적으로 승인할 때만 적용.
  - step7 의 "전체 1회만 실행" 규칙 (github/commit 직전 게이트)
  - step8 commit/push 실패 → 사용자 결정 (재시도 / 브랜치 수정 / 로컬 commit 만 완료)
  - "git remote 없으면 complete 로" 분기
- 그 외 메인 Claude·도우미 agent 의 임의 판단("간단하니 생략", "이전에 했으니 패스", "한 번에 합치자", "사용자가 급하다고 했으니 점프")은 모두 위반.
- 사용자가 step 자체 규칙에 없는 스킵을 요청하면 거절하고, 워크플로우 규칙을 따른다. 단 위의 step6 BLOCKED (B) 경로는 사용자 결정 분기로 워크플로우 내부에 정의돼 있으므로 거절 대상 아님.
- 위반 발생 시 즉시 중단하고 "step{N} 누락" 으로 사용자에게 보고한다.

---

## 흐름

```
step1. harness 초기화
   ↓
step2. 도메인 설계
   ↓
step3. 구현 계획
   ↓
step4. 구현
   ↓
step5. 리뷰
   │
   ├─ LGTM: NO ──> step3 (구현 계획 수정)
   │              * 무제한 반복
   │              * 동일 문제 5회 반복 시 → 중단 + 사용자에게 알림
   │
   └─ LGTM: YES
        ↓
step6. QA 테스트
   * **선행**: test-guide-<slug>.md 작성/갱신 후 도우미에 참조시킴
   │
   ├─ FAIL ──> step3 (구현 계획 수정)
   │           * 무제한 반복
   │           * 동일 결함 5회 반복 시 → 중단 + 사용자에게 알림
   │
   ├─ BLOCKED ──> 사용자 결정 요청
   │              (A) 환경 수정 후 재시도
   │              (B) 이 step 스킵 승인 (사용자 명시적 동의 필요)
   │              (C) 워크플로우 중단
   │
   └─ PASS
        ↓
step7. 커스터머 유저 테스트
   * 전체 워크플로우 중 **단 1회만** 실행 — github/commit 직전 마지막 게이트
   * step3 ↔ step6 루프 횟수와 무관. 모든 구현이 끝난 시점에 1회만 도달
   * **선행**: 동일한 test-guide-<slug>.md 참조 (step6 에서 갱신된 최신본)
   * 게이트 아님 — 결과는 보고만 하고 다음 단계로
        ↓
step8. git remote(원격 저장소) 있나?
        │
        ├─ YES → step8. commit / push
        │          ├─ 성공 → complete
        │          └─ 실패 → 사용자 결정 요청
        │                    (재시도 / 브랜치 수정 / 로컬 commit 만 완료로 처리)
        │
        └─ NO  ───────────────────────→ complete
```

**"동일 문제 / 동일 결함" 판정 기준:** 동일 파일 경로 + 동일 오류 유형(예: 타입 오류, null 참조, 권한 오류) 조합. 표현이 달라도 유형과 위치가 같으면 동일로 간주. step5 와 step6 의 카운터는 공유하지 않고 각자 독립으로 카운트한다.

**"5회" 임계값 선택 이유:** 비용 보수성을 위한 선택. 1 루프당 Codex 호출 + 컨텍스트 재처리 비용이 누적되므로, 일반 LLM tool-call 산업 상한(약 15회) 대비 보수적인 5회를 채택했다. 같은 문제로 5회 실패 = *동일 접근* 의 한계로 판단하고 사용자 의사 결정에 맡긴다.

## Step 이름 + 상세 절차 링크

| step | 한 줄 | 상세 |
|------|------|------|
| step1 | harness 초기화 | [steps/step1-init.md](steps/step1-init.md) |
| step2 | 사용자 요청을 구체적이고 전문적인 계획으로 만드는 단계 (architecture 가 보고 구현 계획을 세울 수 있도록) | [steps/step2-domain.md](steps/step2-domain.md) |
| step3 | 구현 계획 작성 | [steps/step3-impl-plan.md](steps/step3-impl-plan.md) |
| step4 | 구현 | [steps/step4-impl.md](steps/step4-impl.md) |
| step5 | 리뷰 + LGTM 판정 | [steps/step5-review.md](steps/step5-review.md) |
| step6 | QA 테스트 (PASS / FAIL 게이트) | [steps/step6-qa.md](steps/step6-qa.md) |
| step7 | 커스터머 유저 테스트 (전체 워크플로우 중 1회) | [steps/step7-customer.md](steps/step7-customer.md) |
| step8 | git commit / push (remote 있을 때만) | [steps/step8-commit.md](steps/step8-commit.md) |
| complete | 결과 정리 | [steps/complete.md](steps/complete.md) |

---

## 테스트 가이드 문서 (`.harness/test-guide-<slug>.md`)

step6 / step7 의 두 도우미가 동일한 기준으로 테스트하도록 메인 Claude 가 step6 의 1단계로 작성하는 입력 문서.

양식·작성 재료·갱신 규칙: [test-guide-format.md](test-guide-format.md)

---

## 부록: Codex 리뷰 방법

1. 변경 파일 내용을 prompt 파일로 저장 (예: `.harness/reviews/_input.txt`)
2. WSL 에서 Codex wrapper 호출:
   ```bash
   wsl bash .harness/wrappers/codex-review.sh --prompt-file .harness/reviews/_input.txt
   ```
3. Codex 응답을 `review-<slug>.md` 에 누적

**Codex fallback(대안 사용) 시 주의:** Codex 가 인증 실패 등으로 불가해 `code-review` skill 로 전환되면 **Claude 가 구현과 리뷰를 모두 수행**한다. 자기편향(self-review bias) 제거 효과가 사라지므로, 메인 Claude 는 이 사실을 사용자에게 알리고 진행 의사를 확인한다.
