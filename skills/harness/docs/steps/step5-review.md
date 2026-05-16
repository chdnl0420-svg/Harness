# step5. 리뷰

**산출물**: `review-<slug>.md` (하나에 누적)

**입력 게이트**:
- `.harness/progress-<slug>.md` 와 step4 에서 변경된 파일 목록을 확인.
- 변경 없는 빈 step4 면 리뷰 자체를 건너뛰고 사용자에게 보고 후 결정 요청.

**흐름**:
1. Codex 가 코드 리뷰 (n차)
   - Codex 호출이 불가하면 fallback: `code-review` skill (Skill tool, skill="code-review") — 메인 Claude 가 직접 수행
2. **(필요 시) 외부 검증 — `harness-deep-researcher` 위임** — 리뷰어 응답이 다음 신호 중 하나라도 보이면 LGTM 추출 **전에** 리서치 실시:
   - *"verify against current standards / latest docs / 최신 권고 확인 필요"* 류 표현
   - 사용한 라이브러리·API 의 deprecated · breaking change 여부 확인 요청
   - 보안 권고(OWASP / NIST / CVE) 충족 여부 확인 요청
   - *"이 결정이 2026 모범 사례 인지 확인 필요"* 류 메타 신호
   - 위임 방식·산출물 양식은 [harness-plan SKILL.md Phase 2](../../../harness-plan/SKILL.md) 와 동일 (Topic / Tier / Context / 조사 일자 + `.harness/research/research-<slug>-<NN>-<topic>.md` 저장).
   - 위임 prompt 는 **[Learning Prepend 계약](../workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통) 1·2·3·4 단계 수행 필수** — `harness-deep-researcher.md` 학습 파일 2개 (공용 + 프로젝트) Read 후 `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더로 prepend. 누락 시 도우미가 `[BLOCKED]` 로 거부.
   - `.harness/.noagent` 있으면 메인 Claude 직접 (동일 환각 차단 4규칙 적용 + 학습 파일 본인이 Read).
   - 리서치 결과는 `review-<slug>.md` 의 *"외부 검증"* 섹션으로 누적하고, 그 결과를 반영해 리뷰어에게 **재호출** 하거나 메인 Claude 가 LGTM 판정에 반영.
3. 결과를 `review-<slug>.md` 에 누적
4. LGTM 판정 → 흐름 다이어그램 분기 따름
   - LGTM: YES → step6 (QA 테스트) 로 진행
   - LGTM: NO → step3 (구현 계획 수정) 로 되돌림. 동일 문제 5회 반복 시 중단 + 사용자에게 알림

# 반드시 지켜야 할 사항

- 리뷰는 직접 문제를 수정할 수 없다. 따라서 리뷰 결과가 LGTM: NO이면 반드시 step3로 되돌아가야 한다.
- Codex 에 보낼 prompt 는 **리뷰 대상 파일의 본문을 합쳐 넣지 말고 경로만 적는다.** Codex 가 file-read 도구로 직접 읽는다. 양식은 [/harness-review](../../../commands/harness-review.md) Step 2-A / Step 3 와 동일 — `[Files to review]` 섹션에 프로젝트 루트 기준 상대 경로만 한 줄씩.

## LGTM 추출 규칙 (CRITICAL — 임의 해석 금지)

리뷰어 응답에서 LGTM 판정은 다음 규칙으로만 추출한다:

1. **명시적 라벨이 있을 때만 YES** — 응답 본문에 다음 중 하나가 단독으로 명시되어야 한다:
   - `LGTM: YES` / `LGTM YES` / `최종 판정: LGTM`
   - `Verdict: APPROVE` / `Approved`
2. **다음은 모두 NO 로 간주**:
   - 명시 라벨 없음
   - "대체로 괜찮으나…", "minor 만 있음", "전반적으로 LGTM 이지만…" 같은 *조건부* 표현
   - CRITICAL / HIGH 등급 결함이 하나라도 언급됨
   - 응답이 모호하거나 잘렸음
3. **메인 Claude 가 코드를 직접 고친 뒤 LGTM:YES 처리 금지** — 수정이 필요하면 step3 로 되돌아가 정식 루프를 탄다.
4. 동일 결함이 5회 반복되면 중단 후 사용자에게 보고. 자체 판단으로 풀지 않는다.

`review-<slug>.md` 에는 매 회차마다 다음을 명시:

```markdown
## Run #<N> — <날짜·시간>
- 리뷰어: Codex | code-review skill
- 추출된 판정: LGTM YES | LGTM NO
- 판정 근거: <응답 본문에서 라벨이 등장한 줄 인용 또는 "라벨 없음">
- 주요 지적: <목록>
- 다음 행동: step6 진입 | step3 회송
```
