# complete

**산출물**: `report-<slug>.html` (사람-친화 종합 보고서)

**입력 게이트 (CRITICAL — noask 예외, 반드시 통과 후 진입)**:

step8 commit/push 가 끝난 직후, complete 단계 진입 *전에* 메인 Claude 는 `AskUserQuestion` 으로 한 번 물어본다. 이는 noask 기본 정책의 **2 곳뿐인 예외 중 하나** — *워크플로우 본문의 결정 분기가 아니라 워크플로우 종료 후 후속 처리 방향* 이라서. (다른 1 곳은 step6 *동일 사유* BLOCKED 5회 누적 — workflow.md "noask 예외" 참조.)

**질문 양식**:
```
질문: "step7 커스터머 테스트 결과 (개선 제안 / 좋았던 점 / 헷갈린 단어 등) 가 customer-<slug>.md 에 정리되어 있습니다. 어떻게 처리하시겠어요?"
선택지:
- A. (Recommended) 그대로 complete 진행 — 개선안은 report 에 요약만 기록 후 종료
- B. 일시정지 — 사용자가 customer-<slug>.md 를 직접 검토한 후 별도 명령으로 재시작 (현 상태 보존)
- C. 개선안으로 신규 워크플로우 자동 시작 — customer-<slug>.md 의 *권고 / 있었으면 / 없었으면* 3 섹션을 한 줄 목표로 합성해 새 /harness 워크플로우 자동 진입
```

**분기**:
- **A 선택** → 흐름 1·2·3 그대로 진행. report 의 *"step7 후속 처리"* 섹션에 "사용자 그대로 진행 선택" 한 줄 + customer-<slug>.md 의 *권고 / 있었으면 / 없었으면* 3 섹션 요약 포함.
- **B 선택** → complete 진입 **하지 않음**. `.harness/.pending-step7-review` 빈 파일 생성 (재호출 시 이 마커로 상태 식별), `report-<slug>.html` 미작성, 사용자에게 한 줄 안내: *"customer-<slug>.md 검토 후 `/harness complete-resume` 또는 새 `/harness` 호출로 재진입"*. 워크플로우는 *일시정지* 상태로 종료.
- **C 선택** → 현 워크플로우는 흐름 1·2·3 그대로 *complete 완료 처리* (report 작성 + 종료) **+ 신규 /harness 워크플로우 자동 진입**:
  1. customer-<slug>.md 의 `## 권고` · `## 있었으면 하는 것` · `## 없었으면 하는 것` 3 섹션 본문을 합성해 *신규 한 줄 목표* 생성 (예: *"<원본 slug> 의 step7 개선 — <권고 1>, <있었으면 1>, <없었으면 1>"*).
  2. 신규 워크플로우의 progress 파일에 `auto_triggered_from: <원본 slug>` 필드 자동 기록.
  3. **무한 chain 차단 (CRITICAL)**: 신규 워크플로우의 step7 *complete 진입 게이트* 에서는 *C 선택지 비활성* (A·B 만 노출). progress 의 `auto_triggered_from` 존재 여부로 자동 판정. 사용자가 직접 호출한 워크플로우에서만 C 가 활성 — 자동→자동 chain 으로 인한 폭주 차단.
  4. 부모 워크플로우의 report 에 *"step7 → 신규 워크플로우 트리거: <child-slug>"* 한 줄 명시.
  5. 신규 워크플로우 진입 직후 사용자에게 한 줄 안내: *"부모 슬러그 <원본> 의 step7 개선안으로 신규 워크플로우 시작 — slug: <child-slug>"*.

**흐름** (입력 게이트 통과 후, 메인 Claude 가 자동):
1. 작업 결과 정리 (구현 + QA 회차 + 커스터머 테스트 결과 요약 포함)
2. `report-<slug>.html` 작성 — *"step7 후속 처리"* 섹션에 사용자 선택 + 개선 제안 요약 명시
3. `.harness/.noask` 마커 삭제 (워크플로우 종료)
4. 사용자에게 최종 요약 메시지 (report 절대경로 한 줄 보고)
