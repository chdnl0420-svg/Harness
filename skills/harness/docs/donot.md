# /harness Do not

`/harness` 워크플로 전체에서 **절대 하지 말아야 할 것들**. 위반 시 즉시 중단하고 사용자에게 보고한다.

---

## 1. 사용자 의도·범위

- **CRITICAL: 하이레벨 기능 변경은 반드시 `AskUserQuestion` 으로 사용자 동의를 받는다.** 동의 없이 기능을 바꾸지 않는다.
- **CRITICAL: 목표는 사용자가 지정한 그것이다.** 중간에 목표를 갈아치우지 않는다. 예: "앱을 만들어줘" 라고 했는데 "테스트용으로만 만들었습니다" 는 완수가 아니다.
- 동작하지 않는 버튼·필터·드래그 동작 등은 **임의로 제거하지 않는다.** 동작 안 하는 것 자체가 버그일 수 있다. 제거하려면 사용자 확인.
- 사용자가 명시하지 않은 라이브러리·아키텍처·디자인 방향을 임의로 도입하지 않는다.

## 2. Step 스킵·통합·생략

- step 자체에 명시된 분기 규칙이 아닌 한 **어떤 step 도 스킵·통합·무시할 수 없다.** 자세한 규칙은 [workflow.md](workflow.md#critical-step-스킵·무시-금지) 참조.
- "간단하니 생략", "이전에 했으니 패스", "사용자가 급해서 점프" 같은 임의 판단 금지.
- 사용자가 step 자체 규칙에 없는 스킵을 요청해도 거절하고 워크플로 규칙을 따른다.

## 3. Step 간 입력 누락

- step3 시작 시 `domain-<slug>.md` 전문을 **반드시 다시 읽는다.** "step2 에서 만들었으니 기억할 것" 으로 넘기지 않는다.
- step4 시작 시 `implementation-<slug>.md` 전문을 **반드시 다시 읽는다.**
- step6/step7 도우미 호출 시 `test-guide-<slug>.md` 전문을 prompt 에 prepend 하지 않으면 호출 자체를 하지 않는다.
- **모든 `harness-*` subagent 호출 시 [Learning Prepend 계약](workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통) 4단계 (파일 경로 식별 → Read → `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더로 prepend → 본 작업 prepend) 를 모두 수행하지 않은 채 호출하지 않는다.** 학습 파일 경로를 "기억"이나 "요약"으로 대체 금지 — Read 도구로 매번 실제 읽어 본문 전체를 prompt 에 넣어야 한다. 공용·프로젝트 둘 다 비어 있으면 `"(빈 파일)"` / `"(없음)"` 으로 명시. 위반 시 도우미가 `[BLOCKED] Prior Learning header 누락` 으로 거부함.
- 통합 모드에서 메인 Claude 가 페르소나 도우미(harness-customer-user / harness-qa-engineer / harness-deep-researcher) 자리를 직접 수행할 때도 동일하게 공용 학습 파일을 Read 해 본인 컨텍스트에 올린다. 누락 시 학습이 반영되지 않은 결정 = 위반. (프로젝트 learning 은 2026-05-20 폐기 — 공용만 prepend. `.harness/.noagent` 마커도 동일 폐기.)

## 4. 추측 구현

- 코드를 만들기 전에 **기존 코드베이스를 먼저 읽는다.** 파일 위치·기존 패턴·의존성 확인 없이 step4 에 진입하지 않는다.
- 라이브러리 API 를 "기억"으로 사용하지 않는다. 불확실하면 Context7 / 공식 문서 / 실제 패키지 코드를 확인.
- 테스트 없이 "동작할 것 같다" 로 step5 에 넘기지 않는다.

## 5. 가짜 완료

- **테스트만 통과한 것은 완수가 아니다.** 실제 사용자 시나리오가 동작해야 한다. step6 / step7 의 가이드 시나리오가 PASS 되지 않으면 완수 보고 금지.
- step5 LGTM:YES 가 안 나왔는데 step6 로 진입하지 않는다.
- step6 가 BLOCKED(테스트 자체 불가)인데 PASS 처럼 다음 단계로 흘리지 않는다.
- "자동화 도구 없음" 을 게이트 통과의 사유로 삼지 않는다. BLOCKED 로 명시하고 사용자 결정 요청.

## 6. Worktree·격리 함정

- `harness-qa-engineer`, `harness-customer-user` 등 step6/step7 도우미를 Task 도구로 호출할 때 **`isolation: "worktree"` 옵션 절대 금지.** 격리 worktree 안에는 `.harness/`, `test-guide`, 스크린샷이 없어 도우미가 실패한다.
- 메인 Claude 자신이 worktree 안에서 작업 중이면 **step6 시작 전 메인 repo 의 `.harness/` 경로를 명시적으로 식별**해 도우미 prompt 에 절대경로로 prepend.
- worktree 안에 새 `.harness/` 자동 생성 금지 — 자료가 둘로 갈라진다.

## 7. 권한 정책 위반

- QA·커스터머 도우미는 보고서·스크린샷 외 **어떤 파일도 수정·생성하지 않는다.** Edit 도구 부여 안 됨. 위반 시 보고서에 "권한 정책 위반: <행위>" 명시 후 중단.
- 도우미가 빌드·마이그레이션·`git add/commit/push`·의존성 설치를 시도하지 않는다.
- 메인 Claude 도 사용자가 commit/push 를 명시적으로 요청하지 않은 한 임의로 `git push`, `git reset --hard`, `git push --force` 등 파괴적 동작 금지.

## 8. 리뷰·테스트 형식화

- Codex 리뷰 응답에서 LGTM 판정을 **임의로 해석하지 않는다.** 응답에 명시적 LGTM 라벨이 없으면 NO 로 간주하고 step3 로 되돌린다.
- 리뷰가 LGTM:NO 인데 메인 Claude 가 직접 코드를 고치고 LGTM:YES 처럼 진행하지 않는다. 반드시 step3 로 되돌아간다.
- QA 도우미가 "retry 후 PASS" 를 그냥 통과시키지 않는다. flaky 셀로 분류해 기록.


---

> **2026-05-20 폐기 안내**: 본 문서가 언급하는 `--noagent` 플래그 / `.harness/.noagent` 마커 / Task subagent 분기는 모두 폐기됨. 모든 harness-* 단위는 `Skill` 도구로 호출하는 *skill* 으로 통합. 자세히: [harness/SKILL.md 실행 옵션](~/.claude/skills/harness/SKILL.md#실행-옵션-2026-05-20-단순화--agent--skill-전환-후).

