#!/usr/bin/env python3
"""Add CalendarKit SPM dependency + register Schedule Section 1 source files.

- Adds CalendarKit SPM package (https://github.com/richardtop/CalendarKit, 1.1.5+)
- Adds CalendarKit product to the AutoInspectorNetwork app target
- Registers CalendarKitDayView.swift and ScheduleExportMenu.swift in the
  Features/Schedule group and Sources build phase
"""
import re, pathlib, sys

PBX = pathlib.Path(__file__).resolve().parents[1] / "AutoInspectorNetwork.xcodeproj" / "project.pbxproj"

SCHEDULE_GROUP_ID = "38C362A50C6B6123747B41D4"
EXISTING_SCHEDULE_FILE = "851A9FED51A53A0EAF5F18A4"  # ScheduleView.swift
TARGET_ID = "1EAF6B1C573B98DE03975706"
PROJECT_ID = "BDDA1F48097C0373FD15D0DD"
FRAMEWORKS_PHASE_ID = "349B578E88FC623128D2018B"
SOURCES_PHASE_ANCHOR = "A5D470A05ACB94A37FE2DE69"  # AppDelegate.swift in Sources

# Deterministic IDs (CK = CalendarKit)
PACKAGE_REF_ID         = "CK00000000000000000000A1"
PRODUCT_DEP_ID         = "CK00000000000000000000A2"
FRAMEWORK_BUILDFILE_ID = "CK00000000000000000000A3"

FILES = [
    # (path, fileref_id, buildfile_id)
    ("CalendarKitDayView.swift",  "CK00000000000000000000B1", "CK00000000000000000000B2"),
    ("ScheduleExportMenu.swift",  "CK00000000000000000000C1", "CK00000000000000000000C2"),
]

def main():
    text = PBX.read_text()

    # Guard against duplicate runs
    if PACKAGE_REF_ID in text:
        print("Already applied; skipping.")
        return

    # 1) PBXBuildFile entries (source files + CalendarKit framework link)
    bf_block = ""
    for name, fref, bid in FILES:
        bf_block += f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {name} */; }};\n"
    bf_block += (
        f"\t\t{FRAMEWORK_BUILDFILE_ID} /* CalendarKit in Frameworks */ = "
        f"{{isa = PBXBuildFile; productRef = {PRODUCT_DEP_ID} /* CalendarKit */; }};\n"
    )
    text = re.sub(r"(/\* Begin PBXBuildFile section \*/\n)", r"\1" + bf_block, text, count=1)

    # 2) PBXFileReference entries
    fr_block = ""
    for name, fref, _ in FILES:
        fr_block += (
            f"\t\t{fref} /* {name} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
        )
    text = re.sub(r"(/\* Begin PBXFileReference section \*/\n)", r"\1" + fr_block, text, count=1)

    # 3) Add files to Schedule group
    additions = "".join(f"\n\t\t\t\t{fref} /* {name} */," for name, fref, _ in FILES)
    text = re.sub(
        rf"({EXISTING_SCHEDULE_FILE} /\* ScheduleView\.swift \*/,)",
        r"\1" + additions,
        text,
        count=1,
    )

    # 4) Add to Sources build phase
    src_block = "".join(
        f"\t\t\t\t{bid} /* {name} in Sources */,\n" for name, _, bid in FILES
    )
    text = re.sub(
        rf"({SOURCES_PHASE_ANCHOR} /\* AppDelegate\.swift in Sources \*/,\n)",
        r"\1" + src_block,
        text,
        count=1,
    )

    # 5) Add CalendarKit framework to Frameworks build phase
    framework_entry = f"\t\t\t\t{FRAMEWORK_BUILDFILE_ID} /* CalendarKit in Frameworks */,\n"
    text = re.sub(
        rf"({FRAMEWORKS_PHASE_ID} /\* Frameworks \*/ = \{{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \(\n)",
        r"\1" + framework_entry,
        text,
        count=1,
    )

    # 6) Add packageProductDependencies to native target
    target_pkg_block = (
        f"\t\t\tpackageProductDependencies = (\n"
        f"\t\t\t\t{PRODUCT_DEP_ID} /* CalendarKit */,\n"
        f"\t\t\t);\n"
    )
    text = re.sub(
        rf"({TARGET_ID} /\* AutoInspectorNetwork \*/ = \{{\n\t\t\tisa = PBXNativeTarget;[\s\S]*?name = AutoInspectorNetwork;\n)",
        r"\1" + target_pkg_block,
        text,
        count=1,
    )

    # 7) Add packageReferences to PBXProject
    project_pkg_block = (
        f"\t\t\tpackageReferences = (\n"
        f"\t\t\t\t{PACKAGE_REF_ID} /* XCRemoteSwiftPackageReference \"CalendarKit\" */,\n"
        f"\t\t\t);\n"
    )
    text = re.sub(
        rf"({PROJECT_ID} /\* Project object \*/ = \{{\n\t\t\tisa = PBXProject;[\s\S]*?productRefGroup = [A-F0-9]+ /\* Products \*/;\n)",
        r"\1" + project_pkg_block,
        text,
        count=1,
    )

    # 8) Append XCRemoteSwiftPackageReference + XCSwiftPackageProductDependency sections
    spm_sections = f"""
/* Begin XCRemoteSwiftPackageReference section */
\t\t{PACKAGE_REF_ID} /* XCRemoteSwiftPackageReference "CalendarKit" */ = {{
\t\t\tisa = XCRemoteSwiftPackageReference;
\t\t\trepositoryURL = "https://github.com/richardtop/CalendarKit.git";
\t\t\trequirement = {{
\t\t\t\tkind = upToNextMajorVersion;
\t\t\t\tminimumVersion = 1.1.5;
\t\t\t}};
\t\t}};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
\t\t{PRODUCT_DEP_ID} /* CalendarKit */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {PACKAGE_REF_ID} /* XCRemoteSwiftPackageReference "CalendarKit" */;
\t\t\tproductName = CalendarKit;
\t\t}};
/* End XCSwiftPackageProductDependency section */
"""
    # Insert before the closing rootObject footer "}" at end of file (before the final `}\n`)
    text = re.sub(r"(\n\}\s*\Z)", spm_sections + r"\1", text)

    PBX.write_text(text)
    print("OK: CalendarKit SPM + Schedule files registered.")

if __name__ == "__main__":
    main()
