<!--
TEMPLATE: plan.md
Filled by harness orchestrator at Phase 1.0 and updated through Phase 1.5.

Placeholders: <REQUEST_ID>, <USER_REQUEST>, <PROJECT_DIR>, timestamps, phase content.
-->
---
request_id: <REQUEST_ID>
created: <ISO_TIMESTAMP>
status: draft  # draft | self-review | codex-critique | pending-approval | approved | rejected | abandoned
version: 1
revision_count: 0
user_request: "<USER_REQUEST>"
project_dir: <PROJECT_DIR>
critique_method: pending  # codex | code-review-skill | self-only (set after Phase 1.2)
research_count: 0
---

# Plan: <SHORT_TITLE>

## 📋 Active Plan (v<N>, <status>)

### Phases (orchestrator workflow phases — Phase 2 onward)

- [ ] Phase 2: Research (if needed)
- [ ] Phase 3: Implement
  - [ ] <file/component 1>
  - [ ] <file/component 2>
- [ ] Phase 4: Review Loop (max 3 iter)
- [ ] Phase 5: Complete

### Dependencies
- <library/tool> @ <version> — <why> (ref: research-XX if applicable)

### DDD Design
- **Ubiquitous Language:** <terms shared by product, code, and tests>
- **Bounded Context:** <primary context and adjacent contexts>
- **Aggregate / Invariant:** <aggregate root or "not needed"; invariant protected>
- **Domain Events:** <business-significant events or "none"; integration events if boundary-crossing>
- **Application Service Boundary:** <use-case orchestration location; no business rules here>
- **Repository / Adapter Boundary:** <persistence and external-system ports; implementations outside domain core>
- **Persistence / Transaction Boundary:** <aggregate save boundary; cross-aggregate consistency strategy>
- **Context Map / Boundary:** <external or legacy model boundaries; anti-corruption layer if needed>
- **Target DDD Structure:** <domain/application/infrastructure/interface boundaries to enforce>
- **Migration Plan:** <how existing code moves to the target DDD structure>

### Codebase Design Research
- **Existing module map:** <files/modules read>
- **Dependency direction:** <current direction and proposed change>
- **Current transaction / persistence flow:** <where state changes are validated and committed>
- **Tests around affected behavior:** <unit/integration/e2e files that cover the invariant or gap>
- **DDD-to-code mapping:** <where domain model lands in the current codebase>
- **Architecture enforcement:** <existing or proposed dependency tests, lint rules, or validator checks>
- **Research refs:** <research files or "external research not needed — reason">

### Risks
| 위험 | 영향 | 완화 | 근거 |
|------|------|------|------|
| <risk1> | HIGH/MED/LOW | <mitigation> | <research-XX or own analysis> |

### Success Criteria
- [ ] <measurable criterion 1>
- [ ] <measurable criterion 2>
- [ ] Codex 리뷰 LGTM (Phase 4)

### Estimated Time: <minutes>

---

## 📜 Version History

### v1 (<timestamp>) — Initial Draft (Claude)
- <key decisions in v1>

#### v1 Self-Review Result
- ✅ Passed: <N>/10
- ⚠️ Warnings: <list with item numbers>
- ❌ Failed: <list with item numbers>
- Action: <auto-fix to v2 / proceed to Codex critique>

#### v1 External Critique (codex / code-review-skill / skipped)
- Missing Pieces: <list>
- Hidden Risks: <list>
- Better Approaches: <list>
- LGTM: YES / NO

---

## ✅ Self-Review Checklist (latest)

### 1. 요청 정확성
- [ ] 사용자 요청의 핵심 의도를 정확히 파악
- [ ] 명시적 요구사항 모두 phase로 반영
- [ ] 암묵적 요구사항(테스트, 문서) 누락 없음

### 2. Phase 분해
- [ ] 각 phase가 측정 가능한 산출물 보유
- [ ] phase 간 의존성 명시
- [ ] 단일 phase가 너무 크지 않음 (1~3 파일 권장)

### 3. 의존성
- [ ] 외부 라이브러리/도구 의존성 명시
- [ ] 버전 제약 명시 (있으면)
- [ ] 기존 코드와의 통합점 식별

### 4. 위험 식별
- [ ] 최소 3개 위험 식별
- [ ] 각 위험에 영향도(HIGH/MEDIUM/LOW) 부여
- [ ] HIGH 위험은 완화 방안 보유

### 5. 단순화 검토
- [ ] 더 단순한 구현 검토
- [ ] 불필요한 추상화/일반화 없음
- [ ] YAGNI 원칙 준수

### 6. 외부 정보 필요성
- [ ] 외부 리서치 필요 여부 판단
- [ ] (필요시) 리서치 서브에이전트 호출 완료 및 결과 반영
- [ ] DDD / 코드베이스 설계 판단이 구현 구조에 영향이면 딥 리서치 수행

### 7. DDD / 코드베이스 설계 정합성
- [ ] 공통 업무 언어와 코드 이름이 충돌하지 않음
- [ ] bounded context 를 넘는 변경은 명시적으로 경계 처리
- [ ] aggregate / invariant 판단이 실제 업무 규칙과 연결됨
- [ ] 기존 코드와 DDD 목표 구조가 충돌하면 DDD 목표 구조를 우선함
- [ ] DDD 마이그레이션 계획과 rollback 경로를 포함함

### 8. 보안/성능 영향
- [ ] 보안 민감 영역 식별 (인증, 입력 검증, 시크릿)
- [ ] 성능 임팩트 고려 (DB, 메모리, IO)

### 9. Success Criteria
- [ ] 완료 판단 기준 명시
- [ ] 테스트 가능한 기준
- [ ] 사용자 확인 포인트

### 10. 예상 시간
- [ ] 각 phase 예상 시간 합리적
- [ ] 전체 시간 작업 규모에 적절

### 11. 사용자 기대 정합성
- [ ] 사용자 요청이 암시한 결과와 일치
- [ ] 함정(side effect) 명시

---

## 🔍 External Critique (Phase 1.2)

(이 섹션은 Phase 1.2 완료 후 채워짐)

### Codex Critique (or code-review skill fallback)
- **Method:** <codex | code-review-skill | self-only>
- **Missing Pieces:** <list>
- **Hidden Risks:** <list>
- **Better Approaches:** <list>
- **Scope Issues:** <list>
- **Critical Issues:** <list>
- **LGTM:** <YES/NO>

---

## 👤 User Feedback Log

(이 섹션은 Phase 1.3 user approval에서 사용자 피드백 발생 시 채워짐)

### Round 1 (v<N> → v<N+1>)
- 사용자 피드백: "<verbatim feedback>"
- 반영: <change description>

---

## 📚 Linked Research Files

(메인 Claude 가 리서치 수행 시 자동 추가)

- research-<REQUEST_ID>-01-<slug>.md — <topic>
- research-<REQUEST_ID>-02-<slug>.md — <topic>

---

## 🎯 Approval

- **Status:** <approved | pending | rejected>
- **Approved at:** <ISO_TIMESTAMP>
- **Final version:** v<N>
- **Total revisions:** <count> (limit: 3)
- **Final critique:** <Codex LGTM / code-review-skill LGTM / self-only>
