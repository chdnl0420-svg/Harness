# HTML 출력 규칙 (CRITICAL — 모든 harness 산출물·skill·command·agent 공통)

> **이 문서는 `~/.claude/CLAUDE.md` Section 6 + 6.3.1 의 harness 전용 미러이다.**
> 충돌 시 항상 `~/.claude/CLAUDE.md` 가 정본. 이 문서는 harness 워크플로우 안에서 잊지 않도록 가까이 두는 사본일 뿐이다.

## 적용 대상 (예외 없음)

다음 *모두* 가 산출물 파일을 만들 때 이 규칙을 따른다:

- `/harness` 메인 스킬, `/harness-*` 모든 슬래시 커맨드 (`harness-spec`, `harness-review`, `harness-customer-user`, `harness-deep-researcher`, `harness-distill`, `harness-noask`, `harness-audit`, `harness-setup`, `harness-sync`, `harness-help`)
- 모든 `harness-*` 서브에이전트 (`harness-planner`, `harness-architect`, `harness-tdd-guide`, `harness-code-reviewer`, `harness-security-reviewer`, `harness-build-resolver`, `harness-deep-researcher`, `harness-qa-engineer`, `harness-customer-user`)
- harness 메인 Claude (`--noagent` 모드 포함)
- harness 관련 키워드 트리거 (예: "/harness", "harness 실행", "step1~step8", "qa", "customer test", "deep research", "spec", "review" 가 harness 컨텍스트에서 나올 때)
- `.harness/` 디렉터리에 떨어지는 모든 산출물 — plan / progress / review / research / qa / customer / commit-summary / stop-report 등

## 산출물 파일 확장자

- **모든** 산출물 파일은 `.html` 로 작성한다.
- 예외 (`README.md`, `CLAUDE.md`, 외부 라이브러리 내부 .md, 사용자가 *그 작업에 한정하여* 명시적으로 .md 요청한 경우) 만 .md 유지.
- `.harness/` 안의 plan·progress·review·research·qa·customer·stop-report·commit-summary 등은 모두 `.html`.
- 기존에 `.md` 로 만들도록 적혀 있던 워크플로우는 자동으로 `.html` 로 대체된다. (workflow/steps 문서의 옛 .md 지시는 이 규칙으로 덮어쓴다.)

## 4대 UX 기준 (모든 HTML 산출물 공통)

**(A) 단일 파일**
- HTML 1개 파일로 완결. CSS/JS 모두 inline `<style>` / `<script>`.
- 외부 CDN·프레임워크 의존성 0. 아이콘은 SVG inline 또는 이모지.

**(B) 탭/버튼 인터랙티브 UI (필수)**
- 본문이 2섹션 이상이면 상단 탭 네비게이션으로 분할 (`role="tablist"` + `role="tab"` + `aria-selected`).
- **첫 번째 탭은 항상 "요약" 탭** (Summary / 한눈에 / Overview / TL;DR). 예외 없음.
  - 첫 탭 = 결론 · 핵심 지표 카드(3-5개) · 한 줄 요약.
  - 페이지 첫 로드 시 자동 활성화.
  - 라벨은 문서 성격에 맞춤: 보고서/분석 → "한눈에", 플랜/PRD → "Overview", 리뷰/QA → "Summary", research → "TL;DR".
- **상단 chrome 시인성 가이드 (반드시 준수)** — 탭이 화면 영역을 잡아먹어 콘텐츠를 가리지 않도록:
  - **상단 chrome 총 높이는 viewport 의 10% 이내, 절대값 64px 이하** (모바일 <768px 만 88px 허용). header + tab strip 합산 기준.
  - **header 와 tab strip 은 같은 줄에 합치는 것을 우선**. 좌측에 제목/메타, 같은 라인 우측에 탭. 두 줄로 쌓이는 layout 은 금지.
  - 합치기 어려우면 header 패딩 `8-10px`, tab strip 세로 패딩 `6-8px` 로 컴팩트 처리.
  - **tab 컴팩트 조판**: 세로 `6-8px` / 가로 `12-14px` / font `12-13px`. 40px+ fat tab 금지.
  - **탭 라벨 짧게**: 한국어 2-5글자, 영어 1-2단어. "변경 영향 분석" → "영향".
  - **탭 6개 초과 금지** — 초과 시 서브탭·아코디언·드롭다운으로 분할. 5개 이하 권장.
  - active 표시는 underline / pill / soft background 중 하나로 컴팩트하게.
  - 탭 strip 이 폭 넘으면 `overflow-x:auto` 또는 "더 보기" 드롭다운. 두 줄 wrap 금지.
- 시나리오/기간/모드 전환은 토글·세그먼트 컨트롤·아코디언.
- 키보드 접근성 (Tab/Enter/Space/화살표). URL hash 딥링크 가산점.
- 인쇄 시 모든 탭 펼침: `@media print { [role="tabpanel"] { display: block !important } }`.

**(C) 1뷰포트 무스크롤 대시보드**
- 각 탭/패널은 1뷰포트(100vh) 안에 핵심이 모두 들어가야 함.
- `body { overflow: hidden }` 또는 `main { height: 100vh; display: grid }` 우선.
- 정보가 많으면 → 서브탭 / 아코디언 / 모달 / 툴팁 / 접기 카드.
- 표가 길면 → 페이지네이션 / 필터 칩 / **카드 내부 스크롤** (페이지 전체 스크롤 금지).
- 컴팩트 조판: 본문 14-15px, h1 28-32px.
- 1440×900 기준 첫 화면 완결. 1280×720 까지 우아 축소. 모바일(<768px) 은 자연 스크롤 허용.

**(D) 저장 후 브라우저 자동 열기 (필수)**
- HTML 저장 직후 즉시 기본 브라우저로 연다.
  - PowerShell: `Start-Process "<절대경로>"`
  - 또는 Bash: `cmd.exe /c start "" "<절대경로>"`
  - 경로에 공백·한글 있으면 반드시 따옴표.
- 자동 열기 후 사용자에게는 **"저장 위치 + 브라우저에서 자동으로 열었습니다"** 한 줄만 보고.

## 서브에이전트 호출 시 필수 전달 문구

메인 Claude (또는 harness 메인 스킬) 이 `harness-*` 서브에이전트나 다른 스킬을 호출할 때, 프롬프트 안에 다음을 **명시적으로 포함**한다:

> "산출물은 반드시 `~/.claude/CLAUDE.md` Section 6 + 6.3.1, `~/.claude/skills/harness/docs/html-output-rule.md` 규칙을 따른다 — 단일 HTML 파일 + 탭 인터랙티브 (첫 탭은 항상 요약) + 1뷰포트 무스크롤 + 저장 후 브라우저 자동 열기."

서브에이전트가 자동 열기를 수행할 수 없는 환경이면, 메인 Claude 가 산출물 경로를 회수하여 직접 `Start-Process` 호출.

## 보고서 카테고리별 첫 탭 권장 라벨

| 산출물 유형 | 첫 탭 라벨 | 첫 탭 필수 콘텐츠 |
|------------|------------|---------------------|
| 보고서·분석 | "한눈에" | 결론 + 핵심 지표 카드 3-5개 |
| 플랜·PRD·spec | "Overview" | 목표·범위·핵심 결정 1줄씩 |
| 코드/문서 리뷰 (`harness-review`) | "Summary" | 총평·CRITICAL/HIGH 카운트·권고 액션 |
| QA 결과 (`harness-qa-engineer`) | "Summary" | Pass/Fail·블록·재현률 |
| Customer test (`harness-customer-user`) | "Summary" | SUS·SEQ·Time-to-First-Value·첫 인상 |
| Deep research (`harness-deep-researcher`) | "TL;DR" | 1-3문장 결론 + 핵심 근거 카드 |
| Stop / Commit report | "Summary" | 한 일·다음 액션·미해결 항목 |
