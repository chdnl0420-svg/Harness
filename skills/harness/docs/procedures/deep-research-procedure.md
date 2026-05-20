# Deep Research Procedure (Single Source)

> **이 문서가 harness deep research 호출 방식의 single source of truth.** `/harness-deep-researcher` slash · `harness-deep-researcher` skill · `harness-deep-researcher` agent · workflow 의 step2/step3 외부 리서치 분기 모두 이 문서를 cross-ref 한다.

## 5단계 흐름 (Plan-Act-Verify-Iterate-Synthesize)

### Step 1: Topic / Tier / Context 결정

호출자가 4개 필드를 전달 (필수):

```
Topic: <조사 주제 한 줄>
Tier: light | standard | deep
Context: <도메인 / 기술 스택 / 결정 영향 범위>
조사 일자: YYYY-MM-DD
```

`/harness-deep-researcher` slash 는 *항상 deep tier* 고정 (사용자 호출 시점에서 의도 명확).

### Step 2: Plan-Act 루프 (subagent 위임 기본)

**기본 경로** (`.harness/.noagent` 없을 때):

`Task` 도구로 `subagent_type="harness-deep-researcher"` 호출 + 4 필드 명시. 메인 Claude 는 응답 수신만, 검색·페치·합성은 subagent 가 수행.

**Fallback 경로** (`.harness/.noagent` 있을 때):

Task 위임 금지. 메인 Claude 가 직접 WebSearch / WebFetch / 라이브러리 docs 조회.

### Step 3: 환각 차단 4규칙 (subagent 또는 메인 직접 모두 적용)

1. **No citation = no claim** — 모든 단정에 출처 URL 부착
2. **No paraphrasing from training data** — Findings 와 Inferences 명확 분리, `Inferred:` 접두로 추론 표기
3. **No fabricated URLs** — WebFetch 실패한 URL 은 *"unreachable, referenced only"* 라벨 후 결과에서 제외
4. **Iterate 최소 3회** — 단일 검색 1회 종료 = 얕은 검색, deep tier 는 반드시 반복 루프

### Step 4: 결과 저장 (메인 Claude)

응답 본문을 `.harness/research/research-<slug>-<NN>-<topic>.md` 에 저장 (frontmatter 포함):

```yaml
---
topic: <원본 주제>
tier: light | standard | deep
date: <YYYY-MM-DD>
caller: harness-deep-researcher (slash | skill | agent | workflow)
---
```

응답의 *Summary · Key Findings · Sources Consulted · Search Trail · Stop reason* 모두 verbatim 보존. 패러프레이즈 금지.

### Step 5: 호출자 반환

메인 컨텍스트엔 한 줄 요약 + HIGH confidence Key Findings 만 prepend:

```
리서치 결과: research-<slug>-<NN>-<topic>.md 참고
- <HIGH finding 1>
- <HIGH finding 2>
```

본문 verbatim 은 파일에 있고, 메인 컨텍스트는 가벼움 (token 절약).

## 응답 본문 검증 (저장 직전)

저장 직전 메인 Claude 가 grep:

1. **Citation 없는 단정**: Key Findings 각 항목에 `출처:` 라인 있는지 → 없으면 STOP, 호출자에게 *"citation 누락"* 보고
2. **Fabricated URL**: Sources Consulted 표의 URL 중 `https?://` 형식 아니거나 `example.com` 같은 placeholder → STOP
3. **Unreachable URL 의 Findings 인용**: Search Trail 에 `unreachable` 라벨된 URL 이 Key Findings 의 `출처:` 로 다시 등장 → 라벨링 누락, STOP
4. **Inferences/Findings 혼용**: Key Findings 섹션에 `Inferred:` 접두 항목 → 분류 오류, STOP

위반 발견 시 보고서 *저장 안 함* + 호출자에게 원문 그대로 보여줌.

## 호출자별 어댑터

| 호출자 | 진입점 | 컨텍스트 |
|--------|--------|---------|
| `/harness-deep-researcher <주제>` (slash) | 사용자 직접 호출 | tier=deep 고정, slug=adhoc 또는 워크플로우 |
| `harness-deep-researcher` (skill) | 메인 Claude `Skill` 도구 | workflow 내부 (step2/step3), tier 호출자가 전달 |
| `harness-deep-researcher` (agent) | 메인 Claude `Task` 도구 | subagent 별도 컨텍스트, prompt 4 필드 명시 |
| step2/step3 외부 리서치 분기 (workflow) | 메인 Claude inline 또는 위 어댑터 호출 | slug + 조사 일자 prepend |

## 필요 판정 기준 (호출자 공통)

다음 중 하나라도 해당하면 deep research 호출:
- 라이브러리·프레임워크 비교 또는 선택
- 최신 모범 사례 · current trends (학습 데이터 cutoff 이후 변경 가능 영역)
- 보안 권고 (OWASP / NIST / CVE)
- API 사용법 · 마이그레이션 영향
- Phase 1 답변에 *"조사 필요"* 명시 항목
- 사용자가 명시적으로 *"조사 / 비교 / 확인"* 요청

불필요하면 *"리서치 필요 없음 — 사유: …"* 한 줄 기록 (스킵 금지).


---

> **2026-05-20 폐기 안내**: 본 문서가 언급하는 `--noagent` 플래그 / `.harness/.noagent` 마커 / Task subagent 분기는 모두 폐기됨. 모든 harness-* 단위는 `Skill` 도구로 호출하는 *skill* 으로 통합. 자세히: [harness/SKILL.md 실행 옵션](~/.claude/skills/harness/SKILL.md#실행-옵션-2026-05-20-단순화--agent--skill-전환-후).

