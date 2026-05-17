## HTML 출력 규칙 (CRITICAL — 최우선 적용, 다른 모든 기본값 위)

> `/harness` · `/harness-*` 모든 커맨드 · 모든 `harness-*` 서브에이전트 · `--noagent` 모드 메인 Claude 가 만드는 모든 산출물 파일에 적용된다. 예외 없음.

**원칙 4가지** (전체 규칙은 [docs/html-output-rule.md](docs/html-output-rule.md), 정본은 `~/.claude/CLAUDE.md` §6 + §6.3.1):

1. **모든 산출물은 `.html`** — `.harness/` 안의 plan / progress / review / research / qa / customer / stop-report / commit-summary 등 *전부*. `README.md` · `CLAUDE.md` · 외부 .md · 사용자가 그 작업에 명시적으로 .md 요청한 경우만 예외.
2. **단일 HTML 파일 + 탭/버튼 인터랙티브 UI** — `role="tablist"` + `aria-selected`. **첫 번째 탭은 항상 "요약" 탭**(Summary/한눈에/Overview/TL;DR), 결론·핵심 지표 카드 3-5개 배치, 페이지 로드 시 기본 활성화.
3. **1뷰포트 무스크롤 대시보드** — 1440×900 기준 첫 화면 완결, 정보 많으면 서브탭·아코디언·모달로 분할, 표는 카드 내부 스크롤만 허용 (페이지 전체 스크롤 금지).
4. **저장 후 즉시 브라우저 자동 열기** — `Start-Process "<경로>"` (PowerShell) 또는 `cmd.exe /c start "" "<경로>"` (Bash). 링크만 알려주고 끝내지 말 것.

**서브에이전트 호출 시 의무**: 메인 Claude 가 `Task(subagent_type="harness-*")` 또는 다른 스킬을 호출할 때 프롬프트에 *"산출물은 CLAUDE.md §6.3.1 + harness/docs/html-output-rule.md 를 따른다 — 단일 HTML + 탭(첫 탭=요약) + 1뷰포트 + 저장 후 자동 열기"* 를 **명시 전달**.

**옛 문서와의 충돌**: `docs/workflow.md`, `docs/steps/*.md`, `templates/*.md` 가 `.md` 산출을 지시하더라도 이 규칙이 우선한다. 자동으로 `.html` 로 대체하고 위 4원칙을 적용.

---

## 폴더 생성 규칙

구현단계에서 새 폴더를 만들어야 할 때는 다음 규칙을 따릅니다:
- root폴더에 파일을 직접 만들지 말고 폴더를 만들어서 그 안에 파일을 넣는다.

## 학습파일 자동 Fallback (CRITICAL — 모든 harness skill / `/harness-*` 커맨드 공통)

`/harness` 스킬 또는 `/harness-*` 커맨드 호출 시, 각 agent 의 **학습파일을 반드시 컨텍스트에 prepend** 한다. 로드 순서는 항상 다음과 같다:

1. **공용 (마스터, 항상 존재)**: `~/.claude/skills/harness/agents/learning/<agent-name>.md`
2. **프로젝트 (있으면)**: `<PROJECT_ROOT>/.harness/agents/learning/<agent-name>.md`

**규칙**:
- 공용은 **항상** Read 한다. 즉 프로젝트에 학습파일이 없어도 **마스터(공용) 학습은 무조건 적용**된다.
- 프로젝트 파일이 있으면 추가로 Read 해서 공용 위에 덮어쓴다 (프로젝트가 이김).
- 프로젝트 파일이 없으면 본문에 `(없음)` 으로 명시. 마스터만으로 충분히 작동한다.
- 공용 학습파일이 누락된 경우 (마스터 자체에 없음) → `harness-setup` 으로 마스터 재동기화 권고 후 그 agent 자리에 `(빈 파일)` 명시하고 진행.

**적용 범위**: 모든 `harness-*` agent (planner / architect / tdd-guide / code-reviewer / security-reviewer / build-resolver / deep-researcher / qa-engineer / customer-user) 및 `/harness-*` 커맨드. `--noagent` 모드에서도 메인 Claude 자신이 동일하게 두 파일을 Read 한다.

상세 계약: [docs/workflow.md](docs/workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통)

## 실행 옵션 (요약)

| 플래그 | 동작 |
|--------|------|
| `--noagent` | harness-* subagent 호출 없이 메인 Claude 가 모든 step 의 작업을 직접 수행. Workflow 자체는 step1~complete 그대로 진행. 자세히: [docs/workflow.md](docs/workflow.md#--noagent-모드) |

---

## docs/ 안내판

| 파일 | 무엇을 다루나 |
|------|--------------|
| [donot.md](docs/donot.md) | `/harness` 전체 흐름에서 절대 하지 말아야 할 것들
| [setup.md](docs/setup.md) | 설치 + Windows/WSL 실행 환경 + 외부 AI(Codex) 부르는 방법 |
| [workflow.md](docs/workflow.md) | `/harness` 전체 흐름 — 어떤 순서로 무엇이 일어나는지 사람-친화 설명 |
| [steps/](docs/steps/) | step1 ~ step8 + complete 각 단계의 상세 절차 (한 step 당 한 파일) |
| [phases.md](docs/phases.md) | 단계별 상세 절차 (Phase 1 계획 + Phase 4 검토) |
| [stop-report.md](docs/stop-report.md) | 작업 마칠 때 · 중간에 멈출 때 사람이 읽는 종합 보고서 양식 |
| [context-layer.md](docs/context-layer.md) | 장기 메모리 (프로젝트 사양 문서) + AI 누적 학습 |
| [file-formats.md](docs/file-formats.md) | `.harness/` 안 모든 결과물 파일의 형식 표준 |
| [test-guide-format.md](docs/test-guide-format.md) | step6/step7 테스트 진행 전 작성하는 `test-guide-<slug>.md` 의 양식·재료·갱신 규칙 |
| [examples.md](docs/examples.md) | 실제 시나리오 예시 (성공 · 실패 · 중단 케이스) |
