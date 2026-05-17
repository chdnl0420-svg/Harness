# Learning Data: harness-qa-engineer

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-qa-engineer` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] QA 도우미는 **런타임 행동만** 본다. 정적 코드 리뷰는 code-reviewer 영역. 두 책임 섞이면 보고서가 길어지고 핵심 버그가 묻힌다.
- [2026-05-14] 버그 보고는 **재현 단계 + 기대 + 실제 + 스크린샷** 4 요소 모두 있어야 한다. 하나라도 빠지면 수정자가 다시 재현해야 하므로 비용 폭증.
- [2026-05-14] 심각도는 "사용자 영향" 기준으로만 매긴다. 코드 복잡도·수정 난이도는 무관. CRITICAL = 핵심 흐름 불가/데이터 손실.
- [2026-05-14] (training) Test oracle 문제 — "PASS 가 무엇을 의미하는가" 가 모호하면 자동화도 의미 없다. 가이드의 기능별 정상 흐름에 측정 가능한 기대값이 있어야 QA 결과가 신뢰된다. 근거: Earl T. Barr et al. "The Oracle Problem in Software Testing" IEEE TSE 2015.
- [2026-05-14] (training) 한 빌드의 결함은 ISTQB Defect Density 지표로 환산해 회차 간 추세 관찰. 회차 N 의 결함이 회차 N-1 대비 급증 = 직전 변경 위험 신호. 단순 합산이 아닌 영역별 분포까지 보면 회귀 핫스팟 식별. 근거: ISTQB Foundation Syllabus.
- [2026-05-14] (training) Equivalence Partitioning + Boundary Value Analysis — 무한한 입력을 등가 클래스로 나눠 각 클래스 1개 + 경계값 (min-1, min, min+1, max-1, max, max+1) 만 테스트. 케이스 폭증 회피. 근거: Glenford Myers "The Art of Software Testing" 3rd Ed.
- [2026-05-15] (training) Plan-Act-Verify 루프 — 시나리오마다 Plan 단계에서 "무엇이 동작하면 PASS 인가" 측정 가능한 기대값을 사전에 한 줄로 명시. 기대값 없는 Act 는 결과 해석이 자의적이 되어 신뢰 못함. 근거: TestQuality "Agentic QA Architecture" 2026.
- [2026-05-15] (training) axe-core 같은 자동화 도구는 a11y 결함의 **약 57%** 만 자동으로 잡는다 (Deque 연구). 나머지 43% 는 키보드 only 흐름·focus 가시성·스크린리더 라벨 수동 점검 영역. axe 결과만으로 a11y 통과 판정은 거짓 PASS. 근거: Deque Systems study, Playwright accessibility docs.
- [2026-05-15] (training) Core Web Vitals Good 임계값(2026): LCP ≤ 2.5s · INP ≤ 200ms · CLS ≤ 0.1. 단 **Lighthouse 는 진단용 lab 도구**이며 공식 벤치마크는 production CrUX 의 75th percentile 필드 데이터. 회차 비교는 lab 수치로 추세만 보고, 절대값으로 PASS 단정하지 않는다. 근거: web.dev "Defining CWV thresholds" + 2026 CWV guides.
- [2026-05-15] (training) Risk-based 시나리오 우선순위 = **변경 빈도 × 사용자 노출 × 장애 영향** 3축 곱. 상위 셀에 시간 집중. 모든 기능 동등 테스트는 시간만 쓰고 핵심 결함 놓친다. 근거: ISTQB Risk-Based Testing; Hans Schaefer.
- [2026-05-15] (training) Oracle 강도는 **계층(Strength Tier)** 이다 — Specified > Regression > Metamorphic/Property > LLM-as-judge > Implicit(no-crash) > BLOCKED. 강한 oracle 이 없을 때 즉시 blocked 는 오버엔지니어링이고, 추측해서 기록은 false oracle 을 만든다. 사용 가능한 가장 강한 tier 로 내려가되 결과 confidence 를 명시한다. 근거: Anthropic "Demystifying Evals for AI Agents"; SWEN90006 Univ. of Melbourne; TOGLL arXiv 2405.03786; Ministry of Testing oracle taxonomy.

## Patterns
잘 통하는 접근법.

- [2026-05-14] 시나리오는 "정상 경로 → 경계값 → 명백한 오용 → 회귀 위험 영역" 순서로 잡으면 핵심 결함이 앞쪽에서 빨리 드러난다.
- [2026-05-14] 한 시나리오당 스크린샷은 "준비 / 조작 직후 / 결과" 3 장으로 고정. 더 많으면 보고서가 무거워지고 적으면 재현 불가.
- [2026-05-14] (training) Risk-based testing — 모든 기능을 동등하게 테스트하지 않는다. 변경 빈도 × 사용자 노출 × 장애 영향 3축 곱으로 우선순위 행렬을 만들고 상위 셀에 시간 집중. 근거: Hans Schaefer "Risk Based Testing"; ISTQB.
- [2026-05-14] (training) 자동화는 smoke + 정상 경로 + 회귀 핫스팟 위주. 탐색적 테스트 (exploratory) 는 사람/페르소나 도우미 영역 — 시나리오 사전 정의 없이 화면 만지며 새 결함 발견. 근거: James Bach "Exploratory Testing Explained".
- [2026-05-14] (training) Bug triage 우선순위 정렬: severity × frequency × workaround 유무. CRITICAL 이라도 발생 빈도 0.01% + workaround 존재면 HIGH 로 강등 가능. 단일 축만 보면 우선순위 왜곡. 근거: Atlassian Jira priority schemes; ISTQB Defect Management.
- [2026-05-14] (training) Flaky test 격리 — 같은 빌드에서 통과/실패가 갈리는 시나리오는 "PASS" 도 "FAIL" 도 아닌 별도 분류. quarantine pool 로 옮기고 안정화 전까지 게이트에서 제외. 무시도 reproducer 도 같이 기록. 근거: Google Testing Blog "Flaky Tests at Google".
- [2026-05-15] (training) MCP 브라우저 도구 선택 우선순위 — (1) `mcp__Claude_in_Chrome__*` (실제 Chrome, 사용자 세션·MFA 통과 상태) → (2) `mcp__Claude_Preview__*` (헤드리스 격리) → (3) `chrome-devtools-mcp` (DevTools 프로토콜, console/network 정밀 캡처) → (4) 프로젝트 기존 Playwright 스크립트만. 도구마다 재현 영역이 달라서 같은 가이드도 결과가 갈릴 수 있음. 근거: Anthropic Claude for Chrome (2025-08~12 GA); ChromeDevTools chrome-devtools-mcp; Playwright MCP.
- [2026-05-15] (training) 재현성 3분류 — FAIL 발견 시 동일 시나리오 2~3회 자동 재실행 후 DETERMINISTIC (매번 실패) / FLAKY (혼재) / INTERMITTENT (외부 의존) 중 하나로 라벨링. retry 후 PASS 됐다고 무시하면 안 됨 — flaky 셀로 기록해야 회귀 추세가 보임. 근거: Atlassian Flakinator, Slack engineering "Handling Flaky Tests at Scale", Datadog Early Flake Detection.
- [2026-05-15] (training) Semantic visual regression — LLM 의미 비교가 픽셀 diff 보다 우선. 픽셀 diff 만 가능하면 ① anti-aliasing tolerance ② 동적 영역(타임스탬프·광고) 마스킹 ③ 텍스트 영역 분리 세 가지 모두 적용해야 false positive 가 결함 신호를 묻지 않는다. 근거: TestQuality 2026 agentic QA; Playwright/Percy best practices.
- [2026-05-15] (training) Bug triage 3축 = severity × frequency × workaround. workaround 가 있고 빈도가 매우 낮으면 (예: 0.01% 미만) CRITICAL severity 라도 HIGH 로 강등 검토 가능. 단일 축만 보고 우선순위 단정 금지. 근거: ISTQB Defect Management; Atlassian Jira priority schemes.
- [2026-05-15] (training) **재시도 횟수 N 단계 운용** — 3단계 권장: N=3 (빠른 DETERMINISTIC 확인) → N=5 (표준 재시도) → N=10 (신규 테스트 격리 전 확인). N=2~3 은 flake rate ≥ 10% 인 고확률 flaky 만 탐지하고 낮은 flake rate (0.1~5%) 는 못 잡는다. 통계적 완전 탐지를 위해서는 더 많은 재실행 필요 (Concordia 공식: 5% flake 를 95% confidence 로 잡으려면 51회). 산업 기본값: Datadog EFD 10회·Auto Retries 5회·Azure DevOps 1회 시스템 탐지. 근거: docs.datadoghq.com/tests/flaky_tests/early_flake_detection/; learn.microsoft.com/azure/devops/pipelines/test/flaky-test-management; Concordia Univ. Rehman 2019 thesis.
- [2026-05-15] (training) **Flaky 탐지 알고리즘 산업 패턴** — ① 슬라이딩 윈도우 (Slack: 마지막 N=50 실행 이력의 실패율). 히스토리 부족하면 잠정 FLAKY 분류 (안전 우선). ② Multi-signal Bayesian scoring (Atlassian Flakinator: duration variability + environment consistency + result patterns + retry frequency 다중 분포; flakiness score 0.0~1.0). ③ 단회 반전 탐지 (Azure DevOps: 실패→재실행 1회 통과 = FLAKY). 학술 분류는 NF/SF/F/VF 4단계, 실무 단순화는 DETERMINISTIC/FLAKY/INTERMITTENT 3단계. 근거: slack.engineering "Handling Flaky Tests at Scale"; atlassian.com Flakinator; learn.microsoft.com Azure DevOps; adequatica.medium.com dictionary of flaky tests.
- [2026-05-15] (training) **Quarantine Lifecycle 산업 기준 숫자** — SLA 상한 14일 (Microsoft: "fix or remove within two weeks" — 이 정책으로 6개월 내 flakiness 18% 감소) 또는 30일 (Datadog: 자동 비활성화 기준). 격리 중에도 테스트 실행은 계속, 결과만 별도 리포트로 격리 (완전 삭제 아님). 재활성화 조건: 연속 성공 패스 N회 (플랫폼별 구성값) + root cause fix PR merge 시 자동 Fixed. CI 게이트 산업 표준: 격리 테스트만 실패 시 exit code 0 (빌드 통과). 소유자(named person) 지정 필수 — 없으면 quarantine = 사실상 영구 삭제. 근거: devblogs.microsoft.com/engineering-at-microsoft; docs.datadoghq.com/tests/flaky_management/; docs.trunk.io/flaky-tests/quarantining.
- [2026-05-15] (training) **Oracle Strength Tier fallback (Oracle 없을 때 의사결정 절차)** — 가이드에 측정 가능 기대값 없을 때 즉시 blocked 가 아니라 다음 순서로 내려간다: ① Regression (이전 회차 결과 있나) → ② Metamorphic relation (입력-출력 간 관계 — 예: "동일 입력 순열 → 동일 출력", "더 큰 입력 → 더 크거나 같은 출력") → ③ Property invariant (항상 참이어야 할 조건) → ④ LLM-as-judge (단 human calibration 이력 있을 때) → ⑤ Implicit (no-crash, no-exception, no-console.error) → ⑥ BLOCKED. 각 tier 결정은 Plan 산출물에 "어떤 oracle 을 사용했는가" 기록. 사용한 tier 가 낮을수록 결과 confidence 도 낮춤. 근거: SWEN90006 Univ. of Melbourne partial oracle; Ministry of Testing oracle taxonomy; Anthropic eval guide 3-tier; TOGLL arXiv 2405.03786 strong vs weak.
- [2026-05-15] (training) **Oracle cutoff — Risk Tier 와 교차** — CRITICAL 기능: Metamorphic 이상 oracle 미확보 시 blocked + 즉시 가이드 보강 요청. HIGH/MEDIUM/LOW 기능: Implicit oracle 까지 허용 + confidence: LOW + 보강 요청 병행 (escalate + proceed 동시 진행이 산업 표준). Oracle 자체 정의 불가 (비결정적 출력, 순수 주관적 품질): 해당 항목만 blocked, 나머지 진행. "추측해서 기록" 은 false oracle — RBCTest 의 spec 없는 항목 skip 전략과 동일 원칙. 산업 통계: 결함의 50% 가 명세 부재 원인 (TechTarget). 근거: RBCTest arXiv 2504.17287; Anthropic "Demystifying Evals for AI Agents"; TechTarget "Missing Acceptance Criteria"; TOGLL.
- [2026-05-15] (training) **Metamorphic Relation 으로 oracle 대체** — 절대 기대값 없는 기능은 MR 로 PASS/FAIL 판정 가능. 예: "동일 입력의 순열 → 동일 출력", "입력 A < 입력 B → 출력 A ≤ 출력 B". LLM 대상 MR 검증 TP rate 평균 62% (arXiv 2511.02108, 967건 수동 검증). MR 위반 = FAIL. MR 통과는 절대 PASS 가 아닌 "MR 기준 PASS (confidence: MEDIUM)" 로 표기. 근거: Metamorphic Testing (en.wikipedia.org); SWEN90006; DEV Community QA Leaders 2025.
- [2026-05-15] (training) **Semantic visual regression 도구 선택 기준** — 컴포넌트 격리 (Storybook/Ladle) + 동적 영역 없음 + 뷰포트 고정 **3 조건이 모두** 충족될 때만 픽셀 diff + AA tolerance + 마스킹으로 충분. 셋 중 하나라도 불충족 (동적 콘텐츠, 다중 브라우저, 페이지 단위 풀 스크린) 이면 AI semantic 도구 (Applitools Eyes Visual AI, Percy Review Agent) 검토. 2026 도구 분포: Applitools = AI 4모드 (Strict/Layout/Content/Dynamic), Percy + Review Agent = pixel diff + AI 후처리 (~40% FP 감소 주장, 벤더 단일 출처), Chromatic/Argos/Lost Pixel/BackstopJS = pixel diff (의도적). 근거: argos-ci.com/docs/diff-algorithm; pkgpulse.com Chromatic vs Percy vs Applitools 2026; bug0.com Percy KB.
- [2026-05-15] (training) **픽셀 diff → semantic 전환 실용 신호** — 정량적 산업 평균 cutoff 는 독립 출처 부재. 실용 신호는 "팀이 FP 리뷰를 스킵하거나 테스트를 비활성화하기 시작하는 시점". 정성 관찰: 빌드당 노출 diff 의 ~80~90% 이상이 FP 일 때 (예: 50 diffs 중 45개 FP) 리뷰 피로로 실질 붕괴. 경제적 전환점: "빌드당 FP review 시간 > 실제 결함 수정 시간" 역전. Percy Review Agent 40% FP 감소 주장은 벤더 단일 출처 — 결정 근거로 쓰되 "독립 검증 미완" 주석 필수. 근거: bug0.com Percy KB; Percy Visual Review Agent 공식 발표 (late 2025).
- [2026-05-15] (training) **Self-healing locator 도입 cutoff** — 스프린트당 locator 실패율 15~25% 초과가 도입 정당화 임계값 (Tricentis 사례: 1,200 테스트 × 2주마다 15~25% selector 실패). ROI: 유지보수 60% 감소, 신규 커버리지 전환 40%, first-run pass rate 72% → 91%. **단 selector healing 은 전체 실패의 28% 만 처리** (QA Wolf 6-type 분석: Selector 28% / Timing 30% / Test Data 14% / Visual 10% / Interaction 10% / Runtime 8%). selector-only 도입은 ROI 과대 예상. 근거: tricentis.com Self-Healing Test Automation guide; qawolf.com "6 Types of AI Self-Healing" Mar 2026.
- [2026-05-15] (training) **Self-healing locator 변경 이력 누적 패턴** — Healenium 오픈소스: 성공 locator 를 PostgreSQL 에 저장 → 다음 실행 baseline 으로 재활용 (cross-run persistence). QA 에이전트가 healed selector 를 학습 데이터에 기록·재활용은 이 패턴의 경량 구현. **단 반드시 suggest-and-review 워크플로우 세트**: confidence ≥ 90% 자동 적용, 70~90% 사람 검토, < 70% test pause + 수동 수정. audit trail (이전 locator + 새 locator + confidence + 날짜) 없으면 도입 금지. CI 에서는 healing 비활성화 (fully static) 옵션 유지. 2026 알고리즘 우선: multi-attribute fingerprinting (35+ 속성: role, text, aria-label, position, DOM context) → GenAI semantic match fallback. 근거: healenium.io/docs/how_healenium_works; qate.ai/blog/self-healing-tests; shiplight.ai self-healing guide 2026.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] "가끔 안 됨", "느린 것 같음" 같은 모호한 표현 금지. 횟수·시간·조건을 측정해서 적는다.
- [2026-05-14] 버그를 직접 고치려 하지 말 것. QA 도우미는 보고만 하고, 수정은 다른 도우미가 한다. 권한 정책 위반.
- [2026-05-14] 자동화 도구가 없다고 추정으로 PASS 판정 금지. 도구 없으면 "수동 테스트 필요" 라고 분명히 적는다.
- [2026-05-14] (training) 같은 시나리오를 매 회차마다 동일 결과로 반복 보고 금지. 회차 간 변동분 (regression / new fail / fixed) 만 강조. 보고서 무한 팽창 방지. 근거: ISTQB Test Reporting Guidelines.
- [2026-05-14] (training) 자동화 도구의 실패를 "도구 결함" 으로 단정하지 말 것. 90% 이상은 실제 앱 결함 또는 시나리오 정의 결함. 도구 의심 전에 수동 재현 + 다른 환경 재시도 필수. 근거: Test Automation 실무 경험칙.
- [2026-05-14] (training) Visual regression 픽셀 비교는 안티앨리어싱·OS 폰트·GPU 차이로 false positive 폭주. 임계값 (anti-aliasing tolerance) + 동적 영역 마스킹 + 텍스트 영역 분리가 없으면 결함 신호 묻힌다. 근거: Playwright/Percy 공식 모범 사례.
- [2026-05-15] (training) Lighthouse 단일 측정으로 CWV 합격 판정 금지. ① 동일 환경 3회 이상 측정 중간값 ② lab 수치는 추세만, 절대 PASS 결정 안 함 ③ 공식 합격 기준은 production CrUX 의 75th percentile. 단발 측정은 outlier 위험. 근거: web.dev "Defining CWV thresholds".
- [2026-05-15] (training) MCP 도구 실패를 *"도구 자체 결함"* 으로 단정 금지. 같은 시나리오를 다른 MCP 도구로 1회 재시도하고, 그래도 같으면 수동 재현해 본 뒤에 도구 결함 가설 검증. 도구 회피 retry 만 반복하면 실제 앱 결함을 놓친다. 근거: Test Automation 실무 경험칙 + 위 MCP 우선순위 entry.
- [2026-05-15] (training) **Self-healing 을 audit trail 없이 자동 적용 금지** — Ranorex 실측 (qate.ai 인용): 감사 추적 없는 자동 healing 도입 후 false positive 23% 증가, debugging 시간 31% 증가, 팀의 60% 가 3개월 내 AI 기능 비활성화. False-heal (잘못된 요소를 새 locator 로 수용) 은 결함을 통과시키는 false-pass 를 만들어 명시적 실패보다 위험하다. 허용 false-heal 율 상한 5%. self-healing 활성화 시 실행 속도 2~3배 느려짐도 고려. 근거: qate.ai/blog/self-healing-tests 2026 (Ranorex 사례); qawolf.com flake rate under 5% 기준; cypress.io 공식 blog "AI self-healing in Cypress" 2026.
- [2026-05-15] (training) **Oracle 없을 때 "추측 기대값" 으로 기록 금지** — false oracle 은 환각 결과와 동일하게 PASS 신뢰도를 훼손. 명세 없는 항목은 oracle 생성 skip + "명세 요청 필요" 기록이 더 안전 (RBCTest 의 `if desc=NULL then continue` 원칙). LLM-as-judge 도 human calibration 이력 없으면 confidence: LOW. 근거: RBCTest arXiv 2504.17287; Anthropic "Demystifying Evals for AI Agents" (calibration 요건).
- [2026-05-15] (training) **Self-healing = selector healing 으로만 접근 금지** — QA Wolf 6-type 분류상 selector healing 은 전체 실패의 28% 만 다룬다. 나머지 72% (timing 30% / test data 14% / visual 10% / interaction 10% / runtime 8%) 를 위한 별도 치유 전략 (wait 전략, session refresh, visual masking, step 추가) 없이 selector healer 만 도입하면 도구 ROI 과대 예상. 근거: qawolf.com "6 Types of AI Self-Healing" Mar 2026.

## Project-specific
프로젝트별 컨벤션. 공용 파일에는 비어 있음.

## Open Questions
아직 결론 안 난 것. distill 시 결론 났으면 Patterns/Anti-patterns 로 이동.

- [2026-05-14] (training) 페르소나 도우미 (customer-user) 가 발견한 UX 결함을 QA 도우미가 회귀 시나리오로 흡수해야 하는가, 영역 분리를 유지해야 하는가?
- [2026-05-15] (training) **픽셀 diff FP 절대 비율의 산업 평균 수치** — peer-reviewed 또는 공신력 있는 독립 벤치마크 연구 미발견 (2026-05-15 조사). Playwright/Percy/Chromatic 공식 docs 에도 정량적 FP 비율 미게재. 이유: 팀별 환경·설정 차이 과대. "FP/(FP+TP) × 100 > X%" 형태의 명시적 전환 임계값은 현재 학계 공백. 해소 조건: 독립 연구 또는 공신력 있는 사례 연구 발표 시.
- [2026-05-15] (training) **AI semantic visual 도구의 false-negative 비율** — Applitools/Percy 의 false-pass (실제 결함 미검출) 사례 수치 공개 없음. 도구 선택의 중요 tradeoff 인데 데이터 공백. 해소 조건: 독립 벤치마크 또는 사용자 사례 공개.
- [2026-05-15] (training) **Anthropic / OpenAI 의 공식 agentic QA oracle 가이드라인** — Anthropic eval 가이드는 3계층을 명시하나 "oracle 없을 때 blocked 처리" 기준을 수치로 명시한 공개 문서 미발견 (2026-05-15). Demystifying Evals 가 가장 근접하나 직접 다루지 않음. ISTQB AI Testing syllabus 의 oracle-less 가이드도 미확인. 해소 조건: 공식 가이드라인 공개 시.
- [2026-05-15] (training) **LLM-as-judge calibration 정량 임계값** — "calibration 이력이 몇 건 이상이면 신뢰 가능" 같은 정량 기준 부재. Anthropic 가이드는 calibration 필요성만 명시.
- [2026-05-15] (training) **Self-healing locator 의 harness 학습 데이터 누적 형식** — `.md` 자유형식 vs 구조화 `locator-history.json`. md 형식은 중복·충돌 탐지 없어 false-heal 누적 위험. 해소 조건: 실제 프로젝트 도입 시 두 형식 병행 비교.
- [2026-05-15] (training) **Playwright Healer cross-run persistence** — 공식 docs 에 healing 결과의 다음 실행 재활용 구조 미명시. CI 재실행 시 DB 영속화 여부 불분명.
- [2026-05-15] (training) **flip rate 임계값 산업 표준 수치** — "10% flip rate = 산업 표준" 주장이 복수 커뮤니티 블로그에 등장하나 공식 벤더 docs 또는 peer-reviewed 출처 cross-reference 미확인. 단일 출처 (minware guide). confidence: LOW.

## Resolved Questions
해소된 Open Question 의 기록. 어느 entry 로 이동했는지 추적.

- [2026-05-15] **LLM 의미 기반 visual regression 도입 시점 기준** → 부분 해소 (실용 신호는 Patterns 의 "픽셀 diff → semantic 전환 실용 신호" 로 이동, 절대 수치 공백은 Open Questions 의 "픽셀 diff FP 절대 비율" 로 유지).
- [2026-05-15] **Plan-Act-Verify 의 Plan 단계 oracle 미확정 cutoff 기준** → 해소 (Patterns 의 "Oracle Strength Tier fallback" + "Oracle cutoff — Risk Tier 와 교차" 로 이동).
- [2026-05-15] **Self-healing locator 변경된 selector 학습 데이터 재활용 여부** → 조건부 해소 (Patterns 의 "Self-healing locator 변경 이력 누적 패턴" + Anti-patterns "audit trail 없이 자동 적용 금지" 로 이동; 단 md vs json 형식 결정은 Open Questions 신규 entry 로 유지).

## References
- TestQuality, "Agentic QA Architecture: Reasoning Loops, Self-Healing DOM & Autonomous Testing" (2026)
- web.dev, "How the Core Web Vitals metrics thresholds were defined"
- Playwright docs, "Accessibility testing" + `@axe-core/playwright`
- Deque Systems, axe-core 자동 검출률 ~57% 연구
- Atlassian Engineering, "Taming Test Flakiness" (Flakinator)
- Slack Engineering, "Handling Flaky Tests at Scale: Auto Detection & Suppression"
- ISTQB Foundation Syllabus + Defect Management
- Google Testing Blog, "Flaky Tests at Google"
- Anthropic, Claude for Chrome (2025-08~12 GA)
- ChromeDevTools, `chrome-devtools-mcp`
- Microsoft, Playwright MCP
- Anthropic Engineering, "Demystifying Evals for AI Agents"
- SWEN90006 (University of Melbourne), "Property-based Testing" lecture notes
- Ministry of Testing, software-testing-glossary/oracles
- TOGLL, arXiv 2405.03786 (strong vs weak oracle, LLM-generated oracle accuracy)
- RBCTest, arXiv 2504.17287 (spec-missing fallback skip strategy)
- Metamorphic Testing (Wikipedia + en.wikipedia.org/wiki/Test_oracle)
- DEV Community QA Leaders, "Testing AI Systems: Handling the Test Oracle Problem" (2025)
- TechTarget, "Missing Acceptance Criteria" (50% 결함 원인 통계)
- Datadog docs, "Early Flake Detection" + "Auto Test Retries" + "Flaky Management"
- Microsoft Azure DevOps Learn, "Flaky test management"
- Microsoft Engineering Blog, "Improving Developer Productivity via Flaky Test Management"
- Trunk docs, "Quarantining flaky tests"
- adequatica.medium.com, "Dictionary of Flaky Tests" (NF/SF/F/VF 분류)
- Concordia University Rehman 2019 thesis, StableFlakeRate 95% confidence 공식
- Argos CI docs, "Diff Algorithm" (의도적 결정론 pixel diff)
- pkgpulse.com, "Chromatic vs Percy vs Applitools Visual Regression 2026"
- Applitools blog, "Test Maintenance at Scale" (Peloton 78% reduction)
- bug0.com Knowledge Base, Percy / Visual Regression
- Healenium docs, "How Healenium Works" (PostgreSQL cross-run persistence)
- qate.ai, "Self-Healing Tests: What Works, What Doesn't" 2026
- qawolf.com, "6 Types of AI Self-Healing Test Automation"
- Tricentis, "Self-Healing Test Automation" guide
- Cypress blog, "AI Self-Healing in Cypress"
- testdino.com, "Playwright AI Ecosystem" (Healer agent 75% 성공률)
- shiplight.ai, self-healing test automation guide 2026
