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
   - 점검 결과는 `qa-<slug>.md` 의 *의존성 점검* 섹션과 `progress-<slug>.md` 에 기록. 재진입 시 매번 재점검 (도구 가용성 변화 가능).
2. **테스트 가이드 작성/갱신** (메인 Claude 직접 작성) — 양식·재료·갱신 규칙은 [../test-guide-format.md](../test-guide-format.md) 참조
   - 최초 진입 시: 새로 작성
   - 재진입 시 (step3 루프 후): 변경된 사양/구현 반영해 갱신
   - 가이드 없이는 절대 테스트 시작 금지
3. `harness-qa-engineer` 에 위임:
   - **[Learning Prepend 계약](../workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통) 1·2·3·4 단계 수행 필수.** 즉 다음을 Read 후 `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더로 prepend:
     - `~/.claude/skills/harness/agents/learning/harness-qa-engineer.md` (공용만 — 프로젝트 learning 은 2026-05-20 폐기)
   - **test-guide-<slug>.md 전문 prepend** (Prior Learning 헤더 다음, 본 작업 앞)
   - **메인 repo `.harness/` 절대경로 prepend** (worktree 안에서 호출 중인 경우)
   - **`isolation: "worktree"` 옵션 절대 사용 금지** (CRITICAL 섹션 참조)
   - 위 4가지 중 하나라도 누락하면 호출 자체 금지. 도우미가 `[BLOCKED] Prior Learning header 누락` 으로 거부함.
4. 도우미가 가이드 기능 목록 순서대로 스크린샷 + 클릭 기반 시나리오 실행
   - MCP 브라우저 도구 (`mcp__Claude_in_Chrome__*`, `mcp__Claude_Preview__*`) 우선
   - 없으면 프로젝트의 기존 Playwright/Puppeteer 스크립트만 호출 (신규 스크립트 작성 금지)
   - **자동화 도구 전부 없으면 → BLOCKED 보고 후 사용자 결정 요청.** "수동 보고" 만으로 PASS 통과 금지.
5. 보고서에서 최종 판정 추출: **PASS / FAIL / BLOCKED** — 아래 "PASS/FAIL 라벨 추출 규칙" 의 명시적 라벨만 인정. 임의 해석 금지.
5b. **객관 산출물 게이트 (CRITICAL — 자체 판정 우회 차단)** — PASS 라벨이 추출됐어도 다음 산출물 게이트를 통과해야 PASS 확정. 하나라도 미충족 시 자동 BLOCKED:
   - **증거 파일 디스크 실재 확인**: 보고서가 인용하는 스크린샷 경로(`screenshot path:` / `[image:` 등) 가 *실제로 존재* 하는지 `Read` 또는 `ls` 로 검증. 없으면 자동 BLOCKED.
   - **시나리오 커버리지 검증**: `test-guide-<slug>.md` 의 *기능 시나리오 목록* 과 qa 보고서가 실행한 시나리오 목록을 비교. 누락된 시나리오 있으면 자동 BLOCKED ("커버리지 부족").
   - **재진입 시 직전 fail 시나리오 반영 검증**: 회송 후 첫 PASS 회차라면, 직전 fail 회차의 `결함 항목` 텍스트 (유형 enum + 파일 + 증상 키워드) 가 *이번 회차의 시나리오 본문에 grep 가능* 한지 확인. 안 잡히면 *직전 fail 을 우회한 가이드* 신호 → 자동 BLOCKED ("회송 반영 부족").
   - 게이트 결과는 `qa-<slug>.md` 의 *"산출물 게이트"* 섹션에 명시: `evidence_exists / coverage_full / regression_reproduced` 3축 YES/NO.
6. 분기:
   - **PASS** → step7 로 진행
   - **FAIL** → step3 (구현 계획 수정) 로 되돌림
     - **동일 결함** (동일 유형 enum + 동일 파일경로 normalized) 이 5회 반복될 때만 중단 + 사용자에게 알림. *서로 다른* 결함으로 5회 FAIL 누적은 중단 조건 아님 — 각각 다른 결함을 해결 중이라는 정상 진행 신호 (유형 enum 13종 — workflow.md "회송 경로 실행 보장 (5)" 참조).
   - **BLOCKED** (테스트 자체 불가) → **자동 결정 분기** (사용자 결정은 *동일 사유 5회 누적* 시에만):
     - **자동 1차 재시도**: BLOCKED 1회 발생 시 *원인 enum* 식별 후 자동 재시도 1회 (의존성 재점검 + 환경 재점검 + 도우미 재호출). 재시도 성공 시 그대로 진행.
     - **자동 2차 처리** (재시도도 BLOCKED): 슬러그 큐 길이 분기:
       - **다중 슬러그 모드** (큐 > 1): 자동 (D) `paused-by-blocked` 마킹 + 다음 슬러그 자동 시작. progress 의 `step6 BLOCKED 누적` 카운터 1회 증가 + 사유 enum 기록.
       - **단일 슬러그 모드** (큐 = 1): 자동 (C) 워크플로우 중단. report 에 BLOCKED 사유 전문 기록.
     - **동일 사유 5회 누적 → 사용자 결정 요청 (noask 정책의 두 번째 예외)**: 같은 *BLOCKED 사유 enum* 으로 5회 누적 시에만 `AskUserQuestion` 호출. complete 진입 게이트와 함께 noask 정책의 *유일한 2 예외* 중 하나. 선택지:
       - (A) 환경 수정 후 재시도 — supervisor 또는 운영자가 환경 점검 후 재호출
       - (B) 사용자 명시 동의 스킵 — 다음 step 으로 진행 (test 약식 완료 처리)
       - (C) 워크플로우 중단 — report 에 사유 기록
     - *서로 다른* BLOCKED 사유로 5회 누적은 사용자 결정 트리거 아님 — 각각 다른 환경 문제를 거치는 정상 진행.

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

## PASS/FAIL 라벨 추출 규칙 (CRITICAL — 임의 해석 금지)

step5 의 `LGTM 추출 규칙` 과 동등한 강도로 step6 의 라벨 추출도 명시적으로만 인정한다. 메인 Claude 가 도우미 보고서를 "잘 작동한 듯" / "전반적으로 괜찮음" 같은 해석으로 PASS 라벨링하는 anti-pattern 차단.

**1. PASS — 다음 *모든* 조건을 만족할 때만 인정**:
   - 보고서 본문에 다음 중 *하나* 가 단독으로 명시: `최종 판정: PASS` / `Verdict: PASS` / `Status: PASS`
   - `test-guide-<slug>.md` 의 *모든* 기능 시나리오가 보고서의 *실행한 시나리오 목록* 에 매칭 (누락 0건)
   - 각 시나리오마다 다음 증거 중 *최소 1개* 첨부 — `screenshot path:` (실재 파일) / `network trace:` (HTTP 200/400 기록) / `click trace:` (셀렉터 + 결과) / `console assertion:` (콘솔 로그 본문)
   - 산출물 게이트 (5b 단계) 의 3축 모두 YES

**2. FAIL — 다음 중 *하나라도* 해당하면 자동 FAIL**:
   - 보고서에 `최종 판정: FAIL` / `Verdict: FAIL` 명시
   - 시나리오 1개 이상에서 *기대 동작 ≠ 실제 동작* 명시 (보고서가 "PASS" 라벨을 적었어도 본문 모순 시 FAIL 우선)
   - 콘솔 오류·미처리 예외·HTTP 5xx 응답이 시나리오 실행 중 1회라도 발생 (의도된 음성 시나리오 제외)

**3. BLOCKED — 다음 중 하나** (반드시 *사유 enum* 함께 라벨링):
   - 의존성 점검(1b) 결과 자동화 도구 전부 NO → `DEPENDENCY_MISSING`
   - 객관 산출물 게이트(5b) 1축이라도 NO → `EVIDENCE_GATE_FAIL`
   - 도우미가 권한 정책 위반 없이는 시나리오 실행 불가 → `PERMISSION_DENIED`
   - 가이드 또는 환경 자체가 누락 → `GUIDE_MISSING`
   - 앱 실행/환경 접근 불가 (서버 다운·URL 미접근 등) → `ENV_UNREACHABLE`
   - 분류 어려운 환경 차단 → `OTHER`

   **BLOCKED 사유 enum 6종 (CRITICAL — 동일성 판정 기준)**: `DEPENDENCY_MISSING | EVIDENCE_GATE_FAIL | PERMISSION_DENIED | GUIDE_MISSING | ENV_UNREACHABLE | OTHER`. 동일 사유 5회 누적 시 사용자 결정 트리거 (noask 정책의 두 번째 예외 — complete 진입 게이트와 함께). 동일성 = enum 일치. *서로 다른* 사유로 5회 누적은 트리거 아님 — 각각 다른 환경 문제를 거치는 정상 진행.

**4. UNKNOWN (신규 — self-PASS bias 차단)**:
   - `fallback_used = manual self-test` (자동화 도구 없는데 메인 Claude 가 코드만 보고 판단) **AND** 라벨 = PASS → **자동 UNKNOWN 강등** + 슬러그 `paused-by-unknown` 마킹
   - `harness-qa-engineer` agent 호출이 *없었던* 채로 (Skill/Task 호출 0회) PASS 라벨 → 자동 UNKNOWN 강등
   - step5 의 self-LGTM 강등 (arXiv 2508.06225 ECE 39–74%) 와 동일 원칙. 같은 Claude 모델이 self-PASS 판정 = 신뢰 불가.

**충돌 시 우선순위**: BLOCKED > FAIL > UNKNOWN > PASS. 즉 보고서가 PASS 적었어도 산출물 게이트 1축이라도 NO 면 BLOCKED 가 우선.

## CRITICAL: 다음 step 결정 보고 (게이트 — 출력 없이 다음 step 진입 금지)

QA 회차를 `qa-<slug>.md` 에 누적한 직후, **메인 Claude 는 채팅에 다음 11필드 보고를 반드시 출력한다.** 출력 없이 다음 step 호출 시 step 스킵 위반으로 워크플로우 중단.

```
### Step6 결과 → 다음 step 결정
- 판정: PASS | FAIL | BLOCKED | UNKNOWN
- 판정 근거: <qa-<slug>.md 의 해당 회차에서 PASS/FAIL/BLOCKED 라벨이 등장한 줄 인용>
- 다음 step: step7 진입 | step3 회송 | 자동 재시도 | paused-by-blocked + 다음 슬러그 | 자동 (C) 중단 | 사용자 결정 (BLOCKED 5회 누적) | paused-by-unknown
- 이번 루프 회차 (FAIL): <progress-<slug>.md 의 step6 FAIL 누적 카운터>회 (동일 결함 유형 enum = YES | NO)
- 이번 루프 회차 (BLOCKED): <progress-<slug>.md 의 step6 BLOCKED 누적 카운터>회 + 이번 BLOCKED 사유 enum (DEPENDENCY_MISSING | EVIDENCE_GATE_FAIL | PERMISSION_DENIED | GUIDE_MISSING | ENV_UNREACHABLE | OTHER) + 동일 BLOCKED 사유 여부 (YES | NO | N/A)
- 자기 점검 (자체 수정 우회): 이번 fail 후 메인 Claude 가 코드/구현 파일을 직접 수정했는가? YES | NO  (※ git diff 자동 검증 — workflow.md "회송 경로 실행 보장 (3)" 참조)
- fallback_used: harness-qa-engineer subagent | manual self-test | none
- 의존성 점검 결과: Claude_in_Chrome=가용/없음, Claude_Preview=가용/없음, Playwright=존재/없음
- 산출물 게이트 (5b): evidence_exists=YES|NO, coverage_full=YES|NO, regression_reproduced=YES|NO|N/A (회송 첫 회차에만 의미)
- 라벨 추출 검증: 보고서에 명시된 라벨 원문 인용 (예: "Verdict: PASS") + 충돌 검사 결과 (PASS/FAIL/BLOCKED 가 동시 등장 시 우선순위 적용 결과)
- 자동 결정 분기 적용 결과 (BLOCKED 시에만): "자동 재시도 1회 시도 → 성공" | "자동 재시도 fail → (D) paused-by-blocked + 다음 슬러그" | "자동 재시도 fail → (C) 중단" | "동일 사유 5회 누적 → AskUserQuestion 호출"
```

**판정 규칙**:
- 자기 점검이 `YES` 이거나 git diff 자동 검증과 불일치하면 **즉시 워크플로우 중단**. `qa-<slug>.md` 에 "정책 위반: 메인 자체 수정 우회 — workflow 중단" 기록 후 사용자에게 보고. 수정한 변경분은 step3 회송 절차에서 정식 plan 으로 반영해야 함.
- **fallback = manual self-test 이고 라벨 = PASS 이면 → 자동 UNKNOWN 강등** + 슬러그 `paused-by-unknown` 마킹. (자동화 도구 없이 메인 자체 판단으로 PASS 처리하는 우회 차단.)
- **harness-qa-engineer subagent 호출 0회 + 라벨 = PASS 이면 → 자동 UNKNOWN 강등**. (도우미 우회 차단.)
- **산출물 게이트 3축 중 1축이라도 NO 이고 라벨 = PASS 면 → 자동 BLOCKED 강등**. 사유에 어느 축이 실패했는지 명시 (evidence 부재 / coverage 부족 / regression 미반영).
- "이번 루프 회차" 가 5 이상이고 "동일 결함 유형 enum = YES" 이면 **자동 중단** + report 에 "동일 결함 5회 반복으로 자동 중단" 기록. 유형 enum 은 workflow.md "회송 경로 실행 보장 (5)" 의 13종.
- FAIL 이면 step3 회송 — Step3 의 "회송 진입 모드" 절차에 따라 진행.
- BLOCKED 이면 **자동 결정 분기** (사용자에게 묻지 않음):
  - 자동 1차 재시도 1회 → 성공 시 그대로 진행
  - 재시도 fail 시 슬러그 큐 분기 — 다중 슬러그면 (D) `paused-by-blocked` 마킹 + 다음 슬러그 자동 시작, 단일 슬러그면 (C) 자동 중단
  - 매 BLOCKED 회차마다 `progress-<slug>.md` 의 `step6 BLOCKED 누적` 카운터 1회 증가 + 사유 enum 기록
  - **동일 BLOCKED 사유 5회 누적 시에만 → `AskUserQuestion` 호출** (noask 정책의 두 번째 예외, complete 진입 게이트와 함께). 선택지 (A/B/C) 응답에 따라 진행.
- UNKNOWN 이면 다음 step 진입하지 않고 슬러그를 `paused-by-unknown` 으로 마킹 + report 에 사유 기록. noask 무인 모드면 다음 슬러그 자동 시작.
- 의존성 점검에서 셋 다 NO 가 나왔으면 도우미 호출 자체가 일어나지 않았음 — BLOCKED 사유 enum 에 `DEPENDENCY_MISSING` 명시.

## 루프 카운터 누적 의무 (CRITICAL)

위 보고의 "이번 루프 회차" 값은 `progress-<slug>.md` 의 `## Loop Counter` 섹션에서 산출. step6 는 **2개 독립 카운터** 를 유지한다.

**(1) step6 FAIL 누적 카운터**:
- 매 FAIL 발생 시 M 을 1 증가시키고, 직전 회차 결함 유형·파일과 비교해 동일 결함 여부 라벨링.
- step5 LGTM:NO 카운터와 공유하지 않음 (독립).
- 동일 결함 5회 누적 시 자동 워크플로우 중단.
- **유형 enum 13종 (workflow.md "회송 경로 실행 보장 (5)" 와 동일)**: `TYPE_ERROR | NULL_REFERENCE | PERMISSION_DENIED | RESOURCE_NOT_FOUND | RACE_CONDITION | LOGIC_ERROR | IO_FAILURE | TIMEOUT | API_CONTRACT | SECURITY | TEST_COVERAGE | BUILD_FAILURE | OTHER`. enum 외 값으로 적으면 정책 위반. OTHER 5회 누적 시 라벨링 정밀도 부족 신호 → 사용자 alert.

**(2) step6 BLOCKED 누적 카운터 (2026-05-20 신규)**:
- 매 BLOCKED 발생 시 자동 재시도 1회 후에도 BLOCKED 면 B 를 1 증가시키고, 직전 BLOCKED 회차의 사유 enum 과 비교해 동일 사유 여부 라벨링.
- FAIL 카운터와 공유하지 않음 (독립).
- **동일 BLOCKED 사유 5회 누적 시에만** `AskUserQuestion` 호출 (noask 정책의 두 번째 예외). 그 외에는 자동 결정 분기 ((D) paused-by-blocked + 다음 슬러그 또는 (C) 중단).
- **BLOCKED 사유 enum 6종**: `DEPENDENCY_MISSING | EVIDENCE_GATE_FAIL | PERMISSION_DENIED | GUIDE_MISSING | ENV_UNREACHABLE | OTHER`. enum 외 값으로 적으면 정책 위반. OTHER 5회 누적 시 사용자 alert (분류 정밀도 부족).
- 누락 시 5회 사용자 결정 게이트 미발동 = 정책 위반.

**Loop Counter 섹션 양식 (progress 파일)**:
```markdown
## Loop Counter
- step5 LGTM:NO 누적: <N>회
  - 직전 회차 결함 유형·파일: <유형 enum> @ <파일경로>
  - 동일 문제 여부 판정: ...
- step6 FAIL 누적: <M>회
  - 직전 회차 결함 유형·파일: <유형 enum> @ <파일경로>
  - 동일 결함 여부 판정: ...
- step6 BLOCKED 누적: <B>회
  - 직전 회차 BLOCKED 사유: <사유 enum>
  - 동일 사유 여부 판정: ...
```

---

## Chunks 모드 (2026-05-20 신규)

**Chunks 모드일 때** (step3 의 임계값 통과 시):
- test-guide 와 QA 보고서는 *현 chunk_i 의 성공 기준* 만 검증. 다른 chunk 기능은 *완료 가정* (chunk_j<i 는 done 상태).
- test-guide: `.harness/test-guide-<slug>-chunk-<i>.md` (chunk 별 독립).
- QA 보고서: `.harness/results/qa-<slug>-chunk-<i>.md` (회차 누적).
- FAIL 회송 시 step3 의 *회송 진입 모드* — *현 chunk_i 의 implementation plan* 만 재작성. 다른 chunk 영향 없음.
- 회송 카운터는 **chunk 별 독립 5회**. 한 chunk 가 5회 초과 시 워크플로우 *전체* 자동 중단.
- **PASS 후 자동 분기** (noask 정신):
  - chunk_i 의 git commit 자동 호출 (incremental delivery — step8 절차 따름)
  - chunks-overview 의 chunk_i 상태 `done` 으로 갱신
  - if chunk_i == N (last chunk): → step7 진입 (전체 production install 테스트, 1회)
  - else: chunk_i += 1 → step3 의 *다음 chunk plan 작성* → step4 진입
- 자세히: [step3-impl-plan.md Chunks 분해 절차](step3-impl-plan.md#chunks-분해-절차-critical--2026-05-20-신규).
