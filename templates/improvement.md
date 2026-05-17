<!--
TEMPLATE: improvement.md
Generated when a review iteration finds CRITICAL/HIGH issues that need fixing.
Filename: improvement-<REQUEST_ID>-iter-<N>.md
-->
---
request_id: <REQUEST_ID>
iteration: <N>
source_review: reviews/review-<REQUEST_ID>-iter-<N>.md
created: <ISO_TIMESTAMP>
status: pending  # pending | fixing | completed
---

# Improvement Plan (Iter <N> → Iter <N+1>)

## Source
Review: [reviews/review-<id>-iter-<N>.md]

## To Fix (CRITICAL/HIGH priority)

- [ ] <file:line> — <issue> → <fix approach>
- [ ] <file:line> — <issue> → <fix approach>

## Deferred (사용자 판단)

### MEDIUM
- <file:line> — <issue> — (defer reason)

### LOW
- <file:line> — <issue> — (typically ignored)

## Linked Research (if any)

<리서치 결과를 참고해서 수정 시>
- research-<id>-<seq>.md — <how it informed the fix>

## Fix Log

(수정 진행 중 기록)

- <timestamp> — <file>: <change description>
