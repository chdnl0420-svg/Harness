# CLAUDE.md (프로젝트 헌법)

> 이 프로젝트에서 작업할 때 AI 가 따라야 할 규칙. 전역 `~/.claude/CLAUDE.md` 의 위, 그리고 프로젝트 한정 규칙을 정의.
> `/harness` 의 `harness-planner` 가 매 작업 시작 시 자동으로 읽음.

## 1. 코딩 컨벤션 (프로젝트 한정)

- 언어/런타임: {예: Node 20 / Bun 1.2 / Python 3.12}
- 모듈 시스템: {ESM / CommonJS / both}
- 패키지 매니저: {npm / pnpm / bun / poetry}
- 빌드 명령: `{command}`
- 테스트 명령: `{command}`
- 린트 명령: `{command}`

## 2. 폴더·이름 규칙

- 소스: `src/`
- 테스트: `test/` 또는 `*.test.{ts,js}` 옆 배치
- 파일명: {kebab-case / camelCase / snake_case}
- 컴포넌트: {PascalCase}

## 3. Git·커밋

- 브랜치: `{main / develop / ...}`
- 커밋 형식: Conventional Commits (`feat:`, `fix:` 등)
- PR 전 필수: `{lint && test}`

## 4. 보안 규칙

- secret 위치: `.env` (gitignore 됨)
- 절대 커밋 금지: API key, 비밀번호, JWT secret, DB 연결 문자열
- 외부 호출 시: timeout 설정 필수

## 5. AI 가 해도 되는 / 안 되는 것

**해도 됨** (사용자 매번 안 물어봄):
- 파일 권한 변경 (chmod)
- 디렉토리 생성, 임시 파일 정리
- linter/formatter auto-fix
- 표준 빌드/테스트 명령 실행

**반드시 사용자 확인**:
- 파괴적 git 작업 (reset --hard, force-push, branch -D)
- 외부 시스템에 영향 (PR/issue 생성, 배포, 이메일·Slack 전송)
- 의존성 메이저 업그레이드
- DB 마이그레이션 실행

## 6. 이 프로젝트만의 특이 사항

- {예: "이 repo 는 fetch 대신 apiClient wrapper 사용"}
- {예: "WebSocket 연결은 항상 reconnect 로직 포함"}
- {예: "사용자 ID 는 ULID 사용, UUID 금지"}

## 7. 외부 참고 문서

- 사양: `docs/PRD.md`
- 설계: `docs/ARCHITECTURE.md`
- 결정 기록: `docs/ADR.md`
- UI: `docs/UI_GUIDE.md` (해당 시)

## 8. 진행 중 작업 (선택)

현재 집중 중인 영역이나 한시적 규칙:
- {예: "v2 마이그레이션 진행 중 — 새 코드는 v2 패턴만 사용"}
