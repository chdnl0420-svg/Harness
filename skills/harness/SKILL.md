## 실행 옵션 (요약)

| 플래그 | 동작 |
|--------|------|
| `--noagent` | harness-* subagent 호출 없이 메인 Claude 가 모든 step 의 작업을 직접 수행. Workflow 자체는 step1~complete 그대로 진행. 자세히: [docs/workflow.md](docs/workflow.md#--noagent-모드) |

---

## docs/ 안내판

| 파일 | 무엇을 다루나 |
|------|--------------|
| [setup.md](docs/setup.md) | 설치 + Windows/WSL 실행 환경 + 외부 AI(Codex) 부르는 방법 |
| [workflow.md](docs/workflow.md) | `/harness` 전체 흐름 — 어떤 순서로 무엇이 일어나는지 사람-친화 설명 |
| [steps/](docs/steps/) | step1 ~ step8 + complete 각 단계의 상세 절차 (한 step 당 한 파일) |
| [phases.md](docs/phases.md) | 단계별 상세 절차 (Phase 1 계획 + Phase 4 검토) |
| [stop-report.md](docs/stop-report.md) | 작업 마칠 때 · 중간에 멈출 때 사람이 읽는 종합 보고서 양식 |
| [context-layer.md](docs/context-layer.md) | 장기 메모리 (프로젝트 사양 문서) + AI 누적 학습 |
| [file-formats.md](docs/file-formats.md) | `.harness/` 안 모든 결과물 파일의 형식 표준 |
| [test-guide-format.md](docs/test-guide-format.md) | step6/step7 테스트 진행 전 작성하는 `test-guide-<slug>.md` 의 양식·재료·갱신 규칙 |
| [examples.md](docs/examples.md) | 실제 시나리오 예시 (성공 · 실패 · 중단 케이스) |
