#!/usr/bin/env python3
"""Fast (~1s) preflight checks for smart_review_feedback."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FORBIDDEN_SUFFIXES = (".jks", ".keystore")
FORBIDDEN_NAMES = {"key.properties", "google-services.json", ".env"}


def main() -> int:
    errors: list[str] = []
    for rel in (
        "pubspec.yaml",
        "analysis_options.yaml",
        "lib/smart_review_feedback.dart",
        "README.md",
        "LICENSE",
    ):
        if not (ROOT / rel).is_file():
            errors.append(f"Missing required file: {rel}")

    for path in ROOT.rglob("*"):
        if ".git" in path.parts or ".dart_tool" in path.parts:
            continue
        if path.is_file():
            if path.name in FORBIDDEN_NAMES or path.suffix in FORBIDDEN_SUFFIXES:
                errors.append(f"Forbidden secret file found: {path.relative_to(ROOT)}")

    if errors:
        for err in errors:
            print(f"[FAIL] {err}", file=sys.stderr)
        return 1

    print("[OK] smart_review_feedback preflight passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
