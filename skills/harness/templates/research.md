<!--
TEMPLATE: research.md
Generated each time gemini-researcher is called.
Filename: research-<REQUEST_ID>-<SEQ>-<SLUG>.md
-->
---
research_id: <REQUEST_ID>-<SEQ>
parent_request: <REQUEST_ID>
sequence: <SEQ>  # 01, 02, 03 ...
phase_triggered: "<e.g. 1.0 / 1.2 / 3 / 4-iter-2>"
trigger_source: <claude-auto | user-explicit | codex-said | reviewer-said>
trigger_reason: "<why this research was needed>"
topic: "<short topic>"
researched_by: <gemini | claude-fallback>
created: <ISO_TIMESTAMP>
---

# Research: <TOPIC>

## Trigger Context

- **Phase:** <phase>
- **Source:** <who/what asked for this research>
- **Reason:** <why external info was needed>

## Question

<the actual question sent to Gemini>

## Findings

<Gemini's response verbatim>

## Used In

(파일들이 이 research를 참조할 때 자동 추가됨)

- plan-<id>.md v<N> — <how used>
- improvement-<id>-iter-<N>.md — <how used>

## Source

- Tool: <gemini-research.sh | claude-fallback>
- Called at: <ISO_TIMESTAMP>
- Cost estimate: <free (Gemini OAuth) | $0 (Claude self-knowledge)>
