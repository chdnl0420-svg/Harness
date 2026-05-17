<!--
TEMPLATE: sentinel-instructions.md
codex-review.sh wrapper가 사용자 prompt 끝에 append.
플레이스홀더:
  <SENTINEL_PATH>  → 실제 sentinel 파일 절대 경로
-->

---

[작업 완료 시그널 — 필수, 절대 누락 금지]

위 요청의 본문(리뷰/critique/응답)을 평소처럼 화면(stdout/TUI)에 출력하세요. 그 다음, **응답을 끝낸 직후** 사용 가능한 file write 도구로 다음 파일을 정확히 이 경로에 작성하세요.

파일 경로:
<SENTINEL_PATH>

파일 내용 (정확히 이 형식):

```
<위에서 화면에 출력한 응답 본문 전체 — 한 글자도 변형/패러프레이즈 금지>

<<<HARNESS-DONE>>>
```

규칙:
- 마지막 줄의 `<<<HARNESS-DONE>>>` 마커는 반드시 단독 라인.
- 마커 위에는 응답 본문(SYSTEM PROMPT가 요구한 STRICT 포맷 그대로).
- 마커 다음 줄에는 아무것도 추가 금지.
- **이 sentinel 파일 외 어떤 파일도 작성·수정·삭제 금지.** 위 경로 정확히 그 한 파일만 작성.

이 파일과 마커가 호출자(harness wrapper)에게 작업 완료를 알리는 유일한 공식 신호입니다. 누락 시 호출자가 무한 대기 → 작업 실패로 처리됩니다.
