#!/usr/bin/env python3
"""Register the new Mileage feature files in project.pbxproj.

Adds:
  Features/Mileage/        (new group)
    MileageView.swift
    MileageViewModel.swift
    MileageDetailView.swift
    MileageEditView.swift
    AddMileageActionSheet.swift
  Core/Tax/                (new group)
    MileageDeduction.swift
  Shared/UI/               (existing group)
    TripMapSnapshot.swift
"""
import re, sys, pathlib

PBX = pathlib.Path(__file__).resolve().parents[1] / "AutoInspectorNetwork.xcodeproj" / "project.pbxproj"

# Deterministic 24-char hex IDs (prefix MILE.. / TXMS.. to avoid collisions).
FILES = [
    # (group_id, path, fileref_id, buildfile_id)
    ("MILE000000000000000A0001", "MileageView.swift",            "MILE000000000000000F0001", "MILE000000000000000B0001"),
    ("MILE000000000000000A0001", "MileageViewModel.swift",       "MILE000000000000000F0002", "MILE000000000000000B0002"),
    ("MILE000000000000000A0001", "MileageDetailView.swift",      "MILE000000000000000F0003", "MILE000000000000000B0003"),
    ("MILE000000000000000A0001", "MileageEditView.swift",        "MILE000000000000000F0004", "MILE000000000000000B0004"),
    ("MILE000000000000000A0001", "AddMileageActionSheet.swift",  "MILE000000000000000F0005", "MILE000000000000000B0005"),
    ("TXMS000000000000000A0001", "MileageDeduction.swift",       "TXMS000000000000000F0001", "TXMS000000000000000B0001"),
    ("0FBA977372182A1DA1E0DAD5", "TripMapSnapshot.swift",        "TMAP000000000000000F0001", "TMAP000000000000000B0001"),
]

MILEAGE_GROUP_ID = "MILE000000000000000A0001"
TAX_GROUP_ID     = "TXMS000000000000000A0001"
FEATURES_GROUP   = "5DC03ACB53DE45700BB4E9F0"  # Features
CORE_GROUP       = "0ADB5386121963586531221C"  # Core
SHARED_UI_GROUP  = "0FBA977372182A1DA1E0DAD5"  # Shared/UI

def main():
    text = PBX.read_text()

    # 1) PBXBuildFile entries
    bf_block = ""
    for _, name, fref, bid in FILES:
        bf_block += f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {name} */; }};\n"
    text = re.sub(r"(/\* Begin PBXBuildFile section \*/\n)", r"\1" + bf_block, text, count=1)

    # 2) PBXFileReference entries
    fr_block = ""
    for _, name, fref, _ in FILES:
        fr_block += (f"\t\t{fref} /* {name} */ = {{isa = PBXFileReference; "
                     f"lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n")
    text = re.sub(r"(/\* Begin PBXFileReference section \*/\n)", r"\1" + fr_block, text, count=1)

    # 3) Create the new Mileage + Tax groups
    new_groups = f"""\t\t{MILEAGE_GROUP_ID} /* Mileage */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{FILES[0][2]} /* MileageView.swift */,
\t\t\t\t{FILES[1][2]} /* MileageViewModel.swift */,
\t\t\t\t{FILES[2][2]} /* MileageDetailView.swift */,
\t\t\t\t{FILES[3][2]} /* MileageEditView.swift */,
\t\t\t\t{FILES[4][2]} /* AddMileageActionSheet.swift */,
\t\t\t);
\t\t\tpath = Mileage;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{TAX_GROUP_ID} /* Tax */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{FILES[5][2]} /* MileageDeduction.swift */,
\t\t\t);
\t\t\tpath = Tax;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
    text = re.sub(r"(/\* Begin PBXGroup section \*/\n)", r"\1" + new_groups, text, count=1)

    # 4) Add Mileage group to Features group children
    text = re.sub(
        r"(EDEEA5A7C65C0A765BD9B511 /\* Trips \*/,)",
        rf"\1\n\t\t\t\t{MILEAGE_GROUP_ID} /* Mileage */,",
        text, count=1,
    )

    # 5) Add Tax group to Core group children
    text = re.sub(
        r"(FD44EC599816899F4F81FD11 /\* Trips \*/,)",
        rf"\1\n\t\t\t\t{TAX_GROUP_ID} /* Tax */,",
        text, count=1,
    )

    # 6) Add TripMapSnapshot.swift to Shared/UI group
    text = re.sub(
        r"(AB3000000000000000000002 /\* AINSortMenu\.swift \*/,)",
        rf"\1\n\t\t\t\tTMAP000000000000000F0001 /* TripMapSnapshot.swift */,",
        text, count=1,
    )

    # 7) Add entries to PBXSourcesBuildPhase
    src_block = ""
    for _, name, _, bid in FILES:
        src_block += f"\t\t\t\t{bid} /* {name} in Sources */,\n"
    text = re.sub(
        r"(A5D470A05ACB94A37FE2DE69 /\* AppDelegate\.swift in Sources \*/,\n)",
        r"\1" + src_block, text, count=1,
    )

    PBX.write_text(text)
    print("OK: registered", len(FILES), "files.")

if __name__ == "__main__":
    main()
