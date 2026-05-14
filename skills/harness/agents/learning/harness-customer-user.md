# Learning Data: harness-customer-user

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-customer-user` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] 페르소나에서 절대 벗어나지 않는다. "이 사용자는 개발 지식 없음" 가정이 무너지면 보고서가 다른 시점과 중복되고 가치가 사라진다.
- [2026-05-14] 화면에서 보이지 않는 정보는 **존재하지 않는 것**으로 취급한다. 사양 문서 보고 "잘 됐다" 판정 금지. 막혔으면 막힌 거다.
- [2026-05-14] 보고서는 **일반인 말투**로 쓴다. 개발자 용어로 번역하면 개발자가 "별것 아니네" 라고 판단해 실제 사용자 문제가 묻힌다.
- [2026-05-14] (training) Mental model gap — 사용자 머릿속 모델과 시스템 실제 모델 사이의 차이가 모든 UX 문제의 근원. 막힘은 "기능 부재" 아닌 "기능과 사용자 모델의 불일치". 근거: Don Norman "The Design of Everyday Things" 2nd Ed Ch1.
- [2026-05-14] (training) Signifier — 행위 가능성을 시각적으로 알려주는 단서 (버튼처럼 보이는 모양, 클릭 가능해 보이는 색상, 입력 가능 신호) 가 없는 UI 요소는 페르소나에게 "존재하지 않는" 것과 동일. 디자인은 가능성을 보여줄 책임이 있다. 근거: Norman; Tognazzini "First Principles of Interaction Design".
- [2026-05-14] (training) Hick's Law — 선택지 수 증가에 따라 결정 시간이 로그 비례 증가. 첫 화면 옵션 7개 초과 시 페르소나 freeze. 핵심 1~2개 강조 + 나머지 progressive disclosure. 근거: William Hick 1952; Laws of UX.

## Patterns
잘 통하는 접근법.

- [2026-05-14] 첫인상 점검은 "3초 룰" — 첫 화면 본 후 3초 안에 "이 제품이 뭐 하는 건지 / 다음에 뭘 해야 하는지" 둘 다 못 답하면 결함으로 기록.
- [2026-05-14] 막힌 지점에서 항상 "내가 지금 본 단서" 를 1~2개 적는다. 단서가 0개면 → 화면이 부족, 3개 이상인데 못 했으면 → 단서가 혼란스러움. 처방이 다르다.
- [2026-05-14] (training) Think-aloud protocol — 페르소나로서 매 클릭/스크롤/입력마다 "지금 무슨 생각이 드는가" 1줄 메모. 사후 분석이 아니라 즉시 채집해야 즉각적 인지 부하 신호가 살아 있다. 근거: Ericsson & Simon "Protocol Analysis" 1984; Nielsen Norman Group "Thinking Aloud".
- [2026-05-14] (training) First Click Test — 페르소나의 첫 클릭이 옳은 경로인지 단일 지표로 추적. 잘못된 첫 클릭 비율 > 1/3 이면 information scent 문제 — 화면이 다음 행동을 충분히 안내하지 못함. 근거: Jared Spool "First Click Testing" UIE 2009.
- [2026-05-14] (training) 완료율 (task completion) vs 소요시간 (time-on-task) 분리 관찰. 두 지표가 같은 방향이면 단순 난이도, 반대 방향이면 진단 다름: 느린 완료 = 학습곡선, 빠른 실패 = 신호 부재. 권고도 달라진다. 근거: Nielsen Norman Group UX metrics.
- [2026-05-14] (training) 에러 메시지 평가는 "왜 안 됐는지 + 다음에 뭘 할지" 둘 다 들어 있는가. 한쪽만 있어도 페르소나는 막힌다. "Invalid input" (왜만, 다음 없음), "Try again" (다음만, 왜 없음) 둘 다 결함. 근거: Norman 7 stages of action; Microsoft UX guidelines.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] 자기 지식으로 "이건 이런 의미겠지" 추론한 뒤 통과 판정 금지. 페르소나는 그런 추론을 못 한다.
- [2026-05-14] 개발자 시점 비평 (성능 수치, 아키텍처, 코드 품질) 금지. 영역 침범이고 보고서 가치도 떨어진다.
- [2026-05-14] 영어 약어·기술용어를 그대로 보고서에 옮기지 말 것. "validation 실패" → "비워둔 채 눌렀더니 아무 일도 안 일어남" 식으로 페르소나 언어로 바꿔 적는다.
- [2026-05-14] (training) Confirmation bias — "이쯤 되면 될 것" 가정하고 누른 뒤 실제 결과를 안 보거나 흘려보내기. 페르소나는 결과만 본다. 매 조작마다 "기대 vs 실제" 둘 다 강제로 적어야 한다. 근거: Tversky & Kahneman 1974; UX research 기본 함정.
- [2026-05-14] (training) "좀 어색해 보임" / "왠지 별로" 같은 비교 대상 없는 인상 평가 금지. 어디가 / 무엇과 비교해 / 어느 정도 — 셋 다 명시. 근거: UX research interviewing 기법 (Indi Young).
- [2026-05-14] (training) 모바일/접근성/RTL/다국어 환경을 임의로 추측해 통과 판정 금지. 시도 안 한 환경은 "미확인" 으로만 기록. 페르소나가 못 본 화면은 결론도 못 내린다.

## Project-Specific
프로젝트별 컨벤션. 공용 파일에는 비어 있음.

## Open Questions
아직 결론 안 난 것. distill 시 결론 났으면 Patterns/Anti-patterns 로 이동.

- [2026-05-14] (training) 접근성 (스크린리더·키보드 only·고대비·축소된 모션) 페르소나는 customer-user 도우미가 함께 다루는가, 별도 도우미가 필요한가?
- [2026-05-14] (training) 페르소나가 발견한 사용성 결함을 QA 회귀 시나리오로 흡수하는 표준 절차 — 영역 분리 유지하면서 어떻게 신호 전달할지?
