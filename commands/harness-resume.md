---
description: /harness <자연어> 로 시작된 워크플로우를 slug 로 재개. progress-<slug>.md 의 마지막 step 을 식별해 그 다음 단계부터 SKILL.md 절차 재진입. Loop Counter·모드·산출물 모두 보존. step1 부트스트랩은 건너뜀 (기존 progress 덮어쓰기 차단).
argument-hint: '<slug>'
---

# /harness-resume — 진행중인 워크플로우 재개

`/harness-resume <slug>` 형태로 호출. 메인 Claude 가 `<PROJECT>/.harness/progress/progress-<slug>.md` 를 읽어 마지막으로 도달한 step 을 식별하고, 그 다음 단계부터 `harness` skill 본문 ([`~/.claude/skills/harness/SKILL.md`](~/.claude/skills/harness/SKILL.md)) 의 워크플로우를 이어서 자동 실행한다.

> 본 명령은 `/harness` · `/harness-ask` 와 동일한 허용 진입 경로로 인정된다 — SKILL.md 입력 게이트가 차단하지 않는다.

## 절차 (메인 Claude 가 순서대로 수행)

### 1. slug 인자 검증

- 인자 없거나 공백 → 채팅 한 줄:
  ```
  [harness-resume] slug 인자가 필요합니다. 사용법: /harness-resume <slug>
  진행 가능한 slug 목록: ls <PROJECT>/.harness/progress/progress-*.md
  ```
  후 종료. 워크플로우 진입 금지.

### 2. 메인 repo 경로 식별 + progress 파일 위치 결정

step1-init.md 와 동일 절차:

- `git rev-parse --show-toplevel` 로 현재 작업 트리
- `git rev-parse --git-common-dir` 로 공통 git 디렉토리
- 두 값이 다르면 *worktree 안* → `.harness/` 는 공통 git 디렉토리의 부모 (메인 repo 루트)
- progress 파일 경로: `<repo-root>/.harness/progress/progress-<slug>.md`

### 3. progress 파일 Read

- 파일 부재 → 채팅 한 줄:
  ```
  [harness-resume] slug "<slug>" 의 progress 파일이 없습니다.
  예상 경로: <repo-root>/.harness/progress/progress-<slug>.md
  새로 시작하려면 /harness <자연어 목표> 사용.
  ```
  후 종료.

- 파일 존재 → 전체 본문 Read.

### 4. 종료 상태 식별 (재진입 금지 케이스)

다음 조건 중 하나라도 충족하면 *재진입 안 함* + 안내 후 종료:

| 조건 | 안내 메시지 |
|------|------------|
| `<repo-root>/.harness/results/report-<slug>.html` 존재 (= complete 완료) | "이미 complete 종료된 워크플로우입니다. report 위치: <절대경로>. 같은 목표로 다시 돌리려면 /harness <자연어> 로 새 slug 시작." |
| progress 안에 `## complete` 헤더 존재 | 위와 동일 |
| `## resume <timestamp>` 이 5회 이상 누적 | "재개 시도 5회 초과. progress 파일 검토 후 수동 정리 권고." |

### 5. 모드 마커 복원

progress 의 `- 모드:` 필드 추출 → 다음 마커 파일을 *원자적으로* 동기화:

| `모드:` 값 | 마커 |
|----------|------|
| `noask` | `<repo-root>/.harness/.noask` 생성, `.ask` 삭제 |
| `ask` | `<repo-root>/.harness/.ask` 생성, `.noask` 삭제 |

마커 동기화 후 step 진입 시 SKILL.md 의 noask / ask 분기 자동 적용.

### 6. 마지막 step + 라벨 식별

progress 본문에서 가장 마지막 `## step{N} ...` 헤더와 그 섹션의 결과 라벨 추출. 라벨 패턴:

- `LGTM:YES` / `LGTM:NO` (step5)
- `PASS` / `FAIL` / `BLOCKED` / `UNKNOWN` (step6)
- `step6 BLOCKED 사유: <enum>` 라인이 있으면 enum 도 추출
- chunks 모드: `chunk_i = N / M` 표기 또는 `chunks-overview` 참조 → 현재 chunk 인덱스 + 총 N 식별

Chunks 모드인지 판정: `step3` 섹션에 *Chunks 모드 진입* 표시가 있거나 `chunks-overview-<slug>.html` 또는 그 MD 부속 파일이 `<repo-root>/.harness/` 에 존재하면 chunks 모드.

### 7. 재진입 step 판정 매트릭스

| 마지막 상태 | 다음 진입 |
|------------|----------|
| step1 도중 중단 (step2 헤더 없음) | step1 (재부트스트랩 — 단, progress 는 보존, append 모드) |
| step2 완료 (`domain-<slug>.html` 존재 + Codex 리뷰 PASS 기록) | step3 |
| step3 완료 (`implementation-<slug>.html` 존재) | step4 |
| step4 완료 (구현 commit/변경 기록 있고 step5 헤더 없음) | step5 |
| step5 LGTM:NO | step3 (loop, Loop Counter 보존) |
| step5 LGTM:YES | step6 |
| step6 FAIL | step3 (loop, Loop Counter 보존) |
| step6 BLOCKED (단발) | step6 재시도 — 자동 재시도 1회 분기 적용 |
| step6 BLOCKED *동일 사유* 5회 누적 | step6 진입 직후 noask 2번째 예외 (AskUserQuestion A/B/C) |
| step6 UNKNOWN (`paused-by-unknown` 마킹) | step6 — qa-engineer 정상 호출 + self-PASS 강등 사유 명시 |
| step6 PASS + chunks 모드 + chunk_i < N | step3 의 *다음 chunk plan 작성* → step4 (chunk_i+1) |
| step6 PASS + 단일 모드 또는 last chunk | step7 |
| step7 완료 (`customer-<slug>.md` 존재) | step8 |
| step8 commit/push 완료 + `.harness/.pending-step7-review` 마커 존재 | complete 진입 게이트 재실행 (noask 1번째 예외 — AskUserQuestion A/B/C) |
| step8 commit/push 완료 + 완료 마커 없음 | complete |

판정 불가 (헤더는 있는데 라벨 추출 실패 등) → 가장 최근 *완전히 끝난* step 의 다음 step 으로 진입. 그것도 모호하면 **step5 부터** 재시작 (구현은 그대로 두고 리뷰부터). 이유는 progress 의 `## resume` 섹션에 명시.

### 8. Loop Counter 보존

progress 의 `## Loop Counter` 섹션을 **읽기만** — 재설정 안 함. 새 값은 다음 step 진입 시 누적 갱신.

만약 `## Loop Counter` 섹션이 없으면 (옛 progress) 다음 양식으로 1회 시드:

```markdown
## Loop Counter
- step5 LGTM:NO 누적: 0회
- step6 FAIL 누적: 0회
- step6 BLOCKED 누적: 0회
```

### 9. resume entry append

재진입 직전 progress 끝에 다음 양식 append:

```markdown

## resume <YYYY-MM-DD HH:MM UTC>
- 트리거: /harness-resume <slug>
- 마지막 도달 step: step{N} (라벨: {LABEL}{, 사유: {ENUM}})
- 재진입 step: step{M}
- 모드 마커 복원: {noask|ask}
- Loop Counter 보존: step5 LGTM:NO {N1}회 / step6 FAIL {N2}회 / step6 BLOCKED {N3}회
- chunks: {단일 | chunk i/N (다음: chunk i+1)}
```

### 10. step1 부트스트랩 skip + 재진입

- step1-init.md 의 1~8번 절차 **건너뜀** (slug 생성·progress 부트스트랩·legacy cleanup 모두 skip — 보존된 산출물 손상 방지).
- 단, step1-init.md 의 *harness-\* skill / agent 가용성 검증* 만 가볍게 재수행 (세션 변경 가능성). 폴백 처리는 동일.
- 그 후 7번에서 판정한 step 의 절차로 진입. 이후 흐름은 SKILL.md / workflow.md / steps/step{N}.md 그대로.

### 11. 호출 직후 1회 통보 (질문 아님)

step 진입 *전* 단순 통보 1회 출력 (응답 대기 안 함):

```
[harness-resume] slug=<slug> 진행 재개
- 이전 도달: step{N} (라벨: {LABEL})
- 재진입: step{M}
- 모드: {noask|ask}
- Loop Counter: LGTM:NO {N1} / FAIL {N2} / BLOCKED {N3}
- chunks: {단일 | chunk i/N}
progress 파일: <절대경로>
```

## 안전 가드

- **progress 덮어쓰기 금지**: 재진입 시 `append` 만 — 새 헤더는 끝에 추가, 기존 섹션 절대 수정 안 함.
- **모드 전환 금지**: progress 의 `모드:` 가 `noask` 면 `/harness-resume` 도 noask. ask 로 바꾸려면 워크플로우 종료 후 새 `/harness-ask` 호출. (slug 재사용 안 됨 — step1-init.md 의 *중복 시 숫자 추가* 규칙으로 다른 slug.)
- **chunks 모드 무결성**: chunks-overview 의 마지막 PASS chunk 까지는 commit 된 상태여야 정합. 그렇지 않으면 (예: 직전 chunk 가 step6 PASS 인데 commit 안 된 경우) 재진입 직전 commit 자동 시도 1회 (실패 시 step8 절차 따름).
- **자동 결정 매핑 그대로**: noask 2 예외 (complete 진입 전 step7 처리 / step6 BLOCKED 동일사유 5회) 외 `AskUserQuestion` 호출 금지 — 본 명령은 진입 경로일 뿐 정책은 SKILL.md 의 자동 결정 매핑 표 그대로.

## 흔한 오용

| 시도 | 차단 사유 |
|------|----------|
| `/harness-resume foo` 인데 progress-foo 없음 | 4단계에서 종료 + 안내 |
| `/harness-resume foo` 인데 report 이미 있음 | 4단계에서 종료 + 안내 |
| `/harness-resume <자연어 한 줄>` | slug 가 아니라 자연어로 보임 → "slug 만 인자로 받습니다" 안내 + 종료 |
| 두 워크플로우를 동시에 resume | 마커 파일이 1개씩이라 충돌 — 한 번에 1 slug 만 |

## 관련

- 신규 시작: [`/harness`](harness.md) (noask) / [`/harness-ask`](harness-ask.md) (인터랙티브)
- 본체: [`~/.claude/skills/harness/SKILL.md`](~/.claude/skills/harness/SKILL.md) — 입력 게이트가 `/harness-resume` 도 허용 진입 경로로 인정
- 흐름 상세: [`~/.claude/skills/harness/docs/workflow.md`](~/.claude/skills/harness/docs/workflow.md)
- step1 부트스트랩 정의: [`~/.claude/skills/harness/docs/steps/step1-init.md`](~/.claude/skills/harness/docs/steps/step1-init.md) — resume 진입 시 본 step 의 1~8번은 skip
