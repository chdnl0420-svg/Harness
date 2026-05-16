---
description: 마스터 harness skill 폴더와 현재 프로젝트의 .harness/ 를 동기화 (drift 자동 감지 + 백업 자동 + dry-run 지원)
argument-hint: '[--check] [--dry-run] [<PROJECT_DIR>]'
---

# Harness Sync — 마스터 ↔ 프로젝트 동기화

마스터 (`~/.claude/skills/harness/`) 의 `core/*.sh` · `wrappers/*.sh` 중 프로젝트(`<PROJECT>/.harness/`) 측이 **추적 대상 파일**과 다르면 drift 로 감지하고, 마스터 버전으로 덮어쓰기 전에 **자동 백업** 한 뒤 동기화한다.

## 주요 모드

| 호출 | 동작 |
|------|------|
| `/harness-sync` | 현재 디렉토리를 PROJECT 로 보고 drift 자동 동기화 (백업 자동) |
| `/harness-sync --check` | drift 감지만, 동기화 안 함 (사람용 리포트) |
| `/harness-sync --dry-run` | 어떤 파일이 동기화될지 시뮬레이션만 (실제 변경 X) |
| `/harness-sync <PATH>` | 특정 프로젝트 경로 명시 (Windows 경로 가능) |

`--check` 와 `--dry-run` 은 동시에 의미 없음 — `--check` 가 우선.

## 동작 절차

1. **PROJECT_DIR 결정**
   - `$ARGUMENTS` 에 경로 인자(`/`, `\`, 또는 드라이브 문자 포함) 발견 → 그 경로 사용.
   - 없으면 현재 작업 디렉토리(`$PWD`).
2. **`<PROJECT>/.harness/` 존재 확인**
   - 있으면 그대로 다음 단계.
   - 없으면 모드별로 분기:
     - 기본(sync) → 마스터(`~/.claude/skills/harness/`) 의 `core/bootstrap-runtime.sh` 로 자동 부트스트랩 (디렉토리 + 필수 파일 + agent 학습 시드 생성) 한 뒤 다음 단계.
     - `--check` → "프로젝트에 `.harness/` 없음" 알림 + `exit 10` (drift 있는 상태로 간주).
     - `--dry-run` → "부트스트랩 예정" 보고만, 파일 변경 없음.
3. **`check-drift.sh` 호출** (모드별):
   - `--check` → 사람용 리포트만 출력, exit 0/10 그대로 표시.
   - 그 외 → `sync-from-master.sh` 로 위임 (drift 없으면 즉시 종료, 있으면 백업 → 복사).
4. **결과 보고** — 동기화 건수 · 실패 건수 · 백업 위치(`<PROJECT>/.harness/backups/<rel>.bak-<TS>`).

## 검사·동기화 대상

`check-drift.sh` 의 `TRACKED_FILES` 목록 (마스터가 프로젝트에 복사하는 파일만 추적):

- `wrappers/codex-review.sh`
- `wrappers/gemini-research.sh`
- 그 외 `bootstrap-runtime.sh` 가 실제 배포하는 파일들

마스터 전용 스크립트(`harness-doctor.sh`, `sync-from-master.sh`, `check-drift.sh` 자신 등)는 프로젝트에 없어도 정상 — drift 로 잡지 않는다.

## 실행 명령

`$ARGUMENTS` 를 파싱해 WSL 측 sync 스크립트로 위임:

```bash
SKILL_WIN="$(cmd.exe /c echo %USERPROFILE% 2>/dev/null | tr -d '\r')\\.claude\\skills\\harness"
ARGS="$ARGUMENTS"

# 모드·경로 분리
CHECK_ONLY=0
DRY_RUN=0
EXPLICIT_PATH=""
for tok in $ARGS; do
  case "$tok" in
    --check)   CHECK_ONLY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -*)        : ;;  # 기타 옵션 무시 (전달)
    *)         EXPLICIT_PATH="$tok" ;;
  esac
done

# 프로젝트 경로: 명시값 > $PWD
if [ -n "$EXPLICIT_PATH" ]; then
  PROJECT_WIN="$EXPLICIT_PATH"
else
  PROJECT_WIN="$(pwd -W 2>/dev/null || pwd)"
fi

# 모드 선택
if [ "$CHECK_ONLY" = "1" ]; then
  SCRIPT_REL="core/check-drift.sh"
  SCRIPT_EXTRA=""  # 사람용 리포트
  MODE_TOKEN="check"
else
  SCRIPT_REL="core/sync-from-master.sh"
  SCRIPT_EXTRA=""
  if [ "$DRY_RUN" = "1" ]; then
    SCRIPT_EXTRA="--dry-run"
    MODE_TOKEN="dry-run"
  else
    MODE_TOKEN="sync"
  fi
fi

wsl -e bash -lc '
  SKILL_WSL=$(wslpath -u "$1")
  PROJECT_WSL=$(wslpath -u "$2" 2>/dev/null || echo "$2")
  MODE="$3"
  if [ ! -d "$PROJECT_WSL/.harness" ]; then
    case "$MODE" in
      check)
        echo "⚠️  이 프로젝트엔 .harness/ 가 없음: $PROJECT_WSL"
        echo "   /harness-sync (옵션 없이) 실행 시 마스터에서 자동 부트스트랩됨."
        exit 10
        ;;
      dry-run)
        echo "🔍 [DRY] .harness/ 가 없음 → 마스터에서 부트스트랩 예정:"
        echo "   from: $SKILL_WSL"
        echo "   to:   $PROJECT_WSL/.harness/"
        echo "   (실제 변경 없음. /harness-sync 옵션 없이 호출하면 부트스트랩 실행)"
        exit 0
        ;;
      *)
        echo "ℹ️  .harness/ 없음 → 마스터에서 부트스트랩 중..."
        echo "   master: $SKILL_WSL"
        echo "   target: $PROJECT_WSL/.harness/"
        if ! bash "$SKILL_WSL/core/bootstrap-runtime.sh" "$PROJECT_WSL"; then
          echo "❌ 부트스트랩 실패 (bootstrap-runtime.sh)" >&2
          exit 3
        fi
        echo "✅ 부트스트랩 완료. 동기화 단계 계속..."
        ;;
    esac
  fi
  bash "$SKILL_WSL/'"$SCRIPT_REL"'" "$PROJECT_WSL" '"$SCRIPT_EXTRA"'
' _ "$SKILL_WIN" "$PROJECT_WIN" "$MODE_TOKEN"
```

## Exit Code 의미

| Exit | 의미 | 다음 행동 |
|------|------|---------|
| 0 | drift 없음 또는 동기화 성공 (또는 `--dry-run` 시 부트스트랩 예정만 보고) | 추가 작업 불필요 |
| 10 | (`--check` 모드 전용) drift 감지됨 **또는 `.harness/` 자체가 없음** | `/harness-sync` (옵션 없이) 로 부트스트랩 + 동기화 |
| 2 | 사용 오류 (PROJECT_DIR 경로 잘못됨 등) | 경로 확인 후 재호출 |
| 3 | 환경 오류 (`sha256sum` 미설치, 마스터 경로 비정상, 부트스트랩 실패) | `/harness-setup` 실행 |

## 백업 정책

- 동기화 시 프로젝트 측 파일이 이미 있으면 **항상** `<PROJECT>/.harness/backups/<rel>.bak-<YYYYMMDD-HHMMSS>` 로 백업.
- 백업은 자동 삭제 안 함. 누적되면 직접 정리.
- `--dry-run` / `--check` 모드는 백업·복사 모두 안 함.

## 자주 쓰는 흐름

**1. 무엇이 바뀔지 먼저 보기**
```
/harness-sync --check
```
→ drift 항목 목록만 출력. exit 10 이면 동기화 대기. 프로젝트에 `.harness/` 자체가 없는 경우도 exit 10 으로 보고.

**2. 시뮬레이션**
```
/harness-sync --dry-run
```
→ 어느 파일이 backup + overwrite 될지 표시. 파일 변경은 없음.

**3. 실제 동기화**
```
/harness-sync
```
→ 프로젝트에 `.harness/` 가 없으면 먼저 마스터에서 부트스트랩 (디렉토리 + 필수 파일 + agent 학습 시드). 있으면 백업 + 마스터에서 덮어쓰기. 완료 후 백업 위치 표시.

**4. 마스터 자체를 최신화하고 싶을 때**
이 커맨드는 *마스터→프로젝트* 방향만 처리한다. 마스터(`~/.claude/skills/harness/`) 자체를 GitHub 최신으로 끌어오는 건 `/harness-setup --update` 사용.

## 안 하는 것

- **프로젝트→마스터 역방향 동기화 안 함** — 프로젝트 측 임시 패치를 마스터로 끌어올리는 건 별도 PR/수동 적용. 이 커맨드는 한 방향 (마스터를 신뢰).
- **추적 대상 외 파일 동기화 안 함** — `<PROJECT>/.harness/agents/learning/*.md`, `<PROJECT>/.harness/PRD.md` 같은 프로젝트 자체 파일은 손대지 않는다. `TRACKED_FILES` 화이트리스트만.
- **GitHub 호출 안 함** — 로컬 마스터(`~/.claude/skills/harness/`) 기준. 최신 마스터를 받으려면 `/harness-setup --update` 먼저.
- **자동 git commit 안 함** — 동기화 후 변경된 파일을 staging 하지 않는다. 필요하면 사용자가 직접 `git add .harness/`.

## Related

- **drift 감지 스크립트**: [core/check-drift.sh](C:\Users\NX3GAMES\.claude\skills\harness\core\check-drift.sh)
- **동기화 스크립트**: [core/sync-from-master.sh](C:\Users\NX3GAMES\.claude\skills\harness\core\sync-from-master.sh)
- **마스터 업데이트**: `/harness-setup --update` (GitHub → 마스터)
- **초기 설치**: `/harness` skill (step1 초기화에서 `bootstrap-runtime.sh` 가 첫 배포)
