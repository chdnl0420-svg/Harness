# step1. harness 초기화

> **`/harness-resume <slug>` 경로 진입 시 본 step 의 1·3·7·8번은 skip** — slug 생성·산출물 폴더 mkdir·legacy cleanup·progress 부트스트랩 모두 *건너뜀* (기존 progress 와 산출물 보존이 재개의 본질). 2·4·5·6번 (메인 repo 경로 식별, harness-* skill/agent 가용성 검증, 일반 skill 가용성 확인) 은 동일하게 수행 — 세션 변경으로 도구 등록 상태가 바뀔 수 있음. 모드 마커 (`.harness/.noask`·`.harness/.ask`) 는 `/harness-resume` 본문 5단계에서 progress 의 `모드:` 필드 기준으로 이미 복원됨.

1. **REQUEST_ID 생성** — slug 형식 (예: `jwt-middleware`). 중복 시 숫자 추가.
2. **메인 repo 경로 식별 (worktree 안에서 실행된 경우)**
   - `git rev-parse --show-toplevel` 로 현재 작업 트리 경로 획득
   - `git rev-parse --git-common-dir` 로 공통 git 디렉토리 경로 획득. 두 값이 다르면 **현재 위치는 worktree 안**.
   - worktree 안이면 `.harness/` 의 정식 위치는 **공통 git 디렉토리의 부모(메인 repo 루트)** 로 고정한다. 이후 모든 step 이 그 경로를 `$HARNESS_PROJECT_DIR` 로 사용 (worktree 안에 별도 `.harness/` 만들지 않는다 — 자료가 둘로 갈라짐).
   - 일반 repo (worktree 아님) 면 `git rev-parse --show-toplevel` 결과를 그대로 사용.
3. **프로젝트 산출물 폴더 보장** — 메인 repo 경로의 `.harness/{progress,reviews,results,research}` 디렉토리만 mkdir. 마스터의 `core/`, `wrappers/` 코드 복사 *폐기* (2026-05-20 정합화 — 마스터가 진실 원천, 프로젝트엔 산출물 (md/html) 만 존재).
4. **harness-* skill 등록 검증 + 안전 폴백** — 본 워크플로우가 `Skill` 도구로 호출할 harness-* skill 가용성을 확인하고, **부재 skill 은 안전 폴백 경로로 대체**한다 (자동 복구 약속 금지 — 실제 자동 복구 메커니즘이 없으므로).

   | 호출 대상 | 위치 | 부재 시 폴백 |
   |----------|------|------------|
   | `harness-plan` (step2, noask 도메인) | `~/.claude/skills/harness-plan/SKILL.md` | 없으면 일반 `plan` skill + 메인 Claude 가 직접 6 카테고리 합리적 가정 작성 |
   | `harness-plan-ask` (step2, ask 모드 인터랙티브) | `~/.claude/skills/harness-plan-ask/` | 부재 (2026-05-20 시점). `/harness-ask` 모드 사용 시 메인 Claude 가 `harness-plan` 본문 + AskUserQuestion 직접 호출로 대체 |
   | `harness-review` (step5 Codex wrapper) | `~/.claude/skills/harness-review/` | 부재. step5 는 `codex exec` 직접 호출 + 결과 Read 절차 (docs/procedures/codex-review-procedure.md) 메인 Claude 가 직접 수행. Codex 실패 시 `code-review` skill 폴백 |
   | `harness-deep-researcher` (skill 형태) | `~/.claude/skills/harness-deep-researcher/` | 부재. **agent** 형태로 등록 (아래 5번 항목) — `Task` 도구 호출로 사용. skill 형태는 미사용 |
   | `harness-customer-user` (skill 형태) | `~/.claude/skills/harness-customer-user/` | 부재. **agent** 형태로 등록 — `Task` 도구 호출로 사용 |

   - **검증 절차**: 각 경로에 `SKILL.md` 존재 여부만 확인. 부재 시 위 표의 폴백 경로를 `progress-<slug>.md` 의 *skill 폴백* 섹션에 한 줄씩 기록. 워크플로우 진행은 막지 않음 (부재 = 폴백 적용으로 계속).
   - **자동 복구 안 함**: 본 step1 도 `bootstrap-runtime.sh` 도 `/harness-setup` 도 부재 skill 을 자동 생성하지 않는다. 이전 문서에 "자동 복사" 라고 적혀 있어도 그 동작은 *agent 한정*. skill 생성은 사용자가 명시 요청 시에만 (별도 작업).

5. **harness-* agent 등록 검증 (페르소나 3개) + 자동 복사** — `Task` 도구로 호출할 페르소나 agent 가 `~/.claude/agents/` 에 등록되어 있는지 확인:
   - `harness-customer-user.md`, `harness-qa-engineer.md`, `harness-deep-researcher.md` (이 3개만 `harness-*` prefix 보존, 나머지 6개는 2026-05-20 일반 skill 로 대체)
   - **누락 시 `bootstrap-runtime.sh` 가 자동 복사** — `bootstrap-runtime.sh:46-65` 가 실제로 수행하는 유일한 복구 동작 (skill 은 복사 안 함). 자동 복사 후에도 부재면 사용자에게 한 줄 안내 (`/harness-setup` 또는 마스터 재설치 권고).
6. **일반 skill/agent 가용성 확인** — 다음 일반 도구가 호출 가능해야 한다 (Skill/Task 어느 쪽이든):
   - skill `plan` (step3 구현 계획), `code-review` (step5 fallback), `security-review` (보안 게이트), `tdd` (TDD 모드 사이클), `build-fix` (step4 빌드 에러)
   - agent `architect`, `code-reviewer`, `security-reviewer`, `tdd-guide`, 언어별 `*-build-resolver` (typescript/python/go/rust/java/cpp/kotlin/dart/csharp/pytorch)
7. **legacy 폴더·마커 cleanup** — `.harness/.noagent`, `.harness/agents/`, `.harness/core/`, `.harness/wrappers/`, `.harness/plans/`, `.harness/improvements/` 가 보이면 *방치* (사용자 자료 보호 — 자동 삭제 안 함). 모두 2026-05-20 폐기됐고 워크플로우가 사용 안 함. 사용자가 정리 원하면 수동 `rm -rf` 안내.
8. **progress 파일 부트스트랩** — `.harness/progress/progress-<slug>.md` 를 다음 양식으로 생성. 이후 step 들이 이 파일에 섹션 append.

   ```markdown
   # progress-<slug>

   - slug: <slug>
   - 시작일시: <YYYY-MM-DD HH:MM>
   - 모드: noask | ask
   - 한 줄 목표: <사용자 원본 한 줄 목표>
   - auto_triggered_from: <원본 slug> | (없음)   # step7 → 신규 워크플로우 chain 일 때만 채움. 존재하면 complete 진입 게이트에서 C 선택지 비활성 (무한 chain 차단)

   ## Loop Counter
   - step5 LGTM:NO 누적: 0회
   - step6 FAIL 누적: 0회
   - step6 BLOCKED 누적: 0회   # 동일 사유 5회 누적 시 AskUserQuestion (noask 2번째 예외)

   ## step4_commit_sha
   <step4 진입 시 git rev-parse HEAD 결과 자동 기록>
   ```

   - **`auto_triggered_from` 필드 결정 규칙**:
     - 사용자가 직접 `/harness <목표>` 로 호출한 경우 → "(없음)" 으로 채움.
     - 부모 워크플로우의 complete 진입 게이트에서 *C 선택* 으로 자동 트리거된 경우 → 부모 slug 를 자동 기록 (메인 Claude 가 step1 진입 직전 부모 progress 의 slug 를 prompt 컨텍스트에서 식별).
   - 부모 progress 가 있는지 식별이 모호하면 "(없음)" 으로 두고 사용자에게 한 줄 안내 — 자동 chain 감지 실패 시 무한 chain 차단이 발동 안 함, 그러나 동일 슬러그 재호출이 5회 누적되면 별도 가드(workflow.md 의 회송 5회 게이트) 에서 차단됨.
