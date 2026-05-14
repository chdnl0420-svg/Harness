---
description: 프로젝트 사양 문서 (PRD/ARCHITECTURE/ADR/UI_GUIDE) + 헌법 (CLAUDE.md) 을 대화형으로 작성·갱신. /harness 가 매 작업 시 자동 참조하는 장기 컨텍스트.
---

# /harness-spec

프로젝트의 **장기 사양 문서** 를 만들고 관리한다. `/harness` 워크플로우와 직교 — 사양이 채워질수록 `/harness` 가 더 똑똑해진다.

## Usage

```
/harness-spec                  # 4개 doc + CLAUDE.md 상태 보기
/harness-spec init             # 5개 파일 빈 템플릿 생성 (없는 것만)
/harness-spec prd              # PRD 작성·수정 (대화형)
/harness-spec architecture     # ARCHITECTURE 작성·수정 (대화형)
/harness-spec adr add          # 새 ADR entry 추가
/harness-spec adr list         # 기존 ADR 목록
/harness-spec ui               # UI_GUIDE 작성·수정 (대화형, 선택)
/harness-spec claude           # 프로젝트 CLAUDE.md 작성·수정 (대화형)
```

## 동작

### 공통 흐름

1. 대상 파일 Read (없으면 템플릿 시드).
2. 사용자에게 현재 내용 요약 1줄 보고.
3. 자연어 입력 받기 (`AskUserQuestion` 또는 자유 텍스트).
4. Claude 가 형식 맞춰 작성·갱신 (기존 내용 보존 + 새 항목 추가/수정).
5. **diff preview** 사용자에게 보여줌.
6. 사용자 확정 → Edit 으로 적용.

### `/harness-spec init`

- `<PROJECT>/docs/` 생성 (없으면).
- 5개 파일 시드:
  - `docs/PRD.md` ← `templates/doc-prd.md`
  - `docs/ARCHITECTURE.md` ← `templates/doc-architecture.md`
  - `docs/ADR.md` ← `templates/doc-adr.md`
  - `docs/UI_GUIDE.md` ← `templates/doc-ui-guide.md` (비어 있음 상태)
  - `<PROJECT>/CLAUDE.md` ← `templates/project-claude.md`
- **이미 있는 파일은 절대 안 건드림** (사용자 콘텐츠 보호).

### `/harness-spec prd` 절차

1. 현재 PRD.md 읽기.
2. 사용자에게 묻기:
   - "프로젝트 목표가 무엇인가요?"
   - "핵심 기능 3가지?"
   - "MVP 에서 일부러 뺀 것?"
3. 답변 받아 PRD.md 갱신 (기존 내용 있으면 통합).
4. diff preview → 확정.

### `/harness-spec adr add` 절차

1. 사용자에게 묻기:
   - 결정: ?
   - 이유: ?
   - 대안: ?
   - 트레이드오프: ?
2. 다음 ADR 번호 계산 (`ADR-NNN` 최대값 + 1).
3. 템플릿 형식대로 entry 작성.
4. `ADR.md` 끝에 append.

### `/harness-spec architecture` 절차

1. 현재 ARCHITECTURE.md 읽기.
2. 사용자에게 어느 섹션 갱신할지:
   - 디렉토리 구조
   - 기술 스택
   - 디자인 패턴
   - 데이터 흐름
   - 모듈 경계
   - 환경 변수
3. 선택 섹션만 대화형으로 갱신.

### `/harness-spec ui`

UI_GUIDE.md 는 **선택**. 작성하지 않아도 `/harness` 정상 동작.
백엔드 only 프로젝트는 비워둬도 OK.

대화형 작성 시 질문:
- 디자인 방향 (Editorial / Bento / Glassmorphism / Swiss / Retro-futurism / 기타)
- 색상 / 타이포 / 간격 / 모션 기조
- 접근성 등급 (WCAG AA 권장)
- 레퍼런스 사이트·앱 1~3개

### `/harness-spec claude`

프로젝트 CLAUDE.md (헌법) 작성·수정.

질문:
- 코딩 컨벤션 (런타임/모듈/매니저)
- 빌드·테스트·린트 명령
- 보안 규칙 (secret 위치, 금지 사항)
- AI 자율 권한 (Rule 12 의 프로젝트 확장)
- 이 프로젝트만의 특이 사항

## 안전장치

- **기존 파일 보호**: init 은 없는 것만 시드. 다른 모드는 사용자 확정 후만 Edit.
- **diff preview 필수**: 갱신 전 항상 변경 사항 보여줌.
- **민감 정보 차단**: 사용자 입력에 비밀번호·API key 패턴 발견 시 차단 + 경고.
- **백업**: 첫 수정 시 `docs/.bak/<filename>-<timestamp>` 로 자동 백업.

## 통합 지점

### `/harness` 워크플로우와의 연동

- **step2 (도메인 설계)** 및 **step3 (구현 계획)**: `plan` skill 호출 직전 메인 Claude 가 다음을 prompt 앞에 prepend:
  ```
  ## 프로젝트 헌법
  <CLAUDE.md 내용>

  ## 프로젝트 사양
  - PRD: <docs/PRD.md>
  - ARCHITECTURE: <docs/ARCHITECTURE.md>
  - ADR (최근 10건): <docs/ADR.md tail>
  - UI_GUIDE: <docs/UI_GUIDE.md, 비어 있지 않으면>
  ```
  (`--noagent` 모드도 동일 — skill 호출 자체는 항상 메인 Claude 가 수행)
- **complete 단계**: domain/implementation/리뷰 결과의 "주요 결정" 항목을 ADR entry 로 자동 append. 사용자에게 "ADR-N 건 추가" 1줄 보고.

### 비어 있을 때

`/harness` 실행 시 docs/ 비어 있으면:
- 첫 plan 작성 후 한 줄 안내: "💡 `docs/PRD.md` 가 비어 있어요. `/harness-spec prd` 로 채우면 다음 작업이 더 정확해집니다."

## 예시

```
/harness-spec init
→ docs/PRD.md, ARCHITECTURE.md, ADR.md, UI_GUIDE.md, CLAUDE.md 생성

/harness-spec prd
→ Claude: "프로젝트의 목표가 무엇인가요?"
→ User: "주식 시세를 실시간으로 보여주는 데스크탑 앱"
→ Claude: "핵심 기능 3가지를 알려주세요"
→ User: "1. 실시간 차트 2. 알림 3. 포트폴리오 관리"
→ Claude: (diff preview) → 확정 → PRD.md 갱신

/harness-spec adr add
→ Claude: "결정: ?"
→ User: "WebSocket 대신 SSE 사용"
→ Claude: "이유: ?"
→ User: "단방향 충분 + 프록시 안정성"
→ Claude: (ADR-001 형식으로 작성) → 확정 → ADR.md append
```

## 관련 파일

- 템플릿: `~/.claude/skills/harness/templates/doc-*.md`, `project-claude.md`
- 워크플로우 통합: `~/.claude/skills/harness/SKILL.md` "Project Spec Layer" 섹션
- 본 명령: `~/.claude/commands/harness-spec.md`
