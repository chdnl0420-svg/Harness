# step3. 구현 계획

**산출물**: `implementation-<slug>.md` 파일 하나

**흐름** (사용자 승인 없이 자동):
1. `plan` skill 호출 (Skill tool, skill="plan") — 메인 Claude 가 직접 수행
2. skill 결과를 Codex 가 리뷰
3. 리뷰 결과를 메인 Claude 가 검토 / 반영
4. 파일 작성 → step4 로
