#!/usr/bin/env python3
"""Validate iOS embedded extension bundle identifiers are prefixed by the host app.

This catches Xcode's "Embedded binary's bundle identifier is not prefixed with the
parent app's bundle identifier" error before invoking a full xcodebuild.
"""
from __future__ import annotations

import re
import sys
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT_YML = ROOT / "project.yml"
PBXPROJ = ROOT / "AutoInspectorNetwork.xcodeproj" / "project.pbxproj"
HOST_TARGET = "AutoInspectorNetwork"
EMBEDDED_TARGETS = ("InspectFlowShareExtension", "AgendaWidgetExtensionExtension")
EXPECTED_BUNDLE_IDS = {
    HOST_TARGET: "com.autoinspectornetwork.ios",
    "InspectFlowShareExtension": "com.autoinspectornetwork.ios.InspectFlowShareExtension",
    "AgendaWidgetExtensionExtension": "com.autoinspectornetwork.ios.AgendaWidgetExtension",
}
INFO_PLISTS = {
    HOST_TARGET: ROOT / "AutoInspectorNetwork" / "Info.plist",
    "InspectFlowShareExtension": ROOT / "InspectFlowShareExtension" / "Info.plist",
    "AgendaWidgetExtensionExtension": ROOT / "AgendaWidgetExtension" / "Info.plist",
}
LEGACY_BUNDLE_ID_PREFIX = "ios.AutoInspectorNetwork"


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"missing required file: {path}")
    return path.read_text(encoding="utf-8")


def parse_xcodegen_bundle_ids(text: str) -> dict[str, str]:
    """Small, dependency-free parser for target PRODUCT_BUNDLE_IDENTIFIER values."""
    bundle_ids: dict[str, str] = {}
    current_target: str | None = None
    in_targets = False
    target_indent: int | None = None

    for line in text.splitlines():
        if re.match(r"^targets:\s*$", line):
            in_targets = True
            continue
        if in_targets and re.match(r"^[A-Za-z_][\w-]*:\s*$", line):
            break
        if not in_targets:
            continue

        target_match = re.match(r"^(\s{2})([A-Za-z0-9_][\w-]*):\s*$", line)
        if target_match:
            current_target = target_match.group(2)
            target_indent = len(target_match.group(1))
            continue

        if current_target and target_indent is not None:
            unindented = len(line) - len(line.lstrip(" "))
            if line.strip() and unindented <= target_indent:
                current_target = None
                target_indent = None
                continue
            setting_match = re.match(r"^\s+PRODUCT_BUNDLE_IDENTIFIER:\s*['\"]?([^'\"#\s]+)", line)
            if setting_match:
                bundle_ids[current_target] = setting_match.group(1)

    return bundle_ids


def extract_object_body(text: str, object_id: str) -> str | None:
    object_match = re.search(rf"^\s*{re.escape(object_id)} /\*.*?\*/ = \{{", text, re.M)
    if object_match is None:
        return None
    brace_start = text.find("{", object_match.start())
    if brace_start == -1:
        return None
    depth = 0
    for index in range(brace_start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[brace_start + 1 : index]
    return None


def parse_pbxproj_bundle_ids(text: str) -> dict[str, set[str]]:
    """Parse PRODUCT_BUNDLE_IDENTIFIER values by target from an Xcode pbxproj."""
    config_list_to_target: dict[str, str] = {}
    for match in re.finditer(
        r'buildConfigurationList = ([A-F0-9]{24}) /\* Build configuration list for PBXNativeTarget "([^"]+)" \*/;',
        text,
    ):
        config_list_to_target[match.group(1)] = match.group(2)

    config_to_target: dict[str, str] = {}
    for list_id, target in config_list_to_target.items():
        body = extract_object_body(text, list_id)
        if body is None:
            continue
        for config_id in re.findall(r"([A-F0-9]{24}) /\* (?:Debug|Release) \*/", body):
            config_to_target[config_id] = target

    bundle_ids: dict[str, set[str]] = {}
    for config_id, target in config_to_target.items():
        body = extract_object_body(text, config_id)
        if body is None:
            continue
        bid_match = re.search(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", body)
        if bid_match:
            bundle_ids.setdefault(target, set()).add(bid_match.group(1).strip('"'))

    return bundle_ids


def validate_prefix(source: str, bundle_ids: dict[str, str | set[str]]) -> list[str]:
    errors: list[str] = []
    host_values = bundle_ids.get(HOST_TARGET)
    if not host_values:
        return [f"{source}: missing {HOST_TARGET} PRODUCT_BUNDLE_IDENTIFIER"]
    host_set = host_values if isinstance(host_values, set) else {host_values}
    if len(host_set) != 1:
        return [f"{source}: {HOST_TARGET} has inconsistent bundle identifiers: {sorted(host_set)}"]
    host_id = next(iter(host_set))

    for target in EMBEDDED_TARGETS:
        values = bundle_ids.get(target)
        if not values:
            errors.append(f"{source}: missing {target} PRODUCT_BUNDLE_IDENTIFIER")
            continue
        value_set = values if isinstance(values, set) else {values}
        for bundle_id in sorted(value_set):
            if not bundle_id.startswith(host_id + "."):
                errors.append(
                    f"{source}: {target} bundle id '{bundle_id}' must be prefixed with parent app id '{host_id}.'"
                )
    return errors


def validate_expected_bundle_ids(source: str, bundle_ids: dict[str, str | set[str]]) -> list[str]:
    errors: list[str] = []
    for target, expected in EXPECTED_BUNDLE_IDS.items():
        values = bundle_ids.get(target)
        if not values:
            errors.append(f"{source}: missing {target} PRODUCT_BUNDLE_IDENTIFIER")
            continue
        value_set = values if isinstance(values, set) else {values}
        for bundle_id in sorted(value_set):
            if bundle_id != expected:
                errors.append(f"{source}: {target} bundle id '{bundle_id}' must be '{expected}'")
    return errors


def validate_info_plists() -> list[str]:
    """Ensure checked-in Info.plists do not override target bundle identifiers."""
    errors: list[str] = []
    for target, path in INFO_PLISTS.items():
        with path.open("rb") as handle:
            plist = plistlib.load(handle)
        plist_bundle_id = plist.get("CFBundleIdentifier")
        if plist_bundle_id and plist_bundle_id not in (
            "$(PRODUCT_BUNDLE_IDENTIFIER)",
            EXPECTED_BUNDLE_IDS[target],
        ):
            errors.append(
                f"{path.relative_to(ROOT)}: CFBundleIdentifier '{plist_bundle_id}' would override "
                f"{target}'s PRODUCT_BUNDLE_IDENTIFIER"
            )
    return errors


def validate_no_legacy_bundle_ids() -> list[str]:
    errors: list[str] = []
    for path in (PROJECT_YML, PBXPROJ):
        for line_number, line in enumerate(read(path).splitlines(), start=1):
            if LEGACY_BUNDLE_ID_PREFIX in line:
                errors.append(
                    f"{path.relative_to(ROOT)}:{line_number}: legacy bundle id '{LEGACY_BUNDLE_ID_PREFIX}' remains"
                )
    return errors


def main() -> int:
    errors = []
    project_yml_bundle_ids = parse_xcodegen_bundle_ids(read(PROJECT_YML))
    pbxproj_bundle_ids = parse_pbxproj_bundle_ids(read(PBXPROJ))
    errors.extend(validate_expected_bundle_ids("project.yml", project_yml_bundle_ids))
    errors.extend(validate_prefix("project.yml", project_yml_bundle_ids))
    errors.extend(validate_expected_bundle_ids("project.pbxproj", pbxproj_bundle_ids))
    errors.extend(validate_prefix("project.pbxproj", pbxproj_bundle_ids))
    errors.extend(validate_info_plists())
    errors.extend(validate_no_legacy_bundle_ids())

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("Embedded extension bundle identifiers are prefixed by the parent app bundle identifier.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
