# step2. 도메인 설계

**산출물**: `domain-<slug>.html` 파일 하나 (HTML 산출물 — SKILL.md 분류 규칙 따라 계획문서는 HTML)

**모드별 skill 분기 (CRITICAL — `.harness/.noask` 존재 여부로 판정)**:

| 모드 | skill | 사용자 질의 |
|------|-------|------------|
| **noask 기본** (`/harness` 호출 시 `.harness/.noask` 존재) | `harness-plan` skill (Skill tool, skill="harness-plan") | 없음 — 한 줄 목표를 입력 카테고리의 합리적 가정으로 메우고 딥 리서치 판정과 DDD 강제 권고 점검을 거쳐 도메인 초안 작성. 모든 가정은 *"Open Questions"* 섹션에 누적. |
| **ask** (`/harness-ask` 호출 시 `.harness/.noask` 없음) | `harness-plan-ask` skill (Skill tool, skill="harness-plan-ask") | Phase 1 의 입력 카테고리 AskUserQuestion 인터랙티브 질의. |

두 skill 은 동일한 입력 카테고리 / Phase 2 딥 리서치 / DDD 도메인 모델링 / Phase 3 구성 / Phase 4 자체 점검을 공유한다. 차이는 *Phase 1 입력 수집 방식* 만:
- **`harness-plan`** (noask): AskUserQuestion 호출 금지, 합리적 가정으로 자동 메우기, 모든 가정을 Open Questions 에 명시.
- **`harness-plan-ask`** (ask): AskUserQuestion 으로 카테고리별 인터랙티브 질의.

## CRITICAL: 딥 리서치 게이트

step2 는 도메인 초안 작성 전에 딥 리서치 필요 여부를 반드시 판정한다. `harness-plan` / `harness-plan-ask` skill 의 Phase 2 가 이 게이트를 수행하며, 다음 중 하나라도 해당하면 `harness-deep-researcher` 를 호출한다:

- 라이브러리·프레임워크 비교 또는 선택
- 최신 모범 사례·current trends 처럼 학습 데이터 cutoff 이후 바뀔 수 있는 영역
- 보안 권고 (OWASP / NIST / CVE)
- vendor 공식 docs 확인이 필요한 API 사용법·마이그레이션 영향
- DDD 적용 방식, bounded context, aggregate, domain event, anti-corruption boundary 판단이 구현 구조에 직접 영향
- 코드베이스 설계 방식(Clean Architecture, Ports and Adapters, dependency inversion, module boundary, migration path)을 현재 코드에 맞춰 판단해야 함
- Phase 1 답변 또는 noask 가정에 *"조사 필요"* 가 남은 항목
- 사용자가 명시적으로 "조사 / 비교 / 확인 / 리서치" 를 요청한 항목

호출 방식과 저장 형식은 [`docs/procedures/deep-research-procedure.md`](../procedures/deep-research-procedure.md) 를 따른다. 결과는 `.harness/research/research-<slug>-<NN>-<topic>.md` 에 저장하고, 도메인 초안에는 HIGH confidence finding 만 반영한다. 리서치가 필요 없으면 *"리서치 필요 없음 — 사유: …"* 한 줄을 progress 에 남긴다.

## CRITICAL: DDD 도메인 설계 강제 권고

step2 산출물은 구현 계획이 바로 참고할 수 있는 DDD 도메인 모델을 포함하는 것을 **강제 권고**한다. 이 권고는 도메인 주도 설계(DDD)의 목표 구조를 구현 계획의 기본 기준으로 삼게 한다. 기존 코드 구조가 DDD 모델과 다르면 step3 에서 DDD 목표 구조로 옮기는 migration plan 을 우선 검토한다.

도메인 초안에 필수 검토를 강제 권고하는 항목:

- **공통 업무 언어** — 이번 작업에서 코드·문서·테스트 이름에 써야 할 핵심 용어와 뜻.
- **Bounded Context(모델 경계)** — 이번 작업의 주 경계와 인접 경계. 같은 단어가 다른 뜻이면 경계를 나눈다.
- **Subdomain 분류** — core / supporting / generic 중 하나. 분류와 무관하게 bounded context 와 공통 업무 언어는 반드시 둔다.
- **Entity / Value Object / Aggregate 후보** — 업무 규칙을 지키는 데 필요한 모델. aggregate 는 트랜잭션·일관성 경계로 반드시 판정한다.
- **Invariant(항상 지켜야 할 규칙)** — 어떤 상태가 절대 깨지면 안 되는지, 어느 모델이 지키는지.
- **Domain Event 후보** — 다른 경계가 알아야 하는 업무 사건만. 단순 내부 상태 변경은 제외.
- **Context Map / Anti-Corruption Boundary** — 외부 API, 레거시 모델, 다른 모듈과 섞이는 지점과 번역 계층 필요 여부.

강제 점검:
- 위 항목 중 하나라도 비어 있으면 경고를 남기고, 가능한 경우 step3 진입 전에 도메인 초안을 보강한다.
- 단순 CRUD 작업이어도 DDD 최소 세트(공통 업무 언어, bounded context, aggregate 또는 transaction boundary, application service, repository/adapter boundary)를 먼저 검토한다.
- DDD 용어가 기존 코드 변경으로 이어지면 step3 에서 단계적 migration plan 으로 반영하는 것을 기본값으로 삼는다. 따르지 못하면 이유와 대체 검증을 남기는 것이 필수다.

**흐름** (두 모드 공통, Phase 1 입력 방식만 다름):

1. **harness-plan 또는 harness-plan-ask skill 호출** — 산출: 도메인 설계 초안 본문 (사용자 미승인).
2. **딥 리서치 게이트 확인** — skill 결과에 리서치 수행 여부, 저장 파일 또는 불필요 사유가 포함되어야 한다. 누락 시 1번을 재호출한다.
3. **DDD 강제 권고 확인** — 공통 업무 언어, bounded context, aggregate/invariant 판단, context map 포함을 확인한다. 누락 시 보강을 우선하고, 보강하지 않으면 사유를 남기는 것이 필수다.
4. skill 결과(초안)를 Codex 가 리뷰
5. 리뷰 결과를 메인 Claude 가 검토 / 반영
6. **승인 분기**:
   - **noask 모드**: AskUserQuestion 호출 금지. Codex 리뷰 1회 반영한 본문으로 **자동 승인** → 곧장 8번 단계.
   - **ask 모드**: AskUserQuestion 으로 *"1. 승인 / 2. 수정 의견 / 3. 취소"* 제시. 승인 질문 직전에 도메인 설계 본문을 화면에 그대로 보여 사용자가 확인 가능해야 함.
7. (ask 모드 한정) 수정 의견 시 1번(`harness-plan-ask`) 재호출, 단순 질문 시 답변만 하고 다시 승인 질문, 취소 시 워크플로우 중단.
8. 파일 작성 (`.harness/domain-<slug>.html`) → step3 로

---

## CRITICAL: UX 카테고리 강제 게이트 (산출물 검증)

도메인 본문이 다음 키워드 중 **하나라도** 포함하면 *UX 변경 작업* 으로 자동 판정 — `# UX` 또는 `## UX` 카테고리가 도메인 HTML 본문에 **반드시** 존재해야 한다:

`화면` · `UI` · `버튼` · `메뉴` · `레이아웃` · `색상` · `폰트` · `아이콘` · `네비게이션` · `모달` · `툴팁` · `폼` · `입력` · `리스트` · `카드` · `사이드바` · `헤더` · `푸터` · `토글` · `드롭다운` · `애니메이션` · `전환` · `반응형` · `모바일` · `데스크톱` · `다크모드` · `접근성` · `flow` · `wireframe` · `mockup`

### UX 카테고리 필수 항목 (4종)

1. **변경 대상 화면·요소** — 어느 화면의 무엇이 바뀌나 (구체적 위치, 예: "메인 화면의 우측 사이드바 검색 박스")
2. **Before → After** — 현재 동작 vs 변경 후 동작, *사용자 시점 1줄씩* (개발자 용어 금지, [harness-plan §STRONG DIRECTIVE](~/.claude/skills/harness-plan/SKILL.md) 와 동일 문체)
3. **영향 사용자 시나리오** — 누가 어떻게 영향 받나 (페르소나 + 흐름)
4. **시각화 (Best-effort 순위, 가능한 가장 위 옵션 선택)**:
   - (a) **실제 이미지 (Best)** — 사용자 첨부 디자인 / 현재 화면 스크린샷이 있으면 `<img>` 로 임베드. 외부 URL 금지 (HTML 출력 규칙 §단일 파일). 사용자 제공 로컬 이미지는 **base64 인라인** (`<img src="data:image/png;base64,...">`) 또는 `file:///` 상대경로 둘 중 하나.
   - (b) **inline SVG mockup** — 직접 그릴 수 있으면 `<svg>...</svg>` 로 와이어프레임 임베드 (도형·텍스트로 화면 골격 표현).
   - (c) **ASCII 와이어프레임** — 둘 다 어려우면 `<pre>` 안에 ASCII 박스 (`+-----+`, `|btn|` 등) 로 골격 표시.
   - (d) **텍스트 설명만** — 시각화 자체가 의미 없는 변경 (예: 텍스트 라벨 한 줄 바꿈) 만 허용. 이 경우 *"시각화 생략 사유: …"* 명시.

### 자동 검증 (step3 진입 전)

step3 진입 직전 메인 Claude 가 `domain-<slug>.html` 본문에 다음을 grep 확인:

- UX 키워드 등장 여부 (위 키워드 목록)
- UX 키워드 등장 + `# UX` 또는 `## UX` 헤더 존재 + 4종 필수 항목 (변경 대상 / Before-After / 영향 시나리오 / 시각화) 모두 존재 여부

키워드 등장 + UX 섹션 누락 또는 4종 미충족 → **도메인 초안 재작성** (Codex 리뷰 NO 와 동일 분기, 1번 단계 재호출). report 에 *"UX 카테고리 게이트 실패"* 기록.

키워드 미등장 → UX 카테고리 없음 OK (백엔드·인프라·문서 등 화면 변경 없는 작업은 면제).
