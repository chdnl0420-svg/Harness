---
name: harness-plan
description: harness step2(도메인) 전용 인터랙티브 plan 작성 스킬. AskUserQuestion 으로 사용자 의도를 카테고리별로 직접 묻고, 필요 시 외부 리서치를 `harness-deep-researcher` 에 위임 (`--noagent` 모드면 메인 Claude 직접) 한 뒤, 모은 입력을 바탕으로 plan-readability 규칙을 지키는 도메인 설계 초안을 만든다. /harness step2-domain 안에서만 호출. 일반 계획이 필요하면 /plan 사용.
---

# harness-plan

`/harness` step2 도메인 설계 단계에서 **메인 Claude 가 직접 수행**하는 인터랙티브 plan 작성 절차. 호출자(step2-domain.md)는 이 skill 만 부르면 된다.

이 skill 은 **별도 프로세스가 아니다**. 본 문서의 절차를 메인 Claude 가 그대로 따라 행동한다.

---

## 🚨 STRONG DIRECTIVE — Plan Readability (HIGHEST PRIORITY)

**사용자에게 보여주는 plan 출력은 반드시 중·고등학생이 읽고 이해할 수 있어야 한다.** 이 규칙은 본 skill 의 다른 모든 출력 지침보다 우선한다.

**문체 규칙 (강제)**:
- 짧은 문장. 한 문장이 두 줄 넘으면 다시 쓴다.
- 한글 우선. 영어 기술용어는 처음 등장 시 1줄 풀어 설명: 예) "리팩토링(코드 정리)", "fallback(대안 사용)", "TDD(테스트 먼저 쓰기)".
- 일상어로 환산: "수행한다" → "한다", "구현한다" → "만든다", "검증한다" → "확인한다".
- 능동태. 수동태("처리된다") 금지.
- 약어·이모지 절제. 강조는 **굵게** 만 사용.
- 단계마다 "왜 이걸 하는가" 1줄 포함. 단순 작업 나열 금지.
- 위험 항목은 "어떤 일이 벌어질 수 있는지" + "어떻게 막을지" 둘 다 일상어로.
- 코드 블록은 짧게. 긴 diff·stack trace 금지 — 파일 경로만 링크.

---

## 절차 (CRITICAL — 순서 엄수)

### Phase 1. 도메인 입력 수집 (필수 게이트)

CRITICAL: 사용자가 요청한 내용을 실제 완료 할 수 있는 계획을 세워야함. 중간 단계까지만 계획 세우기 절대 금지.

**모드 분기 (CRITICAL — 호출 컨텍스트 확인)**:

호출자의 컨텍스트에 따라 두 모드 중 하나로 진행. 자체 검증으로 모드를 식별한다.

1. **`.harness/.noask` 마커가 존재** OR 호출자가 `/harness` (noask 기본 정책) 인 경우 → **noask 모드**:
   - **`AskUserQuestion` 호출 금지** (harness/SKILL.md noask 정책 준수).
   - 6개 카테고리 각각에 *합리적 기본값* 을 메인 Claude 가 직접 적성. 사용자 원본 한 줄 목표 + 프로젝트 컨텍스트 (`docs/PRD.md`, `docs/ARCHITECTURE.md`, 최근 코드 변경) 만 보고 *최선의 가정* 작성.
   - 가정에 확신 부족한 항목은 **Open Questions** 섹션으로 누적 → step3 의 plan 검토 단계에서 사용자가 직접 검토 가능하게 노출.
   - 모드 진입 시 채팅 한 줄 보고: `[harness-plan noask 모드] AskUserQuestion 호출 없이 6 카테고리 합리적 가정 + Open Questions 누적으로 진행합니다.`

2. **`.harness/.ask` 마커가 존재** OR 호출자가 `/harness-ask` 또는 사용자 직접 호출인 경우 → **interactive 모드**:
   - **`AskUserQuestion` 만 사용.** 추측 / 기본값 / 침묵 진행 금지.
   - 한 번에 묻는 질문 1~4개, 선택지 2~4개씩. 사용자가 자유 답변하고 싶으면 "Other" 옵션으로 입력.

3. **두 마커 모두 부재** + 호출 컨텍스트 불명 → 사용자 안전을 위해 **interactive 모드 기본값** (사용자가 컨텍스트 모르면 묻는 게 안전).

### Phase 1 — interactive 모드 절차 (위 분기에서 모드 2/3 선택 시)

다음 6개 카테고리를 사용자가 답할 때까지 **순차** 진행한다. 한 번에 다 묻지 말고 카테고리별로 끊어 묻는다 (질문 화면 가독성).

1. **핵심 사용자 시나리오** — 어떤 사용자가 어떤 상황에서 무엇을 하려고 하는가
2. **성공 기준** — 무엇이 동작하면 "된 것" 인가 (관찰 가능한 결과)
3. **범위 / 제외 항목** — 이번 작업에 포함할 것 / 제외할 것
4. **제약** — 기술 스택·플랫폼·기존 코드 호환·성능·보안·일정 등 지켜야 할 것
5. **외부 의존성** — 사용할 라이브러리·API·서비스 (미정이면 "조사 필요" 로 표시)
6. **비기능 요구** — 접근성·국제화·로깅·관측성·테스트 수준 등 (해당 시)

규칙:
- 사용자가 되묻거나 부연 질문하면 **그 질문에 답만** 하고, 직후 다시 다음 카테고리 질문으로 복귀.
- 사용자가 명시적으로 "건너뛰자" / "기본값" 이라고 말하면 그 카테고리에 *"사용자 위임 — 기본값 사용"* 으로 메모하고 다음 카테고리로.
- 사용자가 처음 요청 본문에서 어느 카테고리 답을 이미 준 경우, 그 항목은 **확인 질문 1개로 압축** 가능 ("이렇게 이해했는데 맞나요?" 형태). 마음대로 통과 금지.
- 모든 카테고리가 끝나야 Phase 2 진행.

답변 정리:
- 메인 컨텍스트에 카테고리별로 누적.
- 답변이 5문항을 넘거나 길어지면 `.harness/research/answers-<slug>.md` 에 저장하고, 메인엔 한두 줄 요약만 남긴다 (컨텍스트 절약).

### Phase 1 — noask 모드 절차 (위 분기에서 모드 1 선택 시)

`AskUserQuestion` 사용 없이 메인 Claude 가 6 카테고리를 직접 작성. 입력 자료:

- 사용자 원본 한 줄 목표 (필수)
- 프로젝트 컨텍스트 — `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/ADR.md`, `docs/UI_GUIDE.md`, `CLAUDE.md` (존재 시 Read)
- 최근 git history (5 커밋) — 최근 작업 흐름 파악
- 변경 대상 영역의 코드 (한 줄 목표 키워드로 grep)

각 카테고리 작성 규칙:

1. **핵심 사용자 시나리오** — 한 줄 목표 + PRD 의 페르소나/사용자 흐름에서 *가장 직접적인 1개* 시나리오 추출. 불명 시 Open Questions 로.
2. **성공 기준** — "이게 동작하면 된 것" 의 *관찰 가능한* 결과 1~3개. 테스트로 검증 가능한 표현으로.
3. **범위 / 제외 항목** — 한 줄 목표 안에 명시된 것만 범위. 그 외 인접 영역은 *모두 제외* 로 기본 가정 (스코프 보수성).
4. **제약** — 프로젝트 docs + 코드의 *현재 스택·플랫폼* 만 기록. 새로운 의존성 추가는 Open Questions 로.
5. **외부 의존성** — *현재 코드에서 사용 중인* 라이브러리만 활용 가정. 신규 라이브러리 필요 시 Open Questions.
6. **비기능 요구** — PRD / UI_GUIDE 에 명시된 것만 인용. 명시 안 된 비기능은 *프로젝트 기본 수준* 으로 가정.

Open Questions 누적:
- 가정에 자신 없는 항목은 `## Open Questions` 섹션에 *질문 + 임시 가정* 을 짝으로 기록.
- 예: `Q: '재시작 후 모드 유지' 가 필수인가? (가정: YES — localStorage 사용)`.
- 이 섹션은 step3 plan 직전에 메인 Claude 가 사용자에게 한 번에 노출 (`/harness-ask` 전환 또는 inline 보고).

noask 모드 산출물도 interactive 모드와 동일하게 메인 컨텍스트 + (필요 시) `.harness/research/answers-<slug>.md` 누적.

### Phase 2. (필요 시) 외부 리서치 — `harness-deep-researcher` 위임

외부 정보가 필요하면 **`harness-deep-researcher`** 에 Task 위임. 필요 판정 기준 (다음 중 하나라도 해당하면 리서치 실시):
- 라이브러리·프레임워크 비교 또는 선택
- 최신 모범 사례 · current trends (학습 데이터 cutoff 이후 변경 가능 영역)
- 보안 권고 (OWASP / NIST / CVE)
- API 사용법 · 마이그레이션 영향 (vendor 공식 docs 확인 필요)
- Phase 1 답변에 *"조사 필요"* 가 명시된 항목
- 사용자가 명시적으로 "조사 / 비교 / 확인" 요청

**기본 경로 (subagent 위임)** — `.harness/.noagent` 가 **없을 때**:
- `Task` 도구로 `subagent_type="harness-deep-researcher"` 호출.
- prompt 에 4개 필드 명시:
  ```
  Topic: <조사 주제>
  Tier: light | standard | deep
  Context: <도메인 / 기술 스택 / 결정 영향 범위>
  조사 일자: YYYY-MM-DD
  ```
- 메인 Claude 는 도우미 응답을 받아 `.harness/research/research-<slug>-<NN>-<topic>.md` 에 **저장** — 응답의 *Summary · Key Findings · Sources Consulted · Search Trail · Stop reason* 그대로 보존 + 1줄 헤더 (주제, 일자, 호출자 메모).
- 메인 컨텍스트엔 *"리서치 결과: research-<slug>-<NN>-<topic>.md 참고"* 한 줄 + HIGH confidence Key Findings 만 prepend.

**Fallback 경로 (--noagent)** — `.harness/.noagent` 가 **있을 때**:
- Task 위임 금지. 메인 Claude 가 직접 WebSearch / WebFetch / 라이브러리 docs 조회.
- 단, harness-deep-researcher 의 환각 차단 4규칙은 동일 적용:
  1. No citation = no claim
  2. No paraphrasing from training data
  3. No fabricated URLs (WebFetch 실패한 URL 인용 금지)
  4. 검증 없는 추론은 *"Inferred:"* 로 분리
- 결과 저장 경로·양식은 위와 동일.

리서치 불필요 판단:
- 불필요하면 *"리서치 필요 없음 — 사유: …"* 한 줄 기록 (스킵 금지). 결과 파일도 만들지 않는다.

### Phase 3. 도메인 설계 초안 작성

Phase 1 답변 + Phase 2 리서치를 합쳐 **도메인 설계 초안** 을 만든다. 다음 구성을 권장한다:

- **요구사항 재진술 (Requirements Restatement)** — 사용자가 말한 것을 메인 Claude 가 다시 한 줄씩 푼다.
- **핵심 사용자 시나리오 / 성공 기준**
- **범위 / 제외**
- **제약**
- **외부 의존성**
- **비기능 요구**
- **위험 (Risks)** — severity(HIGH/MEDIUM/LOW) 명시. 각 위험에 *"어떤 일이 벌어질 수 있나"* + *"어떻게 막을지"* 둘 다 한국어 일상어로.
- **불확실 / 추후 결정 (Open Questions)** — Phase 1 에서 *"조사 필요"* / *"결정 보류"* 가 나온 항목.

문장 규칙은 위 "🚨 STRONG DIRECTIVE" 그대로 적용. 영어 약어는 처음 등장 시 풀어 설명.

### Phase 4. 자체 점검 4가지 (출력 전 필수)

1. **중학생 테스트**: 코딩 모르는 중학생이 plan 만 보고 *"무엇을 만드는지 · 왜 그렇게 만드는지 · 어떻게 확인하는지"* 말할 수 있나?
2. **전문용어 검사**: 풀어 설명 없이 등장한 영어 약어·기술용어 0개?
3. **문장 길이**: 한 문장이 두 줄 넘는 곳 없나?
4. **수동태 검사**: *"~된다"*, *"~처리된다"* 같은 표현 없나?

하나라도 NO → **다시 작성.** 점검 통과 후 비로소 호출자에게 초안 반환.

### Phase 5. 호출자에게 결과 반환

- 도메인 설계 초안 본문만 반환한다. **사용자 승인은 묻지 않는다** — 그건 호출자(step2-domain.md) 가 한다.
- Codex 리뷰도 호출자가 진행한다. harness-plan 은 초안 단계까지만 책임진다.

---

## 호출자(step2-domain.md) 가 알아야 할 사실

- 이 skill 은 step2-domain.md 의 흐름 중 **"사용자 질의 → 리서치 → 도메인 초안 작성"** 까지 한 덩어리로 담당. 그 다음의 Codex 리뷰 / 사용자 승인 / 파일 저장은 호출자 책임.
- `/plan` 의 일반 plan 출력 형식과 달리 **도메인 설계 카테고리** 를 따른다.
- **AskUserQuestion 호출 없이 plan 본문이 만들어졌다면 워크플로우 위반** 으로 간주 — 다시 Phase 1 부터 시작한다.
- 사용자가 *"질문 더 안 해도 돼, 알아서 해줘"* 라고 명시적으로 말하면 그것을 기록(*"사용자 명시 위임"*)하고 Phase 1 의 남은 카테고리를 기본 가정으로 메우되, Phase 3 의 *"Open Questions"* 에 그 가정들을 모두 적어 사용자가 step2 의 최종 승인 단계에서 점검할 수 있게 한다.

## 사용하면 안 되는 경우

- `/harness` step2 가 아닌 다른 곳 (일반 plan 이 필요한 자리) — 그때는 `/plan` 사용.
- 도메인 설계가 아닌 구현 계획(step3) — step3 는 `plan` skill 의 일반 흐름으로 진행.
