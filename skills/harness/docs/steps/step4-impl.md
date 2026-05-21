# step4. 구현

**산출물**:
- 실제 프로젝트 코드 파일
- `.harness/progress-<slug>.md` 진행 기록

**입력 게이트 (skip 금지)**:
- 단일 모드면 `.harness/implementation-<slug>.html` 전문을 **반드시 다시 읽어** 메인 컨텍스트에 올린다.
- Chunks 모드면 현재 chunk 의 `.harness/implementation-<slug>-chunk-<i>.html` 전문을 **반드시 다시 읽어** 메인 컨텍스트에 올린다. `implementation-<slug>-chunks-overview.html` 은 현재 chunk 번호, 의존성, DDD migration 흐름 확인용으로만 함께 읽는다.
- step3 의 11개 필수 검토 섹션 (변경 파일 / 영향 영역 / 코드베이스 설계 리서치 / DDD 코드베이스 매핑 / DDD 마이그레이션 계획 / Architecture Decision·Views / Fitness Function·Enforcement / TDD RED·GREEN·REFACTOR 계획 / 단계별 순서 / 테스트 전략 / 위험·롤백) 이 채워져 있는지 확인. 누락 시 보강을 강제 권고하고, 보강하지 않으면 사유와 대체 검증을 기록한다.
- DDD/TDD 권고 검증기를 실행한다. 산출물 권고 누락은 구현 금지가 아니라 경고와 보강 대상으로 다룬다.
  ```bash
  python ~/.codex/skills/harness/core/validate-ddd-codebase.py --skill-root ~/.codex/skills/harness --project <PROJECT_ROOT> --slug <slug> --require-artifacts
  ```

**흐름** (메인 Claude 가 직접 구현):

1. **단계별 진행** — `implementation-<slug>.html` 의 *"단계별 구현 순서"* 를 한 단계씩 처리. 한 번에 전체 구현 금지.
2. 각 단계에서:
   - **읽기 먼저** — 변경 대상 파일을 Read 로 먼저 본다. 추측 편집 금지.
   - **TDD 강제 권고** — 동작 변경이면 production code 수정 전에 테스트를 먼저 작성하고 실패를 확인한다(RED). 버그 수정이면 먼저 재현 테스트를 만든다.
   - **RED 증거 기록** — 실패한 테스트 명령, 실패한 테스트명, 실패 메시지 핵심 줄을 progress 에 적는다. 실패하지 않는 테스트는 RED 증거가 아니며, 이 경우 테스트를 고친 뒤 다시 실행한다.
   - **GREEN 최소 구현** — RED 테스트를 통과시키는 최소 production code 만 수정한다. 이 단계에서 scope creep 금지.
   - **REFACTOR 재검증** — 정리 후 동일 테스트와 관련 빠른 regression 명령을 다시 실행한다. refactor 중 behavior 변경이 필요해지면 새 RED 테스트부터 시작한다.
   - **TDD 예외 처리** — step3 의 *"TDD RED/GREEN/REFACTOR 계획"* 에 예외 사유와 대체 검증이 적힌 경우 생략 가능. 예외 사유 없이 test-after-code 로 진행하면 progress 에 경고를 남기고 대체 검증을 필수로 기록한다.
   - **TDD 사이클이 막힐 때 일반 도구 호출**: 테스트 작성·구현·refactor 어느 단계든 3회 시도 후 진척이 없으면 사용 가능한 테스트/QA 관련 skill 또는 agent를 호출해 RED → GREEN → REFACTOR 사이클 안내를 받는다. 사용 가능한 전용 도구가 없으면 테스트 가능성·oracle·범위를 다시 잡고 예외 사유를 기록한다.
   - **빌드/타입체크/lint 등 즉시 검증 가능한 항목**은 단계마다 실행. 실패하면 다음 단계로 넘어가지 않는다.
3. **변경 기록** — 각 단계 완료 시 `.harness/progress-<slug>.md` 에 다음 형식으로 누적:
   ```markdown
   ## Step N (<날짜·시간>)
   - 단계명: <implementation-<slug>.html 의 단계명>
   - 변경 파일: <경로 목록>
   - TDD: RED=<실패 테스트·메시지> / GREEN=<통과 테스트> / REFACTOR=<재검증 명령> / 면제=<사유 또는 N/A>
   - 검증: <테스트·빌드·타입체크 결과>
   - 비고: <발견된 문제·skip 한 항목>
   ```
4. 모든 단계 완료 → step5 로.

**제약 (`donot.md` 참조)**:
- *"동작할 것 같다"* 로 다음 단계 진행 금지. 검증 통과 후에만 진행.
- 동작 변경을 production code 먼저 수정한 뒤 테스트를 맞추는 test-after-code 는 금지 수준으로 강하게 경고한다. 발견 시 TDD 계획을 보강하거나 예외 사유와 대체 검증을 필수로 남긴다.
- `implementation-<slug>.html` 에 없는 기능을 임의로 추가 금지. 추가 필요 시 step3 로 되돌린다.
- 빌드 실패를 *"나중에 한꺼번에 고치자"* 로 미루지 않는다. 즉시 해결 또는 step3 로 회송.
- 동작하지 않는 기존 코드 (버튼·필터 등) 를 임의로 제거하지 않는다 — 버그일 수 있다.

**빌드 실패 처리**:
- 3회 연속 같은 에러 → 일반 도구 호출로 빌드 그린 복구:
  - skill `build-fix` (Skill 도구) — 언어 무관 일반 절차
  - agent `*-build-resolver` (Task 도구) — 언어별: `typescript-build-resolver`, `python-build-resolver`, `go-build-resolver`, `rust-build-resolver`, `java-build-resolver`, `cpp-build-resolver`, `kotlin-build-resolver`, `dart-build-resolver`, `pytorch-build-resolver` (PyTorch 런타임/CUDA 한정), 기본 fallback `build-error-resolver`
- 도우미·진단으로도 안 풀리면 step3 로 되돌려 계획 자체를 수정.

---

## Chunks 모드 (2026-05-20 신규)

**Chunks 모드일 때** (step3 의 임계값 통과 시):
- 본 step 진입 시 *현 chunk_i 의 implementation plan* 만 본다 — `implementation-<slug>-chunk-<i>.html`. 다른 chunk 의 plan 읽지 않음.
- 변경 범위도 *현 chunk 의 변경 대상 파일* 만. 다른 chunk 의 파일 건드리면 chunks 격리 위반.
- progress 파일의 `current_chunk` 필드를 본 step 진입 시 갱신.
- 자세히: [step3-impl-plan.md Chunks 분해 절차](step3-impl-plan.md#chunks-분해-절차-critical--2026-05-20-신규).
