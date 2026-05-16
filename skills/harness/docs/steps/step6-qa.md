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
     - 동일 결함이 5회 반복되면 중단 + 사용자에게 알림
   - **BLOCKED** (테스트 자체 불가) → 사용자에게 원인 보고 후 결정 요청. 자체 판단으로 다음 단계 진행 금지.

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
