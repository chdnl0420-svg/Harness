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

- [2026-05-15] (training) `general-purpose` agent 와의 역할 분담 — general-purpose 도 WebSearch/WebFetch 가능. 어떤 신호에서 deep-researcher 로 격상해야 하나? (현재 가설: 다중 차원 비교 / cross-reference 요구 / 출처 인용 의무 셋 중 하나 이상)
- [2026-05-15] (training) Saturation 판정 기준 — *"새 발견 0건 1회 연속"* 이 충분한가, 2회 연속 요구해야 좀 더 안전한가? deep tier 한정 2회 연속이 적정해 보이나 측정 필요.
- [2026-05-15] (training) 학습 데이터 누적 시 *"이 도메인은 이 출처가 잘 통한다"* 같은 도메인×출처 매핑을 어떤 단위로 적을지 — 도메인을 너무 좁게 (라이브러리 단위) 적으면 폭증, 너무 넓게 (frontend 전체) 적으면 신호 약함.
- [2026-05-15] (training) Multi-agent 가 90.2% 향상이라는 Anthropic 결과를 harness 워크플로우에 적용 가치는? 토큰 15배는 한 PR 리뷰에서 감당 어려움. 적용 후보는 *"풍경 조사 한 번에 6+ 차원 동시"* 같은 명확히 병렬화 이득이 큰 경우만.

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
