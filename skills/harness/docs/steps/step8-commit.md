# step8. git commit / push

**조건**: git remote(원격 저장소) 있을 때만 실행. 없으면 이 단계를 건너뛰고 바로 complete.

**흐름**:
1. 메인 Claude 가 commit 메시지 자동 작성 (변경 맥락을 직접 보고 작성)
2. 현재 브랜치에 commit / push
3. → complete

---

## Chunks 모드 (2026-05-20 신규)

**Chunks 모드일 때** (step3 의 임계값 통과 시):
- **chunk 별 incremental commit** — step6 PASS 직후 *해당 chunk 만* commit. 다른 chunk 의 변경은 staging 안 함.
- commit 메시지 형식: `feat(<slug>): chunk <i>/<N> — <chunk-i title>` (chunks-overview 의 title 인용).
- push 는 **chunk 별 즉시 push** (진행 상황 원격 반영).
  - push 실패 시 재시도 1회 → 그래도 실패면 로컬 commit 만 완료. 다음 chunk 는 정상 진입.
- 모든 chunk 완료 후 *최종 단계* 에서는 *추가 commit 없음* (chunk 별 commit 누적이 이미 git history). step7 결과 / report 생성만.
- 자세히: [step3-impl-plan.md Chunks 분해 절차](step3-impl-plan.md#chunks-분해-절차-critical--2026-05-20-신규).
