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

## Patterns
잘 통하는 접근법.

- [2026-05-14] 시나리오는 "정상 경로 → 경계값 → 명백한 오용 → 회귀 위험 영역" 순서로 잡으면 핵심 결함이 앞쪽에서 빨리 드러난다.
- [2026-05-14] 한 시나리오당 스크린샷은 "준비 / 조작 직후 / 결과" 3 장으로 고정. 더 많으면 보고서가 무거워지고 적으면 재현 불가.
- [2026-05-14] (training) Risk-based testing — 모든 기능을 동등하게 테스트하지 않는다. 변경 빈도 × 사용자 노출 × 장애 영향 3축 곱으로 우선순위 행렬을 만들고 상위 셀에 시간 집중. 근거: Hans Schaefer "Risk Based Testing"; ISTQB.
- [2026-05-14] (training) 자동화는 smoke + 정상 경로 + 회귀 핫스팟 위주. 탐색적 테스트 (exploratory) 는 사람/페르소나 도우미 영역 — 시나리오 사전 정의 없이 화면 만지며 새 결함 발견. 근거: James Bach "Exploratory Testing Explained".
- [2026-05-14] (training) Bug triage 우선순위 정렬: severity × frequency × workaround 유무. CRITICAL 이라도 발생 빈도 0.01% + workaround 존재면 HIGH 로 강등 가능. 단일 축만 보면 우선순위 왜곡. 근거: Atlassian Jira priority schemes; ISTQB Defect Management.
- [2026-05-14] (training) Flaky test 격리 — 같은 빌드에서 통과/실패가 갈리는 시나리오는 "PASS" 도 "FAIL" 도 아닌 별도 분류. quarantine pool 로 옮기고 안정화 전까지 게이트에서 제외. 무시도 reproducer 도 같이 기록. 근거: Google Testing Blog "Flaky Tests at Google".

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] "가끔 안 됨", "느린 것 같음" 같은 모호한 표현 금지. 횟수·시간·조건을 측정해서 적는다.
- [2026-05-14] 버그를 직접 고치려 하지 말 것. QA 도우미는 보고만 하고, 수정은 다른 도우미가 한다. 권한 정책 위반.
- [2026-05-14] 자동화 도구가 없다고 추정으로 PASS 판정 금지. 도구 없으면 "수동 테스트 필요" 라고 분명히 적는다.
- [2026-05-14] (training) 같은 시나리오를 매 회차마다 동일 결과로 반복 보고 금지. 회차 간 변동분 (regression / new fail / fixed) 만 강조. 보고서 무한 팽창 방지. 근거: ISTQB Test Reporting Guidelines.
- [2026-05-14] (training) 자동화 도구의 실패를 "도구 결함" 으로 단정하지 말 것. 90% 이상은 실제 앱 결함 또는 시나리오 정의 결함. 도구 의심 전에 수동 재현 + 다른 환경 재시도 필수. 근거: Test Automation 실무 경험칙.
- [2026-05-14] (training) Visual regression 픽셀 비교는 안티앨리어싱·OS 폰트·GPU 차이로 false positive 폭주. 임계값 (anti-aliasing tolerance) + 동적 영역 마스킹 + 텍스트 영역 분리가 없으면 결함 신호 묻힌다. 근거: Playwright/Percy 공식 모범 사례.
프로젝트별 컨벤션. 공용 파일에는 비어 있음.

## Open Questions
아직 결론 안 난 것. distill 시 결론 났으면 Patterns/Anti-patterns 로 이동.

- [2026-05-14] (training) MCP 브라우저 도구 (Chrome / Preview) 와 Playwright 의 시나리오 호환성 — 같은 가이드로 두 도구에서 결과가 일치하는가, 도구별 재현 가능 영역이 다른가?
- [2026-05-14] (training) 페르소나 도우미 (customer-user) 가 발견한 UX 결함을 QA 도우미가 회귀 시나리오로 흡수해야 하는가, 영역 분리를 유지해야 하는가?
