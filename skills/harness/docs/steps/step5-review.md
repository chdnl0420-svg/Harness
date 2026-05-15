# step5. 리뷰

**산출물**: `review-<slug>.md` (하나에 누적)

**흐름**:
1. Codex 가 코드 리뷰 (n차)
   - Codex 호출이 불가하면 fallback: `code-review` skill (Skill tool, skill="code-review") — 메인 Claude 가 직접 수행
2. 결과를 `review-<slug>.md` 에 누적
3. LGTM 판정 → 흐름 다이어그램 분기 따름
   - LGTM: YES → step6 (QA 테스트) 로 진행
   - LGTM: NO → step3 (구현 계획 수정) 로 되돌림. 동일 문제 5회 반복 시 중단 + 사용자에게 알림

# 반드시 지켜야 할 사항

- 리뷰는 직접 문제를 수정할 수 없다. 따라서 리뷰 결과가 LGTM: NO이면 반드시 step3로 되돌아가야 한다.
- Codex 에 보낼 prompt 는 **리뷰 대상 파일의 본문을 합쳐 넣지 말고 경로만 적는다.** Codex 가 file-read 도구로 직접 읽는다. 양식은 [/harness-review](../../../commands/harness-review.md) Step 2-A / Step 3 와 동일 — `[Files to review]` 섹션에 프로젝트 루트 기준 상대 경로만 한 줄씩.