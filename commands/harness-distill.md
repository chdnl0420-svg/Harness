---
description: harness agent 의 learning 파일을 정리·압축. 800줄 캡 도달 또는 주기적 정리용.
---

# /harness-distill

agent 의 learning 데이터가 비대해지거나 항목이 중복·노후화됐을 때 카테고리별로 통합·압축한다.

## 사용법

```
/harness-distill <agent-name>          # 공용 learning 정리
/harness-distill <agent-name> --project # 현재 프로젝트 learning 정리
/harness-distill --all                 # 공용 모든 agent
```

agent-name: `harness-planner` | `harness-architect` | `harness-code-reviewer` | `harness-security-reviewer` | `harness-tdd-guide` | `harness-build-resolver` | `harness-qa-engineer` | `harness-customer-user`

## 동작

1. 대상 learning 파일 Read.
2. **백업**: 같은 폴더에 `<agent>.md.bak-<YYYYMMDD-HHMMSS>` 로 복사.
3. **분석**:
   - 섹션별 (Principles / Patterns / Anti-patterns / Project-Specific / Open Questions) 항목 수 보고
   - 같은 의미인데 다르게 쓰인 중복 후보 식별 (Codex 한 번 호출해 의미 비교)
   - 6개월 이상 미참조 entry 식별 (날짜 태그 기반)
   - Open Questions 중 결론 도출된 것 → Patterns/Anti-patterns 로 이동 후보
4. **압축 제안 표시**: 사용자에게 변경 사항을 diff 형태로 보여줌.
   ```
   ## Distill Proposal: harness-planner

   ### Merge (의미 같은 중복)
   - [Patterns] "외부 라이브러리 의존 명시" + "라이브러리 의존성 사전 기록"
     → [통합] "[YYYY-MM-DD] 라이브러리 의존성 plan 작성 시 명시."

   ### Move
   - [Open Questions → Patterns] "Bun vs Node?" → 결론: Node 선호. Pattern 으로 승격.

   ### Remove (오래되고 미참조)
   - [Anti-patterns] [2025-11-01] "..." — 6개월 이상 미사용

   변경 후 사이즈: 845 → 412 lines
   ```
5. **사용자 승인** (AskUserQuestion):
   - **A**: 제안 그대로 적용
   - **B**: 일부만 — 어느 항목 적용할지 골라달라고 재질문
   - **C**: 취소

6. 승인 시 Edit 으로 learning 파일 갱신. 백업 파일은 유지 (수동 롤백 가능).
7. progress 가 아닌 별도 `~/.claude/skills/harness/agents/learning/.distill-log.md` 에 변경 요약 append.

## 안전장치

- 백업 필수 (자동, 사용자에게 위치 안내)
- 800줄 초과 케이스에서만 자동 제안. 그 아래는 사용자가 명시 요청해야 동작.
- `Project-Specific` 섹션은 더 보수적으로 정리 (프로젝트 컨벤션은 시간 지나도 유효 가능).
- 민감 정보 패턴 발견 시 distill 과 별개로 즉시 사용자에게 보고.

## 예시

```
/harness-distill harness-planner
→ 현재 사이즈 측정 → 제안 표시 → 승인 → 적용

/harness-distill harness-build-resolver --project
→ 프로젝트 learning 만 정리

/harness-distill --all
→ 공용 모든 agent 순회. 각 agent 별 별도 승인.
```

## 관련

- 학습 파일 위치: `~/.claude/skills/harness/agents/learning/`
- 프로젝트 학습: `<PROJECT>/.harness/agents/learning/`
- 메커니즘 상세: `skills/harness/SKILL.md` 의 "Agent Learning Protocol" 섹션
