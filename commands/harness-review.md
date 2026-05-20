---
description: Codex로 즉석 코드/문서 리뷰 (자연어로 파일·focus 자동 해석, 결과는 .harness/reviews/ 에 자동 저장)
argument-hint: '<자연어 + 파일경로...> [--paste] [--mode plan-critique]'
---

# Harness Review — Codex 즉석 리뷰

`$ARGUMENTS` 를 자연어로 받아 파일 경로와 focus 를 분리하고, **`codex exec` 를 직접 호출**해 리뷰를 받습니다. 결과는 채팅에 verbatim 출력 + `.harness/reviews/adhoc-<timestamp>.md` 에 자동 저장됩니다.

> **2026-05-20 단순화**: WSL · tmux · wt.exe · `wrappers/codex-review.sh` 모두 폐기. 본 명령은 Bash 에서 `codex` (npm-installed, Windows native) 를 직접 호출합니다. 자세히: [`agents/codex-reviewer.md`](~/.claude/skills/harness/skills/harness/agents/codex-reviewer.md).

---

## 절대 규칙

1. **명시적 호출만** — `$ARGUMENTS` 가 비어있으면 사용법만 출력하고 **즉시 종료**. 자동 git diff 같은 추측 행동 금지.
2. **외부 호출 강제** — 반드시 `codex exec` 를 Bash 로 실제 호출. 텍스트 시뮬레이션 금지.
3. **단일 짧은 프롬프트** — `codex-reviewer.md` 의 4단계 흐름과 동일. file-list MD 작성 → 한 줄 프롬프트로 codex exec 호출 → result MD 확인.
4. **검증 게이트** — 호출 후 result 파일이 비어있으면 STOP, 사용자에게 보고.
5. **자동 저장** — 무조건 `.harness/reviews/adhoc-<YYYYMMDD-HHMMSS>.md` 로 저장.

---

## Step 1: 인자 처리

**Input**: `$ARGUMENTS`

### 1-A. 빈 인자 처리

`$ARGUMENTS` 가 비어있다면:

```
사용법: /harness-review <자연어로 무엇을 어떻게 리뷰할지>

예시:
  /harness-review src/auth.ts 보안 위주로
  /harness-review 이 두 파일 타입 안전성 평가: src/api.ts src/types.ts
  /harness-review --paste TypeScript 코드 한 덩어리 리뷰해줘
  /harness-review --mode plan-critique 이 RFC 문서 비판적으로: docs/rfc-001.md

옵션:
  --paste              현재 채팅창에 paste한 텍스트를 리뷰 (파일 경로 대신)
  --mode plan-critique 코드가 아닌 계획서/문서를 plan-critic 모드로 리뷰
                       (생략 시 코드 리뷰 모드)
```

→ 출력 후 종료. 다른 동작 하지 말 것.

### 1-B. 자연어 파싱 (Claude 가 직접 수행)

1. `--paste` 플래그 추출 (있으면 사용자 paste 모드)
2. `--mode plan-critique` 플래그 추출 (있으면 mode=plan-critique, 기본 mode=code)
3. **나머지 자연어**에서:
   - **파일 경로**: 실제로 존재하는 경로 식별 (Bash `[ -f <path> ] || [ -d <path> ]` 로 검증)
   - **focus text**: 파일 경로가 아닌 나머지 자연어 — 사용자의 리뷰 의도

**파싱 규칙**:
- 토큰을 공백 단위로 자르되, 따옴표 묶음 유지
- 슬래시(`/`) 또는 점(`.`) 포함 + 실제 존재하는 토큰 → 파일 경로
- 한국어 조사(을/를/위주로 등) 무시, 핵심 의도만 focus 로 추출
- 콜론(`:`) 뒤는 보통 파일 경로

**예시 파싱**:

| `$ARGUMENTS` | mode | focus | 파일 |
|--------------|------|-------|------|
| `src/auth.ts 보안 위주로` | code | "보안 위주로" | `src/auth.ts` |
| `--paste TypeScript 코드 리뷰` | code | "TypeScript 코드 리뷰" | (paste) |
| `--mode plan-critique docs/rfc.md 비판적으로` | plan-critique | "비판적으로" | `docs/rfc.md` |

## Step 2: timestamp + slug 결정

```bash
TS=$(date +%Y%m%d-%H%M%S)
SLUG="adhoc-$TS"
```

## Step 3: file-list 작성 (`Write` 도구)

🚨 **파일 본문을 prompt 에 합쳐 넣지 않는다.** Codex 가 자기 file-read 도구로 직접 읽도록 **경로만** 명시.

`<project>/.harness/reviews/review-<slug>-file-list.md` 에 *경로 목록만* 작성:

```markdown
- src/auth.ts
- src/api.ts
```

**경로 검증·정규화**:
- Bash `[ -f <path> ] || [ -d <path> ]` 로 존재 확인
- 호출 시점 `pwd` (= 프로젝트 루트) 기준 **상대 경로**
- 경로 개수 상한 20개. 초과 시 사용자 confirm
- 존재하지 않는 경로 발견 → 에러 보고 + 종료
- 디렉토리면 그 한 줄만 (재귀 펼침 금지)

`--paste` 모드면 file-list 대신 paste 본문을 `<project>/.harness/reviews/review-<slug>-pasted.md` 에 그대로 저장.

## Step 4: codex exec 호출 (Bash 직접 실행)

```bash
mkdir -p .harness/reviews

# Mode A (code review) — file-list 사용
codex exec --sandbox workspace-write \
  ".harness/reviews/review-<slug>-file-list.md 에 적힌 파일들 전부 리뷰해줘. 리뷰 결과는 .harness/reviews/codex-review-<slug>-result.md 에 작성해줘."

# Mode B (plan critique) — plan 문서 파일 경로를 file-list 에 넣음. 프롬프트는 동일.
# Paste mode — file-list 대신 pasted.md 를 참조하도록 file-list 한 줄로 그 파일만:
#   - .harness/reviews/review-<slug>-pasted.md
```

**위 한 줄 프롬프트 외 추가 텍스트 절대 금지.** focus / mode / system instruction / output format 지시 모두 안 적음. Codex 가 file-list 보고 자체 형식으로 result.md 에 작성.

**Mode A vs Mode B 차이 = file-list 에 적힌 *파일 종류* 만**:
- Mode A: 코드 파일들 (`src/*.ts`, `lib/*.go` 등)
- Mode B: plan 문서 (`docs/rfc.md`, `.harness/domain-<slug>.html` 등)

호출 명령·프롬프트는 동일.

**run_in_background 금지** — 결과 동기 수신 필요.

## Step 5: Exit Code 처리

| Exit | 행동 |
|------|------|
| 0 | result 파일 Read → 본문 verbatim 출력 + 자동 저장 (Step 6) |
| 2 | **워크플로우 중단**: Codex 로그인 필요. 사용자에게 "터미널에서 `codex login` 실행 후 재시도" 안내. fallback 금지. |
| 3 | **Codex quota 소진** → `code-review` skill 또는 Claude `code-reviewer` agent 로 fallback. result 저장 (review_method: claude) |
| 기타 | 에러 보고. 저장 안 함. |

## Step 6: 자동 저장

응답 받으면 무조건 저장 (Step 5 exit 0/3 둘 다):

1. 파일명: `.harness/reviews/adhoc-<YYYYMMDD-HHMMSS>.md`
2. 내용 (Write 도구로):

```markdown
---
type: adhoc-review
created: <ISO timestamp>
mode: <code | plan-critique>
review_method: <codex | claude>
focus: "<focus text or 'none'>"
targets: ["<path1>", "<path2>"]   # 또는 ["(paste)"]
---

# Adhoc Review

## Focus
<focus text or "(none)">

## Targets
- <path1>
- <path2>

## Review (Codex/Claude verbatim)

<Codex 응답 그대로>
```

저장 후:
```
✅ 리뷰 저장: .harness/reviews/adhoc-<ts>.md
```

## Step 7: 검증 게이트

- 저장된 파일을 `Read` 로 다시 읽어 응답 내용이 실제 들어갔는지 확인
- 비어있으면 STOP, "외부 호출 실패 가능성" 보고 (절대 fake 응답 만들지 말 것)

---

## Anti-patterns (금지)

- ❌ `$ARGUMENTS` 비었는데 git diff 로 자동 진행
- ❌ Codex 호출 없이 Claude 가 직접 리뷰 텍스트 작성 (Step 5 exit 3 fallback 제외)
- ❌ 응답 패러프레이즈 — verbatim 보존
- ❌ 저장 skip
- ❌ `run_in_background: true` — 동기 수신 필요
- ❌ `wrappers/codex-review.sh` 호출 (2026-05-20 폐기)
- ❌ `wsl -e bash -c "codex ..."` wrapping
- ❌ `tmux` / `wt.exe` / sentinel polling 같은 인터랙티브 흐름
- ❌ file-list 에 코드 본문 합치기 — *경로만*

---

## 예시 출력 (사용자 시점)

```
$ /harness-review src/auth.ts 보안 위주로

[Codex 응답 verbatim, 30초~]

✅ 리뷰 저장: .harness/reviews/adhoc-20260520-200305.md
```
