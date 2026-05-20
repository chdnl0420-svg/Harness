---
name: harness-deep-researcher
description: harness 외부 리서치 wrapper. Plan-Act-Verify 반복 루프로 다중 출처 검색·교차검증. 본 skill 은 agent 형태(Task 도구 subagent_type=harness-deep-researcher)를 호출하는 wrapper. 페르소나 객관성 보존 위해 subagent 컨텍스트 유지. 라이브러리 비교/최신 모범 사례/보안 권고/마이그레이션 영향 등에 사용.
---

# harness-deep-researcher (skill wrapper)

본 skill 은 [`agents/harness-deep-researcher.md`](../harness/agents/harness-deep-researcher.md) **agent 를 호출하는 wrapper**. skill 단독으로 동작하지 않고, 메인 Claude 가 `Task` 도구로 subagent 를 호출하는 절차를 정의한다.

## 호출 조건

- step2 (`harness-plan`) Phase 2 — 외부 정보 필요 판단 시
- step5 (`harness-review`) — Codex 리뷰가 "최신 표준 확인 필요" 신호를 낼 때
- 메인 Claude 가 학습 cutoff 이후 변경 가능 영역을 다룰 때 (라이브러리 deprecation, CVE, API breaking change 등)

## 절차

1. **Learning Prepend 계약 4단계 수행** (workflow.md 참조):
   - 공용 학습 파일 Read: `~/.claude/skills/harness/agents/learning/harness-deep-researcher.md`
   - prompt 맨 앞에 `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더 prepend
   - 본 작업 요청 본문은 그 뒤에

2. **`Task` 도구 호출** (CRITICAL — `isolation: "worktree"` 금지):
   ```
   Task(
     description="<짧은 주제>",
     subagent_type="harness-deep-researcher",
     prompt="<Prior Learning 헤더 + 본 작업 요청>"
   )
   ```

3. **결과 처리** — agent 가 작성한 `.harness/research/research-<slug>-<NN>-<topic>.md` 본문을 Read 후 호출자(step2 / step5)에 verbatim 반환.

## 페르소나 객관성 (왜 agent 인가)

본 단위가 **Task subagent 로 유지되는 이유**:
- 메인 Claude 와 *별도 컨텍스트* — 메인의 가정/편향이 리서치에 새지 않음.
- subagent 가 자체 WebSearch/WebFetch 도구로 다중 출처 교차검증 수행.
- "Plan-Act-Verify" 루프가 별도 컨텍스트에서 돌아야 검증 단계가 메인 응답에 침투 안 함.

SKILL.md "자동 결정 매핑" 표가 명시한 **페르소나 3개 (qa-engineer / customer-user / deep-researcher) 중 하나**. skill 통합 대상이 아님 — 본 skill 은 agent 호출 wrapper 일 뿐.

## 관계

- 실제 작업자: [`agents/harness-deep-researcher.md`](../harness/agents/harness-deep-researcher.md) (Task 도구 subagent)
- 공용 학습 파일: `~/.claude/skills/harness/agents/learning/harness-deep-researcher.md`
- 호출자: `harness-plan` (step2 Phase 2), `harness-review` (step5 외부 검증)
- 산출물: `.harness/research/research-<slug>-<NN>-<topic>.md`
