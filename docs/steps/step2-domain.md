# step2. 도메인 설계

**산출물**: `domain-<slug>.md` 파일 하나

**흐름**:

1. **`harness-plan` skill 호출** (Skill tool, skill="harness-plan") — 산출: 도메인 설계 초안 본문 (사용자 미승인).
2. skill 결과(초안)를 Codex 가 리뷰
3. 리뷰 결과를 메인 Claude 가 검토 / 반영
4. **사용자 승인** — `AskUserQuestion` 으로 *"1. 승인 / 2. 수정 의견 / 3. 취소"* 제시. 승인 질문 직전에 도메인 설계 본문을 화면에 그대로 보여 사용자가 확인 가능해야 함.
5. 수정 의견 시 1번(`harness-plan`) 재호출, 단순 질문 시 답변만 하고 다시 승인 질문, 취소 시 워크플로우 중단
6. 사용자 승인 시 파일 작성 (`.harness/domain-<slug>.md`) → step3 로
