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
- 학습 데이터(`.harness/agents/learning/*.md`) 는 subagent 가 호출되지 않으므로 자동 prepend 가 일어나지 않음 → 메인 Claude 가 해당 step 시작 전 직접 읽어와 컨텍스트에 반영.

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

## CRITICAL: Step 스킵·무시 금지

**Step 자체에 정의된 규칙(워크플로우 다이어그램에 명시된 조건 분기)에 의한 것이 아니면, 어떤 step 도 스킵·통합·무시할 수 없다.**

- 허용되는 것은 step 자체에 명시된 규칙뿐이다. 예:
  - step5 의 LGTM NO → step3 루프
  - step6 의 FAIL → step3 루프, BLOCKED → 사용자 결정
  - step7 의 "전체 1회만 실행" 규칙
  - step8 의 "git remote 없으면 complete 로" 분기
- 그 외 메인 Claude·도우미 agent 의 임의 판단("간단하니 생략", "이전에 했으니 패스", "한 번에 합치자", "사용자가 급하다고 했으니 점프")은 모두 위반.
- 사용자가 step 자체 규칙에 없는 스킵을 요청하면 거절하고, 워크플로우 규칙을 따른다.
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
   └─ PASS
        ↓
step7. 커스터머 유저 테스트
   * 전체 워크플로우 중 **단 1회만** 실행
   * step3 ↔ step6 루프를 몇 번 돌든, 여기에는 한 번만 도달
   * **선행**: 동일한 test-guide-<slug>.md 참조 (step6 에서 갱신된 최신본)
   * 게이트 아님 — 결과는 보고만 하고 다음 단계로
        ↓
step8. git remote(원격 저장소) 있나?
        │
        ├─ YES → step8. commit / push → complete
        └─ NO  ───────────────────────→ complete
```

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
