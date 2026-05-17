---
description: `harness-deep-researcher` 서브에이전트를 즉시 생성해 자연어 주제로 외부 출처 다중 검색·교차검증 딥리서치를 **항상 deep tier 로** 수행하고, 메인 Claude 가 `.harness/research/` 에 보고서를 저장한다.
argument-hint: '<주제 자연어> [--noagent]'
---

# /harness-deep-researcher

**핵심 동작**: 커맨드 호출 → 자연어 주제 파싱 → `harness-deep-researcher` 서브에이전트 생성 (tier = deep 고정) → Plan-Act-Verify-Iterate 루프로 외부 검색·교차검증 → 응답 본문 수신 → 메인이 `.harness/research/research-<NN>.md` 로 저장.

`--noagent` 면 서브에이전트 대신 메인 Claude 가 동일 절차 수행.

---

## 절대 규칙

1. **서브에이전트 실제 호출** — `Agent` 도구로 `subagent_type: "harness-deep-researcher"` 실호출. 텍스트 시뮬레이션 금지.
2. **Learning Prepend 계약 준수** — 호출 prompt 첫머리에 `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더 + 공용/프로젝트 학습 본문 통째로 prepend. 누락 시 서브에이전트가 자체 거부.
3. **agent 는 파일 작성 권한 없음** — 응답 본문만 받아 메인이 `.harness/research/` 에 저장. agent 응답을 패러프레이즈하지 말고 원문 그대로 회차 추가.
4. **환각 차단 4규칙 위반 응답은 저장 거부** — citation 없는 단정 / fabricated URL / unreachable URL 인용 / Inferences 와 Findings 혼용 발견 시 사용자에게 보고 후 중단.

---

## Step 1: 인자 처리

`$ARGUMENTS` 파싱:

1. `--noagent` 플래그 추출 (있으면 메인 직접 모드).
2. `--tier <...>` 플래그가 있으면 **무시** (호환성 위해 파싱만 하고 deep 로 고정). 한 줄로 통보: *"--tier 플래그는 무시되었습니다. 본 커맨드는 항상 deep tier 로 실행됩니다."*
3. 남은 토큰 전체를 **주제(topic)** 로 (공백 포함 자연어 그대로).
4. 주제가 비어 있으면 `AskUserQuestion` 으로 "리서치 주제 한 줄로 적어주세요" 묻기. 빈 채로 진행 금지.

**보고서 번호 결정**: `.harness/research/` 디렉토리에서 `research-*.md` 파일 개수 + 1 을 `<NN>` (2자리 zero-pad). 디렉토리 없으면 `01`.

## Step 2: Tier 결정 (deep 고정)

tier 는 항상 `deep` 으로 고정. 추론 단계 없음. 사용자 입력의 키워드·길이·차원 수와 무관하게 deep 으로 실행:

- WebSearch 6–12 회 / WebFetch 4–10 회 / 반복 루프 3–5 회 한도 적용
- "보수적 격상" 조항(과거에 deep 자동 트리거 시 token 15× 폭주 우려) 은 제거됨
- 비용·시간 우려가 있으면 호출자가 본 커맨드 자체를 호출하지 않으면 된다 — 호출 시점에서 이미 deep 의도로 간주

## Step 3: 컨텍스트 수집

다음을 한 번에 Read (병렬):

1. **공용 학습**: `~/.claude/skills/harness/agents/learning/harness-deep-researcher.md`
2. **프로젝트 학습**: `<PROJECT_ROOT>/.harness/agents/learning/harness-deep-researcher.md` (없으면 "(없음)")
3. **프로젝트 컨텍스트** (있을 때만, 주제와 연관도 평가 후):
   - `<PROJECT_ROOT>/.harness/PRD.md`
   - `<PROJECT_ROOT>/.harness/ARCHITECTURE.md`
   - `<PROJECT_ROOT>/CLAUDE.md`
   - `<PROJECT_ROOT>/package.json` / `Cargo.toml` / `pyproject.toml` 중 존재하는 것 (의존성 컨텍스트)

`<PROJECT_ROOT>` 는 호출 시점 `pwd`. worktree 안이면 `git rev-parse --git-common-dir` 의 부모.

**현재 날짜** 확보: 시스템 reminder 또는 `date` 명령 결과. agent 가 검색 쿼리에 연도 강제할 때 사용.

보고서 디렉토리 보장: `mkdir -p .harness/research`.

## Step 4: Prompt 빌드

다음 순서로 합친다 (workflow.md "Learning Prepend 계약" 양식 그대로):

```
## Prior Learning (READ FIRST — DO NOT SKIP)

**학습 파일 (공용)**: ~/.claude/skills/harness/agents/learning/harness-deep-researcher.md
**학습 파일 (프로젝트)**: <PROJECT_ROOT>/.harness/agents/learning/harness-deep-researcher.md  (없으면 "(없음)")

### 공용 학습 본문
<Step 3 에서 Read 한 공용 본문 전체>

### 프로젝트 학습 본문
<Step 3 에서 Read 한 프로젝트 본문 전체 또는 "(없음)">

### 적용 의무
- 본 작업 시작 전 위 두 본문을 처음부터 끝까지 읽고, 본 작업에 적용 가능한 항목을 머릿속에 정리한다.
- 작업 중 학습과 충돌하는 결정을 내리면, 응답 본문에 "기존 학습 X 와 충돌. 이유: ..." 명시.
- 응답 마지막에 `## Learning Proposals` 섹션 (변경 없으면 생략 — templates/learning-proposal.md 형식).
- 학습 파일을 직접 Edit/Write 하지 않는다. 제안만 한다.

---

## 본 작업

**Topic**: <사용자가 입력한 자연어 주제 그대로>
**Tier**: deep (고정)
**조사 일자**: <YYYY-MM-DD>

### 프로젝트 컨텍스트 (있을 때만)
<PRD / ARCHITECTURE / CLAUDE / 의존성 매니페스트 발췌. 주제와 연관도 낮으면 "(생략)">

### 절차 (agent 정의의 Plan-Act-Verify-Iterate 그대로)
- Phase 1 Plan: 하위 질문 3–6개 분해 + 각각의 첫 쿼리 + 기대 출처 유형 + 현재 날짜 명시.
- Phase 2 Act: Wide first, narrow later. deep tier 한도 (WebSearch 6–12 / WebFetch 4–10) 준수.
- Phase 3 Verify: 환각 차단 4규칙 — citation 의무 / 학습 데이터 포장 금지 / fabricated URL 금지 / Inferences 분리.
- Phase 4 Iterate: sufficiency | budget | saturation 중 하나에 도달하면 종료, 사유 명시. 최소 3 회 반복 루프 필수.
- Phase 5 Synthesize: agent 정의 "출력 형식" 그대로.

### 출력 형식 (응답 본문, agent 정의 그대로)
- Summary (1–3 문장)
- Key Findings (confidence + 출처 URL + 직접 인용)
- Comparisons (해당 시 표)
- Open Questions (해소 못한 것)
- Inferences (학습 데이터 기반, Findings 와 분리)
- Sources Consulted (표: # / URL / 유형 / 신뢰도 / Used For)
- Search Trail (Iteration 별 쿼리 + 좁힌 이유)
- 호출자에게 (메인 Claude)

### 절대 안 하는 것 (재확인)
- 단일 검색 1회 종료 — deep tier 는 최소 3 회 반복 루프 필수.
- 출처 없는 단정 — "Inferred:" 접두로 분리.
- WebFetch 실패한 URL 인용 — "unreachable" 표기 후 결과 제외.
- 같은 query / URL 두 번 — 다른 각도로 옮긴다.
- 파일 작성·수정 (Write/Edit 도구 미부여 — 위반 시 권한 정책 위반 응답).
- Subagent 추가 spawn.
- deep 미만으로 다운그레이드 — tier 는 deep 고정.
```

## Step 5: 실행

### 기본 모드 — 서브에이전트 생성

```
Agent(
  subagent_type: "harness-deep-researcher",
  description: "Deep research — <topic 앞 40자>",
  prompt: <Step 4 결과 그대로>,
  run_in_background: false
)
```

응답 본문을 받아 다음 검증 후 Step 6 으로:

- `## 🔬 Deep Research` 헤더 존재 여부.
- `Stop 사유: sufficiency | budget | saturation` 한 줄 존재 여부.
- `Sources Consulted` 표에 URL 1개 이상.
- `[BLOCKED] Prior Learning header 누락` 시 STOP — prepend 빌드 버그. 사용자에게 보고 후 중단.

### `--noagent` 모드

서브에이전트 호출하지 않고 메인 Claude 가 Step 4 prompt 내용대로 직접 수행:

1. 학습 본문은 Step 3 에서 이미 Read 했으므로 그대로 적용.
2. WebSearch / WebFetch / Bash 읽기 명령으로 Plan-Act-Verify-Iterate 직접 실행.
3. agent 정의 "출력 형식" 그대로 응답 본문에 합성.
4. Step 6 에서 동일하게 저장.

## Step 6: 보고서 저장 (메인이 수행)

agent 응답 본문(또는 --noagent 모드의 자체 합성 결과)을 **원문 그대로** 다음 경로에 Write:

```
.harness/research/research-<NN>.md
```

파일 상단 frontmatter:

```yaml
---
topic: <원본 자연어 주제>
tier: deep
date: <YYYY-MM-DD>
caller: harness-deep-researcher command
---
```

frontmatter 아래에 agent 응답 본문 그대로. 패러프레이즈·요약 금지. 응답에서 `## Learning Proposals` 섹션이 있으면 본문에 포함된 상태로 둔다 (Step 7 에서 별도 처리하지만 추적성 위해 보고서에도 남김).

## Step 7: 환각 차단 4규칙 후처리 검증

저장 직전 응답 본문에서 다음을 grep:

1. **Citation 없는 단정** — Key Findings 각 항목에 `출처:` 라인이 있는지. 없으면 STOP, 사용자에게 *"agent 응답에 citation 누락 finding 존재 — 저장 거부"* 보고.
2. **Fabricated URL 의심** — Sources Consulted 표의 URL 들 중 `https?://` 형식이 아닌 것 / domain 이 무의미한 것 (예: `example.com`, `your-source-here`) 발견 시 STOP.
3. **Unreachable URL 의 Findings 인용** — Search Trail 또는 Sources 표에 `unreachable` / `referenced only` 라벨된 URL 이 Key Findings 의 `출처:` 로 다시 등장하는지 grep. 등장하면 해당 finding 라벨링 누락이므로 사용자에게 보고.
4. **Inferences 와 Findings 혼용** — Key Findings 섹션에 `Inferred:` 접두로 시작하는 항목이 있으면 분류 오류. 사용자에게 보고.

위반 발견 시 보고서는 *저장 안 함*. 응답 원문을 사용자에게 그대로 보여주고 *"환각 차단 규칙 X 위반. agent 재호출 또는 수동 검토 필요"* 안내.

## Step 8: Learning Proposals 처리

응답 마지막에 `## Learning Proposals` 섹션이 있으면:

1. 형식 검증 (`templates/learning-proposal.md`): 모든 entry 가 `[YYYY-MM-DD]` 태그 / section 5개 (Principles / Patterns / Anti-patterns / Project-specific / Open Questions) 중 하나 / evidence 존재.
2. 중복 grep — 공용 + 프로젝트 학습 파일에서 비슷한 entry 가 이미 있는지.
3. 민감 정보 검사 (비번 / 내부 URL / 회사명 / 실 사용자 정보 / 미공개 API 키).
4. OK → `AskUserQuestion` 으로 적용 여부:
   - **A**: 공용에 추가 (`~/.claude/skills/harness/agents/learning/harness-deep-researcher.md`)
   - **B**: 프로젝트에 추가 (`<PROJECT_ROOT>/.harness/agents/learning/harness-deep-researcher.md`)
   - **C**: 건너뜀
5. 적용 시 해당 학습 파일 Edit + 보고서 끝에 "Learning Proposals 반영: ..." 한 줄 append.

차단 사유 있으면 사용자에게 보고 + 학습 파일 손대지 말 것.

## Step 9: 사용자 출력

```
✅ Deep Research 완료
  Topic: <원본 자연어 주제>
  Tier: deep (고정)
  보고서: .harness/research/research-<NN>.md
  검색·페치: WebSearch <N> 회 / WebFetch <M> 회
  Stop 사유: <sufficiency | budget | saturation>
  Findings: <HIGH=k / MEDIUM=m / LOW=l>
  Open Questions: <n>
  Learning Proposals: <적용 수>/<제안 수>  (또는 "없음")
```

---

## Anti-patterns (금지)

- ❌ `Agent` 호출 없이 메인이 텍스트로 시뮬레이션 (기본 모드)
- ❌ Prior Learning 헤더 누락 (= 학습 시스템 무력화 → 서브에이전트 자체 거부)
- ❌ agent 응답 패러프레이즈 — 보고서는 응답 본문 원문 그대로 저장
- ❌ 환각 차단 4규칙 위반 응답을 무검증 저장
- ❌ deep 미만으로 다운그레이드 (--tier light/standard 인자 존중) — tier 는 deep 고정. 보수적 격상 조항은 제거됨.
- ❌ 같은 주제로 연속 재호출하며 *"더 깊이"* 요구 — saturation 도달 후엔 새 각도 / 새 하위 질문으로 분해해 재호출
- ❌ `.harness/research/` 외 경로에 저장
- ❌ agent 가 권한 없는 도구 (Write/Edit/git/npm 등) 사용했다는 흔적 발견 시 묵인 — 즉시 사용자에게 보고
- ❌ Findings 와 Inferences 혼용된 응답을 *"대체로 맞으니 저장"* — 분리 안 된 상태로 다운스트림 결정에 새면 환각이 의사결정에 섞임

---

## 관련

- agent 정의: `~/.claude/skills/harness/agents/harness-deep-researcher.md`
- 학습 파일: `~/.claude/skills/harness/agents/learning/harness-deep-researcher.md`
- 프로젝트 학습: `<PROJECT>/.harness/agents/learning/harness-deep-researcher.md`
- 워크플로우 계약: `~/.claude/skills/harness/docs/workflow.md` ("Learning Prepend 계약" 섹션)
- 학습 제안 양식: `~/.claude/skills/harness/templates/learning-proposal.md`
- 출력 형식 / 환각 차단 4규칙: agent 정의의 "출력 형식" / "환각 차단 4규칙" 섹션
