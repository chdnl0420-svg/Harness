# Learning Data: harness-security-reviewer

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-security-reviewer` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] SSRF 차단 목록은 IPv4/IPv6 정규 표현 외에 6to4(`2002::/16`), IPv4-mapped IPv6(`::ffff:0:0/96`), 십진수/옥탈/헥스 인코딩 IP를 반드시 커버해야 한다. 표준 URL 파서(`new URL()`)는 이런 비표준 형식을 정규화하지 않는다.
- [2026-05-14] OWASP Top 10:2025 에서 SSRF 는 A01 Broken Access Control 하위로 통합, A03 Software Supply Chain Failures 신설 — 리뷰 범위에 dependency provenance(출처 서명) 와 lockfile 무결성 포함. 근거: OWASP Top 10:2025 (A01, A03).
- [2026-05-14] 패스워드 해싱은 Argon2id. RFC 9106 SECOND RECOMMENDED (메모리 제약 환경): m=64 MiB, t=3, p=4. FIRST RECOMMENDED: m=2 GiB, t=1, p=4. bcrypt/PBKDF2 는 레거시 호환 한정. salt 는 사용자별 cryptographically random 128-bit 이상. 근거: OWASP Password Storage Cheat Sheet 2024, RFC 9106 §4.
- [2026-05-14] (training) Defense in Depth — 단일 컨트롤 (예: WAF only) 실패 시 전체 노출되는 구조 금지. 입력 검증 + 인증/인가 + 출력 인코딩 + 모니터링/알람 + 응답 자동화 5층 이상 중첩. 근거: NIST SP 800-53; OWASP ASVS.
- [2026-05-14] (training) Least Privilege — 토큰/키/롤은 "필요한 최소 동작 + 최소 자원 + 최소 기간". long-lived admin token 발견 시 즉시 STS / 단기 token + role assumption 로 교체 권고. 근거: AWS IAM Best Practices; NIST AC-6.

## Patterns
잘 통하는 접근법.

- [2026-05-14] DNS rebinding 완화를 위한 `safeFetch` 패턴: URL 파싱 → 문자열 검증 → DNS resolve4/6 → 결과 IP CIDR 재검증 → IP 직접 연결 fetch. 검증과 사용 사이의 시점 분리(TOCTOU) 를 이 패턴으로 줄일 수 있다.
- [2026-05-14] SSRF 방어는 deny-list(CIDR) 만으로 불충분. allow-list + DNS 결과 IP 고정(pinning) + HTTP redirect 비허용 + 클라우드 metadata 별 필수 헤더 강제 (AWS IMDSv2 PUT+token, GCP `Metadata-Flavor: Google`, Azure `Metadata: true`) 조합. 근거: OWASP SSRF Prevention; CVE-2025-53767 (Azure OpenAI metadata).
- [2026-05-14] Prototype pollution 3계층 방어: (1) 스키마 검증 `additionalProperties: false` 로 `__proto__`/`constructor` 차단 (AJV/Zod), (2) KV 저장은 `Map` 또는 `Object.create(null)`, (3) Node `--disable-proto=delete`. 2024년 CVE-2024-21505, CVE-2024-54152 등 반복. 근거: OWASP Prototype Pollution Cheat Sheet.
- [2026-05-14] JWT 검증은 서버에서 알고리즘 하드코딩 고정. `alg` 헤더 신뢰 시 alg:none, RS256↔HS256 confusion, kid SQLi/path traversal 3종 공격 노출. HS256 시 secret ≥ 256-bit cryptographically random. 근거: PortSwigger Web Security Academy JWT Attacks.
- [2026-05-14] 공급망 보안: SLSA Level 2+ + Sigstore/cosign 서명 검증을 빌드 파이프라인에 내재화. GitHub Actions 는 tag 가 아닌 commit SHA 로 pin (GhostAction 2025). npm provenance + npm audit + socket.dev 병용으로 typosquatting / dependency confusion 탐지. 근거: SLSA 프레임워크; Sonatype State of the Software Supply Chain 2024.
- [2026-05-14] (training) Rate limiting 은 사용자 / IP / 엔드포인트 / 자원 비용 4축 다층 적용. 단일 글로벌 limit 은 정교한 공격자에게 무의미. token bucket + sliding window 조합이 burst 와 sustained 모두 커버. 근거: OWASP API4:2023 Unrestricted Resource Consumption; Cloudflare rate limiting 가이드.
- [2026-05-14] (training) 파일 업로드 검증 4단: extension whitelist → MIME 헤더 → magic bytes (실제 파일 시그니처) → AV/sandbox scan. extension 만 검사는 가장 흔한 RCE 경로. 근거: OWASP File Upload Cheat Sheet.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] URL validator 가 `new URL().hostname` 만 추출하고 CIDR 검증만 수행하는 패턴은 `http://2130706433/` 같은 정수형 IP, 옥탈/헥스 표기, 6to4 IPv6 인코딩에 취약하다. 반드시 IPv4/IPv6 정규화 단계를 추가해야 한다.
- [2026-05-14] 차단 사유(`BlockedUrlError.reason`)를 HTTP 응답에 그대로 노출하면 공격자에게 내부 인프라 토폴로지 정보를 제공한다. 외부 응답은 일반 메시지, 상세 이유는 내부 로그 전용으로 분리해야 한다.
- [2026-05-14] In-memory URL store 에 size cap 없이 무한 적재를 허용하면 OOM DoS 벡터가 된다. 최대 엔트리 수 또는 LRU eviction 정책이 필수다.
- [2026-05-14] "사용자 없음" 분기에서 password verification 건너뛰기 금지. bcrypt ~166ms vs 즉시 반환 ~0.6ms 차이가 username enumeration 게이트 (CVE-2024-45052). 항상 dummy hash 연산 + 재설정 토큰은 `crypto.timingSafeEqual`. 근거: CWE-208.
- [2026-05-14] 프로덕션 응답에 stack trace / DB 스키마 / 내부 경로 노출 금지. `X-Powered-By` / `Server` 헤더 / 상세 SQL 오류 → 기술 스택·쿼리 구조 노출. sequential integer ID 는 IDOR/BOLA 게이트 → UUID v4 또는 불투명 토큰. 오류는 상관 ID 만 반환, 상세는 서버 로그. 근거: OWASP API Security 2023 API1:BOLA; CWE-209.
- [2026-05-14] (training) PII (이메일/전화/주민번호/카드번호) 가 INFO 레벨 로그에 평문 노출 → GDPR / CCPA / 개인정보보호법 위반 + 로그 수집 인프라 (Splunk/Elastic/CloudWatch) 가 secondary 침해 표적. 마스킹 또는 hash 필수. 근거: GDPR Art.32; OWASP Logging Cheat Sheet.
- [2026-05-14] (training) CORS `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true` 조합은 사양상 불가능하지만, 일부 브라우저가 관대히 해석하던 시기 잔재 코드가 남아 있으면 cross-origin credential theft. allow-list 화이트리스트만 허용. 근거: MDN CORS; PortSwigger CORS labs.

## Project-Specific
프로젝트별 컨벤션. 공용 파일에서는 비어 있음.

(비어 있음)

## Open Questions
아직 결론 안 난 것.

- [2026-05-14] 6자리 base62(35.7비트) vs 8자리(41비트) 엔트로피 선택 기준: 서비스 예상 URL 수가 10만을 초과할 경우 8자리로 증설하는 것이 Birthday paradox 충돌 확률을 실용적 수준 이하로 낮춘다.
- [2026-05-14] AES-GCM 분산 환경에서 96-bit random nonce 의 birthday bound (2^32 메시지 후 collision 급증) 임계점을 어느 기준으로 키 로테이션 트리거로 삼을지 — counter 기반 nonce 가 항상 현실적 옵션인지 — 구현 환경마다 정책 결정 필요. 근거: NIST SP 800-38D; "Nonce-Disrespecting Adversaries".
