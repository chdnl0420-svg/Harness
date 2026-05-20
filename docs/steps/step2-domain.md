# step2. 도메인 설계

**산출물**: `domain-<slug>.html` 파일 하나 (HTML 산출물 — SKILL.md 분류 규칙 따라 계획문서는 HTML)

**모드별 skill 분기 (CRITICAL — `.harness/.noask` 존재 여부로 판정)**:

| 모드 | skill | 사용자 질의 |
|------|-------|------------|
| **noask 기본** (`/harness` 호출 시 `.harness/.noask` 존재) | `harness-plan` skill (Skill tool, skill="harness-plan") | 없음 — 한 줄 목표를 6 카테고리 합리적 가정으로 메워 도메인 초안 작성. 모든 가정은 *"Open Questions"* 섹션에 누적. |
| **ask** (`/harness-ask` 호출 시 `.harness/.noask` 없음) | `harness-plan-ask` skill (Skill tool, skill="harness-plan-ask") | Phase 1 의 6 카테고리 AskUserQuestion 인터랙티브 질의. |

두 skill 은 동일한 6 카테고리 / Phase 3 구성 / Phase 4 자체 점검을 공유한다. 차이는 *Phase 1 입력 수집 방식* 만:
- **`harness-plan`** (noask): AskUserQuestion 호출 금지, 합리적 가정으로 자동 메우기, 모든 가정을 Open Questions 에 명시.
- **`harness-plan-ask`** (ask): AskUserQuestion 으로 카테고리별 인터랙티브 질의.

**흐름** (두 모드 공통, Phase 1 입력 방식만 다름):

1. **harness-plan 또는 harness-plan-ask skill 호출** — 산출: 도메인 설계 초안 본문 (사용자 미승인).
2. skill 결과(초안)를 Codex 가 리뷰
3. 리뷰 결과를 메인 Claude 가 검토 / 반영
4. **승인 분기**:
   - **noask 모드**: AskUserQuestion 호출 금지. Codex 리뷰 1회 반영한 본문으로 **자동 승인** → 곧장 6번 단계.
   - **ask 모드**: AskUserQuestion 으로 *"1. 승인 / 2. 수정 의견 / 3. 취소"* 제시. 승인 질문 직전에 도메인 설계 본문을 화면에 그대로 보여 사용자가 확인 가능해야 함.
5. (ask 모드 한정) 수정 의견 시 1번(`harness-plan-ask`) 재호출, 단순 질문 시 답변만 하고 다시 승인 질문, 취소 시 워크플로우 중단.
6. 파일 작성 (`.harness/domain-<slug>.html`) → step3 로

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
