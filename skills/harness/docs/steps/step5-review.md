# step5. 리뷰

**산출물**: `review-<slug>.md` (하나에 누적)

**흐름**:
1. Codex 가 코드 리뷰 (n차)
   - Codex 호출이 불가하면 fallback: `code-review` skill (Skill tool, skill="code-review") — 메인 Claude 가 직접 수행
2. 결과를 `review-<slug>.md` 에 누적
3. LGTM 판정 → 흐름 다이어그램 분기 따름
   - LGTM: YES → step6 (QA 테스트) 로 진행
   - LGTM: NO → step3 (구현 계획 수정) 로 되돌림. 동일 문제 5회 반복 시 중단 + 사용자에게 알림
