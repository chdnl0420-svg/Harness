# Harness 사용 예시

## 예시 1: 깨끗한 통과 (간단)

```
사용자: /harness 이메일 검증 함수 user.py에 추가

[Phase 1.0] plan-<id>.md v1 작성
  - Phases: implement validate_email, add tests
  - Deps: re module (built-in)
  - Risks: regex 너무 단순할 수 있음, 빈 문자열 처리

[Phase 1.1] Self-Review: 10/10 ✅

[Phase 1.2] Codex Critique:
  Missing: 없음
  LGTM: YES ✅

[Phase 1.3] 사용자에게 plan v1 + critique 보고
사용자: "진행"

[Phase 1.5] approved

[Phase 3] Implement
  - user.py에 validate_email() 추가
  - test_user.py에 3개 테스트

[Phase 4] Review Iter 1
  - codex-reviewer 호출 → LGTM

[Phase 5] Complete
  - result-<id>.md 작성

총 소요: 2분
```

## 예시 2: Codex가 누락 찾음

```
사용자: /harness 결제 처리 API 추가

[Phase 1.0] plan v1
  - Phases: POST /payment, validation, DB save

[Phase 1.1] Self-Review: 8/10 (#4 위험 부족, #7 보안 미상세)

[Phase 1.4] Auto-fix:
  - 위험 3 → 5개로 확장
  - PCI DSS 영향 명시
  → plan v2

[Phase 1.1] 재검증: 10/10 ✅

[Phase 1.2] Codex Critique:
  Missing Pieces:
    - Idempotency key 누락
    - Webhook signature verification
  Hidden Risks:
    - Decimal precision (HIGH)
  LGTM: NO
  
  → Codex가 Idempotency 패턴 조사 권장 → Gemini Research 호출
  research-<id>-01-idempotency-patterns.md

[Phase 1.4] Revision (v3):
  - Idempotency middleware phase 추가
  - Webhook 서명 검증 추가
  - Decimal.js 의존성 추가

[Phase 1.2] Codex Critique v3: LGTM ✅

[Phase 1.3] 사용자: "진행"

[Phase 3, 4, 5] ... 진행

총 소요: 8분
```

## 예시 3: Codex 인증 실패 → Gemini fallback

```
사용자: /harness JWT 미들웨어 구현

[Phase 1.0] plan v1
[Phase 1.1] Self-Review 10/10
[Phase 1.2] Codex Critique:
  ⚠️ Codex 호출 실패 (exit=2, token_invalidated)
  → Gemini fallback 시도
  ✅ Gemini Plan Critique:
    Missing Pieces: Algorithm pinning 명시 권장
    LGTM: NO (minor)
  critique_method: gemini

[Phase 1.4] Revision (v2):
  - algorithms: ['RS256'] 명시

[Phase 1.2] Gemini Critique v2: LGTM ✅

[Phase 1.3] 사용자: "진행"

... (Phase 4에서도 Codex 실패 시 Claude code-reviewer fallback)

[Phase 5] result.md:
  ⚠️ "Codex 인증 만료. `codex login` 권장."
```

## 예시 4: Plan revision HARD LIMIT 도달

```
사용자: /harness 큰 리팩토링

[Phase 1.0] v1
[Phase 1.3] 사용자: "수정: A 추가"
[Phase 1.4] v2 (revision=1)
[Phase 1.3] 사용자: "수정: B"
[Phase 1.4] v3 (revision=2)
[Phase 1.3] 사용자: "수정: C"
[Phase 1.4] v4 (revision=3)
[Phase 1.3] 사용자: "수정: D"

⚠️ HARD LIMIT 도달

시스템:
"3회 revision 후에도 합의 미달성.
 옵션:
   (a) v4 그대로 진행
   (b) 작업 취소
   (c) harness 종료, 직접 Claude Code 사용"

사용자 선택에 따라 분기.
```

## 예시 5: Resume

```
[세션 1: 작업 시작]
사용자: /harness React Suspense 도입

[Phase 1~3 진행]
[Phase 4 Iter 1 진행 중 사용자 인터럽트]

progress.md status: in_progress, current_phase: 4-iter-1


[세션 2: 다음 날]
사용자: /harness resume

[Skill]
.harness/progress/ 스캔 → in_progress 파일 찾음:
- 20260512-220000-react-suspense (current: 4-iter-1)

복원 보고:
🔄 작업 재개: 20260512-220000-react-suspense
  현재 단계: Phase 4 Iter 1 (review 중)
  마지막 업데이트: 어제 22:30

Phase 4 Iter 1 재시작 (codex-reviewer 호출)
... 정상 진행
```

## 예시 6: 명시적 research 요청

```
사용자: /harness Vitest 도입

[Phase 1.0] plan v1 작성 중
Claude: "Vitest와 Jest 비교 정보 필요" 자동 판단
→ gemini-researcher 호출
→ research-<id>-01-vitest-vs-jest.md

plan v1에 research 인용 + Vitest 선정 근거

[Phase 1.3] 사용자: "Vite와 호환성도 조사해줘"
[Phase 1.4] Revision:
  → gemini-researcher: "Vitest Vite integration patterns"
  → research-<id>-02-vitest-vite.md
  → plan v2에 호환성 섹션 추가

... 계속
```

## 산출물 폴더 구조 (완료 후)

```
<project>/.harness/
├── plans/
│   └── plan-20260512-220000-jwt-middleware.md
├── progress/
│   └── progress-20260512-220000-jwt-middleware.md
├── research/
│   ├── research-20260512-220000-jwt-middleware-01-best-practices.md
│   └── research-20260512-220000-jwt-middleware-02-rs256-vs-es256.md
├── reviews/
│   ├── review-20260512-220000-jwt-middleware-iter-1.md
│   └── review-20260512-220000-jwt-middleware-iter-2.md
├── improvements/
│   └── improvement-20260512-220000-jwt-middleware-iter-1.md
└── results/
    └── result-20260512-220000-jwt-middleware.md
```

7개 파일, 모두 audit/resume/공유 가능.
