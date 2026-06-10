#!/usr/bin/env python3
"""Register Section 3 (Profile + Settings) files into project.pbxproj."""
import re, pathlib

PBX = pathlib.Path(__file__).resolve().parents[1] / "AutoInspectorNetwork.xcodeproj" / "project.pbxproj"

FEATURES_GROUP   = "5DC03ACB53DE45700BB4E9F0"
SETTINGS_GROUP   = "AF2799AFA0CD32C828177CE8"
SETTINGS_ANCHOR  = "DBUG0000000000000000000C"  # DeveloperToolsSection.swift child in Settings group
SOURCES_ANCHOR   = "A5D470A05ACB94A37FE2DE69"  # AppDelegate.swift in Sources

PROFILE_GROUP_ID = "PRF000000000000000000001"

PROFILE_FILES = [
    ("ProfileView.swift",      "PRF000000000000000000B1", "PRF000000000000000000B2"),
    ("ProfileViewModel.swift", "PRF000000000000000000C1", "PRF000000000000000000C2"),
]

SETTINGS_FILES = [
    ("AccountSettingsView.swift",       "STG000000000000000000A1", "STG000000000000000000A2"),
    ("OrganizationSettingsView.swift",  "STG000000000000000000B1", "STG000000000000000000B2"),
    ("AvailabilitySettingsView.swift",  "STG000000000000000000C1", "STG000000000000000000C2"),
    ("EarningsSettingsView.swift",      "STG000000000000000000D1", "STG000000000000000000D2"),
    ("NotificationSettingsView.swift",  "STG000000000000000000E1", "STG000000000000000000E2"),
    ("CalendarSyncSettingsView.swift",  "STG000000000000000000F1", "STG000000000000000000F2"),
    ("AboutView.swift",                 "STG000000000000000000G1", "STG000000000000000000G2"),
]

ALL = PROFILE_FILES + SETTINGS_FILES

def main():
    text = PBX.read_text()
    if PROFILE_GROUP_ID in text:
        print("Already applied; skipping.")
        return

    # 1) PBXBuildFile section
    bf_block = ""
    for name, fref, bid in ALL:
        bf_block += f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {name} */; }};\n"
    text = re.sub(r"(/\* Begin PBXBuildFile section \*/\n)", r"\1" + bf_block, text, count=1)

    # 2) PBXFileReference section
    fr_block = ""
    for name, fref, _ in ALL:
        fr_block += (f"\t\t{fref} /* {name} */ = {{isa = PBXFileReference; "
                     f"lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n")
    text = re.sub(r"(/\* Begin PBXFileReference section \*/\n)", r"\1" + fr_block, text, count=1)

    # 3) Profile group definition + children
    profile_group = f"""\t\t{PROFILE_GROUP_ID} /* Profile */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{PROFILE_FILES[0][1]} /* ProfileView.swift */,
\t\t\t\t{PROFILE_FILES[1][1]} /* ProfileViewModel.swift */,
\t\t\t);
\t\t\tpath = Profile;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
    text = re.sub(r"(/\* Begin PBXGroup section \*/\n)", r"\1" + profile_group, text, count=1)

    # 4) Register Profile group under Features
    text = re.sub(
        rf"(AB20000000000000000000F0 /\* Intake \*/,)",
        rf"\1\n\t\t\t\t{PROFILE_GROUP_ID} /* Profile */,",
        text, count=1,
    )

    # 5) Add settings file refs to Settings group children (before anchor)
    settings_children = "".join(
        f"\t\t\t\t{fref} /* {name} */,\n" for name, fref, _ in SETTINGS_FILES
    )
    text = re.sub(
        rf"({SETTINGS_ANCHOR} /\* DeveloperToolsSection\.swift \*/,\n)",
        r"\1" + settings_children,
        text, count=1,
    )

    # 6) PBXSourcesBuildPhase entries
    src_block = "".join(
        f"\t\t\t\t{bid} /* {name} in Sources */,\n" for name, _, bid in ALL
    )
    text = re.sub(
        rf"({SOURCES_ANCHOR} /\* AppDelegate\.swift in Sources \*/,\n)",
        r"\1" + src_block,
        text, count=1,
    )

    PBX.write_text(text)
    print("OK: registered", len(ALL), "files.")

if __name__ == "__main__":
    main()
