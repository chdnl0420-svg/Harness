# Harness Workflow — 상세 동작

이 문서는 `harness` 스킬의 각 phase 상세 동작을 설명합니다.

## 전체 흐름

```
사용자: /harness <자연어 요청>
        ↓
[Step 0] Initialize
   - REQUEST_ID 생성 (YYYYMMDD-HHMMSS-slug)
   - .harness/ 폴더 보장
        ↓
[Phase 1] Plan (6 sub-phases, 가장 중요)
   1.0 Initial Draft (+ Gemini research 가능)
   1.1 Self-Review (10-point checklist)
   1.2 Codex Critique (ALWAYS, Gemini fallback)
   1.3 User Approval (필수 게이트)
   1.4 Revision (max 3)
   1.5 Finalize
        ↓
[Phase 2] Research (선택, 큰 사전 조사)
        ↓
[Phase 3] Implement (+ Gemini research on-demand)
        ↓
[Phase 4] Review Loop (max 3 iter)
   - codex-reviewer primary
   - code-reviewer (Claude) fallback
   - Gemini research on-demand (확인 필요 시)
        ↓
[Phase 5] Complete
   - result-<id>.md 작성
   - 사용자에게 최종 보고
```

## Phase 1 상세 (가장 중요)

### Phase 1.0: Initial Draft
- 사용자 요청 파싱 → phase 분해
- plan-<id>.md v1 작성
- 작성 중 외부 정보 필요 시 Gemini 호출

### Phase 1.1: Self-Review
10개 항목 자체 평가. ❌ 하나라도 있으면 1.4 자동 revision.

### Phase 1.2: Codex Critique (ALWAYS)
- 항상 Codex 호출 (이전 strict 옵션이었으나 이제 강제)
- 실패 시 Gemini fallback
- 둘 다 실패 시 사용자 결정

### Phase 1.3: User Approval
- Self-review + Codex critique 결과 함께 표시
- 사용자: 진행/수정/다시/취소

### Phase 1.4: Revision (loop, max 3)
- HARD LIMIT 3회 → 사용자 결정

### Phase 1.5: Finalize
- approved 상태로 변경
- progress.md 초기화

## Gemini On-Demand 호출 시점

**모든 phase에서 가능**:
- Phase 1.0: plan 작성 중
- Phase 1.1: 외부 정보 부족 판정 시
- Phase 1.2: Codex critique "needs research" 시
- Phase 2: 큰 사전 조사
- Phase 3: 구현 중 막힘
- Phase 4: 리뷰어가 "확인 필요" 시

무료 (Google OAuth)이므로 자유롭게.

## Failure Modes

| 실패 | 처리 |
|------|------|
| Codex 인증 실패 | Gemini fallback (critique) / Claude fallback (review) |
| Gemini 인증 실패 (critique 시) | 사용자 결정 (self-only/재시도/취소) |
| Plan revision 3회 초과 | 사용자 결정 (강제진행/취소/직접) |
| Review iter 3회 초과 | 강제 완료 + 잔여 보고 |
| 사용자 인터럽트 | progress.md status=in_progress 보존 → resume 가능 |
