#!/usr/bin/env python3
"""Switch project from CalendarKit SPM to native EventKit + SwiftData/CoreData.

- Removes the CalendarKit XCRemoteSwiftPackageReference, XCSwiftPackageProductDependency,
  packageReferences / packageProductDependencies entries, and the (null) Frameworks
  build-file produced by the prior `add_calendarkit_schedule.py`.
- Adds source-file refs + Sources build-phase entries for the new native files.

Idempotent — running twice is a no-op.
"""

from pathlib import Path
import re

PROJ = Path(__file__).resolve().parent.parent / "AutoInspectorNetwork.xcodeproj" / "project.pbxproj"
SOURCES_PHASE = "F3F3D267CF0FD5307403D537"  # AutoInspectorNetwork app target Sources phase

# (path-relative-to-group, group-id, file-uuid, buildfile-uuid)
NEW_FILES = [
    ("Core/Calendar/EventKitService.swift",                "EKSVC0000000000000000F1", "EKSVC0000000000000000B1"),
    ("Core/Persistence/ScheduleMetadataStore.swift",       "SMDS00000000000000000F1", "SMDS00000000000000000B1"),
    ("Core/Persistence/SwiftDataMetadataStore.swift",      "SMSD00000000000000000F1", "SMSD00000000000000000B1"),
    ("Features/Schedule/ScheduleDayGrid.swift",            "SDG000000000000000000F1", "SDG000000000000000000B1"),
    ("Features/Schedule/ScheduleMonthMatrix.swift",        "SMM000000000000000000F1", "SMM000000000000000000B1"),
    ("Features/Schedule/ScheduleRootView.swift",           "SRV000000000000000000F1", "SRV000000000000000000B1"),
    ("Features/Schedule/ScheduleSidebar.swift",            "SSB000000000000000000F1", "SSB000000000000000000B1"),
    ("Features/Schedule/EventInspectorView.swift",         "EIV000000000000000000F1", "EIV000000000000000000B1"),
    ("Features/Schedule/ScheduleViewModel.swift",          "SVM000000000000000000F1", "SVM000000000000000000B1"),
]


def strip_calendarkit(text: str) -> str:
    # Remove malformed Frameworks build-file line.
    text = re.sub(r"\n\t\tCK00000000000000000000A3 .*?\n", "\n", text)
    # Remove "(null) in Frameworks" entry from Frameworks build phase files list.
    text = re.sub(r"\n\t{4}CK00000000000000000000A3 /\* \(null\) in Frameworks \*/,\n", "\n", text)
    # Remove from packageProductDependencies.
    text = re.sub(r"\n\t{4}CK00000000000000000000A2 /\* CalendarKit \*/,\n", "\n", text)
    # Remove from packageReferences.
    text = re.sub(r"\n\t{4}CK00000000000000000000A1 /\* XCRemoteSwiftPackageReference \"CalendarKit\" \*/,\n", "\n", text)
    # Remove the XCRemoteSwiftPackageReference and XCSwiftPackageProductDependency objects.
    text = re.sub(
        r"\t\tCK00000000000000000000A1 /\* XCRemoteSwiftPackageReference \"CalendarKit\" \*/ = \{[\s\S]*?\};\n",
        "",
        text,
    )
    text = re.sub(
        r"\t\tCK00000000000000000000A2 /\* CalendarKit \*/ = \{[\s\S]*?\};\n",
        "",
        text,
    )
    return text


def add_file_refs(text: str) -> str:
    for path, file_uuid, build_uuid in NEW_FILES:
        if file_uuid in text:
            continue
        name = path.rsplit("/", 1)[-1]
        # PBXBuildFile entry — inject before end of PBXBuildFile section.
        bf_line = (
            f"\t\t{build_uuid} /* {name} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {file_uuid} /* {name} */; }};\n"
        )
        text = text.replace(
            "/* End PBXBuildFile section */",
            bf_line + "/* End PBXBuildFile section */",
            1,
        )
        # PBXFileReference entry — use path with sourceTree SOURCE_ROOT so Xcode
        # locates the file without requiring it to be inside a registered group.
        fr_line = (
            f"\t\t{file_uuid} /* {name} */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
            f"name = {name}; path = ios-native/{path}; sourceTree = SOURCE_ROOT; }};\n"
        )
        text = text.replace(
            "/* End PBXFileReference section */",
            fr_line + "/* End PBXFileReference section */",
            1,
        )
        # Inject into AutoInspectorNetwork Sources phase.
        marker = f"{SOURCES_PHASE} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
        insert = f"\t\t\t\t{build_uuid} /* {name} in Sources */,\n"
        text = text.replace(marker, marker + insert, 1)
    return text


def main():
    text = PROJ.read_text()
    new_text = strip_calendarkit(text)
    new_text = add_file_refs(new_text)
    if new_text != text:
        PROJ.write_text(new_text)
        print("OK: pbxproj updated.")
    else:
        print("OK: pbxproj already up to date.")


if __name__ == "__main__":
    main()
