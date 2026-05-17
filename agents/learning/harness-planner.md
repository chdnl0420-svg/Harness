# Learning Data: harness-planner

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-planner` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] 🚨 **STRONG DIRECTIVE — Plan Readability (최우선)**: 사용자에게 보여주는 plan 출력은 반드시 **중·고등학생이 읽고 이해 가능**해야 한다. 다른 모든 출력 지침보다 우선. 규칙: ① 짧은 문장 (두 줄 넘으면 다시 쓰기) ② 한글 우선, 영어 기술용어는 처음 등장 시 1줄 풀이 (예: "리팩토링(코드 정리)", "fallback(대안 사용)") ③ 일상어 ("수행" → "한다", "구현" → "만든다", "검증" → "확인") ④ 능동태, 수동태("처리된다") 금지 ⑤ 강조는 **굵게** 만, 이모지 절제 ⑥ 단계마다 "왜 이걸 하는가" 1줄 포함 ⑦ 위험은 "무슨 일이 생길 수 있는지" + "어떻게 막을지" 둘 다 일상어로 ⑧ 코드 블록 짧게, 긴 diff·stack trace 금지 (파일 경로만). 출력 전 자체 점검 4가지: ⓐ 중학생이 plan 만 보고 "무엇·왜·어떻게 확인" 말할 수 있나 ⓑ 풀이 없는 영어 약어 0개 ⓒ 두 줄 넘는 문장 0개 ⓓ 수동태 0개. 하나라도 NO → **다시 쓴다**.
- [2026-05-14] SSRF 차단 URL validator 는 "문자열 검증" 책임만 지고 DNS resolve 시점 검증은 fetch 레이어로 분리해야 한다. 한 함수가 양쪽을 책임지면 DNS rebinding 에 의해 검증이 무력화된다.
- [2026-05-14] ADR은 결정 자체보다 **결정 당시의 맥락(context)과 기각된 대안(rejected alternatives)** 을 기록하는 것이 핵심 가치다. 근거: Michael Nygard 2011 ADR template — Context / Considered Options / Consequences.
- [2026-05-14] 계획 단계의 성공 기준은 "기능이 동작한다"가 아니라 **측정 가능한 결과** 로 작성해야 한다 (예: "p95 응답시간 200ms 이하"). 근거: BDD Given-When-Then + Atlassian acceptance criteria 가이드.
- [2026-05-14] LLM agent 워크플로우에서 계획 단계는 평가 기준(eval criteria) 을 구현 전에 먼저 정의해야 한다 — eval-driven development 의 핵심. 근거: arxiv 2411.13768 "EDDOps".
- [2026-05-14] (training) "Wicked problem" — 요구사항 자체가 정의되지 않은 문제는 plan 1회 작성으로 끝나지 않는다. 첫 plan 은 "탐색용 가설" 임을 명시하고 학습 후 갱신 트리거를 미리 설계해야 한다. 근거: Rittel & Webber 1973 "Dilemmas in a General Theory of Planning".
- [2026-05-14] (training) 시간 추정은 Cone of Uncertainty — 프로젝트 초기엔 실제의 0.25~4배 범위. 단일 숫자 대신 best/likely/worst 3 값으로 제시하고, phase 마다 좁혀나간다. 근거: Steve McConnell "Software Estimation".

## Patterns
잘 통하는 접근법.

- [2026-05-14] 시간/랜덤성 의존 모듈은 `createX({ now, generateId } = { now: Date.now, generateId })` 형태로 의존성 주입 → deterministic 테스트 가능. `mock.timers` API 버전 의존 회피.
- [2026-05-14] 6~8자리 base62 ID 생성은 외부 라이브러리 없이 `crypto.randomBytes` + rejection sampling 으로 ~20줄 구현 가능. nanoid 도입은 alphabet 요구사항 (base62 strict) 과 충돌.
- [2026-05-14] 복잡한 기능 decompose 시 INVEST 체크리스트 (Independent/Negotiable/Valuable/Estimable/Small/Testable) 를 각 deliverable 에 적용하면 의존성 폭발·과도한 phase 분할을 조기 탐지. 근거: Bill Wake INVEST, Agile Alliance.
- [2026-05-14] Heilmeier Catechism 핵심 두 질문 — "지금 무엇을 하는가" + "성공하면 무엇이 달라지는가" — 을 계획 문서 첫 섹션에 강제하면 hidden assumption 표면화. 근거: DARPA Heilmeier Catechism.
- [2026-05-14] TDD-friendly plan 은 각 phase 완료 조건을 `expect(fn(input)).toBe(output)` 형태로 표현 가능한 단위로 분해. 테스트로 표현 불가하면 설계 미완. 근거: Martin Fowler TDD bliki.
- [2026-05-14] JavaScript 문자열 reverse 시 `split('')` 은 UTF-16 code unit 분해로 BMP 외 문자(U+10000+) 의 surrogate pair 를 깨뜨린다. code point 단위 보존이 필요하면 `Array.from(s)` 또는 `[...s]`. 단, ZWJ 시퀀스·결합문자의 grapheme cluster 보존은 `Intl.Segmenter` 가 필요하며 plan 단계에서 "어느 수준의 유니코드 정확성인지" (code unit / code point / grapheme cluster) 를 명시적 결정 사항으로 올려야 한다.
- [2026-05-14] (training) Pre-mortem 기법 — plan 확정 전에 "이 프로젝트가 6개월 뒤 실패했다고 가정하고, 무엇이 잘못됐을지" 팀이 5분 동안 적는다. 사후 분석보다 hidden risk 표면화 효과 큼. 근거: Gary Klein, HBR 2007 "Performing a Project Premortem".
- [2026-05-14] (training) 단계 목록을 작성한 뒤 의존성 토폴로지 정렬 → critical path 길이 = 최소 소요. critical path 위 항목은 병렬화·자원 집중 우선 대상. 근거: PMBOK CPM (Critical Path Method).
- [2026-05-15] (training) **ADR 결정 항목에 `expires: YYYY-MM` 타임스탬프 부여** + 만료 시 재검증 / 이유 있는 면제 / 폐기 세 경로 중 하나 선택. 실측: 2개월 이내 아키텍처 결정의 20~25% 가 stale evidence 상태가 됨. 타임스탬프 없으면 가정 위반이 사고 시점까지 조용히 누적. AI 추천 자체는 자동으로 L0(추측) 등급으로 시작, 인간 검증 후 격상. 근거: arXiv 2601.21116 "AI-Assisted Engineering Should Track the Epistemic Status and Temporal Validity of Architectural Decisions".
- [2026-05-15] (training) **Plan revision 자동 트리거 이중 게이팅** — ① ADR 증거 만료 (valid_until 초과) ② Change Failure Rate 상승 감지 (CI/CD). 둘 중 하나라도 발생하면 해당 phase 의 가정·의존성 목록을 재검증한다. "Big Design Up Front 후 변경 금지" 운영은 이 신호가 무시되어 사양-코드 분기 심화. 근거: arXiv 2601.21116 (evidence freshness); getdx.com "Measuring change failure rate in the era of AI-assisted engineering".
- [2026-05-15] (training) **Context engineering — plan 은 외부 스크래치패드로 영속** — agent 가 plan 관련 메모를 컨텍스트 윈도우 외부에 (NOTES.md / memory) 지속 기록. 200k 토큰 초과 시 plan 절단·왜곡 발생. *"smallest possible set of high-signal tokens that maximize the likelihood of some desired outcome"* 원칙. 모든 실행에 immutable trace envelope (모델 버전·policy 버전·검색 artifact ID) 부착 권장. 근거: Anthropic "Effective Context Engineering for AI Agents" 2025; Jeremy Daly "Context Engineering for Commercial Agent Systems".
- [2026-05-15] (training) **Plan readability 산업 표준 = Flesch-Kincaid 8th grade 이하** — 캘리포니아 정부 혁신허브 가이드 / Intuit Content Design 가이드 모두 8th grade (= 중학교 2학년) 이하 목표 명시. Intuit 은 5~8th grade. WCAG 2.2 SC 3.1.5: secondary education 수준 초과 시 단순화 버전 제공 의무. 본 도우미의 *"중·고등학생 가독성"* directive 와 정합. 근거: hub.innovation.ca.gov plain language; contentdesign.intuit.com readability; w3.org WCAG22 SC 3.1.5.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] `randomBytes(n) % 62` 직접 사용 → modulo bias. base62 변환엔 반드시 rejection sampling 또는 bias-free 분할.
- [2026-05-14] TTL 만료를 `setTimeout` per key 로 구현 → timer 누적 + `unref()` 누락 시 프로세스 종료 차단. lazy 검사 + 옵션 sweep 가 안전.
- [2026-05-14] IPv4 사설 대역만 막고 IPv6 mapped IPv4 (`::ffff:10.0.0.1`) 미차단 → 우회 가능. mapped IPv4 는 추출 후 IPv4 룰로 재검증 필수.
- [2026-05-14] risk 섹션을 "기술적 복잡도"로만 채우는 것은 anti-pattern — technical / process / people 3축 분리 안 하면 조직·의사결정 리스크 누락. 근거: OWASP Threat Modeling Cheat Sheet 한계 지적.
- [2026-05-14] "Open Questions" 섹션 생략하고 모든 것을 결정된 것처럼 기술하는 것은 hidden assumption anti-pattern — 구현 중 방향 전환 주원인. 근거: AI development patterns (PaulDuvall).
- [2026-05-14] (training) Big Design Up Front — plan 의 모든 step 을 미리 fix 하고 구현 중 수정 금지. 학습 신호를 plan 갱신으로 흡수 못 해 사양과 코드 분기. 짧은 iteration + plan revision 트리거가 정답. 근거: Royce 1970 (waterfall 모델 자체가 반례로 제시됨); Boehm Spiral Model.
- [2026-05-14] (training) "혹시 모르니까" 옵션 / 플래그 / 추상화 추가 = YAGNI 위반. 실제 두 번째 사용 사례가 등장하기 전 일반화는 잘못된 추상화로 굳어진다. 근거: Kent Beck XP "You Aren't Gonna Need It".
- [2026-05-15] (training) **LLM 이 plan 에 기재한 패키지명·CLI 플래그·버전 번호를 검증 없이 확정 기재 금지** — 상업 모델도 패키지명 환각률 5.2% (16개 모델 / 576,000 코드 샘플), 오픈소스 21.7%. 환각 패키지 38% 는 실제 패키지 두 개를 합성한 이름이라 언뜻 그럴듯해 보임. 언어별: Python 15.8% / JavaScript 21.3% / Rust 24.74%. 모든 외부 의존성은 "설치 전 레지스트리(npm/PyPI/crates.io) 존재 확인" 을 plan 완료 조건에 명시 포함. RAG 적용 시 환각 49% 감소, Fine-tuning 83% 감소 (단 코드 품질 -26%), Ensemble 85% 감소. 근거: arXiv 2406.10279 "We Have a Package for You!"; arXiv 2409.20550 (LLM 코드 환각 8개 하위 유형).

## Project-Specific
프로젝트별 컨벤션. 공용 파일에서는 비어 있음.

(공용 파일에는 프로젝트 컨벤션 저장 안 함 — 프로젝트별 learning 파일 참조)

## Open Questions
아직 결론 안 난 것.

- [2026-05-14] Node 22 LTS 에서 `--experimental-test-coverage` 플래그 안정성 / 정식 플래그명 확인 필요.
