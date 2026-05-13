# Harness MD File Formats

모든 산출물은 `.harness/<category>/<name>.md` 형식. frontmatter 필수.

## 폴더별 산출물

```
<project>/.harness/
├── plans/             # plan-<id>.md (한 작업당 1개)
├── progress/          # progress-<id>.md (한 작업당 1개, resume용)
├── research/          # research-<id>-<seq>-<slug>.md (작업당 0~N개)
├── reviews/           # review-<id>-iter-<N>.md (iter별 1개)
├── improvements/      # improvement-<id>-iter-<N>.md (수정 필요 시)
└── results/           # result-<id>.md (완료 시 1개)
```

## 파일별 형식

### plan-<id>.md
- **status**: draft | self-review | codex-critique | pending-approval | approved | rejected | abandoned
- **version**: revision 횟수 따라 증가
- **Active Plan**: 현재 활성 계획 (phase 체크리스트, deps, risks, criteria)
- **Version History**: 각 버전의 변경/critique/feedback 기록
- **Self-Review Checklist**: 10-point 결과
- **External Critique**: Codex 또는 Gemini critique 결과
- **User Feedback Log**: 사용자 피드백
- **Linked Research Files**: 호출된 research 파일 목록
- **Approval**: 최종 승인 상태

### progress-<id>.md
- **status**: in_progress | completed | failed | abandoned
- **current_phase**: "1.4" | "3" | "4-iter-2" 등
- **current_iteration**: Phase 4용
- **Phase Completion**: 체크리스트
- **Recent Actions**: 최근 행동 기록
- **Artifacts Generated**: 생성된 파일 목록
- **Resume Instructions**: 재개 가이드

### research-<id>-<seq>-<slug>.md
- **sequence**: 01, 02, ... (research_count)
- **phase_triggered**: 어느 phase에서 호출됨
- **trigger_source**: claude-auto | user-explicit | codex-said | reviewer-said
- **trigger_reason**: 왜 필요했는지
- **topic**: 주제
- **researched_by**: gemini | claude-fallback
- **Findings**: Gemini 응답 verbatim
- **Used In**: 이 research를 참조한 파일들

### review-<id>-iter-<N>.md
- **iteration**: 1, 2, 3
- **reviewer**: codex | claude-fallback
- **codex_attempt_exit_code**: 0 | 2 | other (fallback 발생 시만)
- **Summary**: 1줄 verdict
- **Issues by Severity**: CRITICAL/HIGH/MEDIUM/LOW
- **LGTM**: YES/NO

### improvement-<id>-iter-<N>.md
- **source_review**: link to review file
- **To Fix**: CRITICAL/HIGH 항목 체크리스트
- **Deferred**: MEDIUM/LOW (사용자 판단)
- **Linked Research**: 수정 시 참고한 research
- **Fix Log**: 실제 수정 기록

### result-<id>.md
- **status**: completed
- **total_iterations**: Phase 4 iteration 횟수
- **critique_method**: codex | gemini | self-only
- **Summary**: 1-2 문장
- **Final Changes**: 변경 파일 목록
- **Workflow Rounds**: Plan/Research/Review 라운드 요약
- **Deferred Issues**: 미해결 항목
- **Recommended Next Steps**: 권장 후속
- **Audit Trail**: 모든 .harness/ 파일 링크

## Naming Convention

**REQUEST_ID** = `YYYYMMDD-HHMMSS-<slug>`

slug 추출 규칙:
- 사용자 요청에서 핵심 명사 추출
- max 30자
- lowercase
- 공백/특수문자 → hyphen
- 한글 → 영문 의역 권장

예시:
- "JWT 미들웨어 구현해줘" → `jwt-middleware`
- "결제 시스템 추가" → `payment-system`
- "user.py 리팩토링" → `user-py-refactor`
