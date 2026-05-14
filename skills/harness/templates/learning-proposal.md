# Learning Proposal Template

agent 가 작업 끝낼 때 응답 마지막에 아래 형식으로 출력.
변경 사항이 없으면 섹션 자체 생략.

```markdown
## Learning Proposals

### Add
- **section**: Patterns
- **entry**: [YYYY-MM-DD] 1~2 문장 요약.
- **evidence**: REQUEST_ID <id> 또는 general.

### Update
- **section**: Anti-patterns
- **old**: 기존 entry 한 줄 그대로.
- **new**: 수정된 entry 한 줄.
- **reason**: 왜 바꾸는지.

### Delete
- **section**: Open Questions
- **entry**: 삭제 대상 entry 한 줄.
- **reason**: 왜 지우는지 (예: 결론 도출 후 Patterns 로 이동).
```

규칙:
- 모든 entry 는 `[YYYY-MM-DD]` 태그로 시작.
- section 은 5개 중 하나: Principles / Patterns / Anti-patterns / Project-Specific / Open Questions.
- evidence 는 추적 가능한 출처 (REQUEST_ID, 파일 경로, 또는 'general').
- 한 항목 1~2 문장. 길면 distill 단계에서 잘려나감.

메인 Claude 가 받으면:
1. 중복 grep
2. 모순 검사 (필요 시 Codex critique)
3. 민감 정보 검사 (비번/내부 URL/회사명)
4. 형식 검증
5. OK → learning 파일 Edit + progress 에 diff 기록
6. 차단 시 → 사용자에게 보고
