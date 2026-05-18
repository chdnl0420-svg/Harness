# step6. QA 테스트

**산출물**:
- `.harness/test-guide-<slug>.md` (테스트 가이드 — 작성/갱신)
- `.harness/results/qa-<slug>.md` (QA 보고서 — 회차 누적)

**입력 게이트 (skip 금지)**:
- step5 의 최신 판정이 LGTM:YES 여야 진입. 그 외에는 step3 로 회송.
- `.harness/test-guide-<slug>.md` 가 비어 있으면 도우미 호출 자체를 하지 않는다.

**흐름**:
1. **`.harness/` 경로 식별 (메인 Claude 가 worktree 안에서 실행 중인 경우 필수)** —
   - `git rev-parse --git-common-dir` 결과의 부모 디렉토리 = 메인 repo 루트
   - 메인 repo 루트의 `.harness/` 를 진실 원천으로 삼는다
   - worktree 안에 별도 `.harness/` 자동 생성 금지
1b. **의존성 사전 점검 (CRITICAL — wasted run 차단)** — 도우미 호출 전에 다음 자동화 도구의 가용성을 점검:
   - MCP 브라우저 (`mcp__Claude_in_Chrome__*`) — 가용 / 없음
   - Claude Preview (`mcp__Claude_Preview__*`) — 가용 / 없음
   - 프로젝트 기존 Playwright / Puppeteer 스크립트 — 존재 / 없음
   - **셋 다 NO 면 도우미 호출 전에 BLOCKED 즉시 보고**. step3 의 plan 이 자동화 테스트를 전제로 한 경우 의존성 부재가 plan 결함이므로 step3 회송 대상 아님 — 사용자 결정 분기로.
   - 점검 결과는 `qa-<slug>.html` 의 *의존성 점검* 카드와 `progress-<slug>.html` 에 기록. 재진입 시 매번 재점검 (도구 가용성 변화 가능).
2. **테스트 가이드 작성/갱신** (메인 Claude 직접 작성) — 양식·재료·갱신 규칙은 [../test-guide-format.md](../test-guide-format.md) 참조
   - 최초 진입 시: 새로 작성
   - 재진입 시 (step3 루프 후): 변경된 사양/구현 반영해 갱신
   - 가이드 없이는 절대 테스트 시작 금지
3. `harness-qa-engineer` 에 위임:
   - **[Learning Prepend 계약](../workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통) 1·2·3·4 단계 수행 필수.** 즉 다음을 Read 후 `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더로 prepend:
     - `~/.claude/skills/harness/agents/learning/harness-qa-engineer.md` (공용)
     - `<메인 repo>/.harness/agents/learning/harness-qa-engineer.md` (프로젝트, 있으면)
   - **test-guide-<slug>.md 전문 prepend** (Prior Learning 헤더 다음, 본 작업 앞)
   - **메인 repo `.harness/` 절대경로 prepend** (worktree 안에서 호출 중인 경우)
   - **`isolation: "worktree"` 옵션 절대 사용 금지** (CRITICAL 섹션 참조)
   - 위 4가지 중 하나라도 누락하면 호출 자체 금지. 도우미가 `[BLOCKED] Prior Learning header 누락` 으로 거부함.
4. 도우미가 가이드 기능 목록 순서대로 스크린샷 + 클릭 기반 시나리오 실행
   - MCP 브라우저 도구 (`mcp__Claude_in_Chrome__*`, `mcp__Claude_Preview__*`) 우선
   - 없으면 프로젝트의 기존 Playwright/Puppeteer 스크립트만 호출 (신규 스크립트 작성 금지)
   - **자동화 도구 전부 없으면 → BLOCKED 보고 후 사용자 결정 요청.** "수동 보고" 만으로 PASS 통과 금지.
5. 보고서에서 최종 판정 추출: **PASS / FAIL / BLOCKED**
6. 분기:
   - **PASS** → step7 로 진행
   - **FAIL** → step3 (구현 계획 수정) 로 되돌림
     - 동일 결함이 5회 반복되면 중단 + 사용자에게 알림 (유형 enum 13종 — workflow.md "회송 경로 실행 보장 (5)" 참조)
   - **BLOCKED** (테스트 자체 불가) → 사용자에게 원인 보고 후 결정 요청. 자체 판단으로 다음 단계 진행 금지.
     - (A) 환경 수정 후 재시도 — supervisor 또는 운영자가 환경 점검
     - (B) 사용자 명시 동의 스킵 — noask 무인 모드에서는 비활성 (정의상 사용자 동의 필요)
     - (C) 워크플로우 중단
     - (D) **`paused-by-blocked` + 다음 슬러그 자동 시작** — noask 무인 모드 + 슬러그 큐 > 1 일 때만 적용. 현 슬러그는 `paused-by-blocked` 마킹, 다음 슬러그가 자동 시작. 최대 N 슬러그 누적 paused 시 사용자 alert (dead-end 폭주 차단). 단일 슬러그 모드면 (C) 와 동일.

**제약**:
- QA 도우미는 보고서·스크린샷 외 어떤 파일도 수정·생성하지 않음 (가이드 작성은 메인 Claude 가 담당)
- 버그를 직접 고치지 않음 — step3 루프에서 다른 도우미가 처리
- "자동화 도구 없음" 을 게이트 통과 사유로 삼지 않는다. BLOCKED 만 가능.

**Worktree 처리 (CRITICAL)**:
- `harness-qa-engineer` 를 Task 도구로 호출할 때 **`isolation: "worktree"` 옵션 절대 사용 금지.** 격리된 worktree 안에는 `.harness/`, `test-guide-<slug>.md`, 기존 스크린샷이 없으므로 agent 가 입력 자료에 접근하지 못해 실패한다.
- 메인 Claude 자체가 `git worktree` 또는 Claude Code `--worktree` 로 격리된 디렉토리에서 작업 중이라면, **step6 시작 전에 메인 repo 의 `.harness/` 경로를 명시적으로 식별**하고 (`git rev-parse --git-common-dir` 의 부모 디렉토리 또는 사용자가 시작한 메인 프로젝트 경로) 그 경로를 agent prompt 에 절대경로로 prepend 한다.
- worktree 안 `.harness/` 가 비어 있고 메인 repo 의 `.harness/` 에 자료가 있는 경우, **메인 repo 의 `.harness/results/qa-<slug>.md` 에 보고서 작성**. worktree 내 새 `.harness/` 자동 생성 금지 (자료가 둘로 갈라짐).

**BLOCKED 판정 기준 (탈출구 차단)**:
다음 중 하나라도 해당되면 **PASS 가 아니라 BLOCKED**:
- 자동화 도구 (Claude_in_Chrome / Claude_Preview / 프로젝트 기존 Playwright) 가 전부 사용 불가
- 앱이 실행되지 않거나 가이드의 환경 정보로 접근 불가
- 가이드 자체가 누락되거나 시나리오 추정 불가
- 도우미가 권한 정책 위반 없이는 가이드 시나리오 실행 불가

BLOCKED 는 사용자 결정 사항이다. 메인 Claude 가 *"테스트 못 했지만 코드 봤을 때 괜찮을 듯"* 으로 PASS 처리 절대 금지.

## CRITICAL: 다음 step 결정 보고 (게이트 — 출력 없이 다음 step 진입 금지)

QA 회차를 `qa-<slug>.md` 에 누적한 직후, **메인 Claude 는 채팅에 다음 5필드 보고를 반드시 출력한다.** 출력 없이 다음 step 호출 시 step 스킵 위반으로 워크플로우 중단.

```
### Step6 결과 → 다음 step 결정
- 판정: PASS | FAIL | BLOCKED
- 판정 근거: <qa-<slug>.md 의 해당 회차에서 PASS/FAIL/BLOCKED 라벨이 등장한 줄 인용>
- 다음 step: step7 진입 | step3 회송 | 사용자 결정 요청 | paused-by-blocked + 다음 슬러그
- 이번 루프 회차: <progress-<slug>.md 의 step6 FAIL 누적 카운터>회 (동일 결함 유형 enum = YES | NO)
- 자기 점검 (자체 수정 우회): 이번 fail 후 메인 Claude 가 코드/구현 파일을 직접 수정했는가? YES | NO  (※ git diff 자동 검증 — workflow.md "회송 경로 실행 보장 (3)" 참조)
- fallback_used: harness-qa-engineer subagent | manual self-test | none
- 의존성 점검 결과: Claude_in_Chrome=가용/없음, Claude_Preview=가용/없음, Playwright=존재/없음
```

**판정 규칙**:
- 자기 점검이 `YES` 이거나 git diff 자동 검증과 불일치하면 **즉시 워크플로우 중단**. `qa-<slug>.html` 에 "정책 위반: 메인 자체 수정 우회 — workflow 중단" 기록 후 사용자에게 보고. 수정한 변경분은 step3 회송 절차에서 정식 plan 으로 반영해야 함.
- "이번 루프 회차" 가 5 이상이고 "동일 결함 유형 enum = YES" 이면 **자동 중단** + report 에 "동일 결함 5회 반복으로 자동 중단" 기록. 유형 enum 은 workflow.md "회송 경로 실행 보장 (5)" 의 13종.
- FAIL 이면 step3 회송 — Step3 의 "회송 진입 모드" 절차에 따라 진행.
- BLOCKED 이면 사용자 결정 요청 (A/B/C 분기). noask 무인 모드 + 슬러그 큐 > 1 이면 (D) `paused-by-blocked` + 다음 슬러그 자동 시작.
- 의존성 점검에서 셋 다 NO 가 나왔으면 도우미 호출 자체가 일어나지 않았음 — BLOCKED 사유에 "의존성 부재" 명시.

## 루프 카운터 누적 의무 (CRITICAL)

위 보고의 "이번 루프 회차" 값은 `progress-<slug>.md` 의 `## Loop Counter` 섹션의 `step6 FAIL 누적` 값에서 산출. 매 FAIL 발생 시 M 을 1 증가시키고, 직전 회차 결함 유형·파일과 비교해 동일 결함 여부 라벨링. step5 와 카운터를 공유하지 않음 (workflow.md "5회 임계값" 참조). 누락 시 5회 게이트 미발동 = 정책 위반.

**유형 enum 13종 (workflow.md "회송 경로 실행 보장 (5)" 와 동일)**: `TYPE_ERROR | NULL_REFERENCE | PERMISSION_DENIED | RESOURCE_NOT_FOUND | RACE_CONDITION | LOGIC_ERROR | IO_FAILURE | TIMEOUT | API_CONTRACT | SECURITY | TEST_COVERAGE | BUILD_FAILURE | OTHER`. enum 외 값으로 적으면 정책 위반. OTHER 5회 누적 시 라벨링 정밀도 부족 신호 → 사용자 alert.
