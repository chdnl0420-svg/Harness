# Codex Review Procedure (Single Source)

> **이 문서가 codex 리뷰 호출 방식의 single source of truth.** `/harness-review` slash · `harness-review` skill · `codex-reviewer` agent · `workflow.md` step5 부록 모두 이 문서를 cross-ref 한다. 본문 수정 시 자동으로 모든 호출 경로에 반영.

## 4단계 흐름

### Step 1: slug 결정

- 워크플로우 내부 호출이면 현재 진행 슬러그 사용
- adhoc 호출이면 `adhoc-<YYYYMMDD-HHMMSS>` 자동 생성

### Step 2: file-list 작성 (`Write` 도구)

`<project>/.harness/reviews/review-<slug>-file-list.md` 에 **경로 목록만** (각 줄 `- <path>`):

```markdown
- <path1>
- <path2>
```

별도 헤더·focus·instructions·코드 본문 일체 금지. 경로는 프로젝트 루트 기준 상대 경로.

### Step 3: codex exec 호출 (Bash 직접 실행)

```bash
codex exec --sandbox workspace-write \
  ".harness/reviews/review-<slug>-file-list.md 에 적힌 파일들 전부 리뷰해줘. 리뷰 결과는 .harness/reviews/codex-review-<slug>-result.md 에 작성해줘."
```

**위 한 줄 프롬프트 외 추가 텍스트 절대 금지.** focus, mode, system instruction, output format 지시 모두 안 적는다.

옵션:
- `--sandbox workspace-write` — codex 가 result 파일 쓰기 권한 필요. read-only 면 result.md 생성 불가.
- 작업 디렉토리 = `pwd` (= 프로젝트 루트). `-C` 옵션 명시 금지 (cwd 자동).
- `run_in_background: false` — 동기 수신 필요.

### Step 4: 결과 검증

1. **exit code 확인**:
   - `0` → result 파일 존재 + 비어 있지 않은지 확인
   - `2` → **Codex 로그인 필요**. 사용자에게 안내: *"새 터미널 (cmd / PowerShell / Git Bash) 열고 `codex login` 실행 후 재시도"*. fallback 금지.
   - `3` → **Codex quota 소진**. Claude `code-reviewer` agent 또는 `code-review` skill 로 fallback. report 에 *"fallback_used: code-review skill (self-review)"* 기록.
   - 기타 → 에러 보고
2. **result 파일 Read** (`Read` 도구):
   - `<project>/.harness/reviews/codex-review-<slug>-result.md` 본문 확인
   - 비어 있거나 *"리뷰 못 함"* 류 메시지면 STOP — fake 응답 생성 절대 금지
3. **호출자 반환**:
   - 호출자 (slash·skill·agent·workflow) 에게 result.md 의 **절대경로 + 본문 verbatim** 둘 다 전달
   - 추가 출력 없음 (사용자가 절대경로로 파일 직접 확인)

## Mode 분기 (Code Review vs Plan Critique)

호출 명령·프롬프트는 **동일**. 차이는 *file-list 에 적힌 파일 종류* 만:

| Mode | file-list 예시 |
|------|----------------|
| **Code Review** | `src/auth.ts`, `lib/api.go` 등 코드 파일 |
| **Plan Critique** | `.harness/domain-<slug>.html`, `docs/rfc-001.md` 등 plan 문서 |

Codex 가 자체 file-read 도구로 파일을 읽고 *적절한 형식* (코드 리뷰 → CRITICAL/HIGH/MEDIUM 분류, plan critique → Missing Pieces/Hidden Risks 등) 으로 result.md 작성. 호출자가 형식을 강제하지 않는다.

## 금지 패턴

- ❌ 프롬프트에 focus / mode / instructions / output format 지시 추가
- ❌ `wrappers/codex-review.sh` wrapper 호출 (2026-05-20 폐기됨)
- ❌ `wsl -e bash -c "codex ..."` 같은 wsl wrapping
- ❌ `tmux` / `wt.exe` / sentinel polling 같은 인터랙티브 흐름
- ❌ file-list 에 코드 본문 합치기 — *경로만*
- ❌ result 비어 있는데 *"리뷰 완료"* 보고
- ❌ result 파일 fake 생성 (codex 가 안 만들었으면 STOP)
- ❌ `-C <project>` 옵션 명시 (cwd 자동)
- ❌ run_in_background: true (동기 수신 필요)

## Failure Behavior

### exit 2 — Codex 로그인 필요 (워크플로우 중단)

호출자에 다음 보고:
```
🔓 Codex 로그인 필요

새 터미널 (cmd / PowerShell / Git Bash) 열고 `codex login` 실행 후 재시도하세요.
  - "완료" / "재시도" → 본 호출자 재실행
  - "취소" → 작업 종료
```

**fallback 절대 금지.** 사용자 로그인 완료까지 대기.

### exit 3 — Quota 소진 (Claude fallback)

호출자에 다음 보고:
```
⚠️ Codex quota 소진 → Claude fallback

- Code review 요청 → `code-reviewer` agent (Claude)로 재실행
- Plan critique 요청 → Claude self critique
```

워크플로우 안에서 호출된 경우 step5-review.md 의 *self-LGTM 강등* 룰 적용 (`LGTM:UNKNOWN`).

## 호출자별 어댑터

| 호출자 | 진입점 | 컨텍스트 |
|--------|--------|---------|
| `/harness-review` (slash) | 사용자 직접 호출 | adhoc, slug 자동 생성 |
| `harness-review` (skill) | 메인 Claude `Skill` 도구 | workflow 내부, slug 전달받음 |
| `codex-reviewer` (agent) | 메인 Claude `Task` 도구 | workflow 내부, prompt 에 slug + file-list 명세 |
| step5-review.md (workflow) | 메인 Claude inline 수행 | slug + Loop Counter + 자기 점검 + 결정 보고 |

위 어댑터들이 본 procedure 의 *4단계 흐름* 을 그대로 실행. 각 어댑터는 *컨텍스트* 만 다르고 *호출 절차* 는 동일.
