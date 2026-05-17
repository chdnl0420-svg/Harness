<!--
TEMPLATE: review.md
Generated each Phase 4 iteration.
Filename: review-<REQUEST_ID>-iter-<N>.md
-->
---
request_id: <REQUEST_ID>
iteration: <N>
reviewer: <codex | claude-fallback>
reviewed_files:
  - <file path 1>
  - <file path 2>
created: <ISO_TIMESTAMP>
codex_attempt_exit_code: <0 | 2 | other>  # only relevant if fallback occurred
---

# Code Review (Iteration <N>) — by <Reviewer>

## Summary

<1-line verdict>

## Issues by Severity

### CRITICAL
- [<file:line>] <issue description>

### HIGH
- [<file:line>] <issue description>

### MEDIUM
- [<file:line>] <issue description>

### LOW
- [<file:line>] <issue description>

## LGTM

<YES | NO>

---

## Fallback Note (if applicable)

(only shown if Codex failed and Claude code-reviewer was used)

⚠️ Codex unavailable: <reason>. Reviewed by Claude code-reviewer as fallback.
User action recommended: `codex login` in WSL.

---

## Linked Improvement

(자동 생성 시 추가됨, NO LGTM 일 때)

→ improvements/improvement-<REQUEST_ID>-iter-<N>.md
