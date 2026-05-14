# Learning Data: harness-code-reviewer

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-code-reviewer` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] 리뷰어는 완벽함이 아닌 "시스템 전체 코드 건강도를 확실히 개선하는가" 를 승인 기준으로 삼아야 하며, 기술적 사실과 데이터가 의견·취향을 이긴다. 근거: Google Engineering Practices "The Standard of Code Review".
- [2026-05-14] 라인 커버리지는 "어디를 방문했는가" 만 알려주고, Mutation Score 는 "방문했을 때 실제 버그 감지력" 을 알려준다. 90%+ 라인 + mutation score 60% 미만 → 테스트가 실질 취약. 근거: Stryker Mutator + IEEE 2024 "Mutation Testing in Practice".
- [2026-05-14] (training) 리뷰 한 번에 처리 가능한 결함 발견 한계는 LOC 200~400. 그 이상 PR 은 결함 발견율이 급감 ("rubber stamp"). PR 크기가 한계를 넘으면 결함 0 보고도 신뢰 불가 — split 요청이 정답. 근거: SmartBear Cisco 코드 리뷰 연구 2006; Google Engineering Practices.
- [2026-05-14] (training) 리뷰는 정확성 → 보안 → 가독성 → 스타일 순으로 본다. 스타일 코멘트가 먼저 나가면 정확성·보안 이슈가 묻힌다. 자동화 가능한 스타일은 formatter/linter 로 전부 흡수. 근거: Google "How To Do A Code Review".

## Patterns
잘 통하는 접근법.

- [2026-05-14] API 시그니처는 "주 대상 먼저, 옵션 객체 마지막" 순서 유지. open/close·lock/unlock·set/get/delete 같은 대칭 쌍은 짝으로 검토해 한쪽 누락 탐지. 근거: Speakeasy API consistency + Clean Code Ch6.
- [2026-05-14] 리뷰 코멘트는 `suggestion:` / `issue:` / `nitpick:` / `praise:` prefix + `(non-blocking)` 데코레이터로 블로킹 여부 명시 → PR 지연 방지 + 기계 파싱 가능. 근거: Conventional Comments 표준 (conventionalcomments.org).
- [2026-05-14] (training) Guard clause + early return 으로 중첩 깊이 줄이기 — `if (!valid) return err;` 식 선조건 처리 후 본문은 1depth. else 체인 누적이 인지 부하의 1차 원인. 근거: Martin Fowler "Refactoring" 2nd Ed "Replace Nested Conditional with Guard Clauses".
- [2026-05-14] (training) 동시성 코드는 (1) shared mutable state, (2) lock 획득 순서, (3) cancel/timeout 전파 세 축으로 본다. 한 축이라도 명시되지 않으면 race / deadlock / leak 잠재. 근거: Java Concurrency in Practice Ch2-3; Rust async 가이드.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] 부울 변수·파라미터는 `is/has/can/should` 중 하나로 시작, 이중 부정 (`isNotDisabled`, `!isNotValid`) 즉시 거부. 근거: Clean Code Ch2.
- [2026-05-14] Train Wreck (`a.getB().getC().getD().process()`) 은 Law of Demeter 위반 + 중간 타입 변경 파급 은닉. 체인 3단 초과 시 중간 변수 추출 또는 Tell-Don't-Ask 리팩터 요청. 근거: Fowler "Refactoring" 2nd Ed.
- [2026-05-14] 수치/문자열 리터럴이 로직에 인라인이면 (magic number/string) 의미가 코드 부재 → 정확성 판단 불가. 명명된 상수/enum/config 없이 등장 시 블로킹. 근거: Clean Code Ch17.
- [2026-05-14] (training) 함수 파라미터 4개 초과 → 명시적 옵션 객체 (`fn({ a, b, c, d, e })`) 로 리팩토링 요청. 호출 측이 위치 의존을 잃고, 추가 파라미터의 호환성 비용 감소. 근거: Clean Code Ch3 "Function Arguments".
- [2026-05-14] (training) Feature envy — 메서드가 자기 클래스보다 다른 객체의 데이터를 더 자주 만지면 잘못된 위치. 옮기거나 책임 재배치. `obj.getX().getY().compute()` 가 길어지면 신호. 근거: Fowler "Refactoring" 2nd Ed.

## Project-Specific
프로젝트별 컨벤션. 공용 파일에서는 비어 있음.

(비어 있음)

## Open Questions
아직 결론 안 난 것.

- [2026-05-14] `validateUrl` 은 비-문자열 입력(`null`/`undefined`/`number`/`object`)을 `new URL()` 호출 전 타입 가드로 거부하는가, 아니면 `new URL()` 의 `TypeError` 를 catch 하여 래핑하는가? — 정책 표준화 필요.
- [2026-05-14] URL 길이 상한을 validator 레벨에서 적용할 것인가, README 경고만으로 족한가?
- [2026-05-14] ID 충돌 재시도 N회 초과 시 던지는 에러 타입은 무엇인가 (`Error`, 별도 서브클래스)?
- [2026-05-14] `ttlMs: 0` / `ttlMs: -1` / `ttlMs: Infinity` 는 어느 레이어에서 어떻게 처리하는가?
- [2026-05-14] LLM 보조 리뷰 (Copilot Code Review, CodeRabbit) 가 엣지케이스 탐지에서 주니어 수준 초과 사례 있으나 null/timezone/encoding 경계에서 체계적 False Negative 가능성. harness-code-reviewer 가 LLM 제안을 신뢰할 임계 조건 미정. 근거: 2025-2026 DEV/실증 사례.
