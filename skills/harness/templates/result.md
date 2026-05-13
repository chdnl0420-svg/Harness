<!--
TEMPLATE: result.md
Generated at Phase 5 (Complete).
Filename: result-<REQUEST_ID>.md
-->
---
request_id: <REQUEST_ID>
status: completed
total_iterations: <N>
created: <ISO_TIMESTAMP_START>
completed: <ISO_TIMESTAMP_END>
plan_final_version: <N>
research_count: <N>
review_count: <N>
critique_method: <codex | gemini | self-only>
---

# ✅ Result: <SHORT_TITLE>

## Summary
<1-2 sentence summary of what was accomplished>

## Original Request
> <USER_REQUEST verbatim>

## Final Changes

### Files Created
- `<path>` — <description>

### Files Modified
- `<path>` (+<lines added> / -<lines removed>) — <description>

## Workflow Rounds

### Plan Stage (Phase 1)
- Plan revisions: <N>
- Self-Review final: <X/10>
- External critique: <Codex LGTM | Gemini LGTM | self-only>

### Research (Phase 2 + on-demand)
- Total research calls: <N>
- Topics covered:
  - <topic 1> (research-XX)
  - <topic 2> (research-XX)

### Review Loop (Phase 4)
- Iter 1: <reviewer> — <N CRITICAL, M HIGH → fixed>
- Iter 2: <reviewer> — <LGTM | issues>
- ...

## Deferred Issues (선택적 후속 작업)

- <MEDIUM/LOW item from final review — for user judgement>

## Recommended Next Steps

- [ ] Run tests: `<command>`
- [ ] (필요시) PR 생성
- [ ] (필요시) <additional follow-up>

## Reproduce / Audit Trail

모든 산출물은 `.harness/` 아래 보존됨:

| 종류 | 파일 |
|------|------|
| Plan | `plans/plan-<id>.md` |
| Progress | `progress/progress-<id>.md` |
| Research | `research/research-<id>-*.md` |
| Reviews | `reviews/review-<id>-iter-*.md` |
| Improvements | `improvements/improvement-<id>-iter-*.md` |
| **Result** | **`results/result-<id>.md`** ← 이 파일 |

## Cost Summary

- Codex critique/review calls: <N> (subscription)
- Gemini research calls: <N> (free OAuth tier)
- Claude main orchestration: subscription (Claude Max)
