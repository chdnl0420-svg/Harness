# Learning Data: harness-deep-researcher

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-deep-researcher` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-15] 모든 단정은 출처 인용을 부착해야 한다. "No citation = no claim." 학습 데이터로부터 떠올린 내용을 외부 발견으로 포장하면 환각이 결정에 섞인다. 근거: arXiv 2604.03173 (citation hallucination), GPTZero ICLR 2026 hallucination report.
- [2026-05-15] (training) Retrieval-augmented 환경에서도 fabricated URL 률이 3–13% 보고. WebFetch 실패한 URL 은 *"unreachable"* 표시 후 결과에서 제외. URL 위조 시 영향이 가장 큰 환각이므로 사전 차단. 근거: arXiv 2604.03173 "Detecting and Correcting Reference Hallucinations".
- [2026-05-15] (training) Plan-Act-Verify-Iterate 반복 루프가 deep research 의 핵심. 단일 검색 1회 종료는 *얕은 검색* 이지 deep research 가 아니다. 반복마다 새 발견 0건이면 saturation, 그때만 종료. 근거: Anthropic "Multi-agent research system" 2025-09; arXiv 2506.18959 "Agentic Deep Research".
- [2026-05-15] (training) Wide first, narrow later — 첫 쿼리는 짧고 넓게, 결과 본 후 점점 좁은 기술 용어로 전환한다. 좁은 쿼리부터 시작하면 인접 영역의 핵심 키워드를 놓친다. 근거: Anthropic engineering blog "Multi-Agent Research System".
- [2026-05-15] (training) 효력 등급(Effort tier) 을 prompt 에 명시. agent 가 스스로 깊이 판단하면 단순 질문에 50회 검색 같은 폭주가 발생. light/standard/deep 한도를 호출자가 지정하거나 질문 형태로 추론. 근거: Anthropic multi-agent system "embedded scaling rules in prompts".

## Patterns
잘 통하는 접근법.

- [2026-05-15] (training) 출처 품질 5단계 휴리스틱: 공식 docs > primary engineering blog > peer-reviewed paper > 검증 커뮤니티 > Q&A 사이트. SEO 콘텐츠 팜·AI 자동 생성 텍스트는 인용 금지. 근거: Anthropic multi-agent system prompts "favoring academic PDFs, primary sources over SEO-optimized content farms".
- [2026-05-15] (training) WebFetch 의 prompt 는 *"X·Y·Z 항목 bullet 추출, quote 우선, 추측 금지"* 같은 구조화 추출 요청으로 작성. 페이지 전체 요약은 token 낭비 + 신호 희석. 근거: 본 세션에서 직접 측정 (qa-engineer 리서치 시 구조화 prompt 가 결과 가독성 ↑).
- [2026-05-15] (training) 민감 사실(수치·날짜·인용)은 2개 이상 독립 출처로 교차검증. 1개 출처만 있으면 confidence: LOW 표기. 단일 출처 의존 시 ICLR/NeurIPS 처럼 fabricated citation 이 그대로 다운스트림으로 흘러간다. 근거: Atlas / Elicit / Consensus benchmark — citation-grounded tools 의 hallucination 점수 0.05–0.18 vs ungrounded 0.4–0.9.
- [2026-05-15] (training) 검색 쿼리에 **현재 연도**(예: "2026") 를 명시해 stale 결과 회피. 모델 학습 cutoff 이후 변경된 모범 사례·API·정책을 잡는 가장 단순한 방법. 근거: 본 세션 다회 측정; Prompting Guide "context engineering for deep research".
- [2026-05-15] (training) 반복 루프 종료 조건은 sufficiency / budget / saturation 셋 중 하나. *"sufficiency"* 는 모든 하위 질문이 HIGH/MEDIUM confidence 로 답변됨. *"saturation"* 은 같은 키워드 군에서 새 발견 0건 연속. *"budget"* 은 tier 별 한도 도달. stop 사유를 응답에 명시해야 호출자가 재호출 여부 결정 가능. 근거: Anthropic multi-agent system "explicit search budgets and success criteria"; AI21 Maestro budget manager.
- [2026-05-15] (training) **PIES 복합 환각 점수가 2026 평가 표준** — Deep research agent 의 환각 측정은 PIES 4분류 복합 점수 ℋ = ¼(ℋES + ℋIS + ℋEP + ℋIP) — Planning × Summarization, Explicit × Implicit. 2026년 최저 관측 ℋ ≈ 0.149 (Qwen), 상위 6개 DRA 가 0.149~0.175 분포. citation accuracy 는 DeepResearch Bench 기준 90.24% (Perplexity, 최고) 가 현실 목표선. 기존 "0.05–0.18" 은 Atlas/Elicit/Consensus 같은 citation-only 도구 대상이고, PIES 는 전체 연구 궤적 대상 — **두 체계 혼용 금지**. 근거: arXiv 2601.22984 "Why Your Deep Research Agent Fails"; arXiv 2506.11763 DeepResearch Bench (FACT 프레임워크).
- [2026-05-15] (training) **Multi-agent 정당화 조건 = 독립 병렬 서브쿼리 한정** — 고정 토큰 예산 하 multi-hop reasoning 에서 single-agent 가 multi-agent 를 정보이론적으로 (Data Processing Inequality) 앞선다. Multi-agent 정당화 신호: ① 출처 간 독립 병렬 연구 서브쿼리, ② 공유 상태 수정 불필요, ③ 6+ 차원 동시 조사. Anthropic 실적 "+90.2% 향상" 은 이 조건 한정. 순차 의존 태스크에서는 멀티에이전트가 최대 70% 성능 저하, 토큰 비용 15× (Anthropic 실측) / 최적화 후 2–12×. harness PR 리뷰·단일 파일 작업·디버깅 = 적용 부적합. 근거: arXiv 2604.02460 (Tran & Kiela, Apr 2026); Augment Code "Single vs Multi-Agent AI Guide" 2026.
- [2026-05-15] (training) **Saturation 종료는 정보 이득 임계값 아닌 "budget + 컨텍스트 임계값" 이중 구조가 실제 표준** — 학계·산업 deep research 시스템 (Step-DeepResearch, arXiv 2508.12752 survey) 어디서도 "새 발견 0건 N회" 같은 정량 기준을 사용하지 않음. 실제 종료 조건: (a) 도구 호출 횟수 명시 예산, (b) 컨텍스트 윈도우 임계값 접근, (c) BFS 확장 최대 스텝, (d) 보고서 생성 완료 신호. harness 의 "새 발견 0건 1회 연속" 은 **보조 휴리스틱**으로 유효하나 지배적 제약은 budget. deep tier 한정 "2회 연속" 요구는 budget 범위 안에서만 적용. 근거: arXiv 2512.20491 Step-DeepResearch; arXiv 2508.12752 Deep Research Survey.
- [2026-05-15] (training) **Effort tier 자동 추론 — "순차 의존 단계 수" 가 "병렬 차원 수" 보다 강한 예측 인자** — ResearchRubrics 벤치마크 (arXiv 2511.07685) 측정: 순차 추론 4단계 초과 또는 인간 등가 35분 초과 태스크에서 모든 시스템 (Gemini DR 65~70%, ChatGPT DR 60~65%, Perplexity DR ~50%) 공통 붕괴. tier 추론 시 질문에 "단계 수 ≥ 4" 또는 "다중 차원 ≥ 6" 신호가 있으면 deep, 그 외는 standard 이하. 근거: arXiv 2511.07685 ResearchRubrics; Augment Code 2026 분석.

## Anti-patterns
하면 안 되는 것.

- [2026-05-15] 출처 없는 단정 작성 금지. *"일반적으로"*, *"보통"* 같은 학습 데이터 기반 단정은 추론 섹션으로만 옮긴다 (`Inferred:` 접두). 검증된 fact 와 섞으면 호출자가 구분 못 함. 근거: arXiv 2604.03173; Atlas hallucination-to-verification 0.05 (최저).
- [2026-05-15] 같은 query 두 번 검색·같은 URL 두 번 fetch 금지. 결과 없으면 다른 각도(동의어·상위 개념·인접 영역)로 옮긴다. 근거: Anthropic blog "endless web searching" 실패 모드.
- [2026-05-15] (training) **deep tier 자동 트리거 금지**. 사용자/호출자 명시 요청 또는 질문이 명확히 풍경 조사일 때만 deep. simple 질문에 deep 강제 시 token 15배 / 시간 5배 증가. 근거: Anthropic blog "Multi-agent uses ~15× more tokens than chat" + "spawn 50 subagents for simple queries" 실패 사례.
- [2026-05-15] (training) WebFetch 실패한 URL 을 "아마 그 페이지에 있을 것" 으로 인용 금지. 페이지 본문을 본 적 없으면 그 URL 은 *"unreachable, referenced only"* 라벨 후 결과에서 제외. 근거: arXiv 2604.03173 fabricated URL 률.
- [2026-05-15] (training) Subagent 추가 spawn 금지. 이 도우미는 단일 컨텍스트에서만 동작. 추가 분기 필요하면 호출자(메인 Claude)에게 보고하고 호출자가 결정. 근거: 본 harness 워크플로우 정책 — `--noagent` 모드 호환성 + 컨텍스트 복잡성 차단.
- [2026-05-15] (training) Lighthouse·Q&A 사이트 단일 출처로 *"공식 권고"* 단정 금지. 공식 docs 또는 standards body 출처와 cross-reference 필수. 근거: Atlas / Consensus benchmark — grounded vs ungrounded 차이.

## Project-specific
프로젝트별 컨벤션. 공용 파일에는 비어 있음.

## Open Questions
아직 결론 안 난 것. distill 시 결론 났으면 Patterns/Anti-patterns 로 이동.

- [2026-05-15] (training) **도메인×출처 매핑 캐싱 단위** — Anthropic / Google / OpenAI 의 agentic search 시스템이 출처 품질을 내부 캐싱·재활용하는 방식을 공개 문서화한 사례 없음. MCP (Model Context Protocol) 서버 단위가 가장 근접 표준이나, harness learning 에 적용할 추상화 단위 (라이브러리 단위 / 프레임워크 단위 / 도메인 단위) 는 미검증. 가설: 프레임워크 단위 (React / Next.js) + 표준 기관 단위 (WCAG / arXiv) 가 균형점. 해소 조건: 실제 N회차 누적 후 entry 폭증/신호 약함 측정.
- [2026-05-15] (training) **Citation accuracy / hallucination 합격 cutoff** — DeepResearch Bench 는 90.24% 를 최고치로 기록하나 "합격 기준" 수치 미명시. PIES ℋ < 0.15 가 best-in-class 지만 산업 표준 합격선 미정. 측정 인프라 (FEVER / SciFact 검증 파이프라인) 없이는 자가 평가 불가 — harness 환경에서 어떻게 근사할지 미해결.

## Resolved Questions
해소된 Open Question 의 기록. 어느 entry 로 이동했는지 추적.

- [2026-05-15] **`general-purpose` agent 와의 역할 분담** → 부분 해소. 격상 신호: 다중 차원 비교 + cross-reference 의무 + 순차 의존 4단계 이상 + 인간 등가 35분 이상 (ResearchRubrics 기준). 단일 출처 조회로 충분하면 general-purpose 로 족함. (Patterns 의 "Effort tier 자동 추론" entry 로 흡수)
- [2026-05-15] **Saturation 판정 기준 1회 vs 2회 연속** → 해소. 학계·산업 어디서도 "새 발견 0건 N회" 정량 기준 미사용. 실제 표준은 budget + 컨텍스트 임계값 이중 구조 — "0건 1회" 는 보조 휴리스틱으로만 유효. deep tier 2회 연속 요구는 budget 범위 안에서만 적용. (Patterns 의 "Saturation 종료는 budget + 컨텍스트 임계값" entry 로 이동)
- [2026-05-15] **Multi-agent 90.2% 향상의 harness 적용 가치** → 해소. 독립 병렬 서브쿼리·6+ 차원 동시 조사 한정. 순차 의존 태스크에서는 단일 에이전트가 우세 (Data Processing Inequality, arXiv 2604.02460). harness PR 리뷰·단일 파일 작업·디버깅 = 적용 부적합. (Patterns 의 "Multi-agent 정당화 조건" entry 로 이동)

## References
- Anthropic, [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) (2025-09)
- arXiv 2506.18959, [Agentic Deep Research: Incentivizing Search with Reasoning Agents](https://arxiv.org/abs/2506.18959)
- arXiv 2604.03173, Detecting and Correcting Reference Hallucinations in Commercial LLMs and Deep Research Agents
- arXiv 2510.05145, FlashResearch — Real-time Agent Orchestration for Efficient Deep Research (adaptive depth/breadth)
- Prompting Guide, [Context Engineering Deep Dive — Deep Research Agent](https://www.promptingguide.ai/agents/context-engineering-deep-dive)
- Atlas / Elicit / Consensus benchmarks (citation-grounded tools, hallucination ratio 0.05–0.18)
- GPTZero ICLR 2026 hallucination report (50+ citations missed by reviewers)
- Fortune (2026-01) on NeurIPS fabricated citation rise (1 in 277 papers, 2026)
- web.dev / playwright.dev / ISTQB — 공식 docs 출처 예시
- Gemini Deep Research API docs (Google)
- AI21 Maestro — budget manager / Pareto frontier for deep research
- arXiv 2601.22984, "Why Your Deep Research Agent Fails? On Hallucination Evaluation in Full Research Trajectory" (2026) — PIES 4분류 ℋ 점수
- arXiv 2506.11763 / [DeepResearch Bench](https://deepresearch-bench.github.io/) — FACT 프레임워크, citation accuracy 90.24% (Perplexity)
- arXiv 2604.02460 (Tran & Kiela 2026-04) — Single-agent vs multi-agent Data Processing Inequality, FRAMES/MuSiQue 벤치마크
- arXiv 2512.20491, "Step-DeepResearch Technical Report" (StepFun, Dec 2025) — 도구 호출 예산 + 컨텍스트 임계값 이중 종료 구조
- arXiv 2508.12752, Deep Research Survey — saturation 정량 기준 미사용 확인
- arXiv 2511.07685, [ResearchRubrics Benchmark](https://arxiv.org/html/2511.07685v1) — 순차 4단계 / 35분 초과 시 모든 시스템 붕괴
- Augment Code, "Single-Agent vs Multi-Agent AI" guide (2026) — 병렬화 정당화 기준
