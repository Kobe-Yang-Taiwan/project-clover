#!/usr/bin/env python3
"""Fail CI if an upstream Gemini credential/API boundary leaks into Android."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_PATHS = [ROOT / "lib", ROOT / "android", ROOT / "pubspec.yaml"]
FORBIDDEN = (
    "GEMINI_API_KEY",
    "generativelanguage.googleapis.com",
    "x-goog-api-key",
)


def main() -> None:
    violations: list[str] = []
    for path in APP_PATHS:
        files = [path] if path.is_file() else path.rglob("*") if path.exists() else []
        for file in files:
            if not file.is_file():
                continue
            try:
                value = file.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for forbidden in FORBIDDEN:
                if forbidden in value:
                    violations.append(f"{file.relative_to(ROOT)}: {forbidden}")
    if violations:
        raise SystemExit("Upstream provider secret boundary violation:\n" + "\n".join(violations))
    print("Provider secret boundary verified: upstream Gemini API details are proxy-only.")


if __name__ == "__main__":
    main()
