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
- [2026-05-15] (training) **OWASP Top 10:2025 구조 변화** — A01 Broken Access Control (SSRF 흡수 — CWE-918 → A01 하위) → A02 Security Misconfiguration (5위 → 2위 급등) → **A03 Software Supply Chain Failures 신설** (2021 A06 확장) → A04 Cryptographic Failures (2위 → 4위) → A05 Injection (3위 → 5위) → A06 Insecure Design → A07 Authentication Failures → A08 Software/Data Integrity → A09 Logging & Alerting → **A10 Mishandling of Exceptional Conditions 완전 신규** (fail-open 로직·복원력 문제 통합). 데이터: NVD CVE→CWE 매핑 175,000+ / 애플리케이션 280만+ 분석. 근거: owasp.org/Top10/2025 공식.
- [2026-05-15] (training) **AI 생성 코드 리뷰 TOP 5 CWE 체크리스트** — 7,703 파일 / 1,236,725 LOC 분석 (ChatGPT·Copilot·CodeWhisperer·Tabnine). 1위 **CWE-563** 미사용 변수 대입 (1,412건), 2위 **CWE-396** 제네릭 예외 catch (379건), 3위 **CWE-561** Dead Code (210건), 4위 **CWE-772** 유효 수명 후 리소스 미해제 (142건), 5위 **CWE-390** 오류 조건 탐지 후 무처리 (119건). 언어별 취약률: Python 16~18%, JavaScript 8~9%, TypeScript 2.5~7%. *"Language characteristics influence vulnerabilities more than the AI tool itself"*. AI 귀속 CVE 2026-01 6건 → 2월 15건 → 3월 35건 급증. → AI 생성 코드 리뷰 시 dead code + 에러 무처리 + 리소스 미해제 3종을 1순위 체크. 근거: arXiv 2510.26103 (ACM TOSEM).
- [2026-05-15] (training) **공급망 보안 2026 — SLSA v1.1 + Sigstore + GitHub Actions 워크플로 보호** — SLSA v1.1 안정화 (이전 Level 4 → Level 3 통합, hermetic/재현 가능 빌드는 권고로 전환). Level 3 핵심: 격리·에페머럴 빌드 환경 + 서명 비밀 키 보호. Sigstore+SLSA Level 2 달성이 GitHub 내장 attestation + cosign + slsa-github-generator 로 반나절 수준 단축. **GhostAction 캠페인 (2025-09)**: 327 GitHub 계정 탈취 → 817 repos 에 *"Add Github Actions Security workflow"* 위장 워크플로 주입 → 3,325 credential 탈취 (DockerHub / PAT / npm / PyPI / AWS / Cloudflare). 별도 tj-actions/changed-files (2025-03): 23,000+ repos 영향. → GitHub Actions 워크플로 파일 변경은 **PR 리뷰 필수**, 평소 없던 `curl POST + 외부 도메인` 패턴 = exfiltration 신호. **npm/PyPI**: 2025-07~2026-01 사이 128 phantom 패키지 / 121,539 다운로드, typosquatting 플래그 3,658건 중 86.1% 가 실제 악성. 근거: stepsecurity.io GhostAction 분석; practical-devsecops SLSA guide; OWASP GenAI.
- [2026-05-15] (training) **AI Agent / MCP 신규 취약점 패턴** — **EchoLeak** (CVE-2025-32711, CVSS 9.3): Microsoft 365 Copilot 제로클릭 prompt injection → OneDrive/SharePoint/Teams 외부 exfiltration. **Flowise RCE** (CVE-2025-59528, CVSS 10.0): CustomMCP 노드가 외부 MCP 서버 설정 중 JavaScript 보안 검증 없이 실행, 12,000+ 인스턴스 노출. **Anthropic Git MCP exploit chain** (2026-01-20): CVE-2025-68143 (경로 순회) + 68144 (인수 주입) + 68145 (스코핑 우회) 3-CVE 로 prompt injection 만으로 RCE. **PoisonedRAG** (USENIX Security 2025): 5개 정교한 문서로 AI 응답 90% 조작. **OWASP Agentic AI Top 10 (2025-12)**: ASI01 Agent Goal Hijack / ASI02 Tool Misuse / ASI03 Identity Abuse / ASI04 Agentic Supply Chain / ASI05 Unexpected Code Execution / ASI06 Memory Poisoning / ASI07 Insecure Inter-Agent Comm / ASI08 Cascading Failures / ASI09 Human-Agent Trust Exploit / ASI10 Rogue Agents. 2025 조사: 프로덕션 AI 배포의 73% prompt injection 취약. 근거: genai.owasp.org; thehackernews.com.
- [2026-05-15] (training) **Secrets scanning 도구 FP 율 2026** — Gitleaks 5~15% (regex, 튜닝 없으면 과탐), TruffleHog 10~20% (검증 비활성) / <2% (live 검증 활성, 700+ 시크릿 타입), GitGuardian 1~3% (ML 필터, contextual 분석), detect-secrets 0~5% (베이스라인), GitHub Secret Scanning + Push Protection 94% FP 감소 (~150 서비스 통합). 권장 조합: Gitleaks (pre-commit 속도) + TruffleHog (CI/CD 깊이). 신규 스캐너 배포 시 1~2주 튜닝, 프로덕션 시크릿 rotation SLA 1시간 / 비프로드 1일. 근거: devsecops.ae 2026 비교; jit.io; github.blog 2025-08.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] URL validator 가 `new URL().hostname` 만 추출하고 CIDR 검증만 수행하는 패턴은 `http://2130706433/` 같은 정수형 IP, 옥탈/헥스 표기, 6to4 IPv6 인코딩에 취약하다. 반드시 IPv4/IPv6 정규화 단계를 추가해야 한다.
- [2026-05-14] 차단 사유(`BlockedUrlError.reason`)를 HTTP 응답에 그대로 노출하면 공격자에게 내부 인프라 토폴로지 정보를 제공한다. 외부 응답은 일반 메시지, 상세 이유는 내부 로그 전용으로 분리해야 한다.
- [2026-05-14] In-memory URL store 에 size cap 없이 무한 적재를 허용하면 OOM DoS 벡터가 된다. 최대 엔트리 수 또는 LRU eviction 정책이 필수다.
- [2026-05-14] "사용자 없음" 분기에서 password verification 건너뛰기 금지. bcrypt ~166ms vs 즉시 반환 ~0.6ms 차이가 username enumeration 게이트 (CVE-2024-45052). 항상 dummy hash 연산 + 재설정 토큰은 `crypto.timingSafeEqual`. 근거: CWE-208.
- [2026-05-14] 프로덕션 응답에 stack trace / DB 스키마 / 내부 경로 노출 금지. `X-Powered-By` / `Server` 헤더 / 상세 SQL 오류 → 기술 스택·쿼리 구조 노출. sequential integer ID 는 IDOR/BOLA 게이트 → UUID v4 또는 불투명 토큰. 오류는 상관 ID 만 반환, 상세는 서버 로그. 근거: OWASP API Security 2023 API1:BOLA; CWE-209.
- [2026-05-14] (training) PII (이메일/전화/주민번호/카드번호) 가 INFO 레벨 로그에 평문 노출 → GDPR / CCPA / 개인정보보호법 위반 + 로그 수집 인프라 (Splunk/Elastic/CloudWatch) 가 secondary 침해 표적. 마스킹 또는 hash 필수. 근거: GDPR Art.32; OWASP Logging Cheat Sheet.
- [2026-05-14] (training) CORS `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true` 조합은 사양상 불가능하지만, 일부 브라우저가 관대히 해석하던 시기 잔재 코드가 남아 있으면 cross-origin credential theft. allow-list 화이트리스트만 허용. 근거: MDN CORS; PortSwigger CORS labs.
- [2026-05-15] (training) **AES-GCM Nonce Rotation — 현행 2^32 cap 유지, NIST Rev.1 확정 전** — 현행 NIST SP 800-38D (2007): 96비트 랜덤 nonce 사용 시 **2^32 메시지 상한** (충돌 확률 2^-32 이하 유지). 실용 트리거: 고트래픽 시스템 기준 **세션당 ~10억 메시지 이전 키 교체** 권고. 128바이트 메시지면 이론상 2^43.5 (~12.4조) 가능하나 표준 모드는 2^32 도달 전 교체. **NIST SP 800-38D Rev.1 Pre-Draft** (2025-01-06 공개, 의견수렴 2025-03-14 마감): 256비트 블록 (Rijndael-256) 기반 GCM 변형 → nonce 및 카운터 두 배 확장 → 2^64+ 호출 상한 검토. AES-XGCM / DNDK-GCM / XAES-256-GCM 등 키-nonce 도출 방식 논의. **확정 시점 미정** → 현재는 2^32 cap 유지, Rev.1 확정 후 재검토. 근거: NIST CSRC sp/800/38/d/r1/iprd; Neil Madden "Galois Counter Mode and Random Nonces" 2024-05.
- [2026-05-15] (training) **Base62 Token Entropy 권고** — OWASP Cheat Sheet: 세션 ID 최소 64비트 엔트로피. 보수적 표준: 128비트. base62 각 문자 ≈ log₂(62) = 5.954 비트 → 11자 ≈ 65비트 (OWASP 최소 충족), **22자 ≈ 131비트 (고보안 권고 충족)**. 신규 토큰 시스템 설계 시 22자 base62 권고. 근거: OWASP Session Management Cheat Sheet; NIST SP 800-63b 2025-07-24 개정.

## Project-Specific
프로젝트별 컨벤션. 공용 파일에서는 비어 있음.

(비어 있음)

## Open Questions
아직 결론 안 난 것.

- [2026-05-15] **NIST SP 800-38D Rev.1 확정 시점·내용** — 2025-01 pre-draft 이후 확정 타임라인 미공개. 256비트 블록 GCM 변형 (XAES-256-GCM 등) 채택 여부 불명. 확정 후 라이브러리 (Go/Rust/Java) 마이그레이션 영향 평가 필요.
- [2026-05-15] **SLSA Source Track 확정 시기** — Build Track 과 달리 Source Track 은 개발 중. 소스 무결성 전체 체인 완성 시점 미정.
- [2026-05-15] **AI 코드 취약점 도구별 세분화** — arXiv 2510.26103 은 언어 패턴이 도구 차이보다 크다고 결론지으나, Copilot vs Cursor vs Devin 개별 정량 비교 데이터 미공개.

## Resolved Questions
- [2026-05-15] **6자리 vs 8자리 base62 엔트로피 선택** → 해소. OWASP 최소 권고 64비트 → 11자 (=65비트) 충족, 고보안 권고 128비트 → 22자 (=131비트). 신규 토큰 시스템은 22자 권고. (Patterns 의 "Base62 Token Entropy 권고" entry 로 이동)
- [2026-05-15] **AES-GCM 96-bit random nonce 키 로테이션 트리거** → 부분 해소. 현행 NIST 기준 2^32 메시지 상한 유지, 실용 트리거 "세션당 ~10억 메시지 이전 교체". NIST Rev.1 확정 시 재검토. (Patterns 의 "AES-GCM Nonce Rotation" entry 로 이동)
