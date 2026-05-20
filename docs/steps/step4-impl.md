# step4. 구현

**산출물**:
- 실제 프로젝트 코드 파일
- `.harness/progress-<slug>.md` 진행 기록

**입력 게이트 (skip 금지)**:
- `.harness/implementation-<slug>.md` 전문을 **반드시 다시 읽어** 메인 컨텍스트에 올린다.
- step3 의 5개 필수 섹션 (변경 파일 / 영향 영역 / 단계별 순서 / 테스트 전략 / 위험·롤백) 이 채워져 있는지 확인. 누락 시 step3 로 되돌린다.

**흐름** (메인 Claude 가 직접 구현):

1. **단계별 진행** — `implementation-<slug>.md` 의 *"단계별 구현 순서"* 를 한 단계씩 처리. 한 번에 전체 구현 금지.
2. 각 단계에서:
   - **읽기 먼저** — 변경 대상 파일을 Read 로 먼저 본다. 추측 편집 금지.
   - **TDD 권장** — 동작이 측정 가능한 경우 테스트를 먼저 작성(RED) → 구현(GREEN) → 정리(REFACTOR). 사용자가 명시적으로 TDD 면제를 요청한 경우만 생략.
   - **TDD 사이클이 막힐 때 일반 도구 호출**: 테스트 작성·구현·refactor 어느 단계든 3회 시도 후 진척이 없으면 `tdd` skill (Skill 도구) 또는 `tdd-guide` agent (Task 도구) 호출. RED → GREEN → REFACTOR 사이클 안내 받음.
   - **빌드/타입체크/lint 등 즉시 검증 가능한 항목**은 단계마다 실행. 실패하면 다음 단계로 넘어가지 않는다.
3. **변경 기록** — 각 단계 완료 시 `.harness/progress-<slug>.md` 에 다음 형식으로 누적:
   ```markdown
   ## Step N (<날짜·시간>)
   - 단계명: <implementation-<slug>.md 의 단계명>
   - 변경 파일: <경로 목록>
   - 검증: <테스트·빌드·타입체크 결과>
   - 비고: <발견된 문제·skip 한 항목>
   ```
4. 모든 단계 완료 → step5 로.

**제약 (`donot.md` 참조)**:
- *"동작할 것 같다"* 로 다음 단계 진행 금지. 검증 통과 후에만 진행.
- `implementation-<slug>.md` 에 없는 기능을 임의로 추가 금지. 추가 필요 시 step3 로 되돌린다.
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
