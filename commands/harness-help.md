---
description: harness 관련 모든 명령·skill·agent 의 사용법을 한 곳에서 보여주는 도움말. 처음 쓸 때, 잊었을 때, 어떤 명령을 써야 할지 막힐 때 호출.
---

# /harness-help

harness 워크플로우 + 관련 도구 전체 안내. 이 명령은 코드를 건드리지 않고 **읽기만** 한다.

## Usage

```
/harness-help                  # 전체 개요
/harness-help <topic>          # 특정 주제만
```

`<topic>` 예시:
- `setup` / `install` — 설치·검진
- `workflow` / `flow` — `/harness` 전체 phase 흐름
- `agents` — 6개 harness-* agent 와 learning protocol
- `commands` — 슬래시 명령 전체 목록
- `wrappers` — codex/gemini wrapper 와 환경변수
- `troubleshoot` / `오류` — 자주 나는 에러와 해결
- `files` / `artifacts` — `.harness/` 폴더 구조

---

## 동작

Claude는 이 명령 받으면 **순서대로**:

1. 사용자가 topic 인자를 줬으면 그 섹션만, 안 줬으면 전체 출력.
2. 각 섹션 끝에 "관련 파일" 경로 명시 (사용자가 직접 더 깊이 볼 수 있게).
3. 코드 변경 없음. 마지막에 다음 행동 제안 1줄.

---

## 출력 템플릿

### 📦 Harness 가족 (한눈에)

| 분류 | 이름 | 용도 |
|------|------|------|
| **슬래시 명령** | `/harness` | 본 워크플로우 시작·재개·상태 조회 |
| | `/harness-setup` | 의존성 10개 항목 검진 + 자동 설치 |
| | `/harness-spec` | 프로젝트 사양 (PRD/ARCH/ADR/UI) + 헌법 작성 |
| | `/harness-review` | 즉석 코드/문서 리뷰 (Codex) |
| | `/harness-audit` | 저장소 audit 점수표 |
| | `/harness-distill` | agent learning 파일 압축 |
| | `/harness-help` | 이 도움말 |
| **Skill** | `harness` | `/harness` 명령이 실제로 실행하는 워크플로우 정의 |
| **Agent** | `harness-planner` | Plan 작성 (Phase 1.0) |
| | `harness-architect` | 시스템 차원 검토 (Phase 1.1) |
| | `harness-code-reviewer` | 라인 단위 코드 리뷰 |
| | `harness-security-reviewer` | 보안 게이트 |
| | `harness-tdd-guide` | TDD 사이클 안내 |
| | `harness-build-resolver` | 빌드 에러 해결 |
| | `codex-reviewer` / `gemini-researcher` | 외부 LLM 래퍼 호환 agent |

---

### 🚀 처음 쓰는 사람을 위한 5분 가이드

1. **설치 확인**: `/harness-setup` → 10개 항목 ✅ 확인. 누락 항목은 화면 안내대로.
2. **첫 호출**: `/harness <자연어로 무엇을 만들지>` 예) `/harness src/util/discount.js 에 discount(price, percent) 추가, percent 0~100 검증`
3. **단계 진행**: Plan 검토 → 사용자 승인 → 구현 → 코드 리뷰 → 완료.
4. **결과 확인**: `<프로젝트>/.harness/results/report-<id>.md` (중학생 가독성 보고서).
5. **재개**: 중간에 멈췄으면 `/harness resume <REQUEST_ID>`.

---

### 🔄 `/harness` 워크플로우 (Phase 흐름)

```
Step 0: Initialize        — doctor + bootstrap + drift 검사
Phase 1.0: Plan Draft     — harness-planner 가 plan v1 작성
Phase 1.1: Self-Review    — 메인 10-point + architect/code-reviewer/security-reviewer 병렬
Phase 1.2: Codex Critique — codex-review.sh 호출 (필수 외부 실행)
Phase 1.3: User Approval  — 사용자 확정·수정·취소 선택
Phase 1.4: Revision       — 피드백 반영 (최대 3회)
Phase 1.5: Finalize       — plan 승인 + progress 초기화
Phase 2:   Research       — Gemini 자유 호출 (선택)
Phase 3:   Implement      — 메인 Claude 직접 또는 tdd-guide/build-resolver 위임
Phase 4:   Review Loop    — Codex 리뷰 최대 3회 + 수정 + 재리뷰
Phase 5:   Complete       — result.md + 중학생 가독성 report.md
```

**중단/한계 시**: 어디서 멈췄든 항상 `report-<id>.md` 작성됨.

**관련 파일**: `~/.claude/skills/harness/SKILL.md`

---

### 📚 Project Spec Layer (장기 컨텍스트)

매 `/harness` 호출 시 자동으로 참조되는 **장기 사양 문서**.

| 파일 | 용도 |
|------|------|
| `<PROJECT>/CLAUDE.md` | 프로젝트 헌법 (컨벤션·금지·자율 권한) |
| `<PROJECT>/docs/PRD.md` | 뭘 만드는지 (목표·핵심 기능·MVP 제외) |
| `<PROJECT>/docs/ARCHITECTURE.md` | 어떻게 만드는지 (디렉토리·패턴·데이터 흐름) |
| `<PROJECT>/docs/ADR.md` | 왜 이렇게 만드는지 (결정 누적, Phase 1.5 가 자동 append) |
| `<PROJECT>/docs/UI_GUIDE.md` | 어떻게 보여야 하는지 (선택, 비워둬도 OK) |

부트스트랩 시 빈 템플릿 자동 시드. **이미 있는 파일은 보호**.

작성: `/harness-spec init` → `/harness-spec prd` → `/harness-spec architecture` → ...
사양이 채워질수록 plan 정확도 ↑.

**관련 파일**: `~/.claude/skills/harness/templates/doc-*.md`, `project-claude.md`

---

### 🧠 Agent Learning Protocol

각 agent 는 자기 학습 파일을 가지고 점점 똑똑해진다.

- **저장 위치 (하이브리드)**:
  - 공용: `~/.claude/skills/harness/agents/learning/<agent>.md` (모든 프로젝트 공유)
  - 프로젝트: `<PROJECT>/.harness/agents/learning/<agent>.md` (로컬 컨벤션)
- **갱신 방식**: agent 가 응답 끝에 `## Learning Proposals` 출력 → 메인 Claude 가 검증(중복/형식/민감정보/사이즈/모순) 후 반영.
- **로드**: agent 호출 직전 메인 Claude 가 두 파일 머지 후 prompt 앞에 prepend.
- **사이즈 캡**: 800줄. 초과 시 `/harness-distill <agent>` 권고.

**관련 파일**:
- 스키마: `~/.claude/skills/harness/agents/learning/README.md`
- 템플릿: `~/.claude/skills/harness/templates/learning-{file,proposal}.md`

---

### 🛠️ 슬래시 명령 상세

#### `/harness <요청>`
새 워크플로우 시작. 자연어로 무엇을 만들지 적으면 됨.

옵션:
- `/harness resume [REQUEST_ID]` — 중단된 작업 재개. id 생략 시 가장 최근.
- `/harness status` — 진행 중 작업 리스트.
- `/harness list` — 모든 작업 (최근 20개).
- `/harness sync` — wrapper 마스터 → 프로젝트 강제 동기화.

#### `/harness-setup`
**언제**: 처음 설치 후 / 의존성 누락 메시지 본 후 / GitHub 업데이트 반영하려고.

**검사 10개 항목**:
1. WSL 환경
2. Windows Terminal (`wt.exe`) — 선택
3. 기본 도구 (`bash`/`git`/`curl`/`stdbuf`)
4. NVM
5. Node ≥ 20
6. Codex CLI (`@openai/codex`)
7. Codex 로그인 (`~/.codex/`)
8. Gemini CLI (`@google/gemini-cli`)
9. Gemini API key
10. Agent learning 구조 (6 agents + 6 learning + 2 templates)

옵션:
- `--fix` — 누락 항목 자동 처리 시도.
- `--update` — GitHub 최신본 재설치.

#### `/harness-spec <subcommand>`
프로젝트 사양 문서 작성·갱신. 매 `/harness` 호출 시 자동 참조됨.

```
/harness-spec                # 5개 파일 상태 보기
/harness-spec init           # 빈 템플릿 5개 시드 (있는 것은 건너뜀)
/harness-spec prd            # PRD 작성 (대화형)
/harness-spec architecture   # ARCHITECTURE 작성 (대화형)
/harness-spec adr add        # 새 ADR entry 추가
/harness-spec adr list       # 기존 ADR 목록
/harness-spec ui             # UI_GUIDE 작성 (선택)
/harness-spec claude         # 프로젝트 CLAUDE.md 작성
```

#### `/harness-review <자연어로 무엇을 리뷰할지>`
plan/code/문서를 Codex 로 즉석 리뷰. `/harness` 워크플로우 안 쓰고 가볍게 의견만 받을 때.

예시:
```
/harness-review src/auth/login.ts 보안 관점에서 검토
/harness-review CHANGELOG.md 최근 항목 표현 다듬어줘
```

결과: `.harness/reviews/review-<timestamp>-<slug>.md`

#### `/harness-audit [scope]`
저장소 health 점수표.

scope: `repo` (기본) / `hooks` / `skills` / `commands` / `agents`
format: `--format text` (기본) / `--format json`

#### `/harness-distill <agent-name> [--project] [--all]`
agent 의 learning 파일 정리·압축.

언제 자동 트리거: 800줄 초과 시 메인 Claude 가 권고.
수동 트리거: 주기적 정리, 노후화된 entry 제거.

**관련 파일**: `~/.claude/commands/harness-{audit,distill,help,review,setup}.md`

---

### 🤖 6개 Agent 역할표

| Agent | Phase | 모델 | 핵심 책임 |
|-------|-------|------|----------|
| `harness-planner` | 1.0 | opus | 요구사항 → 단계 분해, 리스크 식별 |
| `harness-architect` | 1.1 | opus | 시스템 경계·일관성·확장성 |
| `harness-code-reviewer` | 1.1, 4 fallback | sonnet | 라인 단위 결함, edge case |
| `harness-security-reviewer` | 1.1, commit 직전 | sonnet | OWASP, secret, 인증·인가 |
| `harness-tdd-guide` | 3 (TDD 모드) | sonnet | RED → GREEN → REFACTOR 사이클 |
| `harness-build-resolver` | 3 (빌드 실패 시 자동) | sonnet | 최소 변경으로 빌드 그린 |

**관련 파일**: `~/.claude/skills/harness/agents/harness-*.md`

---

### 🪟 환경변수 (wrapper 동작 조정)

| 변수 | 기본 | 설명 |
|------|------|------|
| `HARNESS_NO_VISIBLE` | (off) | wt.exe 별창 비활성 → 인라인 모드 |
| `HARNESS_WAIT_LIMIT` | 600 | Codex/Gemini 응답 hard timeout (초) |
| `HARNESS_IDLE_LIMIT` | 180 | idle 감지 한도 (초). 0 = 비활성 |
| `HARNESS_TMUX_READY_TIMEOUT` | 30 | tmux 로딩 대기 (초) |
| `HARNESS_LARGE_PROMPT_BYTES` | 10240 | prompt 크기 기반 paste 임계 |
| `HARNESS_SKIP_DRIFT_CHECK` | (off) | drift 검사 영구 비활성 |

**관련 파일**: `~/.claude/skills/harness/wrappers/codex-review.sh` (line 150 부근 변수 선언)

---

### 📂 `.harness/` 폴더 구조

워크플로우 1회당 생성되는 산출물:

```
<PROJECT>/.harness/
├── plans/plan-<id>.md                — Phase 1 결과
├── progress/progress-<id>.md         — 실시간 상태
├── research/research-<id>-NN-*.md    — Gemini 조사
├── reviews/review-<id>-iter-N.md     — Phase 4 리뷰
├── improvements/improvement-...md    — 리뷰 후 수정 계획
├── results/result-<id>.md            — 머신 가독 요약
├── results/report-<id>.md            — 사람 가독 보고서 (중학생 수준)
├── wrappers/                         — 마스터에서 부트스트랩
├── core/                             — 마스터에서 부트스트랩
├── agents/learning/                  — 프로젝트 학습 데이터
└── backups/                          — drift sync 시 백업
```

`REQUEST_ID` = `YYYYMMDD-HHMMSS-<slug>`

---

### 🚑 자주 나는 오류

| 증상 | 원인 | 해결 |
|------|------|------|
| `Codex 로그인 필요` | Codex CLI 인증 만료 | wt.exe 별창에서 `codex login` 완료 후 메인 채팅에 "완료" |
| `Codex quota 소진 (exit 3)` | ChatGPT Plus 한도 도달 | Claude self critique 로 자동 fallback. 그대로 진행됨 |
| `Codex CLI 내부 에러 (exit 4)` | codex_core::tools::router stdin closed | `npm i -g @openai/codex@latest` 후 재시도 |
| `Argument list too long` | code review prompt 가 ARG_MAX 초과 | `--prompt-file` 패턴 사용 (SKILL.md Phase 4 참조) |
| Worktree 에서 `git init` 시도 | 옛 버전 wrapper | `/harness-setup --update` 로 최신 wrapper 받기 |
| `harness-* agent not found` | Claude Code 세션 시작 후 추가된 agent | Claude Code 재시작. registry 는 시작 시만 스캔 |
| Drift 4건 감지 | 마스터 wrapper 가 갱신됨 | `/harness sync` 또는 다음 `/harness` 호출 시 A 선택 |

---

### 🔗 추가 자료 경로

- 본문 정의: `~/.claude/skills/harness/SKILL.md`
- README (GitHub): https://github.com/chdnl0420-svg/Harness
- 도구 동작 상세: `~/.claude/skills/harness/docs/{setup,workflow,file-formats,examples}.md`

---

## 마무리 1줄

도움말 끝에 다음 행동 1줄 제안:
- 처음이면: "👉 `/harness-setup` 으로 10개 항목 확인부터 시작하세요."
- 설치 끝났으면: "👉 `/harness <만들고 싶은 것>` 한 줄로 시작."
- 막혔으면: "👉 `/harness-help troubleshoot` 으로 자주 나는 오류 보세요."
