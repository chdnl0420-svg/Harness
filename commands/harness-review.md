---
description: Codex로 즉석 코드/문서 리뷰 (자연어로 파일·focus 자동 해석, 결과는 .harness/reviews/에 자동 저장)
argument-hint: '<자연어 + 파일경로...> [--paste] [--mode plan-critique]'
---

# Harness Review — Codex 즉석 리뷰

`$ARGUMENTS` 를 자연어로 받아서 파일 경로와 focus를 자동으로 분리하고, Codex CLI 에 보내 리뷰를 받습니다. 결과는 채팅에 verbatim 출력 + `.harness/reviews/adhoc-<timestamp>.md` 에 자동 저장됩니다.

---

## 절대 규칙

1. **명시적 호출만** — `$ARGUMENTS`가 비어있으면 사용법만 출력하고 **즉시 종료**. 자동 git diff 같은 추측 행동 금지.
2. **외부 호출 강제** — 반드시 `codex-review.sh` wrapper를 Bash로 실제 호출. 텍스트 시뮬레이션 금지.
3. **검증 게이트** — 호출 후 응답이 비어있으면 STOP, 사용자에게 보고.
4. **자동 저장** — 결과는 무조건 `.harness/reviews/adhoc-<YYYYMMDD-HHMMSS>.md` 로 저장 (사용자가 명시적 거부 안 하면).

---

## Step 1: 인자 처리

**Input**: `$ARGUMENTS`

### 1-A. 빈 인자 처리

`$ARGUMENTS` 가 비어있다면 (공백 포함, trim 후 빈 문자열):

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

### 1-B. 자연어 파싱 (Claude가 직접 수행)

빈 인자가 아니면:

1. `--paste` 플래그 추출 (있으면 사용자 paste 모드)
2. `--mode plan-critique` 플래그 추출 (있으면 mode=plan-critique, 기본 mode=code)
3. **나머지 자연어**에서 다음을 분리:
   - **파일 경로**: 실제로 존재하는 경로 식별 (Bash로 `[ -f <path> ]` 또는 `[ -d <path> ]` 확인)
   - **focus text**: 파일 경로가 아닌 나머지 자연어 — 사용자의 리뷰 의도/관심사

**파싱 규칙**:
- 토큰을 공백 단위로 자르되, 따옴표 있으면 묶음 유지
- 슬래시(`/`) 또는 점(`.`) 포함 + 실제 존재하는 토큰 → 파일 경로
- 한국어 조사(을/를/위주로/등) 무시하고 핵심 의도만 focus로 추출
- 콜론(`:`) 뒤는 보통 파일 경로 (예: `"이 두 파일 리뷰: foo.ts bar.ts"`)

**예시 파싱**:

| `$ARGUMENTS` | mode | focus | 파일 |
|--------------|------|-------|------|
| `src/auth.ts 보안 위주로` | code | "보안 위주로" | `src/auth.ts` |
| `이 두 파일 타입 안전성 평가: src/api.ts src/types.ts` | code | "타입 안전성 평가" | `src/api.ts`, `src/types.ts` |
| `--paste TypeScript 코드 리뷰` | code | "TypeScript 코드 리뷰" | (paste) |
| `--mode plan-critique docs/rfc.md 비판적으로` | plan-critique | "비판적으로" | `docs/rfc.md` |
| `README.md` | code | (없음, 기본 SYSTEM_PROMPT 사용) | `README.md` |

## Step 2: 리뷰 대상 콘텐츠 수집

### 2-A. 파일 경로가 있는 경우 (코드 본문 합치지 말 것)

🚨 **파일 본문을 prompt 에 합쳐 넣지 않는다.** Codex 가 자신의 file-read 도구로 직접 읽도록 **경로만** 명시한다. prompt 크기를 ~2KB 수준으로 유지해 ARG_MAX·context 부담을 줄인다.

목록 형식 (Step 3 의 `[Files to review]` 섹션에 그대로 들어감):

```
- <path1>
- <path2>
```

**경로 검증·정규화**:
- 각 경로에 대해 Bash `[ -f <path> ] || [ -d <path> ]` 로 존재만 확인. 본문 Read 금지.
- 경로는 호출 시점 `pwd` (= `$PROJECT_DIR`) 기준 **상대 경로** 로 통일. Codex 는 `-C $PROJECT` 로 실행되므로 그 디렉토리 기준으로 해석된다.
- 경로 개수 상한 20개. 초과 시 사용자 confirm.
- 존재하지 않는 경로가 하나라도 있으면 에러 보고 + 종료.
- 디렉토리 경로면 그 디렉토리 경로만 한 줄로 적는다 (codex 가 안의 파일을 알아서 탐색). 재귀 펼침 금지.

### 2-B. `--paste` 모드

`AskUserQuestion` 도구로 사용자에게 텍스트 입력 요청:
```
리뷰할 코드/텍스트를 입력해주세요.
```
사용자 응답을 그대로 콘텐츠로 사용.

### 2-C. 파일도 paste도 없는 경우

`$ARGUMENTS`에 자연어만 있고 파일/paste 둘 다 없으면:
```
❌ 리뷰 대상이 없습니다.

다음 중 하나가 필요합니다:
  - 파일 경로 (예: src/foo.ts)
  - --paste 플래그 (paste 입력 받기)

사용법: /harness-review <focus> <파일경로...>
```
→ 종료.

## Step 3: Prompt 빌드

파일 경로 모드 (Step 2-A) 인 경우:

```
[Reviewer focus]
<focus text — 비어있으면 이 섹션 생략>

[Files to review]
- <path1>
- <path2>

[Instructions]
위 경로의 파일을 당신의 file-read 도구로 직접 읽어 검토하세요. 본문은 이 prompt 에 포함돼 있지 않습니다. 경로는 프로젝트 루트 기준 상대 경로입니다.
```

paste 모드 (Step 2-B) 인 경우 — 본문이 실제로 필요하므로 그대로 포함:

```
[Reviewer focus]
<focus text — 비어있으면 이 섹션 생략>

[Pasted content]
<paste 본문>
```

plan-critique 모드 — 검토 대상이 plan md 파일이면 2-A 처럼 경로만, 사용자가 plan 본문을 직접 paste 했으면 2-B 처럼 본문 포함.

focus 가 비어있으면 wrapper 의 기본 SYSTEM_PROMPT 가 알아서 동작.

## Step 4: Codex 호출 (Bash 실제 실행 필수)

🚨 **반드시 `--prompt-file` 사용**. `$REVIEW_PROMPT` 를 인자로 직접 넘기면 큰 파일/다중 파일에서
"Argument list too long" (ARG_MAX) 실패. Step 3 에서 빌드한 prompt 를 임시 파일에 먼저 저장.

```bash
# 1) prompt 파일 저장 (Write 도구로)
#    경로: .harness/reviews/_adhoc-<TS>-input.txt
#    내용: Step 3 에서 빌드한 $REVIEW_PROMPT 전체

# 2) wrapper 호출 (forward slash 통일)
SKILL_WIN="$(cmd.exe /c echo %USERPROFILE% 2>/dev/null | tr -d '\r')\\.claude\\skills\\harness"
PROJECT_WIN="$(pwd -W 2>/dev/null || pwd)"
PROMPT_FILE_WIN="$PROJECT_WIN/.harness/reviews/_adhoc-<TS>-input.txt"

wsl -e bash -lc '
    PROJECT_WSL=$(wslpath -u "$1")
    SKILL_WSL=$(wslpath -u "$2" 2>/dev/null || echo "$HOME/.claude/skills/harness")
    PROMPT_WSL=$(wslpath -u "$3")
    if [ -f "$PROJECT_WSL/.harness/wrappers/codex-review.sh" ]; then
        bash "$PROJECT_WSL/.harness/wrappers/codex-review.sh" --mode "'"$MODE"'" --prompt-file "$PROMPT_WSL"
    elif [ -f "$SKILL_WSL/wrappers/codex-review.sh" ]; then
        bash "$SKILL_WSL/wrappers/codex-review.sh" --mode "'"$MODE"'" --prompt-file "$PROMPT_WSL"
    else
        bash "$HOME/.claude/skills/harness/wrappers/codex-review.sh" --mode "'"$MODE"'" --prompt-file "$PROMPT_WSL"
    fi
' _ "$PROJECT_WIN" "$SKILL_WIN" "$PROMPT_FILE_WIN"
```

**MODE**: `code` (기본) 또는 `plan-critique`.

**run_in_background 금지** — 결과 동기 수신 필요.

❌ **금지 패턴**: `--mode code "$REVIEW_PROMPT"` (인자 직접). ARG_MAX 한계 (~128KB) 로 큰 리뷰에서 거의 항상 실패.

## Step 5: Exit Code 처리

| Exit | 행동 |
|------|------|
| 0 | 응답 verbatim 출력 + 자동 저장 (Step 6) |
| 2 | **워크플로우 중단**: wrapper가 로그인 창 띄움. 사용자에게 "로그인 완료 후 재시도" 안내. fallback 금지. |
| 3 | **Codex quota 소진** → Claude `code-reviewer` agent (Task 도구)로 fallback. 결과 저장 (review_method: claude) |
| 기타 | 에러 보고. 저장 안 함. |

## Step 6: 자동 저장

응답 받으면 무조건 저장 (Step 5 exit 0/3 둘 다):

1. 디렉토리 보장:
   ```bash
   mkdir -p .harness/reviews
   ```
2. 파일명: `.harness/reviews/adhoc-<YYYYMMDD-HHMMSS>.md`
3. 내용 (Write 도구로):
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

저장 후 사용자에게:
```
✅ 리뷰 저장: .harness/reviews/adhoc-<ts>.md
```

## Step 7: 검증 게이트

- 저장된 파일을 `Read` 로 한 번 더 읽어 응답 내용이 실제 들어갔는지 확인
- 비어있으면 STOP, "외부 호출 실패 가능성" 보고 (절대 fake 응답 만들지 말 것)

---

## Anti-patterns (금지)

- ❌ `$ARGUMENTS` 비었는데 git diff로 자동 진행
- ❌ Codex 호출 없이 Claude 가 직접 리뷰 텍스트 작성 (Step 5에서 exit 3 (quota 소진) fallback 인 경우 외)
- ❌ 응답 패러프레이즈 — verbatim 보존
- ❌ 저장 skip — 무조건 `.harness/reviews/adhoc-*.md`
- ❌ `run_in_background: true` — 동기 수신 필요

---

## 예시 출력 (사용자 시점)

```
$ /harness-review src/auth.ts 보안 위주로

[Codex 응답 verbatim, 30초~]

✅ 리뷰 저장: .harness/reviews/adhoc-20260513-160305.md
```
