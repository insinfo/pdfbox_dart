#!/usr/bin/env python3
"""Utility to compare Dart ucar/jpeg/jj2000 ports with the original Java sources."""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable, List, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parents[1]
DART_ROOT = REPO_ROOT / "lib" / "src" / "ucar"
JAVA_ROOT = REPO_ROOT / "jj2000" / "src" / "main" / "java" / "ucar"

COMMENT_RE = re.compile(r"//.*?$|/\*.*?\*/", re.MULTILINE | re.DOTALL)
ATTRIBUTE_RE = re.compile(r"@\w+(?:\([^)]*\))?\s*", re.MULTILINE)

JAVA_CLASS_RE = re.compile(
    r"\b(?:public\s+|protected\s+|private\s+)?"
    r"(?:abstract\s+|final\s+)?"
    r"(?:class|interface|enum)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
)

DART_CLASS_RE = re.compile(
    r"\b(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)?"
    r"(?:class|mixin|enum)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
)

JAVA_METHOD_RE = re.compile(
    r"^\s*"
    r"(?:(?:public|protected|private|static|final|abstract|synchronized|native|strictfp|transient)\s+)*"
    r"(?:<[^>]+>\s+)?"
    r"(?:[A-Za-z_][\w<>\[\]\.\?]*\s+)+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(",
    re.MULTILINE,
)

DART_METHOD_RE = re.compile(
    r"^\s*"
    r"(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:external\s+)?(?:static\s+)?(?:final\s+)?(?:late\s+)?"
    r"(?:const\s+)?(?:factory\s+)?"
    r"(?:[A-Za-z_][\w<>?]*\s+)?"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(",
    re.MULTILINE,
)

DART_KEYWORDS = {"if", "for", "while", "switch", "return", "throw", "catch", "else", "assert", "case"}
JAVA_KEYWORDS = {"if", "for", "while", "switch", "return", "throw", "catch", "else", "assert", "case"}


def strip_comments(source: str) -> str:
    return re.sub(COMMENT_RE, "", source)


def extract_java_classes(text: str) -> Set[str]:
    return {m.group("name") for m in JAVA_CLASS_RE.finditer(text)}


def extract_dart_classes(text: str) -> Set[str]:
    return {m.group("name") for m in DART_CLASS_RE.finditer(text)}


def extract_java_methods(text: str, classes: Iterable[str]) -> Set[str]:
    methods = {m.group("name") for m in JAVA_METHOD_RE.finditer(text) if m.group("name") not in JAVA_KEYWORDS}
    for cls in classes:
        ctor_re = re.compile(
            rf"^\s*(?:public|protected|private)?\s+{re.escape(cls)}\s*\(",
            re.MULTILINE,
        )
        if ctor_re.search(text):
            methods.add(cls)
    return methods


def extract_dart_methods(text: str, classes: Iterable[str]) -> Set[str]:
    methods = {m.group("name") for m in DART_METHOD_RE.finditer(text) if m.group("name") not in DART_KEYWORDS}
    for cls in classes:
        ctor_re = re.compile(
            rf"^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:const\s+|factory\s+)?{re.escape(cls)}(?:\.(?P<named>[A-Za-z_][A-Za-z0-9_]*))?\s*\(",
            re.MULTILINE,
        )
        for match in ctor_re.finditer(text):
            named = match.group("named")
            methods.add(cls if named is None else f"{cls}.{named}")
    return methods


@dataclass
class FileReport:
    dart_relative: str | None
    java_relative: str | None
    dart_path: str | None
    java_path: str | None
    missing_java: bool
    missing_dart: bool
    path_mismatch: bool
    dart_classes: List[str]
    java_classes: List[str]
    extra_dart_classes: List[str]
    missing_dart_classes: List[str]
    dart_methods: List[str]
    java_methods: List[str]
    extra_dart_methods: List[str]
    missing_dart_methods: List[str]


def resolve_java_relative(dart_relative: str, java_map: dict[str, Path]) -> Tuple[str | None, bool]:
    normalized = dart_relative.replace("\\", "/")
    if normalized in java_map:
        return normalized, False
    needle = "jpeg/jj2000/"
    if normalized.startswith(needle):
        alt = "jpeg/" + normalized[len(needle):]
        if alt in java_map:
            return alt, True
    return None, False


def build_report_for_pair(
    dart_relative: str | None,
    java_relative: str | None,
    dart_path: Path | None,
    java_path: Path | None,
) -> FileReport:
    dart_source = dart_path.read_text(encoding="utf-8", errors="ignore") if dart_path else ""
    java_source = java_path.read_text(encoding="utf-8", errors="ignore") if java_path else ""
    dart_clean = strip_comments(dart_source)
    java_clean = strip_comments(java_source)
    dart_classes = sorted(extract_dart_classes(dart_clean))
    java_classes = sorted(extract_java_classes(java_clean))
    dart_methods = sorted(extract_dart_methods(dart_clean, dart_classes))
    java_methods = sorted(extract_java_methods(java_clean, java_classes))
    return FileReport(
        dart_relative=dart_relative.replace("\\", "/") if dart_relative else None,
        java_relative=java_relative.replace("\\", "/") if java_relative else None,
        dart_path=str(dart_path) if dart_path else None,
        java_path=str(java_path) if java_path else None,
        missing_java=java_path is None,
        missing_dart=dart_path is None,
        path_mismatch=(dart_relative and java_relative and dart_relative.replace("\\", "/") != java_relative.replace("\\", "/")),
        dart_classes=dart_classes,
        java_classes=java_classes,
        extra_dart_classes=sorted(set(dart_classes) - set(java_classes)),
        missing_dart_classes=sorted(set(java_classes) - set(dart_classes)),
        dart_methods=dart_methods,
        java_methods=java_methods,
        extra_dart_methods=sorted(set(dart_methods) - set(java_methods)),
        missing_dart_methods=sorted(set(java_methods) - set(dart_methods)),
    )


def main() -> None:
    dart_files = {f for f in DART_ROOT.rglob("*.dart") if f.is_file()}
    java_files = {f for f in JAVA_ROOT.rglob("*.java") if f.is_file()}

    java_map = {
        str(f.relative_to(JAVA_ROOT).with_suffix("")).replace("\\", "/"): f
        for f in java_files
    }
    matched_java: Set[str] = set()
    reports: List[FileReport] = []

    for dart_path in sorted(dart_files):
        dart_relative = str(dart_path.relative_to(DART_ROOT).with_suffix(""))
        java_relative, path_mismatch = resolve_java_relative(dart_relative, java_map)
        java_path = java_map.get(java_relative) if java_relative else None
        if java_relative:
            matched_java.add(java_relative)
        report = build_report_for_pair(dart_relative, java_relative, dart_path, java_path)
        report.path_mismatch = path_mismatch
        reports.append(report)

    for java_key, java_path in java_map.items():
        if java_key in matched_java:
            continue
        reports.append(
            build_report_for_pair(
                dart_relative=None,
                java_relative=java_key,
                dart_path=None,
                java_path=java_path,
            )
        )

    report = {
        "dart_root": str(DART_ROOT),
        "java_root": str(JAVA_ROOT),
        "files": [asdict(r) for r in reports],
    }

    output_path = REPO_ROOT / "build" / "reports" / "ucar_port_report.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"Report written to {output_path}")


if __name__ == "__main__":
    main()
