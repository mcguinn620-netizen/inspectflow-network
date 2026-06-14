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
    ("Core/Calendar/EventIdentity.swift",                  "EVID00000000000000000F1", "EVID00000000000000000B1"),
    ("Core/Calendar/CalendarRepository.swift",             "CALR00000000000000000F1", "CALR00000000000000000B1"),
    ("Core/Calendar/EventRepository.swift",                "EVTR00000000000000000F1", "EVTR00000000000000000B1"),
    ("Core/Calendar/EventConflictResolver.swift",          "ECNF00000000000000000F1", "ECNF00000000000000000B1"),
    ("Core/Calendar/CalendarFilterModel.swift",            "CFMD00000000000000000F1", "CFMD00000000000000000B1"),
    ("Core/Calendar/EventKitService+Recurrence.swift",     "EKSR00000000000000000F1", "EKSR00000000000000000B1"),
    ("Core/Calendar/ScheduleSearchService.swift",          "SSCH00000000000000000F1", "SSCH00000000000000000B1"),
    ("Core/Persistence/ScheduleMetadataStore.swift",       "SMDS00000000000000000F1", "SMDS00000000000000000B1"),
    ("Core/Persistence/SwiftDataMetadataStore.swift",      "SMSD00000000000000000F1", "SMSD00000000000000000B1"),
    ("Features/Schedule/ScheduleDayGrid.swift",            "SDG000000000000000000F1", "SDG000000000000000000B1"),
    ("Features/Schedule/ScheduleMonthMatrix.swift",        "SMM000000000000000000F1", "SMM000000000000000000B1"),
    ("Features/Schedule/ScheduleRootView.swift",           "SRV000000000000000000F1", "SRV000000000000000000B1"),
    ("Features/Schedule/ScheduleSidebar.swift",            "SSB000000000000000000F1", "SSB000000000000000000B1"),
    ("Features/Schedule/CalendarSidebarView.swift",        "CSBV00000000000000000F1", "CSBV00000000000000000B1"),
    ("Features/Schedule/RecurrenceEditorView.swift",       "RCED00000000000000000F1", "RCED00000000000000000B1"),
    ("Features/Schedule/EventInspectorView.swift",         "EIV000000000000000000F1", "EIV000000000000000000B1"),
    ("Features/Schedule/ScheduleViewModel.swift",          "SVM000000000000000000F1", "SVM000000000000000000B1"),
    ("Core/Calendar/EventDragPayload.swift",               "EDPL00000000000000000F1", "EDPL00000000000000000B1"),
    ("Features/Schedule/EventDropDelegates.swift",         "EDRP00000000000000000F1", "EDRP00000000000000000B1"),
    ("Features/Schedule/ScheduleWeekGrid.swift",           "SWGD00000000000000000F1", "SWGD00000000000000000B1"),
    ("Features/Schedule/EventDetailWindow.swift",          "EDTW00000000000000000F1", "EDTW00000000000000000B1"),
    ("Core/Calendar/NaturalLanguageSchedulingService.swift","NLSS00000000000000000F1", "NLSS00000000000000000B1"),
    ("Features/Schedule/QuickAddEventField.swift",          "QAEF00000000000000000F1", "QAEF00000000000000000B1"),
    ("Core/Calendar/FocusFilterManager.swift",              "FFMG00000000000000000F1", "FFMG00000000000000000B1"),
    ("Shared/Widget/SharedAgendaStore.swift",                "AGSS00000000000000000F1", "AGSS00000000000000000B1"),
    ("Shared/Widget/UpcomingEventLiveActivityAttributes.swift","AGAT00000000000000000F1", "AGAT00000000000000000B1"),
    ("Core/Calendar/LiveActivityController.swift",           "AGLC00000000000000000F1", "AGLC00000000000000000B1"),
    ("Core/Calendar/EventRepository+Snapshot.swift",         "AGSN00000000000000000F1", "AGSN00000000000000000B1"),
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
    # Use a tolerant matcher that consumes nested `};` (e.g. requirement = { ... };).
    text = re.sub(
        r"\t\tCK00000000000000000000A1 /\* XCRemoteSwiftPackageReference \"CalendarKit\" \*/ = \{(?:[^{}]|\{[^{}]*\})*\};\n",
        "",
        text,
    )
    text = re.sub(
        r"\t\tCK00000000000000000000A2 /\* CalendarKit \*/ = \{(?:[^{}]|\{[^{}]*\})*\};\n",
        "",
        text,
    )
    # Clean up any orphan `};` left inside the now-empty section by a prior buggy run.
    text = re.sub(
        r"(/\* Begin XCRemoteSwiftPackageReference section \*/\n)\t\t\};\n",
        r"\1",
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
        # PBXFileReference entry — paths are relative to SOURCE_ROOT (the
        # ios-native/ directory that contains the .xcodeproj), matching the
        # convention used by every other Swift source in this project.
        fr_line = (
            f"\t\t{file_uuid} /* {name} */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
            f"path = {path}; sourceTree = \"<group>\"; }};\n"
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
