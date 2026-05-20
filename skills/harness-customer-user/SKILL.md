---
name: harness-customer-user
description: harness step7 커스터머 테스트 wrapper. 제품 지식·전문 용어 모르는 일반 사용자 페르소나로 production 설치본을 스크린샷+클릭+5초 테스트+Cognitive Walkthrough 4질문으로 검증. SUS/SEQ 점수, Time-to-First-Value, 첫 클릭 정확도 측정. 본 skill 은 agent 형태(Task 도구) 호출 wrapper. 페르소나 객관성 보존 위해 subagent 컨텍스트 유지.
---

# harness-customer-user (skill wrapper)

본 skill 은 [`agents/harness-customer-user.md`](../harness/agents/harness-customer-user.md) **agent 를 호출하는 wrapper**. skill 단독으로 동작하지 않고, 메인 Claude 가 `Task` 도구로 subagent 를 호출하는 절차를 정의한다.

## 호출 조건

- step7 진입 게이트 통과 시 (step6 라벨 PASS 확인 후)
- 워크플로우 전체에서 **단 1회만** 호출 (`/harness` 흐름 다이어그램)
- `/harness-customer-user` 사용자 직접 호출 (워크플로우 외부)

## 절차

1. **메인 Claude 가 production 빌드 + 설치 + 실행** — dev 환경 금지. 사용자가 받는 그 산출물로 직접 설치/실행. [`step7-customer.md`](../harness/docs/steps/step7-customer.md) 의 2번 단계 절차 따름.

2. **Learning Prepend 계약 4단계 수행**:
   - 공용 학습 파일 Read: `~/.claude/skills/harness/agents/learning/harness-customer-user.md`
   - `test-guide-<slug>.md` 전문 prepend
   - `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더 prepend

3. **`Task` 도구 호출** (CRITICAL — `isolation: "worktree"` 금지):
   ```
   Task(
     description="customer test for <slug>",
     subagent_type="harness-customer-user",
     prompt="<Prior Learning + test-guide 전문 + 본 작업 요청>"
   )
   ```

4. **결과 처리** — agent 가 작성한 `.harness/results/customer-<slug>.md` Read. 메인 Claude 가 production 설치본 정리 (uninstall 등) 후 complete 단계로.

## 페르소나 객관성 (왜 agent 인가)

본 단위가 **Task subagent 로 유지되는 이유**:
- 메인 Claude 는 *구현자* — 코드와 디자인 의도를 알고 있어 *일반 사용자 페르소나* 흉내 불가.
- subagent 가 별도 컨텍스트에서 *"이 제품을 처음 본 사람"* 으로 시작 → 첫 클릭 정확도·헷갈린 단어 등을 객관적으로 측정.
- LLM 페르소나 함정 6종 (overconfidence, 가독성 과장, 친절 편향 등) 차단은 별도 컨텍스트에서만 가능.

SKILL.md "자동 결정 매핑" 표가 명시한 **페르소나 3개 (qa-engineer / customer-user / deep-researcher) 중 하나**. skill 통합 대상이 아님 — 본 skill 은 agent 호출 wrapper 일 뿐.

## 입력 게이트 의무

[`step7-customer.md`](../harness/docs/steps/step7-customer.md) "입력 게이트 (skip 금지)" 절을 진입 직전 자체 검증:
- `.harness/results/qa-<slug>.md` 마지막 회차 라벨이 PASS 여야 진입.
- BLOCKED/FAIL/UNKNOWN 이면 본 skill 호출 자체 금지.

## 관계

- 실제 작업자: [`agents/harness-customer-user.md`](../harness/agents/harness-customer-user.md) (Task 도구 subagent)
- 공용 학습 파일: `~/.claude/skills/harness/agents/learning/harness-customer-user.md`
- 호출자: `/harness` step7-customer.md
- 사용자 진입점: `/harness-customer-user` 슬래시 커맨드
- 산출물: `.harness/results/customer-<slug>.md`
