<!--
TEMPLATE: progress.md
Updated continuously throughout the workflow. Used for /harness resume.
The frontmatter is the source of truth for resume logic.
-->
---
request_id: <REQUEST_ID>
last_updated: <ISO_TIMESTAMP>
status: in_progress  # in_progress | completed | failed | abandoned
current_phase: <e.g. "3" or "4-iter-2">
current_iteration: <N>  # for Phase 4 review loops
plan_version: <N>
research_count: <N>
review_count: <N>
files_created: []  # list of new files
files_modified: []  # list of modified files
---

# Progress: <REQUEST_ID>

## Current State

**Phase:** <current_phase>
**Step within phase:** <description>

## Phase Completion

- [x] Phase 1: Plan (approved at <timestamp>, v<N>)
- [ ] Phase 2: Research (status)
- [ ] Phase 3: Implement
  - [x] file1.ts
  - [ ] file2.ts (in progress)
- [ ] Phase 4: Review Loop
  - [ ] Iter 1
  - [ ] Iter 2
- [ ] Phase 5: Complete

## Recent Actions (newest first)

- <timestamp> — <phase>: <action description>
- <timestamp> — <phase>: <action description>

## Artifacts Generated

### Plans
- plans/plan-<id>.md (v<N>)

### Research
- research/research-<id>-01-<slug>.md
- research/research-<id>-02-<slug>.md

### Reviews
- reviews/review-<id>-iter-1.md (codex, NO LGTM, 2 CRITICAL)
- reviews/review-<id>-iter-2.md (in progress)

### Improvements
- improvements/improvement-<id>-iter-1.md

### Results
- (not yet)

## Resume Instructions

이 작업을 재개하려면:
```
/harness resume <REQUEST_ID>
```
또는 (가장 최근 in_progress 작업 자동 선택):
```
/harness resume
```

스킬이 이 progress.md의 `current_phase` / `current_iteration`을 읽고 해당 지점부터 워크플로우 재개.

## Notes

(자유 기록 — 메인 컨텍스트 보존용)
- <important decision recorded for resume>
- <known issue to revisit>
