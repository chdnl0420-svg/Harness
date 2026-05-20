---
description: /harness 자동 워크플로우 — 자연어 목표(여러 줄 가능)를 받아 step1~complete 8단계 + complete 까지 자동 진행. noask 기본 정책. 사용자 결정 자동 진행 (2 예외만 AskUserQuestion). 페르소나 3개 도우미는 Task subagent, 그 외는 Skill 도구 통합.
argument-hint: '[--push] <자연어>'
---

# /harness — 자동 워크플로우 진입점

`/harness <자연어>` 형태로 호출. 메인 Claude 가 `harness` skill 본문 ([`~/.claude/skills/harness/SKILL.md`](~/.claude/skills/harness/SKILL.md)) 의 절차를 그대로 따라 step1~complete 까지 자동 실행한다.

## 호출 시 노출되는 1회 통보 (질문 아님)

```
[noask 기본 정책] 모든 사용자 결정을 자동 진행합니다.
- 도메인 설계 → 자동 승인
- *동일 문제·결함* 5회 반복 게이트 → 자동 중단 (서로 다른 문제로 5회 발생 시는 중단 아님)
- step6 BLOCKED 단발 → 자동 재시도 1회 → (D) paused-by-blocked 또는 (C) 중단
- step6 *동일 사유* BLOCKED 5회 누적 → 사용자 결정 요청 (noask 2번째 예외)
- step8 commit → 항상 자동 / push → 옵트인 (`.harness/.auto-push` 또는 `--push` 시에만)
모든 자동 결정은 progress-<slug>.md 와 report-<slug>.html 에 기록됩니다.
결정 지점에 사용자 확인이 필요하면 다음번에 /harness-ask 를 사용하세요.
```

## 플래그

| 플래그 | 동작 |
|--------|------|
| `--push` | step8 에서 자동 push 활성 (`.harness/.auto-push` 마커 자동 생성과 동등) |

플래그 없으면 push 안 함 (검증 워크플로우의 본질 — 배포성 부작용 차단).

## step1 진입 시 자동 동작

1. `.harness/.noask` 마커 파일 생성 (이전 `.ask` 마커가 있으면 삭제)
2. slug 생성 + `.harness/progress/progress-<slug>.md` 부트스트랩
3. step2~complete 진행 (자세히: [`~/.claude/skills/harness/docs/workflow.md`](~/.claude/skills/harness/docs/workflow.md))

## noask 정책의 2 예외

워크플로우 내부에서 `AskUserQuestion` 이 허용되는 *유일한 2 곳*:

1. **complete 진입 전 step7 결과 처리** — A/B/C 3선택지
2. **step6 동일 사유 BLOCKED 5회 누적** — A/B/C 3선택지

그 외 *어떤 step 에서든* `AskUserQuestion` 호출 = 정책 위반.

## 관련

- 인터랙티브 모드: [`/harness-ask`](harness-ask.md) — AskUserQuestion 허용
- 도움말: [`/harness-help`](harness-help.md) — 전체 명령·skill·agent 안내
- 설치 검진: [`/harness-setup`](harness-setup.md) — Codex CLI / agent 등록 / GitHub 버전 확인
- 본체: [`~/.claude/skills/harness/SKILL.md`](~/.claude/skills/harness/SKILL.md) — 자동 결정 매핑 표 + 진행 로그 의무 등 정본
