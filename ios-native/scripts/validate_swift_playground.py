#!/usr/bin/env python3
"""Validate the checked-in Swift Playground opener bundle."""

from pathlib import Path
import plistlib
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
PLAYGROUND = ROOT / "InspectFlowNative.playground"
CONTENTS = PLAYGROUND / "Contents.swift"
METADATA = PLAYGROUND / "contents.xcplayground"


def fail(message: str) -> int:
    print(f"FAIL: {message}")
    return 1


def main() -> int:
    if not PLAYGROUND.is_dir():
        return fail(f"missing playground bundle: {PLAYGROUND.relative_to(ROOT)}")
    if not CONTENTS.is_file():
        return fail("missing Contents.swift")
    if not METADATA.is_file():
        return fail("missing contents.xcplayground")

    text = CONTENTS.read_text()
    required_snippets = [
        "InspectFlow Native iOS Playground",
        "InspectFlowConnector",
        "ios-native/App",
        "ios-native/Core",
        "ios-native/Features",
        "ios-native/Shared",
        "InspectionModel",
    ]
    missing = [snippet for snippet in required_snippets if snippet not in text]
    if missing:
        return fail(f"Contents.swift missing required guidance: {', '.join(missing)}")

    try:
        plistlib.loads(METADATA.read_bytes())
    except Exception as exc:  # noqa: BLE001 - emit parser details for tool repair.
        return fail(f"contents.xcplayground is not valid XML property list: {exc}")

    result = subprocess.run(
        ["swift", "-frontend", "-parse", str(CONTENTS)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        return fail("Contents.swift does not parse with Swift")

    print("OK: Swift Playground opener bundle is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
