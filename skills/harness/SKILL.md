---
name: harness
description: Iterative multi-LLM development workflow with persistent MD artifacts. Plan (with Codex critique) → Research (Gemini on-demand) → Implement → Review (Codex primary, Claude fallback) → Fix → Re-review → Complete. All artifacts saved to <project>/.harness/ for audit and resume. ONLY runs when explicitly invoked via /harness slash command.
---

# Harness: Iterative Multi-LLM Workflow

## 🚨 ABSOLUTE RULES — READ FIRST 🚨

**This skill REQUIRES actual external tool execution. Text-only simulation is FORBIDDEN.**

1. **Codex critique (Phase 1.2)** — MUST execute `codex-review.sh` via Bash. Cannot write fake critique text. Cannot skip.
2. **Code review (Phase 4)** — MUST execute `codex-review.sh` via Bash for each iteration.
3. **Research (any phase)** — MUST execute `gemini-research.sh` when external info is needed.
4. **Validation gate** — After each external call, READ the saved file to confirm content exists. If empty/missing, the call did NOT happen — retry or report failure.

**If you cannot execute Bash (e.g., sandboxed), STOP and report. Do NOT fabricate results.**

---

## 🪟 Interactive Command Policy (필수)

**sudo·비밀번호·OAuth 로그인 등 사용자 입력이 필요한 명령은 inline Bash 도구로 실행 금지.**
Bash 도구는 stdin 입력 불가 → 좀비 프로세스 됨.

**필수 패턴**: `core/run-interactive.sh` 헬퍼로 wt.exe 별창 실행.

```bash
bash "$HOME/.claude/skills/harness/core/run-interactive.sh" "<title>" "<command>"
# 예: "🔓 codex login" "codex login"
# 예: "📦 apt install" "sudo apt update && sudo apt install -y unzip"
```

→ 사용자가 별창에서 직접 입력. Claude는 다음 단계로 진행하기 전에 사용자에게 "완료/취소" 확인.

상세: `/harness-setup` 명령 문서의 "Interactive Command Policy" 섹션 참조.

---

## 🚨 Environment — Windows + WSL (CRITICAL)

**가정**: Claude Code Bash 도구 (Windows에서는 Git Bash) 환경. PowerShell에서 직접 실행은 별도 지원 필요.

### 아키텍처: 마스터 + 프로젝트 복제

- **마스터** (skill 폴더 안): `~/.claude/skills/harness/{wrappers,core}/` — source of truth, 배포 단위
- **프로젝트 실행본**: `<PROJECT>/.harness/{wrappers,core}/` — 첫 사용 시 마스터에서 부트스트랩, 이후 이쪽 .sh로 실행

### 올바른 wrapper 호출 패턴 (프로젝트 상대)

```bash
# Step 0 부트스트랩 이후 모든 호출은 프로젝트 상대 경로
PROJECT_WIN="$(pwd -W 2>/dev/null || pwd)"
wsl -e bash -lc '
  PROJECT_WSL=$(wslpath -u "$1")
  bash "$PROJECT_WSL/.harness/wrappers/codex-review.sh" --mode plan-critique "$2"
' _ "$PROJECT_WIN" "$PROMPT"
```

❌ **절대 사용 금지**:
```bash
bash ~/.harness/wrappers/codex-review.sh ...   # Git Bash가 ~ 잘못 해석
/home/<user>/.harness/...                       # 사용자명/경로 하드코딩
wsl -e bash -d Ubuntu-24.04 ...                 # distro 이름 하드코딩
```

---

## When This Skill Runs

**ONLY** when user types:
- `/harness <자연어 요청>` — 새 워크플로우 시작
- `/harness resume [request_id]` — 중단된 작업 재개
- `/harness status` — 진행 중 작업 목록
- `/harness list` — 모든 작업 목록

DO NOT auto-invoke based on keywords.

---

## Architecture

```
사용자: /harness X 구현
    ↓
Step 0: Initialize
Phase 1: Plan (6 sub-phases) — Codex critique MANDATORY
Phase 2: Research (선택)
Phase 3: Implement
Phase 4: Review Loop (max 3 iter) — Codex review MANDATORY
Phase 5: Complete
```

All artifacts: `<PROJECT_ROOT>/.harness/{plans,progress,research,reviews,improvements,results}/`

Templates: `~/.claude/skills/harness/templates/`

---

## Step 0: Initialize

1. **PROJECT_ROOT**: `pwd` (or PowerShell `(Get-Location).Path`)
2. **REQUEST_ID**: `<YYYYMMDD>-<HHMMSS>-<slug>` (slug max 30 chars, lowercase, hyphen)
3. **🩺 Prereq 검진 (필수, 한 번만)** — `~/.harness/.doctor-passed` 마커가 없으면 doctor 실행:
   ```bash
   SKILL_WIN="$(cmd.exe /c echo %USERPROFILE% 2>/dev/null | tr -d '\r')\\.claude\\skills\\harness"
   wsl -e bash -lc '
     SKILL_WSL=$(wslpath -u "$1")
     if [ ! -f "$HOME/.harness/.doctor-passed" ]; then
       bash "$SKILL_WSL/core/harness-doctor.sh" --quiet
     fi
   ' _ "$SKILL_WIN"
   ```

   **Exit code 분기 (절대):**
   - `0` → 모든 prereq 충족, 다음 단계 진행
   - `1` → **워크플로우 즉시 중단**. 사용자에게 다음 메시지 출력 후 종료:
     ```
     🩺 Harness 의존성 누락 감지

     실행: /harness-setup
       (검진 + npm 패키지 자동 설치를 한 번에 수행)

     자동 처리 불가 항목(인증/API key 등)은 화면 안내에 따라 직접 처리 후
     워크플로우 재시도.
     ```
   - `2` → **워크플로우 즉시 중단**. 환경 자체 부적합 (WSL 아님 등).

   **이 단계 통과 없이 절대 Bootstrap/Phase 1 진행 금지.**
   재검진 강제: `rm ~/.harness/.doctor-passed` 후 재호출.

4. **Bootstrap (한 줄 호출)** — `.harness/{plans,...,wrappers,core}` 생성 + 마스터에서 wrappers/core 복사 + CRLF/+x 보정 + stale 알림:
   ```bash
   SKILL_WIN="$(cmd.exe /c echo %USERPROFILE% 2>/dev/null | tr -d '\r')\\.claude\\skills\\harness"
   PROJECT_WIN="$(pwd -W 2>/dev/null || pwd)"
   wsl -e bash -lc '
     SKILL_WSL=$(wslpath -u "$1")
     PROJECT_WSL=$(wslpath -u "$2")
     bash "$SKILL_WSL/core/bootstrap-runtime.sh" "$PROJECT_WSL"
   ' _ "$SKILL_WIN" "$PROJECT_WIN"
   ```
5. **🔍 Drift 검사 (마스터 ↔ 프로젝트 .sh 동기화)** — 매 호출마다 자동:

   ### 5.1. Skip 조건 (있으면 검사 건너뜀, exit code 처리 없이 다음 단계로)
   - `HARNESS_SKIP_DRIFT_CHECK=1` 환경변수
   - `~/.harness/.skip-drift-check` 파일 존재 (사용자가 영구 비활성)
   - `<PROJECT>/.harness/.skip-drift-this-task` 파일 존재 — **사용 후 즉시 삭제** (one-shot)

   ### 5.2. 검사 실행
   ```bash
   wsl -e bash -lc '
     SKILL_WSL=$(wslpath -u "$1")
     PROJECT_WSL=$(wslpath -u "$2")
     bash "$SKILL_WSL/core/check-drift.sh" "$PROJECT_WSL" --json
   ' _ "$SKILL_WIN" "$PROJECT_WIN"
   ```

   ### 5.3. Exit code 분기
   - `0` → drift 없음, 조용히 다음 단계
   - `10` → drift 있음, JSON 응답 파싱 (예: `{"drift_count":2,"files":[{"file":"wrappers/codex-review.sh","status":"modified"},...]}`)
   - 기타 → 에러 보고 + skip (워크플로우 계속)

   ### 5.4. drift 있을 때 (`AskUserQuestion` 도구 호출)

   Claude는 사용자에게 4지선다 prompt:
   ```
   질문: "{drift_count}건의 .sh 파일이 마스터와 다릅니다:
           - {file1} ({status1})
           - {file2} ({status2})
           ...
           어떻게 처리할까요?"

   옵션:
   [A] 마스터로 최신화 (백업 후 덮어쓰기)        ← 권장
   [B] 이번 task만 skip (다음 호출 시 다시 물음)
   [C] 영구 무시 (~/.harness/.skip-drift-check)
   [D] 작업 취소
   ```

   응답 처리:
   - **A**: `sync-from-master.sh` 호출 →
     ```bash
     wsl -e bash -lc '
       SKILL_WSL=$(wslpath -u "$1")
       PROJECT_WSL=$(wslpath -u "$2")
       bash "$SKILL_WSL/core/sync-from-master.sh" "$PROJECT_WSL"
     ' _ "$SKILL_WIN" "$PROJECT_WIN"
     ```
     성공 시 다음 단계 진행. 실패 시 사용자에게 보고 후 결정 받음.
   - **B**: `<PROJECT>/.harness/.skip-drift-this-task` 마커 생성 → 다음 단계 진행
   - **C**: `~/.harness/.skip-drift-check` 마커 생성 → 다음 단계 진행
   - **D**: `status: rejected`, END

6. **.gitignore 안내** (첫 생성 시, 강제 X):
   - repo 공유: `.harness/wrappers/`, `.harness/core/` ignore 권장 (각자 bootstrap)
   - full archive 공유: 포함해도 OK (bootstrap이 CRLF/+x 보정)
   - 항상: `.harness/plans/`, `.harness/progress/`, `.harness/backups/`, `.harness/.skip-drift-this-task` 등 ignore 권장

### `/harness sync` (선택 명령)

마스터 wrapper가 업데이트되었을 때 프로젝트 복제본 갱신:
```bash
wsl -e bash -lc '
  SKILL_WSL=$(wslpath -u "$1")
  PROJECT_WSL=$(wslpath -u "$2")
  bash "$SKILL_WSL/core/bootstrap-runtime.sh" "$PROJECT_WSL" --force
' _ "$SKILL_WIN" "$PROJECT_WIN"
```
기존 파일은 `.bak-YYYYMMDD-HHMMSS` 로 백업 후 덮어쓰기.

---

## Phase 1: Plan (6 Sub-Phases)

### Phase 1.0: Initial Draft

1. 요청 분석 → phase 분해
2. **Write 도구로** `<PROJECT_ROOT>/.harness/plans/plan-<id>.md` v1 작성
3. 작성 중 외부 정보 필요 시 → Gemini Research 호출 (아래 참고)
4. frontmatter `status: self-review` → Phase 1.1

### Phase 1.1: Self-Review (10-point)

체크리스트 평가 → plan.md의 "Self-Review Result" 섹션에 저장.

분기:
- ❌ 1+ → Phase 1.4 (auto-revision)
- ⚠️ 만 → Phase 1.2 진행
- 모두 ✅ → Phase 1.2

### Phase 1.2: Codex Critique — 🚨 MANDATORY EXECUTION 🚨

**이 단계는 절대 텍스트로 시뮬레이션 금지. 실제 Bash 호출 필수.**

> 💡 **실시간 가시화 (Option B — 별창 미러)**: wrapper가 자동으로 새 **Windows Terminal 창**을 띄워 거기서 Codex/Gemini를 실행합니다. 사용자는 그 창에서 reasoning, tool 사용, 응답을 줄 단위로 봅니다. 부모(Claude)는 done flag로 동기 대기 후 결과 받음 — 워크플로우는 그대로.
>
> 환경:
> - `wt.exe` 없으면 자동으로 인라인 모드 fallback.
> - 비활성화: `HARNESS_NO_VISIBLE=1` 환경변수.
> - 타임아웃: `HARNESS_WAIT_LIMIT=600` (초, 기본 600).
> - 작업 완료 후 별창 3초 뒤 자동 닫힘.

#### Step 1: plan.md 내용 읽기

```
Read tool: <PROJECT_ROOT>/.harness/plans/plan-<id>.md
```

#### Step 2: Bash 도구로 Codex critique 실행 (필수)

**환경별 올바른 호출 (Step 0에서 PROJECT_WIN 변수 이미 정의됨)**:

```bash
PLAN_CONTENT=$(cat <PROJECT_ROOT>/.harness/plans/plan-<id>.md)
wsl -e bash -lc '
  PROJECT_WSL=$(wslpath -u "$1")
  bash "$PROJECT_WSL/.harness/wrappers/codex-review.sh" --mode plan-critique "$2"
' _ "$PROJECT_WIN" "$PLAN_CONTENT"
```

**⚠️ background 실행 금지** — 결과를 동기적으로 받아야 검증 가능. `run_in_background: true` 사용 금지.

#### Step 3: Exit code 분기 (정책 명확)

| exit | 의미 | 행동 |
|------|------|------|
| **0** | 정상 critique | plan.md "External Critique" 섹션에 verbatim 저장 + `critique_method: codex` |
| **2** | **인증 실패 (로그인 필요)** | **워크플로우 즉시 중단** — wrapper가 로그인 창 띄움. 사용자 로그인 완료 대기 |
| **3** | **Quota 소진 (로그인 됐으나 사용 불가)** | **Claude 자체 critique로 fallback** — `critique_method: claude-self` |
| **4** | **Codex CLI 내부 subprocess 에러** (codex_core::tools::router stdin closed) | **Claude 자체 critique로 fallback** — `critique_method: claude-self-codex-internal-error`. 사용자에게 원인 보고 + `npm i -g @openai/codex@latest` 업데이트 권장 안내 |
| 기타 | 일반 오류 | 사용자에게 에러 보고 + 결정 요청 |

**exit 2 처리 (절대 fallback 금지, 무조건 중단):**
```
🔓 Codex 로그인 필요 — 새 터미널 창에서 'codex login' 진행 중

작업 진행 불가. 로그인 완료 후 메인 채팅에 입력:
  - "완료" / "재시도" → Phase 1.2 재실행
  - "취소" → 작업 종료
```
사용자 "완료"까지 **다음 phase로 절대 진행 금지**. Gemini fallback도 금지 (Gemini도 로그인 필요할 수 있으므로 같은 규칙).

**exit 3 처리 (Claude fallback):**
- 사용자에게 "⚠️ Codex quota 소진 — Claude로 자체 critique 진행" 알림
- Claude가 직접 plan을 비판적으로 검토 (자기 자신과 다른 관점으로):
  - Missing Pieces, Hidden Risks, Better Approaches, Scope Issues, Critical Issues 항목 채움
  - plan.md "External Critique" 섹션에 저장. `critique_method: claude-self`
- **주의**: claude-self는 self-review와 별개 단계로 명확히 표기

**exit 4 처리 (Codex CLI 내부 에러 → Claude fallback):**
- 사용자에게 보고:
  ```
  ⚠️ Codex CLI 내부 subprocess 에러 감지 (codex_core::tools::router stdin 닫힘)
     — Codex 자체 버그, 큰 repo + 다중 rg/find subprocess 환경에서 가끔 발생
     — 권장: npm i -g @openai/codex@latest 로 업데이트 확인
     — 이번 task 는 Claude self critique 로 fallback
  ```
- exit 3과 동일하게 Claude self critique 진행, `critique_method: claude-self-codex-internal-error`
- result.md 작성 시 `codex_internal_error: true` 메타 기록 (audit trail)

#### Step 4: Gemini Fallback (선택, exit 3에서만)

Codex가 quota out(exit 3)인 경우 **사용자 선택**:
- (a) Claude self critique 사용 (기본)
- (b) Gemini로 critique 시도:
  ```bash
  wsl -e bash -lc '
    PROJECT_WSL=$(wslpath -u "$1")
    bash "$PROJECT_WSL/.harness/wrappers/gemini-research.sh" --mode plan-critique "$2"
  ' _ "$PROJECT_WIN" "$(cat <PROJECT_ROOT>/.harness/plans/plan-<id>.md)"
  ```
  - Gemini exit 0 → `critique_method: gemini`
  - Gemini exit 2 → **중단** (Gemini 로그인 필요, 사용자 결정)
  - Gemini exit 3 → Claude self로 자동 회귀

#### Step 5: 🚨 검증 게이트 (필수)

Phase 1.3 진행 전에:

```
Read tool: <PROJECT_ROOT>/.harness/plans/plan-<id>.md
```

다음 확인:
- "External Critique" 섹션이 비어있지 않은지
- "critique_method" frontmatter가 설정됐는지

**만약 비어있다면** = Codex/Gemini 호출이 실제로 안 일어남.
- 사용자에게 보고: "외부 critique 누락 감지 — 다시 실행하거나 self-only로 진행할까요?"
- 절대 텍스트로 critique를 만들어내지 마세요.

### Phase 1.3: User Approval

사용자에게 plan + self-review + critique 결과 요약 제시:

```markdown
📋 Plan v<N> 준비됨 — <REQUEST_ID>

✅ Self-Review: <X>/10
🔍 External Critique: <codex/gemini/self-only>
  - LGTM: <YES/NO>
  - Missing/Risks/Critical: <counts>

## Plan 요약
<key phases/risks/criteria>

선택: 진행 / 수정: <피드백> / 다시 / 취소
```

#### 🚨 응답 분류 게이트 (필수 — 임의 해석 금지)

`AskUserQuestion` 또는 자유 입력으로 사용자 응답을 받으면, **분기 결정 전에 반드시 다음 3분류 수행**:

| 분류 | 정의 | 처리 |
|------|------|------|
| **(a) 명시 선택** | 제시한 선택지 라벨과 완전 매칭 (예: "진행", "취소", "γ: Live Activity + APNs 풀스택") | 그대로 진행 분기 |
| **(b) 자유 텍스트 — 명확한 결정/지시** | 명령형 / 결정 표현. 예: "γ로 가자", "수정: X 반영해줘", "다시 작성" | 진행 분기 |
| **(c) 자유 텍스트 — 질문/되묻기/모호** | 의문문, 단순 키워드, 설명 요청, 부정확한 매칭. 예: "왜?", "그게 뭐야?", "더 설명해줘", "Suspended가 뭔데?" | **임의 해석 절대 금지 — 답변 후 다시 묻기** |

**규칙**:
1. **분류가 애매하면 무조건 (c)로 처리**. 추론으로 (a)/(b) 채우는 것 금지.
2. **(c) 처리 절차**:
   - 사용자 질문에 텍스트로 답변/설명만 제공
   - **plan.md / progress.md 절대 수정 금지**
   - Phase 1.4 / 1.5 / 다음 phase 절대 진행 금지
   - 같은 또는 보강된 `AskUserQuestion`을 다시 호출 (사용자가 이제 결정 가능한 상태로)
3. **Multi-question 처리**: 여러 질문 중 일부만 (a)/(b)고 나머지가 (c)면 → **전부 보류**. 부분 진행 금지. 답변 후 미답변 항목만 재질문해도 OK.
4. **재질문 무한 루프 방지**: 동일 질문에 두 번째도 (c) 응답 시, "Other 자유 입력" 옵션 명시 또는 선택지 다시 풀어 설명. 단 진행은 여전히 금지.
5. **anti-hallucination 자기 점검**: 응답 처리 직전 자체 확인 — "사용자가 명시적으로 선택/지시했나? 내가 추론으로 채우려 하나? 의문문/되묻기면 STOP."

#### 응답 분기 (분류 게이트 통과 후만 적용)

- 진행 (a/b) → Phase 1.5
- 수정 + 구체적 피드백 (b) → Phase 1.4
- 다시 (a/b) → Phase 1.0 (revision_count 유지)
- 취소 (a/b) → status=rejected, END
- **(c) 분류 응답 → 위 분기 어디에도 진행 금지. 답변 후 재질문.**

### Phase 1.4: Revision (loop, max 3)

1. 반영 대상: Self-Review fail + critique 지적 + 사용자 피드백
2. plan.md에 new Version History entry 추가
3. Active Plan 섹션을 v<N+1>로 update (Edit 도구)
4. frontmatter `version: N+1`, `revision_count: ++`
5. Phase 1.1로 loop

**HARD LIMIT** revision_count > 3:
```
⚠️ 3회 revision 후에도 합의 미달성
옵션: (a) v<latest> 진행  (b) 취소  (c) harness 종료, 직접 진행
```

### Phase 1.5: Finalize

1. plan.md frontmatter `status: approved` + Approval 섹션 채움 (Edit)
2. **Write 도구로** progress-<id>.md 초기화 (`templates/progress.md` 기반)
3. Phase 2 또는 Phase 3로 진행

---

## Phase 2: Research (조건부, 사전 큰 조사)

큰 구조적 사전 조사 필요 시:
- 라이브러리 선정 (3+ 비교)
- 아키텍처 패턴 결정
- 보안/규제 표준

방법: 아래 "Gemini On-Demand"와 동일.

---

## Phase 3: Implement

1. progress.md 갱신: `current_phase: 3`
2. Edit/Write로 직접 구현
3. **막힐 때마다 Gemini Research 호출** (자유롭게)
4. 변경 후 progress.md `files_created`/`files_modified` 갱신
5. plan.md Phase 3 체크리스트 체크
6. → Phase 4

---

## Phase 4: Review Loop — 🚨 MANDATORY EXECUTION 🚨

**이 단계도 텍스트 시뮬레이션 금지. 실제 codex-review.sh 호출 필수.**

```
ITER = 1
while ITER <= 3:
    Step 4.1: 변경 파일들의 diff 또는 내용 수집
    Step 4.2: Bash 실제 호출 (background 금지, 결과 동기 수신):
        wsl -e bash -lc '
          PROJECT_WSL=$(wslpath -u "$1")
          bash "$PROJECT_WSL/.harness/wrappers/codex-review.sh" --mode code "$2"
        ' _ "$PROJECT_WIN" "$DIFF_CONTENT"
    Step 4.3: Exit code 처리:
        - 0 → review-<id>-iter-<ITER>.md에 저장 (Write 도구), review_method: codex
        - 2 → **중단**. wrapper가 로그인 창 띄움. 사용자 로그인 완료까지 대기.
              "완료" 입력 후 Step 4.2 재시도. fallback 금지.
        - 3 → Claude code-reviewer agent로 fallback (Task 도구), review_method: claude
        - 4 → Codex CLI 내부 subprocess 에러. 사용자에게 원인 보고 + Codex CLI
              업데이트 권장. Claude code-reviewer agent로 fallback,
              review_method: claude-codex-internal-error
    Step 4.4: 🚨 검증 게이트: Read review-...iter-<ITER>.md 확인. 비어있으면 STOP.
    Step 4.5: LGTM 파싱:
        - YES → break (완료)
        - NO + CRITICAL/HIGH → improvement-<id>-iter-<ITER>.md 작성 → 수정 → ITER++
        - NO + MEDIUM/LOW만 → 사용자 결정
    Step 4.6: 리뷰가 "추가 리서치 필요" 지적 시 → Gemini Research 호출
```

3 iter 도달 → 강제 완료 + 잔여 보고.

---

## Phase 5: Complete

1. **Write 도구로** result-<id>.md 작성 (`templates/result.md`)
2. plan.md `status: completed` (Edit)
3. progress.md `status: completed` (Edit)
4. 사용자에게 최종 요약:
   ```
   ## ✅ <REQUEST_ID> 완료
   <summary, files, review rounds>
   📂 .harness/results/result-<id>.md
   ```

---

## Gemini On-Demand Research

**언제든 호출 가능** — Gemini OAuth는 무료.

### 자동 트리거 조건
- 라이브러리/도구 선택, 최신 best practice, API/syntax 불확실
- Codex critique "needs research" 명시
- 리뷰어 "확인 필요" 지적
- Plan 작성 중 외부 정보 필요

### 사용자 명시 트리거
- "조사" / "research" / "확인" 키워드

### 호출 절차 — 🚨 실제 Bash 호출 필수 🚨

1. **sequence 결정**: progress.md `research_count + 1`
2. **slug**: 주제 핵심 단어 (max 30자, lowercase, hyphen)
3. **Bash 실제 호출** (background 금지, 동기 수신):
   ```bash
   wsl -e bash -lc '
     PROJECT_WSL=$(wslpath -u "$1")
     bash "$PROJECT_WSL/.harness/wrappers/gemini-research.sh" --mode research "$2"
   ' _ "$PROJECT_WIN" "$TOPIC_PROMPT"
   ```
4. **Exit code 처리**:
   - 0 → Write 도구로 `<PROJECT_ROOT>/.harness/research/research-<id>-<seq>-<slug>.md` 저장 (templates/research.md 형식)
   - 2 → **중단**. wrapper가 로그인 창 띄움. 사용자 로그인 완료까지 대기. fallback 금지.
   - 3 → Claude self-knowledge로 리서치 진행 + "Claude knowledge (Gemini quota out)" 명시
5. **🚨 검증**: Read로 파일 확인. 비어있으면 STOP.
6. **progress.md** `research_count++` 업데이트 (Edit)
7. 참조 파일에 link 추가 (Edit)

### Anti-patterns
- ❌ 명백한 사실 리서치
- ❌ 같은 주제 중복 (먼저 `<PROJECT_ROOT>/.harness/research/` 스캔)
- ❌ "혹시 모르니까" 식 남발
- ❌ **결과 fabrication** — wrapper 호출 없이 텍스트로 "Gemini가 이렇게 말함" 만들기 절대 금지

---

## Resume Logic

`/harness resume [request_id]`:

1. `Glob: <PROJECT_ROOT>/.harness/progress/*.md`
2. frontmatter `status: in_progress` 필터
3. 지정 ID 또는 가장 최근
4. progress.md frontmatter 읽음 → `current_phase` / `current_iteration` 추출
5. 해당 지점부터 재개
6. 사용자에게 복원 보고

---

## Status / List Commands

### /harness status
in_progress 작업들 리스트.

### /harness list
모든 작업 (recent 20).

---

## File Naming

| 종류 | 패턴 |
|------|------|
| Plan | `plan-<REQUEST_ID>.md` |
| Progress | `progress-<REQUEST_ID>.md` |
| Research | `research-<REQUEST_ID>-<SEQ>-<SLUG>.md` |
| Review | `review-<REQUEST_ID>-iter-<N>.md` |
| Improvement | `improvement-<REQUEST_ID>-iter-<N>.md` |
| Result | `result-<REQUEST_ID>.md` |

REQUEST_ID: `YYYYMMDD-HHMMSS-<slug>`

---

## 🚨 Critical Rules (Re-emphasized) 🚨

1. **명시적 호출만** — `/harness` 슬래시 없이는 발동 X
2. **외부 도구 실행 강제** — Codex critique (Phase 1.2), Code review (Phase 4)는 반드시 Bash로 wrapper 실제 호출. **텍스트 시뮬레이션 금지**.
3. **검증 게이트** — 각 외부 호출 후 Read로 파일 존재 + 내용 확인. 없으면 호출 안 일어난 것.
4. **3 iteration hard limit** — Phase 1.4 revision, Phase 4 review 둘 다
5. **Codex 우선, fallback 자동** — code review와 plan critique 모두
6. **폴더 깔끔** — 모든 산출물 `.harness/` 하위
7. **Verbatim 보존** — Codex/Gemini 응답 패러프레이즈 금지
8. **Gemini 자유 호출** — 무료, 안 망설임
9. **사용자 승인 게이트** — Phase 1.3 통과 없이 Phase 2~5 진행 금지
10. **인증 vs Quota 구분 (핵심 정책)**:
    - **exit 2 (로그인 필요)** → 워크플로우 즉시 중단, auth-helper 창 띄움, 사용자 로그인 완료까지 대기. fallback 금지.
    - **exit 3 (Quota 소진)** → Claude로 fallback (Phase 4는 code-reviewer agent, Phase 1.2/Research는 Claude self).
11. **응답 임의 해석 금지** — `AskUserQuestion` 또는 자유 입력 응답이 (a) 명시 선택지 매칭 또는 (b) 명확한 결정/지시가 아니면, 절대 임의 해석으로 분기 진행 금지. 질문/되묻기/모호한 응답은 (c)로 분류, 답변/설명만 제공하고 다시 묻기. 부분 매칭이어도 미답변 항목까지 함께 보류. 상세는 Phase 1.3 "응답 분류 게이트" 참조.

---

## Failure Handling

| 실패 | Exit | 대응 |
|------|------|------|
| Codex/Gemini 로그인 안 됨 | 2 | **워크플로우 중단** + auth-helper 자동 창. 사용자 로그인 후 "완료" → 재시도. fallback 금지. |
| Codex quota 소진 (Phase 1.2) | 3 | Claude self critique로 진행, `critique_method: claude-self` |
| Codex quota 소진 (Phase 4) | 3 | Claude `code-reviewer` agent로 fallback, `review_method: claude` |
| Codex CLI 내부 에러 (subprocess stdin closed) | 4 | Claude self/`code-reviewer` fallback + 사용자에게 원인 보고. Codex 업데이트 권장 (`npm i -g @openai/codex@latest`). |
| Gemini quota 소진 (Research) | 3 | Claude self-knowledge로 진행, "Claude knowledge" 명시 |
| 3 revision 도달 | — | 사용자 결정 |
| 3 iter 도달 | — | 강제 완료 + 잔여 보고 |
| Bash 실행 자체 실패 | — | STOP, 사용자에게 환경 점검 요청 (절대 fabricate 금지) |

---

## Cost Awareness

- Gemini Research: 무료 (OAuth)
- Codex: ChatGPT Plus 또는 API
- Claude: subscription
- result.md에 호출 횟수 audit

---

## Anti-Hallucination Checks (Self-Verify)

작업 진행 중 다음 자체 점검:

- Phase 1.2 시작 시: "지금 codex-review.sh를 Bash로 호출할 준비됐나? 텍스트로 critique 만들려 하나?"
  - 후자라면 STOP. Bash 호출로 전환.
- Phase 4 each iter: 동일 점검
- Phase 5 진입 전: `.harness/reviews/review-<id>-iter-*.md` 파일들이 실제 존재하는지 Read로 확인. 없으면 Phase 4 미완료 — Phase 5 진행 금지.
- **Phase 1.3 응답 처리 직전 (필수)**: "사용자 답변이 진짜 명시 선택/결정인가, 내가 추론으로 채우려 하는가? 의문문/되묻기/모호하면 STOP — 답변 후 재질문." (Phase 1.3 응답 분류 게이트 / Rule 11 참조)
- **AskUserQuestion 결과 수신 직후 (필수)**: 각 답변을 (a) 명시 선택 / (b) 명확한 결정 / (c) 질문·모호 로 분류. (c) 하나라도 있으면 전체 보류, 분기 진행 금지.

---

## Quick Reference

| Command | Action |
|---------|--------|
| `/harness <request>` | New workflow |
| `/harness resume [id]` | Resume |
| `/harness status` | In-progress list |
| `/harness list` | All workflows |

| Phase | Output |
|-------|--------|
| 1.0~1.5 | `plans/plan-<id>.md` |
| 1.2 critique | (in plan.md, must be from wrapper) |
| 2 / on-demand | `research/research-<id>-NN-*.md` |
| 3 | project files + `progress/progress-<id>.md` |
| 4 each iter | `reviews/review-<id>-iter-N.md` + `improvements/improvement-<id>-iter-N.md` |
| 5 | `results/result-<id>.md` |
