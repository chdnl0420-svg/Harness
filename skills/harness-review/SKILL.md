---
name: harness-review
description: harness step5 외부 Codex 리뷰 wrapper. file-list MD 작성 → codex exec 한 줄 프롬프트 호출 → result.md Read → 호출자에 verbatim 반환의 4단계 절차. self-review bias 차단을 위해 외부 verifier 로 동작. Codex 인증 실패(exit 2) 또는 quota 소진(exit 3) 시 code-review skill 로 자동 fallback + fallback_used 필드 명시.
---

# harness-review

`/harness` step5 리뷰 단계에서 메인 Claude 가 수행하는 **Codex 외부 리뷰** wrapper.

본 skill 은 별도 프로세스가 아니다. [`codex-review-procedure.md`](../harness/docs/procedures/codex-review-procedure.md) 의 4단계 절차를 메인 Claude 가 그대로 수행한다.

## 호출 조건

- `/harness` step5 진입 시 (자동)
- `/harness-review` 슬래시 커맨드 직접 호출

## 절차 (single source — codex-review-procedure.md 참조)

1. **file-list MD 작성** — `.harness/reviews/review-<slug>-file-list.md` 에 *경로만* 한 줄씩.
2. **`codex exec` 한 줄 프롬프트** 호출:
   ```bash
   codex exec --sandbox workspace-write \
     ".harness/reviews/review-<slug>-file-list.md 에 적힌 파일들 전부 리뷰해줘. \
      리뷰 결과는 .harness/reviews/codex-review-<slug>-result.md 에 작성해줘."
   ```
3. **결과 파일 Read** — `.harness/reviews/codex-review-<slug>-result.md` 본문 확인.
4. **호출자에 verbatim 반환** + result 절대경로 한 줄 보고.

## Fallback 정책 (정합 — SKILL.md "자동 결정 매핑" 따름)

`codex exec` exit code 별 처리:

- **exit 0** — 정상. 결과 파일 Read 후 호출자에 반환.
- **exit 2 (로그인 필요)** — `code-review` skill 로 자동 fallback (Claude self-review). `fallback_used=code-review (codex auth)` 필드 명시 + report 에 기록. self-review bias 안내 후 진행. workflow.md "자동 결정 매핑" 표의 80번째 줄 정책과 일치.
- **exit 3 (quota 소진)** — `code-review` skill 자동 fallback. `fallback_used=code-review (codex quota)` 필드 명시.
- **기타 exit code** — STOP, 사용자/호출자 보고. fake 응답 생성 절대 금지.

> **2026-05-20 정합화 노트**: `agents/codex-reviewer.md` line 48 의 "exit 2 fallback 금지" 는 본 skill 의 fallback 정책에 의해 *override* 됨. 본 skill 이 step5 호출의 primary entry point 이며, SKILL.md "자동 결정 매핑" 표가 최종 진실 원천.

## 결과 양식

```
Codex 리뷰 완료
결과: <project>/.harness/reviews/codex-review-<slug>-result.md
fallback_used: <none | code-review (codex auth) | code-review (codex quota)>

(이하 result.md 본문 verbatim)
```

## 관계

- 본문 절차 정본: [`docs/procedures/codex-review-procedure.md`](../harness/docs/procedures/codex-review-procedure.md)
- 자매 agent: [`codex-reviewer`](../harness/agents/codex-reviewer.md) — Task 도구 호출용 (skill 과 동일 절차, subagent 컨텍스트만 다름)
- Fallback: `code-review` skill (Skill 도구) + Claude `code-reviewer` agent (Task 도구)
- 사용자 진입점: `/harness-review` 슬래시 커맨드
