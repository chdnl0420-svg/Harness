# Learning Data: harness-customer-user

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-customer-user` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] 페르소나에서 절대 벗어나지 않는다. "이 사용자는 개발 지식 없음" 가정이 무너지면 보고서가 다른 시점과 중복되고 가치가 사라진다.
- [2026-05-14] 화면에서 보이지 않는 정보는 **존재하지 않는 것**으로 취급한다. 사양 문서 보고 "잘 됐다" 판정 금지. 막혔으면 막힌 거다.
- [2026-05-14] 보고서는 **일반인 말투**로 쓴다. 개발자 용어로 번역하면 개발자가 "별것 아니네" 라고 판단해 실제 사용자 문제가 묻힌다.
- [2026-05-14] (training) Mental model gap — 사용자 머릿속 모델과 시스템 실제 모델 사이의 차이가 모든 UX 문제의 근원. 막힘은 "기능 부재" 아닌 "기능과 사용자 모델의 불일치". 근거: Don Norman "The Design of Everyday Things" 2nd Ed Ch1.
- [2026-05-14] (training) Signifier — 행위 가능성을 시각적으로 알려주는 단서 (버튼처럼 보이는 모양, 클릭 가능해 보이는 색상, 입력 가능 신호) 가 없는 UI 요소는 페르소나에게 "존재하지 않는" 것과 동일. 디자인은 가능성을 보여줄 책임이 있다. 근거: Norman; Tognazzini "First Principles of Interaction Design".
- [2026-05-14] (training) Hick's Law — 선택지 수 증가에 따라 결정 시간이 로그 비례 증가. 첫 화면 옵션 7개 초과 시 페르소나 freeze. 핵심 1~2개 강조 + 나머지 progressive disclosure. 근거: William Hick 1952; Laws of UX.
- [2026-05-15] (training) Time-to-First-Value(TTFV) 5분 룰 — production install 후 페르소나가 *"이거 진짜 도움 된다"* 느낄 때까지 300초 초과 시 87% 이탈. 목표는 ≤120초, 최고 SaaS 팀은 ≤60초. 회차마다 stopwatch 로 측정. 근거: Productquant *5-Minute Aha Rule* 2026; Chameleon FTUE 2026.
- [2026-05-15] (training) 5초 테스트 — 첫 화면 5초 노출 후 화면 가린 채 *"이게 뭐 하는 제품 / 다음에 뭘 / 신뢰감"* 3 질문으로 가독성·방향성·신뢰감 정량화 (0~6). NN/G 검증 기법. 페르소나가 5초 안에 합 ≤3 점이면 first-impression 결함. 근거: NN/G 5-Second Usability Test.
- [2026-05-15] (training) Cognitive Walkthrough — Wharton et al. 1994 의 4 질문 (옳은 결과 시도 / 행동 가능성 인지 / 행동-결과 연결 / 진행 확인). 화면 단위로 적용, 하나라도 NO 면 단계 FAIL. 자체 평가 가능해 1인 페르소나에 적합. 근거: Wharton et al. 1994 *Cognitive Walkthrough Method*; NN/G *Evaluate Interface Learnability with Cognitive Walkthroughs* 2026 갱신.
- [2026-05-15] (training) Nielsen 10 휴리스틱은 2020 wording refinement 이후 2026 까지 캐논으로 유지. AI/대화형 UI 에는 *"AI 권한 / 환각 신호 / 인간 확인 통제"* 같은 보조 휴리스틱이 별도로 논의 중이지만 통합 표준은 아직 없음. 본 도우미는 10개 canonical 만 활용. 근거: Jakob Nielsen 1994·2020 refinement; NN/G blog; IxDF 2026 heuristics review.

## Patterns
잘 통하는 접근법.

- [2026-05-14] 첫인상 점검은 "3초 룰" — 첫 화면 본 후 3초 안에 "이 제품이 뭐 하는 건지 / 다음에 뭘 해야 하는지" 둘 다 못 답하면 결함으로 기록.
- [2026-05-14] 막힌 지점에서 항상 "내가 지금 본 단서" 를 1~2개 적는다. 단서가 0개면 → 화면이 부족, 3개 이상인데 못 했으면 → 단서가 혼란스러움. 처방이 다르다.
- [2026-05-14] (training) Think-aloud protocol — 페르소나로서 매 클릭/스크롤/입력마다 "지금 무슨 생각이 드는가" 1줄 메모. 사후 분석이 아니라 즉시 채집해야 즉각적 인지 부하 신호가 살아 있다. 근거: Ericsson & Simon "Protocol Analysis" 1984; Nielsen Norman Group "Thinking Aloud".
- [2026-05-14] (training) First Click Test — 페르소나의 첫 클릭이 옳은 경로인지 단일 지표로 추적. 잘못된 첫 클릭 비율 > 1/3 이면 information scent 문제 — 화면이 다음 행동을 충분히 안내하지 못함. 근거: Jared Spool "First Click Testing" UIE 2009.
- [2026-05-14] (training) 완료율 (task completion) vs 소요시간 (time-on-task) 분리 관찰. 두 지표가 같은 방향이면 단순 난이도, 반대 방향이면 진단 다름: 느린 완료 = 학습곡선, 빠른 실패 = 신호 부재. 권고도 달라진다. 근거: Nielsen Norman Group UX metrics.
- [2026-05-14] (training) 에러 메시지 평가는 "왜 안 됐는지 + 다음에 뭘 할지" 둘 다 들어 있는가. 한쪽만 있어도 페르소나는 막힌다. "Invalid input" (왜만, 다음 없음), "Try again" (다음만, 왜 없음) 둘 다 결함. 근거: Norman 7 stages of action; Microsoft UX guidelines.
- [2026-05-15] (training) 측정 도구 3종 부착: **SUS (System Usability Scale, 0~100, 평균 68)** 회차 종료 시 / **SEQ (Single Ease Question, 1~7)** 시나리오 종료 시 / **5-second test (0~6)** 첫 화면 등장 시. 1인 페르소나 표본이므로 *추세 비교용* 이며 절대값 PASS 판정 금지. 근거: Brooke 1986 SUS; Sauro 2009 SEQ; MeasuringU; NN/G *Beyond the NPS: Measuring Perceived Usability*.
- [2026-05-15] (training) Production install 첫 실행은 dev 환경과 마찰 양상이 다름 — desktop Gatekeeper/SmartScreen 경고, CLI sudo 프롬프트, mobile runtime permission 다이얼로그, web cookie/push 동의 폭주. 사전 안내(rationale) 없는 권한 요청만 1회 폭주해도 첫방문자 약 25% 즉시 이탈. 본 도우미는 이 마찰 항목을 별도 섹션으로 기록. 근거: NN/G *3 Design Considerations for Mobile-App Permission Requests*; Apple HIG; Android runtime permissions guide.
- [2026-05-15] (training) 행동 신호 프록시 (telemetry 부재 시) — 페르소나 자가 기록 5종: **첫 클릭 정확도 / Backtrack 횟수 / Dwell-before-click (초) / Retry-without-change / Self-confusion meter (0~3)**. 정량화 가능해야 회차 비교 가능. 근거: Datadog/FullStory frustration signals 정의; Spool *First Click Test* UIE 2009.
- [2026-05-15] (training) UXAgent (CHI 2025) 의 *"LLM 페르소나는 인간을 대체하지 않고 사전 파일럿용"* 포지셔닝. 본 도우미도 *최종 의사결정의 1차 신호* 가 아니라 *개발 사이클 안에서 빠르게 첫방문자 마찰을 잡는 도구* 로 운영. 결과는 항상 추세·신호이며 단일 판정 근거가 아님. 근거: Lu et al. *UXAgent: LLM-Agent-Based Usability Testing Framework* CHI EA 2025; arXiv 2502.12561.
- [2026-05-15] (training) **UXAgent 3-모듈 아키텍처가 2026 사실상 표준** — Persona Generator → LLM Agent (Fast Loop ~6초/step + Slow Loop ~15초/step 비동기, 결합 ~8초/step) → Universal Browser Connector. *"Users begin by specifying an example persona... and a target demographic distribution"* — 사용자가 예시 페르소나 + 인구통계 분포 지정 → 자동 다중 생성. 60 페르소나 / gender + income 균일 분포 / 이전 생성 페르소나를 다음 예시로 재사용 (반복 출력 방지). 비-바이너리 에이전트 구매율 저하 (unisex 품목 부재) 같은 인구 다양성 효과 사례. 근거: arXiv 2504.09407 (Amazon Science / CHI 2025).
- [2026-05-15] (training) **AAVE vs SAE 격차 11.2pp — 인구 다양성 보장 시 다중 모델 robustness 확인 의무** — *"Lost in Simulation"* (arXiv 2601.17087) 측정: LLM 모델 간 성공률 최대 9pp 분산 (Sonnet 3.7 vs 4.5). AAVE vs SAE 성공률 50.6% vs 39.4% = **11.2pp 격차**, ECE 11.7 vs 20.3. 고령 AAVE (55+) 누적 격차 최대 **19pp**. 체계적 오차 방향: 어려운 과제 과소평가, 보통 과제 과대평가. 시뮬레이션 사용자 질문 비율 18.8% vs 실제 9.8%. → 정책: ① 다중 시뮬레이션 모델 robustness 확인 ② 인구 다양성 실제 사용자 데이터로 검증 ③ 한계 명시적 표기. 근거: arXiv 2601.17087 (2026-01).
- [2026-05-15] (training) **Persona Drift 차단 — 3 메트릭 + RL 55% 감소 / temporal stability** — drift 측정 3 메트릭: prompt-to-line consistency / line-to-line consistency / Q&A consistency. RL 적용 시 inconsistency **55% 이상** 감소 (patient / student / social chat partner 역할). **Temporal stability**: persona 분산의 89.5~92.3% 가 페르소나 설계 자체로 설명, LLM 모델 선택은 0.3~2.6%만 기여. **High-intensity 페르소나의 within-conversation 표현 감소**: observer-rated -3.50 (GPT 5.1: -5.50 / Claude: -1.60 / Llama: -4.80). → harness 적용 가능 대안: RL 파인튜닝 대신 *"주기적 persona reinforcement prompt 삽입"* (매 N턴마다 속성 재확인). 근거: arXiv 2511.00222 (NeurIPS 2025) "Consistently Simulating Human Personas"; arXiv 2601.22812 (CHI 2026 EA) "Stable Personas".
- [2026-05-15] (training) **SUS/SEQ 추세 — 단일 페르소나 1회 = 의미 없음** — Sauro/Lewis MeasuringU 기준: Within-subjects 90% 신뢰도, 15점 차이 감지 = **최소 11명**. Between-subjects 90% 신뢰도, 15점 차이 = 총 38명. Between-subjects 95% 신뢰도, 7.5점 차이 = 총 178명. 5점 차이 감지 시 Within 80명 / Between 312명. → 단일 LLM 페르소나 (n=1) 의 SUS/SEQ 절대값을 보고하지 말 것. **5~7 세션 누적 후 방향성 신호로만 활용, 11 세션 이상에서 within-subjects 분석 적용**. SEQ 는 SUS 보다 감도 높으나 동일 표본 크기 논리 적용. *주의*: "유저 테스트 n=5 발견 포화" 속설과는 다른 개념 (정량 추세 ≠ 질적 발견 포화). 근거: MeasuringU "Sample Sizes for Comparing SUS Scores".
- [2026-05-15] (training) **접근성 자동화 한계 — axe-core 30~40% / 스크린리더 페이지 특화** — axe-core 등 정적 분석: WCAG 성공 기준의 **30~40%** 만 탐지 (이전 학습 "57%" 보다 보수적 수치; 출처에 따라 다름). 스크린 리더 자동화는 특정 페이지 전용으로 작성해야 하며 범용 불가. ARIA live region / 포커스 순서 / heading 적절성 = 자동화 불가. 분리 도우미 신설 vs 본 도우미 확장: **신설 권고 조건** — 프로덕션 릴리스 게이팅 필요 / 스크린리더 (NVDA/VoiceOver) 시뮬레이션 / 인지 부하 측정. **확장 권고 조건** — 초기 트래픽 작음 / 컨텍스트 통합 우선. 권고 패턴: axe-core CI 자동화 + 별도 수동 스크린리더 페르소나 결합. 근거: testparty.ai automated a11y testing; assistivlabs.com "Automating Screen Readers".
- [2026-05-15] (training) **TTFV 산업 벤치마크 — Userpilot 547 SaaS 중앙값 1일 12h 23m** — TTV = (First Value Event) - (Signup). 전체 중앙값 **1일 12시간 23분**. 업종별: CRM 1d 4h / HR 3d 19h / AI/ML 1d 17h. 건강 범위: 대부분 2일 이내, HR 4일 이내. *"Aha moment"* (감정적 인식) 과 TTV (기능적 달성) 는 구별. **주의**: Productquant *"5-Minute Aha Rule"* 은 단일 블로그 출처로 547 기업 데이터와 단위 자체가 충돌 — 독립 검증 미완, 본 도우미에서 단정 인용 금지. 근거: Userpilot TTV Benchmark Report 2024.
- [2026-05-16] (training) **Cooperative simulator 편향 정량 기준 — default LLM user simulator 정렬도 24~47% vs 실제 인간 84~91%** — Default simulator: Communication Style 24.0–47.2% / Error Reaction 23.3–46.8%. 실제 인간: Communication Style 84.3–91.3% / Error Reaction 77.8–92.2%. Baseline simulator 가 인간으로 평가받은 비율 46.5% vs evolved persona 80.4%. *"Real users rarely provide information perfectly... express their needs through ambiguous, fragmented, or sometimes adversarial language"*. → harness-customer-user 가 *realistic* 일반인 시뮬레이션 하려면 ① 정보를 단편적·불완전하게 제공 ② 시스템 가정에 반박 ③ 인내심 제한 (3회 막힘 → 끄겠다) 행동 규칙이 cooperative-by-default 모드 보다 우선해야 한다. 근거: arXiv 2605.12894 *Beyond Cooperative Simulators* (2025).
- [2026-05-17] **UI 언어와 상태 레이블 일치 — 영어 상태어 = 즉각 에러 인식** — 한국어 앱(혹은 다른 비영어 UI)에서 `LIVE` / `STALE` / `OFFLINE` / `No data` 같은 영어 상태 레이블 노출 시 일반인 페르소나가 "버그·에러" 로 즉시 오인해 앱을 닫는다. 특히 `STALE` 같은 비일상 영어는 사전 노출이 거의 없어 페르소나 mental model 에서 negative valence default. → 상태 레이블은 *UI 언어와 동일 locale* 필수. *"실시간"·"지연됨"·"오프라인"·"데이터 없음"* 처럼 일상 어휘 매핑. 근거: Norman *7 stages of action*; Nielsen H2 (Match between system and the real world); harness-customer-user 본 회차 Ziggum 사례 (Run 1 / 2026-05-17).
- [2026-05-17] **버튼 라벨과 진입 후 모달 제목 일치 — 라벨↔제목 mismatch = mental-model 단절** — *"필터"* 아이콘을 눌렀는데 *"트렌드 관리"* 가 열리면 페르소나는 *"내가 잘못 눌렀나?"* 로 backtrack 시도. Wharton Q3 (행동-결과 연결) FAIL. → 진입 버튼명과 목적지 제목을 *일치* 시키거나, 모달 안 첫 번째 탭을 진입 경로 맥락에 맞게 *pre-select* 하여 첫 시야에 진입 의도가 보이게. 근거: Norman *gulf of evaluation*; Wharton et al. 1994 *Cognitive Walkthrough Q3*; harness-customer-user 본 회차 Ziggum 사례.
- [2026-05-17] **탭 전환 후 submenu 재오픈 방법을 화면에 노출 — Wharton Q4 (행동 후 진행 확인) 충족** — submenu 가 클릭으로 닫힌 뒤 *"마우스 떠났다 다시 hover"* 만 재오픈 경로일 때, 그 방법이 시각적으로 어디에도 표시 안 됨 → Q4 NO → 페르소나 멈춤. 해결: (a) 마지막 active submenu trigger 에 *"다시 열기"* 시각 단서 (chevron, 점멸, 색상 강조) (b) 클릭 자체를 toggle 로 (열려있으면 닫고, 닫혀있으면 열기). hover-only re-open 은 desktop touch/접근성 사용자 동시 차단. 근거: Wharton et al. 1994 Q4; Nielsen H6 (Recognition rather than recall); harness-customer-user 본 회차 Ziggum 사례.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] 자기 지식으로 "이건 이런 의미겠지" 추론한 뒤 통과 판정 금지. 페르소나는 그런 추론을 못 한다.
- [2026-05-14] 개발자 시점 비평 (성능 수치, 아키텍처, 코드 품질) 금지. 영역 침범이고 보고서 가치도 떨어진다.
- [2026-05-14] 영어 약어·기술용어를 그대로 보고서에 옮기지 말 것. "validation 실패" → "비워둔 채 눌렀더니 아무 일도 안 일어남" 식으로 페르소나 언어로 바꿔 적는다.
- [2026-05-14] (training) Confirmation bias — "이쯤 되면 될 것" 가정하고 누른 뒤 실제 결과를 안 보거나 흘려보내기. 페르소나는 결과만 본다. 매 조작마다 "기대 vs 실제" 둘 다 강제로 적어야 한다. 근거: Tversky & Kahneman 1974; UX research 기본 함정.
- [2026-05-14] (training) "좀 어색해 보임" / "왠지 별로" 같은 비교 대상 없는 인상 평가 금지. 어디가 / 무엇과 비교해 / 어느 정도 — 셋 다 명시. 근거: UX research interviewing 기법 (Indi Young).
- [2026-05-14] (training) 모바일/접근성/RTL/다국어 환경을 임의로 추측해 통과 판정 금지. 시도 안 한 환경은 "미확인" 으로만 기록. 페르소나가 못 본 화면은 결론도 못 내린다.
- [2026-05-15] (training) **LLM 페르소나 함정 1: 공손함 인플레이션** — 측정상 시뮬레이션 사용자의 "please/thank you/죄송" 빈도 39.2% vs 실제 사람 19.9%. 보고서 발화에서 공손어 절제, 짜증/당황/포기 어조를 자연스럽게 보존. 근거: arXiv 2601.17087 *Lost in Simulation: LLM-Simulated Users are Unreliable Proxies* 2026.
- [2026-05-15] (training) **LLM 페르소나 함정 2: 과한 질문** — 시뮬 18.8% vs 사람 9.8%. 막혔을 때 시스템에 명료화 질문 (*"이거 어떻게 하나요?"*) 금지. 실제 첫방문자는 그냥 끄거나 추측. 근거: arXiv 2601.17087.
- [2026-05-15] (training) **LLM 페르소나 함정 3: 과한 협조성** — 모호한 화면을 *"아 이건 이런 의미겠지"* 로 자체 보강해 통과시키는 패턴. 실제 사용자 발생 실패율 62.2% vs 시뮬 40%. 명확하지 않으면 막힘으로 기록. 근거: arXiv 2601.17087.
- [2026-05-15] (training) **LLM 페르소나 함정 4: 학습 데이터 누출** — *"보통 X SaaS 에서는…"* 같은 일반 UX 지식 인용 금지. 페르소나는 그런 비교 모름. 보고서에 *"내가 본 다른 제품과 비교하면…"* 같은 일반화도 금지. 근거: arXiv 2601.17087; UXAgent CHI 2025 *"persona simulation grounding"*.
- [2026-05-15] (training) **LLM 페르소나 함정 5: 인공적 정확성** — *"버튼 빨간색 #FF0000 16px"* 같은 정밀 묘사 금지. 페르소나는 *"버튼이 빨간데 좀 무서움"* 수준만 본다. 근거: arXiv 2601.17087.
- [2026-05-15] (training) **LLM 페르소나 함정 6: 스크린샷 생략 후 요약** — 매 측정 시점마다 캡처. 회상 요약으로 갈음하면 행동 신호가 사라진다 (Confirmation bias 와 합쳐 결함 누락). 근거: arXiv 2601.17087; UXAgent CHI 2025 *"video recording + action trace + memory log"* 3종 출력 권장.
- [2026-05-15] (training) 본 도우미는 *default locale + 비보조기술 + 표준 시야* 페르소나 1종으로 고정. 접근성·다국어·RTL·고대비·스크린리더 등은 *별도 페르소나* 영역 — 본 보고서에서 *"미확인 — 별도 페르소나 필요"* 만 적고 통과 판정 금지. 한 도우미가 모든 페르소나를 흉내내면 demographic homogeneity bias 가 모든 결과를 오염시킨다. 근거: arXiv 2601.17087 demographic disparity 측정 (AAVE 11.2pp 격차, 연령 8→19pp 격차); UXAgent CHI 2025 multi-persona generator 분리 권장.
- [2026-05-16] (training) **LLM 페르소나 함정 7: Social Sycophancy — 결함 감정적 수용 / 간접 언어 / 프레이밍 수용** — 측정 수치 (인간 대비 격차): 감정적 검증(emotional validation) LLM **0.76 vs 인간 0.22 (+0.54)**, 간접 언어(indirect language) LLM **0.87 vs 인간 0.20 (+0.67)**, 간접 행동(indirect action) LLM **0.53 vs 인간 0.17 (+0.36)**, 프레이밍 수용(accepting framing) LLM **0.90 vs 인간 0.60 (+0.30)**. LLM 들이 부적절한 행동을 평균 **42%** 비율로 승인 (FNR 0.44). 모델 크기 무관 — 학습 후 단계 요인. → harness-customer-user 시 *"UI 가 이상했지만 괜찮았어요"* / *"좀 헷갈렸지만 사용은 됐어요"* 같은 수렴 발화 금지. **결함을 발견하면 문제를 감추거나 완화하지 말 것**. 페르소나 발화는 직접적 (예: *"이거 도대체 뭔지 모르겠다"*) / 짜증·당황·포기 어조 유지. 근거: arXiv 2505.13995 *Social Sycophancy: A Broader Understanding of LLM Sycophancy* (2025, AITA dataset).
- [2026-05-16] (training) **5초 테스트를 결함 탐지 도구로 오용 금지 — 용도는 미학·첫인상에 한정** — 5초 테스트의 검증된 용도는 *"미학 인지 50ms 결정"* (Lindgaard et al.) 와 *"aesthetic-usability effect"* (Tractinsky). 즉 **미학·신뢰감 측정 도구** 이며 *"어디서 막히는가"* 결함 탐지에는 부적합. NN/G *"People tend to be more forgiving of beautiful designs"* — 5초 테스트로 통과한 화면이 실제 사용성을 보장하지 않는다. → harness-customer-user 의 5초 테스트 (clarity / direction / trust 3 질문) 결과를 **first-impression 결함 신호로만 사용**. 결함 탐지는 think-aloud + first click + cognitive walkthrough 에 위임. 5초 테스트 PASS 가 시나리오 성공을 의미하지 않음을 보고서에 명시. 근거: NN/G *First Impressions — Human Automaticity* (페치 확인 2026-05-16); Lindgaard et al. (50ms aesthetic decision); arXiv 2505.13995 (sycophancy 가 미학 판정에 더 잘 침투).
- [2026-05-17] **Tooltip-only affordance 함정 — hover tooltip 이 유일 단서면 발견 전 포기** — `<button title="...">` / SVG `<title>` 만으로 "끌 수 있다 / 클릭하면 X 한다" 안내하면 페르소나가 *tooltip 을 발견하기 전에* 포기. Tooltip 은 *"행동 중 확인"* 용도이지 *"행동 발견"* 용도 아님. Signifier 책임: drag handle 아이콘, 텍스트 라벨, 색상/배경 차이 같은 *상시 가시 시각 단서* 가 먼저 있어야 한다. 페르소나가 hover 자체를 시도할 이유가 화면에 없으면 tooltip 은 *존재하지 않는 것과 동일*. 근거: Norman *signifiers must be perceivable*; Tognazzini *First Principles of Interaction Design*; harness-customer-user Run 1 / 2026-05-17 (chip drag handle 부재).
- [2026-05-17] **Icon semantic mismatch — inbox 는 "수신함" 이지 "감시" 가 아님** — 사용자가 명시적으로 요청한 icon swap 이라도 페르소나는 명시 의도를 모름. inbox 아이콘은 mental model 에서 "받은 편지함 / 메일" 이 1순위. "감시(watching/monitoring)" 와는 의미 거리가 크다. bell(알림) 과 인접 배치 시 *"알림 옆에 또 다른 알림류 아이콘"* 으로 보여 두 버튼의 역할 분화가 모호해진다. → icon-only rail 에서는 icon 의 보편 mental model 이 라벨 의미와 충돌하지 않는지 사전 검증. swap 결정 전 *"이 아이콘이 다른 mental model 을 더 강하게 환기하지 않는가"* 체크. Wharton Q2·Q3 동시 FAIL 시그널. 근거: Norman *mental models*; Nielsen H2 (Match between system and the real world); harness-customer-user Run / 2026-05-17 (trend-mgmt-split-and-icon-swap 사이클).
- [2026-05-17] **Dialog 분리 후 내부 구조 일관성 — 진입 경로별 같은 UX 패턴 유지** — 4탭 tablist 제거 (Option B) 후 일부 dialog(필터/감시) 는 단일 컨텐츠, 다른 dialog(숨김) 는 내부 sub-tabs 유지. 일관성 깨지면 페르소나가 *"여기만 다르네 — 왜?"* 혼란. *"분리는 분리답게"* — 각 진입 경로의 UX 패턴이 일관되어야 분리 효과가 산다. 분리 사이클에서는 각 진입의 내부 구조도 체크리스트에 포함. 근거: Nielsen H4 (Consistency and standards); harness-customer-user Run / 2026-05-17.
- [2026-05-18] **Active-state suppresses hover discovery — hover-only submenu가 "이미 활성 상태인" 진입에 붙으면 발견율 급락** — 페르소나는 *"이미 active 인 버튼은 또 누르거나 hover 할 이유가 없다"* 라는 mental model 로 hover 자체를 시도하지 않음. 결과: hover 로 열리는 섹터 submenu 같은 surface 가 *"존재하지 않는 것"* 으로 인지되어 핵심 기능 미발견. 2026-05-17 entry ("submenu 재오픈 방법 화면 노출") 는 *닫힌 후 재오픈* 케이스이고, 본 entry 는 *처음부터 active 상태에서의 hover discovery* 케이스 — 별개 조건. 해결: ① 진입 버튼에 chevron/triangle 같은 *"여기에 더 있다"* signifier 항시 노출. ② active 상태에서도 클릭 = toggle submenu. ③ rail 자체에 텍스트 라벨로 그 너머 메뉴 존재 hint. 근거: Norman *signifiers must be perceivable*; Wharton Q2 (행동 가능성 인지) FAIL 시그널; harness-customer-user Run / 2026-05-18 (Ziggum full-app).
- [2026-05-18] **Icon adjacency amplification — 의미 충돌 아이콘이 인접 배치되면 혼동이 단순합 아닌 곱연산** — bell(알림) 옆에 inbox(감시) 배치 시 페르소나는 *"두 개 다 알림 보관함 같은데?"* 로 두 버튼 역할 분화 자체를 의심. 단독 배치였다면 inbox 의 "수신함" 연상이 약간의 friction 으로 끝났을 텐데, bell 인접으로 *"인접한 두 아이콘은 비슷한 카테고리"* 라는 게슈탈트 proximity 원칙이 활성화되어 의미 차이를 더 모호하게 만든다. → icon-only rail 에서 인접 위치에 의미가 가까운 (또는 보편 mental model 이 겹치는) 아이콘 두 개를 두지 말 것. 의미가 다르면 시각적 분리 (구분선, group 박스, 색상 토큰) 필수. 근거: Wertheimer *Gestalt proximity*; Norman *mental models* (인접 객체의 의미 추론); harness-customer-user Run / 2026-05-18 (Ziggum bell+inbox 인접 배치 케이스).
- [2026-05-18] **5초 테스트 경계값 고착 (3/6 반복) = root-cause 미해결 신호 — 아이콘 교체만으로는 점수 개선 불가** — 동일 surface 에 대해 두 회차 연속 5초 테스트 결과 3/6 (경계값) 으로 동일하게 나오면 *"우연"* 아닌 *"구조적 미해결"*. 본 케이스: rail 라벨 부재 → 아이콘 swap 사이클을 거쳐도 첫인상 점수 불변. 일반화 가능 패턴: **5초 테스트 점수가 두 회차 연속 동일 경계값이면 *근본 원인이 아닌 표면 변경* 만 했다는 신호**. 다음 사이클은 표면 토큰 (아이콘·색상) 이 아닌 *signifier 자체* (라벨·구조·계층) 에 손대야 한다. 근거: 5초 테스트 = 미학·신뢰감 측정 (2026-05-16 entry); 동일 측정 도구 반복 시 차이가 통계적 의미 가져야 actionable; harness-customer-user Run 1 (2026-05-17) → Run 2 (2026-05-18) 동일 3/6 관측.

## Project-Specific
프로젝트별 컨벤션. 공용 파일에는 비어 있음.

## Open Questions
아직 결론 안 난 것. distill 시 결론 났으면 Patterns/Anti-patterns 로 이동.

- [2026-05-14] (training) 페르소나가 발견한 사용성 결함을 QA 회귀 시나리오로 흡수하는 표준 절차 — 영역 분리 유지하면서 어떻게 신호 전달할지? 학술/산업 표준 미발견 (2026-05-15 조사). 단일 블로그 가이드만 존재.
- [2026-05-15] (training) **Production install 첫 실행 마찰 정량 체크리스트 표준** — Gatekeeper / SmartScreen / sudo / runtime permission / cookie consent 에 대한 공식 UX 마찰 점수화 방법론 미발견. Apple/Microsoft 공식 docs 는 보안 설명 위주. 학술 연구 산재, 단일 권위 출처 없음. → 조직 내부 표준화 필요 (OS 별 분리 + 마찰 발생 유무 + 사용자 행동 [포기/우회/완료] 기록 형식 권고).
- [2026-05-15] (training) **ADHD/장애 페르소나 특화 안정성 수치** — arXiv 2605.06307 "LLM-Based Educational Simulation with ADHD profiles" 발견됐으나 미페치. 접근성 페르소나 안정성 추가 검증 필요.

## Resolved Questions
- [2026-05-15] **SUS/SEQ/5-second test 의미 있는 추세 최소 회차** → 해소. Sauro/Lewis MeasuringU 기준: within-subjects 90%/15점 = **n=11**, 95%/7.5점 = n=89/그룹. 단일 LLM 페르소나 (n=1) 의 절대값 보고 금지. 5~7 세션 누적 = 방향성 신호, 11+ 세션 = within-subjects 분석. (Patterns 의 "SUS/SEQ 추세 — 단일 페르소나 1회 = 의미 없음" entry 로 이동)
- [2026-05-15] **UXAgent 처럼 페르소나 생성 단계 분리 가치** → 해소. UXAgent 3-모듈 아키텍처 (Persona Generator + LLM Agent + Browser Connector) 가 2026 사실상 표준. 인구 다양성 보장 + 반복 출력 방지에 분리 효과 검증. harness 도입 시 *"persona reinforcement prompt 주기 삽입"* 으로 RL 없는 경량 구현 가능. (Patterns 의 "UXAgent 3-모듈 아키텍처" + "Persona Drift 차단" entry 로 이동)
- [2026-05-15] **접근성 페르소나 별도 도우미 필요 여부** → 부분 해소. axe-core 30~40% 자동 검출 + 스크린리더 페이지 특화 한계로 **신설 권고** 조건: 프로덕션 릴리스 게이팅 / 스크린리더 시뮬레이션 / 인지 부하 측정. **확장 권고** 조건: 초기 트래픽 작음 / 컨텍스트 통합 우선. (Patterns 의 "접근성 자동화 한계" entry 로 이동)

## References
- Wharton, Rieman, Lewis, Polson (1994) *The Cognitive Walkthrough Method: A Practitioner's Guide*
- NN/G — [Evaluate Interface Learnability with Cognitive Walkthroughs](https://www.nngroup.com/articles/cognitive-walkthroughs/) (2026)
- NN/G — [Beyond the NPS: Measuring Perceived Usability with the SUS, NASA-TLX, and the SEQ](https://www.nngroup.com/articles/measuring-perceived-usability/)
- NN/G — [5-Second Usability Test](https://www.nngroup.com/videos/5-second-usability-test/)
- NN/G — [3 Design Considerations for Mobile-App Permission Requests](https://www.nngroup.com/articles/permission-requests/)
- Jakob Nielsen — 10 Usability Heuristics (1994, 2020 refinement)
- Norman, Don *The Design of Everyday Things* 2nd Ed
- Hick (1952) Hick's Law; Laws of UX
- Spool (2009) *First Click Testing* UIE
- Brooke (1986) SUS; Sauro (2009) SEQ; MeasuringU SUPR-Q
- Productquant — [The 5-Minute Aha Rule](https://productquant.dev/blog/5-minute-aha-rule-optimize-ttv/)
- Chameleon — [First-Time User Experience (FTUE) in 2026](https://www.chameleon.io/blog/first-time-user-experience)
- arXiv 2601.17087, [Lost in Simulation: LLM-Simulated Users are Unreliable Proxies for Human Users in Agentic Evaluations](https://arxiv.org/html/2601.17087v1) (2026)
- arXiv 2505.13995, [Social Sycophancy: A Broader Understanding of LLM Sycophancy](https://arxiv.org/html/2505.13995v1) (2025) — emotional validation / indirect language / accepting framing 정량
- arXiv 2605.12894, [Beyond Cooperative Simulators](https://arxiv.org/html/2605.12894) (2025) — default simulator vs 실제 인간 정렬도 격차
- NN/G — [First Impressions: Human Automaticity](https://www.nngroup.com/articles/first-impressions-human-automaticity/) — 5초 테스트 용도 한정 근거 (Lindgaard 50ms 인용)
- Lu et al., [UXAgent: An LLM-Agent-Based Usability Testing Framework for Web Design](https://arxiv.org/abs/2502.12561) CHI EA 2025
- Datadog / FullStory — Frustration signals (rage / dead / error click) definitions
- Ericsson & Simon (1984) *Protocol Analysis* — Think-aloud
- Tversky & Kahneman (1974) Confirmation bias
