#!/usr/bin/env python3
"""Adds the AgendaWidgetExtension app-extension target to project.pbxproj.

Idempotent — running twice is a no-op. Models its surgery on the existing
InspectFlowShareExtension target (same proxy/embed/build-config shape).
"""

from pathlib import Path
import re

PROJ = Path(__file__).resolve().parent.parent / "AutoInspectorNetwork.xcodeproj" / "project.pbxproj"

# Stable UUIDs used throughout
T_TARGET            = "AGWX000000000000000T0001"
T_CFGLIST           = "AGWX000000000000000C0001"
T_CFG_DEBUG         = "AGWX000000000000000C0002"
T_CFG_RELEASE       = "AGWX000000000000000C0003"
T_PHASE_SOURCES     = "AGWX000000000000000P0001"
T_PHASE_FRAMEWORKS  = "AGWX000000000000000P0002"
T_PHASE_RESOURCES   = "AGWX000000000000000P0003"
T_PROXY             = "AGWX000000000000000X0001"
T_DEP               = "AGWX000000000000000D0001"
T_GROUP             = "AGWX000000000000000G0001"
T_APPEX             = "AGWX000000000000000R0001"   # product .appex file ref
T_EMBED             = "AGWX000000000000000E0001"   # embed build file
T_INFOPLIST         = "AGWX000000000000000R0002"
T_ENTITLEMENTS      = "AGWX000000000000000R0003"

MAIN_TARGET     = "1EAF6B1C573B98DE03975706"
MAIN_GROUP      = "8A23CA811AD5DE2F3F9275D1"
PRODUCTS_GROUP  = "C863DA5204F95EC573510473"
EMBED_PHASE     = "B1526CEE2FDB6F3900964B69"  # Embed Foundation Extensions
PROJECT_OBJECT  = "BDDA1F48097C0373FD15D0DD"

# Reuse the shared file references registered by switch_to_native_schedule.py.
SHARED_AGENDA_STORE_FR   = "AGSS00000000000000000F1"
SHARED_ATTRIBUTES_FR     = "AGAT00000000000000000F1"

# Widget-only files: (path-relative-to-AgendaWidgetExtension, file-ref UUID, build-file UUID)
WIDGET_ONLY_FILES = [
    ("AgendaWidgetBundle.swift",            "AGBN000000000000000F0001", "AGBN000000000000000B0001"),
    ("AgendaWidget.swift",                  "AGWG000000000000000F0001", "AGWG000000000000000B0001"),
    ("UpcomingEventLiveActivityWidget.swift","AGLA000000000000000F0001","AGLA000000000000000B0001"),
]

# Shared files (already have FRs from the app-target script). Each needs a
# *second* PBXBuildFile so it can be a member of the widget target's Sources.
SHARED_SOURCES = [
    (SHARED_AGENDA_STORE_FR, "AGSS00000000000000000B2", "SharedAgendaStore.swift"),
    (SHARED_ATTRIBUTES_FR,   "AGAT00000000000000000B2", "UpcomingEventLiveActivityAttributes.swift"),
]


def already_applied(text: str) -> bool:
    return T_TARGET in text


def ensure_section_entry(text: str, end_marker: str, entry: str) -> str:
    """Insert `entry` immediately before the End marker if it isn't already
    present in the section."""
    if entry.strip() in text:
        return text
    return text.replace(end_marker, entry + end_marker, 1)


def add_pbxbuildfile(text: str, uuid: str, fileref: str, name: str, phase: str) -> str:
    line = (
        f"\t\t{uuid} /* {name} in {phase} */ = "
        f"{{isa = PBXBuildFile; fileRef = {fileref} /* {name} */; }};\n"
    )
    if uuid in text:
        return text
    return text.replace("/* End PBXBuildFile section */", line + "/* End PBXBuildFile section */", 1)


def add_pbxfileref_swift(text: str, uuid: str, name: str) -> str:
    if uuid in text:
        return text
    line = (
        f"\t\t{uuid} /* {name} */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
        f"path = {name}; sourceTree = \"<group>\"; }};\n"
    )
    return text.replace(
        "/* End PBXFileReference section */",
        line + "/* End PBXFileReference section */",
        1,
    )


def apply(text: str) -> str:
    if already_applied(text):
        return text

    # --- PBXFileReferences (widget-only sources, Info.plist, entitlements, appex)
    for name, fr, _ in WIDGET_ONLY_FILES:
        text = add_pbxfileref_swift(text, fr, name)

    plist_line = (
        f"\t\t{T_INFOPLIST} /* Info.plist */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
        f"path = Info.plist; sourceTree = \"<group>\"; }};\n"
    )
    ent_line = (
        f"\t\t{T_ENTITLEMENTS} /* AgendaWidgetExtension.entitlements */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; "
        f"path = AgendaWidgetExtension.entitlements; sourceTree = \"<group>\"; }};\n"
    )
    appex_line = (
        f"\t\t{T_APPEX} /* AgendaWidgetExtension.appex */ = "
        f"{{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; "
        f"includeInIndex = 0; path = AgendaWidgetExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
    )
    for line in (plist_line, ent_line, appex_line):
        text = ensure_section_entry(text, "/* End PBXFileReference section */", line)

    # --- PBXBuildFile entries: widget-only sources, embed, shared dual-membership
    for name, fr, bf in WIDGET_ONLY_FILES:
        text = add_pbxbuildfile(text, bf, fr, name, "Sources")
    for fr, bf, name in SHARED_SOURCES:
        text = add_pbxbuildfile(text, bf, fr, name, "Sources")
    embed_line = (
        f"\t\t{T_EMBED} /* AgendaWidgetExtension.appex in Embed Foundation Extensions */ = "
        f"{{isa = PBXBuildFile; fileRef = {T_APPEX} /* AgendaWidgetExtension.appex */; "
        f"settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
    )
    text = ensure_section_entry(text, "/* End PBXBuildFile section */", embed_line)

    # --- Widget group (children of mainGroup)
    group_body = (
        f"\t\t{T_GROUP} /* AgendaWidgetExtension */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"\t\t\t\t{T_ENTITLEMENTS} /* AgendaWidgetExtension.entitlements */,\n"
        f"\t\t\t\t{WIDGET_ONLY_FILES[0][1]} /* {WIDGET_ONLY_FILES[0][0]} */,\n"
        f"\t\t\t\t{WIDGET_ONLY_FILES[1][1]} /* {WIDGET_ONLY_FILES[1][0]} */,\n"
        f"\t\t\t\t{WIDGET_ONLY_FILES[2][1]} /* {WIDGET_ONLY_FILES[2][0]} */,\n"
        f"\t\t\t\t{T_INFOPLIST} /* Info.plist */,\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = AgendaWidgetExtension;\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End PBXGroup section */", group_body)

    # Attach the group as a child of mainGroup (before Products group entry).
    main_group_child = f"\t\t\t\t{T_GROUP} /* AgendaWidgetExtension */,\n"
    main_group_anchor = f"\t\t\t\t{PRODUCTS_GROUP} /* Products */,\n"
    if main_group_child.strip() not in text:
        text = text.replace(main_group_anchor, main_group_child + main_group_anchor, 1)

    # Add appex to Products group.
    appex_in_products = f"\t\t\t\t{T_APPEX} /* AgendaWidgetExtension.appex */,\n"
    products_anchor = re.compile(
        rf"({re.escape(PRODUCTS_GROUP)} /\* Products \*/ = \{{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)"
    )
    if appex_in_products.strip() not in text:
        text = products_anchor.sub(rf"\1{appex_in_products}", text, count=1)

    # --- Build phases
    sources_phase = (
        f"\t\t{T_PHASE_SOURCES} /* Sources */ = {{\n"
        f"\t\t\tisa = PBXSourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{WIDGET_ONLY_FILES[0][2]} /* {WIDGET_ONLY_FILES[0][0]} in Sources */,\n"
        f"\t\t\t\t{WIDGET_ONLY_FILES[1][2]} /* {WIDGET_ONLY_FILES[1][0]} in Sources */,\n"
        f"\t\t\t\t{WIDGET_ONLY_FILES[2][2]} /* {WIDGET_ONLY_FILES[2][0]} in Sources */,\n"
        f"\t\t\t\t{SHARED_SOURCES[0][1]} /* {SHARED_SOURCES[0][2]} in Sources */,\n"
        f"\t\t\t\t{SHARED_SOURCES[1][1]} /* {SHARED_SOURCES[1][2]} in Sources */,\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End PBXSourcesBuildPhase section */", sources_phase)

    frameworks_phase = (
        f"\t\t{T_PHASE_FRAMEWORKS} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End PBXFrameworksBuildPhase section */", frameworks_phase)

    resources_phase = (
        f"\t\t{T_PHASE_RESOURCES} /* Resources */ = {{\n"
        f"\t\t\tisa = PBXResourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End PBXResourcesBuildPhase section */", resources_phase)

    # --- Container item proxy + target dependency for the main-app embed
    proxy = (
        f"\t\t{T_PROXY} /* PBXContainerItemProxy */ = {{\n"
        f"\t\t\tisa = PBXContainerItemProxy;\n"
        f"\t\t\tcontainerPortal = {PROJECT_OBJECT} /* Project object */;\n"
        f"\t\t\tproxyType = 1;\n"
        f"\t\t\tremoteGlobalIDString = {T_TARGET};\n"
        f"\t\t\tremoteInfo = AgendaWidgetExtension;\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End PBXContainerItemProxy section */", proxy)

    dep = (
        f"\t\t{T_DEP} /* PBXTargetDependency */ = {{\n"
        f"\t\t\tisa = PBXTargetDependency;\n"
        f"\t\t\ttarget = {T_TARGET} /* AgendaWidgetExtension */;\n"
        f"\t\t\ttargetProxy = {T_PROXY} /* PBXContainerItemProxy */;\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End PBXTargetDependency section */", dep)

    # Attach dependency to main target's `dependencies` list and embed file to embed phase.
    main_dep_line = f"\t\t\t\t{T_DEP} /* PBXTargetDependency */,\n"
    if main_dep_line.strip() not in text:
        text = re.sub(
            rf"({re.escape(MAIN_TARGET)} /\* AutoInspectorNetwork \*/ = \{{(?:.|\n)*?dependencies = \(\n)",
            rf"\1{main_dep_line}",
            text,
            count=1,
        )

    embed_file_line = f"\t\t\t\t{T_EMBED} /* AgendaWidgetExtension.appex in Embed Foundation Extensions */,\n"
    if embed_file_line.strip() not in text:
        text = re.sub(
            rf"({re.escape(EMBED_PHASE)} /\* Embed Foundation Extensions \*/ = \{{(?:.|\n)*?files = \(\n)",
            rf"\1{embed_file_line}",
            text,
            count=1,
        )

    # --- Native target object
    target_obj = (
        f"\t\t{T_TARGET} /* AgendaWidgetExtension */ = {{\n"
        f"\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {T_CFGLIST} /* Build configuration list for PBXNativeTarget \"AgendaWidgetExtension\" */;\n"
        f"\t\t\tbuildPhases = (\n"
        f"\t\t\t\t{T_PHASE_SOURCES} /* Sources */,\n"
        f"\t\t\t\t{T_PHASE_FRAMEWORKS} /* Frameworks */,\n"
        f"\t\t\t\t{T_PHASE_RESOURCES} /* Resources */,\n"
        f"\t\t\t);\n"
        f"\t\t\tbuildRules = (\n"
        f"\t\t\t);\n"
        f"\t\t\tdependencies = (\n"
        f"\t\t\t);\n"
        f"\t\t\tname = AgendaWidgetExtension;\n"
        f"\t\t\tproductName = AgendaWidgetExtension;\n"
        f"\t\t\tproductReference = {T_APPEX} /* AgendaWidgetExtension.appex */;\n"
        f"\t\t\tproductType = \"com.apple.product-type.app-extension\";\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End PBXNativeTarget section */", target_obj)

    # Register target in PBXProject `targets` list.
    project_target_line = f"\t\t\t\t{T_TARGET} /* AgendaWidgetExtension */,\n"
    if project_target_line.strip() not in text:
        text = re.sub(
            r"(targets = \(\n(?:\t\t\t\t[^\n]+\n)+)",
            lambda m: m.group(1) + project_target_line,
            text,
            count=1,
        )

    # --- Build configurations
    common = (
        "\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;\n"
        "\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";\n"
        "\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;\n"
        "\t\t\t\tCODE_SIGN_ENTITLEMENTS = AgendaWidgetExtension/AgendaWidgetExtension.entitlements;\n"
        "\t\t\t\tCODE_SIGN_IDENTITY = \"Apple Development\";\n"
        "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
        "\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n"
        "\t\t\t\tDEVELOPMENT_TEAM = 264U37X2A5;\n"
        "\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n"
        "\t\t\t\tINFOPLIST_FILE = AgendaWidgetExtension/Info.plist;\n"
        "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.2;\n"
        "\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n"
        "\t\t\t\t\t\"$(inherited)\",\n"
        "\t\t\t\t\t\"@executable_path/Frameworks\",\n"
        "\t\t\t\t\t\"@executable_path/../../Frameworks\",\n"
        "\t\t\t\t);\n"
        "\t\t\t\tMARKETING_VERSION = 1.0;\n"
        "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.autoinspectornetwork.ios.AgendaWidgetExtension;\n"
        "\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
        "\t\t\t\tSKIP_INSTALL = YES;\n"
        "\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n"
        "\t\t\t\tSWIFT_VERSION = 5.0;\n"
        "\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";\n"
    )
    debug_cfg = (
        f"\t\t{T_CFG_DEBUG} /* Debug */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n"
        f"{common}"
        f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;\n"
        f"\t\t\t\tMTL_FAST_MATH = YES;\n"
        f"\t\t\t}};\n"
        f"\t\t\tname = Debug;\n"
        f"\t\t}};\n"
    )
    release_cfg = (
        f"\t\t{T_CFG_RELEASE} /* Release */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n"
        f"{common}"
        f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;\n"
        f"\t\t\t\tMTL_FAST_MATH = YES;\n"
        f"\t\t\t}};\n"
        f"\t\t\tname = Release;\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End XCBuildConfiguration section */", debug_cfg + release_cfg)

    cfg_list = (
        f"\t\t{T_CFGLIST} /* Build configuration list for PBXNativeTarget \"AgendaWidgetExtension\" */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{T_CFG_DEBUG} /* Debug */,\n"
        f"\t\t\t\t{T_CFG_RELEASE} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};\n"
    )
    text = ensure_section_entry(text, "/* End XCConfigurationList section */", cfg_list)

    return text


def main():
    text = PROJ.read_text()
    new_text = apply(text)
    if new_text != text:
        PROJ.write_text(new_text)
        print("OK: AgendaWidgetExtension target added.")
    else:
        print("OK: pbxproj already has AgendaWidgetExtension.")


if __name__ == "__main__":
    main()
