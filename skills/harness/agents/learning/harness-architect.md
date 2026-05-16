# Learning Data: harness-architect

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-architect` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] 시간/무작위성에 의존하는 모듈은 조립자(index/factory) 레벨에서도 `now` / `generateId` 주입 슬롯을 열어둘 것. 하위(store)에만 슬롯이 있고 상위에 없으면 통합 테스트가 실시간 의존하게 되어 결정론이 깨진다.
- [2026-05-14] Hexagonal 에서 Port 는 도메인 언어로 정의. 어댑터 반환 타입(JPA Entity, HTTP DTO) 이 Port 시그니처에 노출되면 "어댑터가 안쪽 오염" 구조 붕괴 시작. 근거: Mark Seemann "Ports and fat adapters" (blog.ploeh.dk 2025).
- [2026-05-14] IoC 컨테이너 없이 "파라미터 기본값으로 실 구현체 주입, 테스트 시 파라미터 교체" (DI Slot with Default) 패턴이 소규모 모듈에서 가장 낮은 인지 부하. 수십 개 의존성 초과 시 명시적 컨테이너가 안전하며, Service Locator 는 어느 규모에서도 안티패턴. 근거: Martin Fowler "Inversion of Control Containers".
- [2026-05-14] Fitness Function 은 "아키텍처 특성을 코드로 표현한 자동화 테스트". 순환 의존 금지·응답시간·결합도 임계값을 CI 에서 지속 검증하는 유일한 방법. 근거: Building Evolutionary Architectures (Ford/Parsons/Kua 2017).
- [2026-05-14] (training) Conway's Law — "시스템 아키텍처는 그것을 만든 조직의 소통 구조를 닮는다". 모듈/팀 경계가 어긋나면 어느 한쪽이 깨진다. 새 모듈을 그릴 때 누가 소유·온콜·배포할지 함께 그린다. 근거: Melvin Conway 1968.
- [2026-05-14] (training) 분산 시스템의 첫 결정은 "동기 vs 비동기 경계 어디" 다. 트랜잭션·일관성 요구가 높은 호출만 동기, 나머지는 메시지/이벤트로 분리. 동기 호출 체인은 latency 곱셈 + cascading failure 의 원인. 근거: AWS "Designing distributed systems" / Martin Kleppmann DDIA Ch11.

## Patterns
잘 통하는 접근법.

- [2026-05-14] 다층 factory 에서는 모든 DI 슬롯에 기본값을 제공해 "production caller 는 옵션 1개, 테스트는 슬롯 다수" 형태로 인터페이스를 1개만 유지한다 (`createX({ ttlMs, now = Date.now, generateId = defaultGen, store = createDefaultStore() })`).
- [2026-05-14] 에러 모델은 "호출자가 에러를 처리할 수 있는가" 기준으로 선택. 라이브러리/도메인 경계는 `Result<T, 구체 enum>` 으로 케이스 타입 표현, 애플리케이션 최상단(CLI/HTTP handler) 은 opaque error 로 수렴. 근거: mmapped.blog "Designing error types in Rust" (2023).
- [2026-05-14] ADR 의 핵심 가치는 결정이 내려지기 *전에* 작성되어 대안·트레이드오프를 명시 → 검토 가능 상태. 사후 ADR 은 "fait accompli 문서화" 로 실질 효과 없음. 근거: Martin Fowler "ArchitectureDecisionRecord".
- [2026-05-14] (training) Strangler Fig — 레거시 일시 교체 대신, 신/구 시스템이 façade 뒤에서 공존하며 요청을 점진적으로 신 시스템으로 이동. cutover 리스크 분산. 근거: Martin Fowler "StranglerFigApplication" 2004.
- [2026-05-14] (training) Bulkhead — 한 다운스트림 장애가 전체 스레드풀/커넥션풀을 잠식하지 않도록 자원을 격벽 분할. 외부 호출당 별도 풀+timeout+circuit breaker 3종 세트. 근거: Michael Nygard "Release It!" 2nd Ed.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] 에러 클래스 위치를 "파일 A 또는 inline" 처럼 plan 단계에서 두 옵션으로 남겨두면 import 경로가 분기되어 추후 재노출/리팩터링 비용 발생. plan 단계에서 1곳으로 고정.
- [2026-05-14] 잘못된 추상화(Wrong Abstraction) 의 징후: 추상화 수정에 `boolean flag` / `if typeof` 분기를 파라미터로 추가하기 시작하는 시점. 처방은 더 다듬기가 아니라 복제본으로 inline 되돌리고 새 압력이 올바른 분리 지점 드러낼 때까지 기다림. 근거: Sandi Metz "The Wrong Abstraction" (2016).
- [2026-05-14] Inner-platform Effect: "나중에 필요할지도" 사고에서 시작되어 기존 런타임/프레임워크 기능을 재구현하는 설정 시스템을 내부에 만들어냄. 진단: "이 configurability 를 실제 사용자가 증명할 수 있는가". 근거: Wikipedia "Inner-platform effect" / The Daily WTF.
- [2026-05-14] (training) Distributed Monolith — 서비스로 분리는 했지만 호출 그래프가 동기 + 강결합 + 동시 배포 필수. 모놀리식 단순성도 잃고 분산 시스템 복잡성도 얻은 최악 형태. 진단 신호: "한 서비스 배포가 다른 서비스 재시작을 요구" / "데이터베이스 공유". 근거: Sam Newman "Building Microservices" 2nd Ed.
- [2026-05-14] (training) 모든 서비스가 자기 DB 를 가져야 한다는 원칙을 회피하려고 shared schema 를 두면 schema 변경이 N 팀 협의로 비대해진다. read-only replica + 도메인 이벤트 발행이 우회로. 근거: DDIA Ch10; Sam Newman.
- [2026-05-15] (training) **Fitness function 도구 선택 — 언어별 표준 + Python 공백 주의** — Java→ArchUnit (ThoughtWorks Radar Adopt 단계), Kotlin→Konsist (Mercedes-Benz.io 2024-10 사례), .NET→NetArchTest/ArchUnitNET. **Python→Tach 는 2025-06-03 유지보수 중단 공식 발표**, 포크 dtach 존재하나 미래 불확실. Python 프로젝트에 fitness function 적용 시 `import-linter` 등 대안 추가 검증 필요. 공통: 모든 도구가 *"CI 파이프라인에 아키텍처 규칙을 단위 테스트로 인코딩"* 으로 수렴, 런타임 영향 없음. 근거: archunit.org 공식; github.com/LemonAppDev/konsist; github.com/tach-org/tach (중단 발표); github.com/BenMorris/NetArchTest.
- [2026-05-15] (training) **AI 생성 ADR hallucination 3 유형** — ① Hallucinated reference material (존재하지 않는 API·웹페이지·제품 기능 인용), ② Misaligned justification (실제 의사결정 맥락과 무관한 근거 생성), ③ Overgeneralization (충분한 증거 없이 가정·추론). 정량 분포 (arXiv 2602.07609, 980 ADR / 109 GitHub repos): Semantic/Logical Misinterpretation 44.57% + Missing Context Inference 28.26% + Insufficient Domain Knowledge 18.48% + Overgeneralization 8.7%. 탐지 정확도 (Marco-o1 91.1% / Qwen3 90.4%) 도 "Code Is Insufficient to Answer(CIA)" 카테고리에서 F1 0.708~0.792 로 급락. 완화: 두-LLM judge 패턴 (생성 LLM 과 별도 LLM 이 논리 결함 비평) + 인간 최종 검토 + 충분한 코드베이스 컨텍스트. 근거: Equal Experts ADR + GenAI; arXiv 2602.07609 "LLM ADR Violation Detection"; arXiv 2403.01709.
- [2026-05-15] (training) **Distributed Monolith 자동 진단 = OTel Service Graph Connector + Grafana 스택** — 클라이언트 span + 서버 span 쌍으로 서비스 간 의존성 메트릭 자동 생성. 핵심 메트릭: `traces_service_graph_request_total{client, server}` (호출 그래프), `request_failed_total{server="unknown"}` (계측되지 않은 숨겨진 의존성 탐지). `virtual_node_peer_attributes: [db.name, peer.service, messaging.system]` 설정으로 계측 미완 DB·캐시·메시지 브로커를 가상 노드로 표현 → 공유 DB 패턴 가시화. Dynatrace ServiceFlow / PurePath 가 상용 대안. 근거: oneuptime.com "OTel Service Dependency Graphs" 2026-02; dynatrace.com 분산 추적 docs.
- [2026-05-15] (training) **Lookup/Resolve return contract — 언어별 분기 + DDD 컨센서스** — Rust: `Result<T,E>` / `Option<T>` 컴파일러 강제. Go: 다중 반환값 `(T, error)`, panic 은 unrecoverable 만. TS: throw 기반 + `Result<T,E>` 패턴 확산 (neverthrow / ts-results). Java: `Optional<T>` 관용구 (Spring Data JPA 표준). Python: 전통적 raise/except, `returns` 라이브러리로 Result 패턴 도입 증가 (비주류). **DDD 컨센서스**: Repository → null/Optional/None 반환, throw 는 Application Service 또는 Domain Service 레이어 결정. Repository 가 직접 throw 하면 단일 책임 원칙 위반. 근거: dev.to "Rust-like error handling TS"; enterprisecraftsmanship.com "Advanced error handling"; medium.com "Stop returning null from Repositories".

## Project-Specific
프로젝트별 컨벤션. 공용 파일에서는 비어 있음.

(비어 있음)

## Open Questions
아직 결론 안 난 것.

- [2026-05-15] **Distributed Monolith 공유 DB 패턴 자동 정적 탐지** — OTel virtual node 로 시각화는 가능하나 "두 서비스가 동일 DB 스키마를 공유하는가" 를 코드/스키마 수준에서 자동 검출하는 전용 도구 미발견. 동시 배포 의존성 탐지도 동일.
- [2026-05-15] **AI 기반 조직-아키텍처 정렬 전용 도구** — SAFe Team Topologies for AI-enabled Teams 등 프레임워크 확장은 있으나, 실제 코드베이스와 org chart 를 연결해 misalignment 탐지하는 제품화 도구는 2026-05 기준 미확인.
- [2026-05-15] **Python fitness function 표준 후속** — Tach 중단 이후 import-linter 가 후보로 거론되나 직접 검증 미완. Python 진영의 표준 대체재 미정.

## Resolved Questions
- [2026-05-15] **lookup/resolve 미존재·만료 시 반환 contract: throw vs null** → 해소. **DDD 컨센서스**: Repository → null/Optional/None 반환, throw 는 Application Service 또는 Domain Service 레이어. Repository 직접 throw = 단일 책임 위반. 언어별 관용구: Rust `Option/Result`, Go `(T, error)`, Java `Optional<T>` (Spring Data JPA 표준), TS `Result` 라이브러리 확산. (Patterns 의 "Lookup/Resolve return contract" entry 로 이동)
