# step8. git commit / push

**입력 게이트 (skip 금지 — 메인 Claude 가 commit 직전 자체 검증)**:

step6/step7 미통과 상태에서 step8 직진을 차단하는 강제 게이트. 본 게이트가 없으면 step7 게이트만으론 우회 가능 (정문/옆문 문제). 누락 시 step 스킵 위반으로 즉시 워크플로우 중단.

1. **step6 라벨 검증** — `.harness/results/qa-<slug>.md` 마지막 회차 라벨이 PASS 여야 함.
   ```
   grep -oE "(Verdict|Status|최종 판정):[[:space:]]*(PASS|FAIL|BLOCKED|UNKNOWN)" .harness/results/qa-<slug>.md | tail -1
   ```
   PASS 아니면 채팅 한 줄: `[step8-gate] step6 미통과 (<라벨>) — commit/push 금지`. 워크플로우 중단 상태 유지.

2. **step7 보고서 존재 검증** — `.harness/results/customer-<slug>.md` 파일 존재 + 비어있지 않음.
   부재 시: `[step8-gate] step7 customer 보고서 없음 — commit 금지`.

3. **step7 도우미 호출 흔적 검증** — customer 보고서 안에 도우미 호출 흔적 grep.
   ```
   grep -E "harness-customer-user|첫인상|페르소나|test-guide" .harness/results/customer-<slug>.md
   ```
   흔적 0건: `[step8-gate] step7 도우미 호출 흔적 없음 (self-test 의심) — commit 금지`.

4. 위 3축 모두 통과 후에만 commit/push 진행. 게이트 통과 결과는 commit 메시지 본문 끝에 한 줄 footer 로 명시:
   ```
   harness-gate: step6=PASS, step7=customer-<slug>.md (도우미 호출 OK)
   ```

5. **Chunks 모드** 의 chunk 별 incremental commit (line 17 이하) 도 동일 게이트 적용. chunk 별 step6 PASS 여야 chunk commit 가능. last chunk 의 step8 만 step7 보고서까지 요구.

**조건**: 게이트 통과 후 실행. push 는 옵트인 (아래 push 정책 참조).

**push 정책 (2026-05-20 신규 — 배포성 부작용 차단)**:

검증 워크플로우의 본질에 맞춰, 원격 push 는 **기본 비활성** 이다. 사용자가 명시 opt-in 한 경우에만 push 시도.

- **기본 (push 안 함)**: 로컬 commit 만 수행. 사용자가 작업 검토 후 직접 `git push` 또는 PR 생성.
- **opt-in 활성**: 다음 중 하나
  1. `.harness/.auto-push` 마커 파일 존재 (`touch .harness/.auto-push`)
  2. 사용자가 `/harness --push` 플래그로 호출
  3. Chunks 모드의 chunk 별 incremental commit 도 동일 — 마커 없으면 로컬만
- **opt-in 모드에서 push 실패**: 재시도 1회 → 로컬 commit 만 완료로 처리. report 에 사유 기록.
- **git remote 없음**: 옵션 무관 — 로컬 commit 만. complete 로 진행.

**흐름**:
1. 메인 Claude 가 commit 메시지 자동 작성 (변경 맥락을 직접 보고 작성). 게이트 통과 footer 포함.
2. **현재 브랜치에 commit (항상 수행)**.
3. **push 정책 분기**:
   - `.harness/.auto-push` 존재 OR `--push` 플래그 → `git push` 시도
   - 둘 다 부재 → push 생략. 채팅 한 줄 안내: `[step8] 로컬 commit 완료 (push 비활성 — opt-in 필요 시 .harness/.auto-push 생성 또는 /harness --push)`
4. → complete

---

## Chunks 모드 (2026-05-20 신규)

**Chunks 모드일 때** (step3 의 임계값 통과 시):
- **chunk 별 incremental commit** — step6 PASS 직후 *해당 chunk 만* commit. 다른 chunk 의 변경은 staging 안 함.
- commit 메시지 형식: `feat(<slug>): chunk <i>/<N> — <chunk-i title>` (chunks-overview 의 title 인용).
- push 는 **chunk 별 즉시 push** (진행 상황 원격 반영).
  - push 실패 시 재시도 1회 → 그래도 실패면 로컬 commit 만 완료. 다음 chunk 는 정상 진입.
- 모든 chunk 완료 후 *최종 단계* 에서는 *추가 commit 없음* (chunk 별 commit 누적이 이미 git history). step7 결과 / report 생성만.
- 자세히: [step3-impl-plan.md Chunks 분해 절차](step3-impl-plan.md#chunks-분해-절차-critical--2026-05-20-신규).
