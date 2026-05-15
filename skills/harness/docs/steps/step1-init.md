# step1. harness 초기화

1. **REQUEST_ID 생성** — slug 형식 (예: `jwt-middleware`). 중복 시 숫자 추가.
2. **메인 repo 경로 식별 (worktree 안에서 실행된 경우)**
   - `git rev-parse --show-toplevel` 로 현재 작업 트리 경로 획득
   - `git rev-parse --git-common-dir` 로 공통 git 디렉토리 경로 획득. 두 값이 다르면 **현재 위치는 worktree 안**.
   - worktree 안이면 `.harness/` 의 정식 위치는 **공통 git 디렉토리의 부모(메인 repo 루트)** 로 고정한다. 이후 모든 step 이 그 경로를 `$HARNESS_PROJECT_DIR` 로 사용 (worktree 안에 별도 `.harness/` 만들지 않는다 — 자료가 둘로 갈라짐).
   - 일반 repo (worktree 아님) 면 `git rev-parse --show-toplevel` 결과를 그대로 사용.
3. **`.harness/` 폴더 보장** — 마스터(`~/.claude/skills/harness/`) 의 `core/`, `wrappers/` 폴더를 위에서 정한 메인 repo 경로의 `.harness/` 로 복사. 그 안에서 구동.
4. 마스터의 `core/`, `wrappers/` 내용과 프로젝트의 `.harness/` 내용이 일치하는지 확인. 불일치 시 마스터로 덮어쓰기.
5. **harness-* agent 등록 검증** — Task 도구로 호출할 모든 harness-* agent 가 `~/.claude/agents/` 에 등록되어 있는지 확인. 마스터(`~/.claude/skills/harness/agents/`) 에 있는 다음 9개 + codex-reviewer 가 등록 위치에도 있어야 한다:
   - `harness-planner.md`, `harness-architect.md`, `harness-tdd-guide.md`, `harness-code-reviewer.md`, `harness-security-reviewer.md`, `harness-build-resolver.md`, `harness-qa-engineer.md`, `harness-customer-user.md`, `harness-deep-researcher.md`, `codex-reviewer.md`
   - 누락된 파일은 마스터에서 `~/.claude/agents/` 로 복사 (덮어쓰기 OK — 마스터가 진실 원천). 등록 안 된 agent 는 Task 도구가 *"agent type 'harness-qa-engineer' not found"* 같은 에러로 거절하여 step6/step7 이 호출조차 못 한다.
6. **`--noagent` 플래그 처리** — 사용자 입력에 `--noagent` 가 포함되어 있으면 `.harness/.noagent` 빈 파일을 생성, 포함되어 있지 않으면 기존 파일이 있어도 **삭제**해 모드를 호출별로 깨끗하게 초기화한다. 이후 step 들은 매번 이 파일 존재 여부만 보고 모드 분기.
