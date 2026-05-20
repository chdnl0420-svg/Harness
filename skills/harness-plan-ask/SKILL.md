---
name: harness-plan-ask
description: harness step2 도메인 설계 ask 모드 wrapper. /harness-ask 호출 또는 .harness/.ask 마커 존재 시 사용. AskUserQuestion 으로 6 카테고리 사용자 의도를 인터랙티브 수집한 뒤 plan-readability 규칙을 지키는 도메인 설계 초안을 만든다. /harness step2-domain 안에서만 호출. 일반 계획은 /plan 사용.
---

# harness-plan-ask

`/harness-ask` step2 도메인 설계 단계에서 메인 Claude 가 수행하는 **인터랙티브 plan 작성** wrapper.

본 skill 은 자매 skill `harness-plan` 의 *interactive 모드* 를 단독으로 호출하는 진입점이다. 본문은 거기서 정의된 모든 절차 (Phase 1 interactive ~ Phase 5) 를 그대로 따른다.

## 호출 조건

다음 중 하나일 때만 본 skill 진입:
1. 사용자가 `/harness-ask` 슬래시 커맨드로 호출
2. `.harness/.ask` 마커 파일 존재
3. 두 마커 (`.noask` / `.ask`) 모두 부재 + 호출 컨텍스트 불명 (사용자 안전 기본값)

## 본문 — `harness-plan` 의 interactive 절차 호출

본 skill 의 실제 작업 내용은 자매 skill [`harness-plan/SKILL.md`](../harness-plan/SKILL.md) 의 절차를 그대로 따른다. 단 다음만 강제:

- **모드 강제 = interactive**. `harness-plan` 의 Phase 1 모드 분기에서 *항상 interactive 모드* 로 진행.
- `.harness/.noask` 마커가 있어도 무시 (본 skill 진입 자체가 ask 의사 표명).
- `AskUserQuestion` 호출이 허용된 *유일한 step2 진입점*.

## 호출 직후 1회 보고 (질문 아님)

```
[harness-plan-ask] AskUserQuestion 인터랙티브 모드로 진입합니다.
6 카테고리 (시나리오/성공기준/범위/제약/외부의존성/비기능) 를 순차로 묻습니다.
중간에 "건너뛰자" 또는 "기본값" 이라고 답하면 그 카테고리는 사용자 위임으로 기록됩니다.
```

## 관계

- 자매: [`harness-plan`](../harness-plan/SKILL.md) (noask 모드 — `.harness/.noask` 또는 `/harness` 호출 컨텍스트)
- 호출자: `/harness-ask` 슬래시 커맨드 → step2-domain.md
- 산출물: `.harness/domain-<slug>.html` (interactive 모드 입력 기반 도메인 설계 HTML)
