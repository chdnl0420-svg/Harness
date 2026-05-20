---
description: /harness 의 인터랙티브(ask) 모드. AskUserQuestion 허용. step2 도메인 설계 + 자동 결정 매핑 표의 결정 지점들을 사용자에게 질문해 진행. 결정에 사용자 검토가 필요한 작업에 사용. 일반은 /harness (noask) 사용.
argument-hint: '[--push] <한 줄 목표>'
---

# /harness-ask — 인터랙티브 워크플로우 진입점

`/harness-ask <한 줄 목표>` 형태로 호출. `/harness` 와 동일한 step1~complete 흐름이지만 *결정 지점마다 `AskUserQuestion`* 으로 사용자에게 묻는 모드.

`/harness` 본체 skill ([`~/.claude/skills/harness/SKILL.md`](~/.claude/skills/harness/SKILL.md)) 의 절차를 따르되, "자동 결정 매핑" 표의 결정 지점들이 *자동 진행* 대신 *사용자 질문* 으로 변환된다.

## 호출 시 노출되는 1회 통보

```
[ask 모드] 모든 결정 지점에서 AskUserQuestion 으로 사용자에게 묻습니다.
- 도메인 설계 승인 → 사용자 확인 (1.승인 / 2.수정 / 3.취소)
- step5 LGTM:NO 시 → 회송 방향 사용자 확인
- step6 FAIL/BLOCKED 시 → 처리 방향 사용자 확인
- step8 push 여부 → 사용자 확인
- complete 전 step7 결과 처리 → 사용자 확인 (A/B/C)
중간에 noask 로 전환하려면 워크플로우 종료 후 /harness 재호출.
```

## /harness 와의 차이

| 결정 지점 | `/harness` (noask) | `/harness-ask` (ask) |
|----------|-------------------|---------------------|
| step2 도메인 설계 skill | `harness-plan` (noask 모드) | **`harness-plan-ask`** (인터랙티브 모드) |
| 도메인 설계 승인 | 자동 승인 | AskUserQuestion 3선택지 |
| 동일 문제 5회 반복 | 자동 중단 | 사용자에게 진행 여부 확인 |
| step6 BLOCKED | 자동 재시도 → (D)/(C) | 사용자에게 (A)/(B)/(C) 질문 |
| step8 push | 옵트인 (`--push` 또는 마커) | 매번 사용자 확인 |
| complete 진입 | step7 결과 처리만 AskUserQuestion | 다른 결정도 추가 질문 가능 |

## step1 진입 시 자동 동작

1. **`.harness/.ask` 마커 파일 생성** (이전 `.noask` 마커가 있으면 삭제)
2. slug 생성 + `.harness/progress/progress-<slug>.md` 부트스트랩 (`모드: ask` 기록)
3. step2~complete 진행 — 각 step 시작 시 `.harness/.ask` 마커로 ask 모드 분기 적용

## 플래그

| 플래그 | 동작 |
|--------|------|
| `--push` | step8 push 도 자동 활성 (그래도 push 직전 한 번 더 사용자 확인) |

## 관련

- noask 모드: [`/harness`](harness.md) — 기본 자동 진행
- 도움말: [`/harness-help`](harness-help.md)
- 본체: [`~/.claude/skills/harness/SKILL.md`](~/.claude/skills/harness/SKILL.md) — "자동 결정 매핑" 표 참조 (각 항목의 ask 모드 동작은 "사용자에게 묻기" 로 치환)
