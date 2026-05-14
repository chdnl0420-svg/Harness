# Learning Data: harness-tdd-guide

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-tdd-guide` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] London School (mockist/outside-in) 은 외부 협력자 인터페이스 설계 시 적합, Chicago School (classicist/state-based) 은 도메인 로직 정확성 검증 시 적합. 두 스타일은 상호 배타적 아닌 상호 보완적. 근거: Freeman & Pryce "GOOS" (2009); Symfony 2024 "TDD Styles".
- [2026-05-14] 80% 라인 커버리지는 "테스트가 실행됐다" 만 증명. 분기·변이(mutation) 점수가 실제 결함 탐지력의 진짜 지표. Stryker (JS/.NET), mutmut (Python), PIT (Java) 로 mutant kill rate 측정. 근거: IEEE Software 2024 "Mutation Testing in Practice"; Stryker docs.
- [2026-05-14] 외부 라이브러리/프레임워크를 직접 mock 하지 말고, 자체 어댑터 인터페이스로 감싼 뒤 그 인터페이스를 mock. 외부 API 변경이 테스트 전체를 깨뜨리는 것 방지. 근거: GOOS Ch7 "Don't Mock What You Don't Own"; Google Testing Blog.
- [2026-05-14] (training) Arrange-Act-Assert (AAA) 또는 Given-When-Then 구조를 명시적 빈 줄로 구분 → 테스트가 읽기 쉬워지고 assertion 위치 즉시 파악. 한 테스트에 Act 가 2개 이상이면 두 시나리오로 split 신호. 근거: Kent Beck "TDD By Example"; Liz Keogh BDD.
- [2026-05-14] (training) Test naming 은 `methodName_condition_expectedResult` 또는 `should X when Y` 패턴 일관. 실패 메시지 만으로 무엇이 깨졌는지 알 수 있어야 함. 근거: Roy Osherove "The Art of Unit Testing" 2nd Ed.

## Patterns
잘 통하는 접근법.

- [2026-05-14] 마이크로서비스에서는 서비스 간 통합 테스트 비중 두는 Spotify Honeycomb, 단일 FE 앱에서는 통합 중심 Kent C. Dodds Testing Trophy. 서비스 경계 유형에 따라 테스트 형태 선택. 근거: Spotify Engineering 2018; Kent C. Dodds 2018.
- [2026-05-14] 시간/타이머 의존 테스트는 `vi.useFakeTimers()` / `jest.useFakeTimers()` / node:test `mock.timers` 로 결정론. `advanceTimersByTimeAsync` 로 promise-timer 교착 회피. `afterEach` 복원 필수. `sleep` 절대 금지. 근거: Vitest docs; Mergify 2024.
- [2026-05-14] 알고리즘 불변식 (역함수, 교환법칙, 멱등성) 이 성립해야 하는 순수 함수/파서/직렬화는 예시 기반 대신 fast-check (JS) / Hypothesis (Python) / QuickCheck (Rust) 로 수백 케이스 자동 생성 + shrinking 으로 최소 반례 확보. 근거: Goldstein et al. ICSE 2024.
- [2026-05-14] (training) Outside-in TDD — 가장 바깥의 acceptance/integration test 부터 시작해 안쪽으로 unit test 를 채워 나간다. 도메인 모델을 사용자 가치 흐름에 정렬시키는 효과. 근거: Freeman & Pryce GOOS Ch5.
- [2026-05-14] (training) Test data builder / Object Mother — 시나리오마다 `User.create({...20 fields...})` 반복하는 대신 `aUser().withEmail(...).verified().build()` 빌더 패턴. 테스트 의도가 데이터 조립 코드에 묻히지 않음. 근거: GOOS Ch22 "Test Data Builders".

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] LLM 이 생성한 테스트는 기존 코드 재현 또는 assertion 오생성 경향. "커버리지는 높지만 결함 탐지력이 낮은" 허위 안전감 생성. 도메인 전문가가 oracle(기대값) 정확성 검토 필수. 근거: arXiv 2504.18985 (2025); Pactflow 2024.
- [2026-05-14] (training) Snapshot 테스트 남용 — 모든 컴포넌트/응답을 toMatchSnapshot 하면 의도된 변경과 회귀를 구별 못 함. 결국 "자동 업데이트" 가 일상화되어 회귀 검출력 소실. 작은 단위에 명시적 assertion 우선, 거대 출력에만 snapshot 보조. 근거: Kent C. Dodds "Effective Snapshot Testing".
- [2026-05-14] (training) Production 로직을 테스트 안에서 다시 계산 (`expect(sum(a,b)).toBe(a+b)`) → 구현을 거울처럼 검증할 뿐 결함 검출 0. 기대값은 손으로 계산한 상수 또는 독립 reference 구현이어야 한다. 근거: Beck "TDD By Example" Ch1.

## Project-Specific
프로젝트별 컨벤션. 공용 파일에서는 비어 있음.

(비어 있음)

## Open Questions
아직 결론 안 난 것.

- [2026-05-14] Pact 기반 Consumer-Driven Contract Testing 이 마이크로서비스 E2E 비용 절감 대안으로 부상. Pact Rust core 마이그레이션 후 LLM 자동 생성 계약 테스트 정확성 미검증 — AI 생성 provider state 신뢰도 평가 기준 필요. 근거: Sachith Dassanayake 2026-02-10; Pactflow 2024.
