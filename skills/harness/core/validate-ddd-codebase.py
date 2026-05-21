#!/usr/bin/env python3
"""
Validate that Harness keeps DDD/TDD as strong recommendations through step2-step4.

Usage:
  python validate-ddd-codebase.py --skill-root <path-to-harness-skill>
  python validate-ddd-codebase.py --skill-root <path> --project <repo> --slug <slug> --require-artifacts

Exit codes:
  0 = PASS
  1 = validation failed
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


MASTER_CHECKS = {
    "harness-plan/SKILL.md": [
        "DDD 도메인 모델",
        "DDD 도메인 모델링 강제 권고",
        "DDD 목표 구조",
        "단계적 migration plan",
        "DDD 강제 권고 점검",
    ],
    "harness/docs/steps/step2-domain.md": [
        "DDD 도메인 설계 강제 권고",
        "목표 구조를",
        "구현 계획의 기본 기준",
        "DDD 목표 구조로 옮기는 migration plan",
    ],
    "harness/docs/steps/step3-impl-plan.md": [
        "코드베이스 설계 리서치",
        "DDD 코드베이스 매핑",
        "DDD 마이그레이션 계획",
        "DDD 목표 구조 우선",
        "Formal DeepResearch",
        "Research Log",
        "TDD Formal DeepResearch",
        "TDD 테스트 로드맵 강제 권고",
        "TDD RED/GREEN/REFACTOR 계획",
        "Architecture Decision / Views",
        "Fitness Function / Enforcement",
        "위 11개 섹션",
        "필수 검토 산출 섹션",
        "강제 권고",
        "`chunks-overview` 는 요약 산출물",
    ],
    "harness/docs/steps/step4-impl.md": [
        "step3 의 11개 필수 검토 섹션",
        "implementation-<slug>-chunk-<i>.html",
        "implementation-<slug>-chunks-overview.html",
        "DDD 코드베이스 매핑",
        "DDD 마이그레이션 계획",
        "TDD 강제 권고",
        "RED 증거 기록",
        "GREEN 최소 구현",
        "REFACTOR 재검증",
    ],
    "harness/docs/workflow.md": [
        "DDD 코드 매핑",
        "DDD 마이그레이션 계획",
        "강제 권고",
        "TDD 테스트 로드맵",
        "RED/GREEN/REFACTOR",
    ],
    "harness/templates/plan.md": [
        "Target DDD Structure",
        "Migration Plan",
        "Domain Events",
        "Repository / Adapter Boundary",
        "Persistence / Transaction Boundary",
        "Architecture Decision / Views",
        "Fitness Function / Enforcement",
        "Architecture enforcement",
        "TDD Plan",
        "Behavior under test",
        "Test oracle",
        "RED",
        "GREEN",
        "REFACTOR",
        "강제 권고",
        "TDD exception",
    ],
    "harness/docs/donot.md": [
        "test-after-code 금지 수준의 강제 권고",
        "RED 실패 증거 없는 GREEN 주장 금지 수준의 강제 권고",
    ],
    "harness/docs/procedures/deep-research-procedure.md": [
        "DDD 적용 방식",
        "코드베이스 설계 방식",
        "Formal DeepResearch",
        "최소 **50회**",
        "Research Log",
    ],
}

SOFTENING_WARNINGS = [
    "기존 구조 우선",
    "최소 변경",
    "전술 DDD 불필요",
    "현재 구조 안에서",
    "기존 도구나 단순 구조 우선",
    "대형 리팩토링을 추가하지",
    "smallest compatible",
    "preserve current architecture",
    "preserve existing",
]

DOMAIN_REQUIRED = [
    "DDD 도메인 모델",
    "공통 업무 언어",
    "Bounded Context",
    "Aggregate",
    "Invariant",
    "Domain Event",
    "Context Map",
]

IMPLEMENTATION_REQUIRED = [
    "코드베이스 설계 리서치",
    "DDD 코드베이스 매핑",
    "DDD 마이그레이션 계획",
    "Architecture Decision",
    "Fitness Function",
    "TDD RED",
    "GREEN",
    "REFACTOR",
    "단계별 구현 순서",
    "테스트 전략",
    "위험",
]

CHUNKS_OVERVIEW_REQUIRED = [
    "chunk_id",
    "DDD 코드베이스 매핑",
    "DDD 마이그레이션 계획",
    "bounded context",
    "aggregate",
    "rollback",
]


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8-sig")


def resolve_skill_root(raw: str | None) -> Path:
    if raw:
        root = Path(raw).expanduser().resolve()
    else:
        root = Path(__file__).resolve().parents[1]

    if (root / "SKILL.md").exists():
        return root
    if (root / "harness" / "SKILL.md").exists():
        return root
    raise ValueError(f"Cannot find Harness skill root from: {root}")


def skill_file(skill_root: Path, relative: str) -> Path:
    if (skill_root / "SKILL.md").exists():
        if relative.startswith("harness/"):
            return skill_root / relative.removeprefix("harness/")
        if relative.startswith("harness-plan/"):
            return skill_root.parent / relative
    return skill_root / relative


def check_required(path: Path, required: list[str], errors: list[str]) -> None:
    if not path.exists():
        errors.append(f"MISSING file: {path}")
        return
    text = read_text(path)
    for marker in required:
        if marker not in text:
            errors.append(f"MISSING marker in {path}: {marker}")


def check_forbidden(paths: list[Path], errors: list[str]) -> None:
    for path in paths:
        if not path.exists() or path.is_dir():
            continue
        text = read_text(path)
        for phrase in SOFTENING_WARNINGS:
            if phrase in text:
                errors.append(f"SOFTENING phrase in {path}: {phrase}")


def check_recommended(path: Path, recommended: list[str], warnings: list[str]) -> None:
    if not path.exists():
        warnings.append(f"MISSING recommended-check file: {path}")
        return
    text = read_text(path)
    for marker in recommended:
        if marker not in text:
            warnings.append(f"MISSING recommended marker in {path}: {marker}")


def check_softening(paths: list[Path], warnings: list[str]) -> None:
    for path in paths:
        if not path.exists() or path.is_dir():
            continue
        text = read_text(path)
        for phrase in SOFTENING_WARNINGS:
            if phrase in text:
                warnings.append(f"SOFTENING phrase in {path}: {phrase}")


def validate_master(skill_root: Path) -> list[str]:
    errors: list[str] = []
    checked_paths: list[Path] = []
    for relative, required in MASTER_CHECKS.items():
        path = skill_file(skill_root, relative)
        checked_paths.append(path)
        check_required(path, required, errors)
    return errors


def find_artifact(project: Path, slug: str | None, prefix: str) -> list[Path]:
    harness_dir = project / ".harness"
    if not harness_dir.exists():
        return []
    if slug:
        return sorted(harness_dir.glob(f"{prefix}-{slug}*.html"))
    return sorted(harness_dir.glob(f"{prefix}-*.html"))


def split_implementation_artifacts(paths: list[Path]) -> tuple[list[Path], list[Path]]:
    overviews = [path for path in paths if path.name.endswith("-chunks-overview.html")]
    details = [path for path in paths if path not in overviews]
    return details, overviews


def validate_project(project: Path, slug: str | None, require_artifacts: bool) -> list[str]:
    errors: list[str] = []
    warnings: list[str] = []

    if not project.exists():
        return [f"MISSING project path: {project}"]

    domains = find_artifact(project, slug, "domain")
    implementation_paths = find_artifact(project, slug, "implementation")
    implementations, chunk_overviews = split_implementation_artifacts(implementation_paths)

    if not domains:
        msg = f"MISSING domain artifact under {project / '.harness'}"
        (errors if require_artifacts else warnings).append(msg)
    for path in domains:
        check_recommended(path, DOMAIN_REQUIRED, warnings)

    if not implementations:
        msg = f"MISSING implementation artifact under {project / '.harness'}"
        (errors if require_artifacts else warnings).append(msg)
    for path in implementations:
        check_recommended(path, IMPLEMENTATION_REQUIRED, warnings)

    for path in chunk_overviews:
        check_recommended(path, CHUNKS_OVERVIEW_REQUIRED, warnings)

    check_softening(domains + implementations + chunk_overviews, warnings)

    for warning in warnings:
        print(f"WARN: {warning}")
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skill-root", help="Harness skill root or skills root")
    parser.add_argument("--project", help="Project root to validate .harness artifacts")
    parser.add_argument("--slug", help="Artifact slug, without domain-/implementation- prefix")
    parser.add_argument("--require-artifacts", action="store_true")
    args = parser.parse_args(argv)

    try:
        skill_root = resolve_skill_root(args.skill_root)
    except ValueError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    errors = validate_master(skill_root)

    if args.project:
        errors.extend(
            validate_project(
                Path(args.project).expanduser().resolve(),
                args.slug,
                args.require_artifacts,
            )
        )

    if errors:
        print("DDD_CODEBASE_VALIDATION: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("DDD_CODEBASE_VALIDATION: PASS")
    print(f"skill_root: {skill_root}")
    if args.project:
        print(f"project: {Path(args.project).expanduser().resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
