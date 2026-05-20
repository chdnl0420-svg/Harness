# step7. 커스터머 유저 테스트

**산출물**: `.harness/results/customer-<slug>.md`

**조건**: 워크플로우 전체에서 **단 1회만** 실행. step6 가 몇 번 FAIL → PASS 를 반복하든 이 단계는 한 번뿐.

**흐름**:
1. **테스트 가이드 확인** — step6 에서 작성·갱신된 `test-guide-<slug>.md` 최신본을 그대로 재사용 (이 단계에서 별도 작성 안 함). 가이드 없으면 step6 에서 누락된 것이므로 거기로 되돌려 작성 후 진행. 양식은 [../test-guide-format.md](../test-guide-format.md) 참조.
2. **실제 제품 빌드 + 설치 + 실행** (메인 Claude 가 직접 수행) — step6 의 dev 환경이 아니라, **실제 사용자가 받는 그 형태**로 설치하고 띄운다.
   - CLI 라면: production 빌드 후 글로벌/로컬 설치 (`npm i -g .`, `pip install .`, `cargo install --path .` 등 프로젝트에 맞는 방식)
   - 데스크톱 앱이라면: production 빌드 산출물(installer / app bundle) 을 사용자처럼 설치 후 실행
   - 웹 앱이라면: production 빌드(`npm run build` 등) 후 정적 서버 또는 preview 모드로 서빙. dev hot-reload 서버 금지
   - 모바일 앱이라면: release 빌드 산출물(APK/IPA) 을 device/emulator 에 설치 후 실행
   - 설치·실행 명령과 접근 경로(URL/실행 파일/명령) 를 `test-guide-<slug>.md` 의 "환경" 섹션에 production install 정보로 적어 둔다.
   - 설치/빌드 실패 시 사용자에게 보고 후 결정 요청 (BLOCKED).
3. `harness-customer-user` 에 위임 — **호출 방식 single source**: [`docs/procedures/customer-test-procedure.md`](../procedures/customer-test-procedure.md) 의 4단계 흐름 + LLM 페르소나 함정 6종 차단 + 권한 정책. 다음 3가지 어댑터 중 하나로 위임 (셋 다 동일 procedure):
   - `harness-customer-user` skill (`Skill` 도구)
   - `harness-customer-user` agent (`Task` 도구 — 본 워크플로우의 *기본*. subagent 별도 컨텍스트 + 페르소나 객관성)
   - `/harness-customer-user` slash (사용자 진입점 — workflow 내부에선 사용 안 함)
   - **[Learning Prepend 계약](../workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통) 1·2·3·4 단계 수행 필수.** 즉 다음을 Read 후 `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더로 prepend:
     - `~/.claude/skills/harness/agents/learning/harness-customer-user.md` (공용만 — 프로젝트 learning 은 2026-05-20 폐기)
   - **test-guide-<slug>.md 전문 prepend** (Prior Learning 헤더 다음, 본 작업 앞)
   - 누락 시 도우미가 `[BLOCKED]` 로 거부.
   - 도우미는 메인이 설치/실행해 둔 **실제 설치본**에 접속해서 테스트한다.
4. 도우미가 "제품을 처음 본 일반인" 페르소나로 가이드 기능 흐름을 시도 — 스크린샷 + 클릭
5. 보고서 작성 (첫인상, 막힌 지점, 헷갈린 단어 등)
6. **게이트 아님** — 결과 통과/실패와 무관하게 다음 단계 (step8) 로
   - 발견된 사용성 이슈는 complete 단계의 `report-<slug>.html` 에 요약 포함
   - 사용자가 "지금 고치자" 라고 하면 별도 요청으로 새 워크플로우 시작
7. **정리** — 메인 Claude 가 글로벌 설치 등 사용자 시스템에 흔적이 남는 항목을 제거 (예: `npm uninstall -g <pkg>`). 정리 내용도 보고서에 명시.

**다음 단계 안내**: step7 의 *결과* (개선 제안 / 좋았던 점 / 헷갈린 단어 등) 처리 방향은 step8 commit/push 완료 후 **complete 진입 전 사용자 확인 (AskUserQuestion)** 으로 한 번 물어본다 (noask 정책의 단 하나 예외). 3선택지 — A) 그대로 진행 (개선안 report 요약) / B) 일시정지 (직접 검토 후 재호출) / C) 개선안으로 신규 워크플로우 자동 시작 (auto_triggered_from chain + 무한 루프 차단). 자세히: [complete.md](complete.md#입력-게이트-critical--noask-예외-반드시-통과-후-진입).

**제약**:
- 커스터머 도우미도 보고서·스크린샷 외 파일 수정·생성 금지 — 빌드/설치/정리는 모두 메인 Claude 책임
- QA 와 시점·페르소나가 다르므로 시나리오를 QA 보고서와 중복시키지 않음
- **dev 환경 / 테스트용 빌드로 대체 금지** — 실제 사용자가 받는 그 산출물로 테스트해야 의미가 있다

**Worktree 처리 (CRITICAL)**:
- `harness-customer-user` 를 Task 도구로 호출할 때 **`isolation: "worktree"` 옵션 절대 사용 금지.** 격리된 worktree 안에는 `.harness/`, `test-guide-<slug>.md`, 설치된 production 산출물이 없으므로 agent 가 실패한다.
- 메인 Claude 가 worktree 안에서 작업 중이라면 step6 와 동일 — 메인 repo 의 `.harness/` 경로를 식별해 prompt 에 절대경로로 prepend, 보고서도 메인 repo 의 `.harness/results/customer-<slug>.md` 에 작성한다.
