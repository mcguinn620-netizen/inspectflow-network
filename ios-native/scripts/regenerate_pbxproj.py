#!/usr/bin/env python3
"""
Regenerate AutoInspectorNetwork.xcodeproj/project.pbxproj from scratch.

Discovers Swift sources, assets, plists, entitlements, and storyboards on disk
under ios-native/ and emits a fresh, deterministic OpenStep PBX project.

Targets:
  - AutoInspectorNetwork           (com.autoinspectornetwork.ios)
  - InspectFlowShareExtension      (com.autoinspectornetwork.ios.InspectFlowShareExtension)
  - AgendaWidgetExtension          (com.autoinspectornetwork.ios.AgendaWidgetExtension)

UUIDs are content-addressed: sha1("pbx:" + stable_key)[:24].upper().
Also writes the two shared schemes.
"""

from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parent.parent          # ios-native/
PROJ_DIR = ROOT / "AutoInspectorNetwork.xcodeproj"
PBX_PATH = PROJ_DIR / "project.pbxproj"
SCHEMES_DIR = PROJ_DIR / "xcshareddata" / "xcschemes"


# --------------------------------------------------------------------------- #
# UUID allocator
# --------------------------------------------------------------------------- #
_seen: Dict[str, str] = {}
_used: Dict[str, str] = {}


def uid(key: str) -> str:
    if key in _seen:
        return _seen[key]
    h = hashlib.sha1(("pbx:" + key).encode()).hexdigest()[:24].upper()
    # collision check
    if h in _used and _used[h] != key:
        # extend with extra hash bits if collision (extremely unlikely)
        for i in range(1, 1000):
            h2 = hashlib.sha1((f"pbx:{key}:{i}").encode()).hexdigest()[:24].upper()
            if h2 not in _used:
                h = h2
                break
    _seen[key] = h
    _used[h] = key
    return h


# --------------------------------------------------------------------------- #
# Source discovery
# --------------------------------------------------------------------------- #
APP_SOURCE_DIRS = ["App", "CarPlay", "Core", "Features", "Shared"]
SHARE_DIR = "InspectFlowShareExtension"
WIDGET_DIR = "AgendaWidgetExtension"

# Files in Shared/Widget also compiled into the widget target.
WIDGET_EXTRA_SHARED = [
    "Shared/Widget/SharedAgendaStore.swift",
    "Shared/Widget/UpcomingEventLiveActivityAttributes.swift",
]


def walk_swift(rel_dir: str) -> List[str]:
    base = ROOT / rel_dir
    out: List[str] = []
    if not base.exists():
        return out
    for p in sorted(base.rglob("*.swift")):
        out.append(str(p.relative_to(ROOT)).replace(os.sep, "/"))
    return out


def discover() -> Dict[str, List[str]]:
    app_sources: List[str] = []
    for d in APP_SOURCE_DIRS:
        app_sources.extend(walk_swift(d))

    share_sources = walk_swift(SHARE_DIR)
    widget_sources = walk_swift(WIDGET_DIR) + WIDGET_EXTRA_SHARED

    return {
        "app": sorted(set(app_sources)),
        "share": sorted(set(share_sources)),
        "widget": sorted(set(widget_sources)),
    }


# --------------------------------------------------------------------------- #
# File-type metadata
# --------------------------------------------------------------------------- #
FILE_TYPES = {
    ".swift": ("sourcecode.swift", "<group>"),
    ".plist": ("text.plist.xml", "<group>"),
    ".entitlements": ("text.plist.entitlements", "<group>"),
    ".storyboard": ("file.storyboard", "<group>"),
    ".xcassets": ("folder.assetcatalog", "<group>"),
    ".xcdatamodeld": ("wrapper.xcdatamodel", "<group>"),
    ".png": ("image.png", "<group>"),
    ".jpg": ("image.jpeg", "<group>"),
    ".json": ("text.json", "<group>"),
    ".md": ("net.daringfireball.markdown", "<group>"),
}


def file_type_for(path: str) -> Tuple[str, str]:
    # special cases
    if path.endswith(".xcassets"):
        return ("folder.assetcatalog", "<group>")
    if path.endswith(".xcdatamodeld"):
        return ("wrapper.xcdatamodel", "<group>")
    ext = "." + path.rsplit(".", 1)[-1] if "." in path else ""
    return FILE_TYPES.get(ext, ("text", "<group>"))


# --------------------------------------------------------------------------- #
# Group tree builder
# --------------------------------------------------------------------------- #
class Node:
    __slots__ = ("name", "path", "is_file", "children", "uid", "ref_uid")

    def __init__(self, name: str, path: str, is_file: bool):
        self.name = name
        self.path = path  # relative to ROOT (ios-native/)
        self.is_file = is_file
        self.children: Dict[str, "Node"] = {}
        self.uid: str = ""        # group uid (for dirs) or fileRef uid (for files)
        self.ref_uid: str = ""    # fileRef uid (file only)


class Tree:
    """Builds a Node tree mirroring on-disk paths for a set of file paths."""

    def __init__(self):
        self.root = Node("MainGroup", "", False)

    def add_file(self, rel_path: str) -> Node:
        parts = rel_path.split("/")
        cur = self.root
        accumulated = ""
        for part in parts[:-1]:
            accumulated = f"{accumulated}/{part}" if accumulated else part
            if part not in cur.children:
                cur.children[part] = Node(part, accumulated, is_file=False)
            cur = cur.children[part]
        leaf = parts[-1]
        if leaf not in cur.children:
            node = Node(leaf, rel_path, is_file=True)
            cur.children[leaf] = node
        return cur.children[leaf]

    def assign_uids(self):
        def visit(n: Node, prefix: str):
            if n.is_file:
                n.ref_uid = uid(f"fileref:{n.path}")
                n.uid = n.ref_uid
            else:
                key = f"group:{n.path or '<root>'}"
                n.uid = uid(key)
                for child in n.children.values():
                    visit(child, prefix + "/" + n.name)
        for c in self.root.children.values():
            visit(c, "")


# --------------------------------------------------------------------------- #
# pbxproj emission
# --------------------------------------------------------------------------- #
def comment(s: str) -> str:
    return f" /* {s} */"


class PBX:
    def __init__(self):
        self.objects: List[Tuple[str, str, str, str]] = []  # (section, uid, comment, body)

    def add(self, section: str, uid_: str, comment_text: str, body: str):
        self.objects.append((section, uid_, comment_text, body))

    def render(self, archive_version: str, object_version: str,
               root_object_uid: str, root_object_comment: str) -> str:
        # group by section, preserve insertion order within each
        sections: Dict[str, List[Tuple[str, str, str]]] = {}
        section_order: List[str] = []
        for sec, u, c, body in self.objects:
            if sec not in sections:
                sections[sec] = []
                section_order.append(sec)
            sections[sec].append((u, c, body))

        # sort sections in canonical Xcode order
        canonical = [
            "PBXBuildFile",
            "PBXContainerItemProxy",
            "PBXCopyFilesBuildPhase",
            "PBXFileReference",
            "PBXFrameworksBuildPhase",
            "PBXGroup",
            "PBXNativeTarget",
            "PBXProject",
            "PBXResourcesBuildPhase",
            "PBXSourcesBuildPhase",
            "PBXTargetDependency",
            "PBXVariantGroup",
            "XCBuildConfiguration",
            "XCConfigurationList",
        ]
        section_order = [s for s in canonical if s in sections] + \
                        [s for s in section_order if s not in canonical]

        out: List[str] = []
        out.append("// !$*UTF8*$!")
        out.append("{")
        out.append(f"\tarchiveVersion = {archive_version};")
        out.append("\tclasses = {")
        out.append("\t};")
        out.append(f"\tobjectVersion = {object_version};")
        out.append("\tobjects = {")
        for sec in section_order:
            out.append("")
            out.append(f"/* Begin {sec} section */")
            # sort entries by uid for stability
            entries = sorted(sections[sec], key=lambda x: x[0])
            for u, c, body in entries:
                lbl = comment(c) if c else ""
                if "\n" in body:
                    out.append(f"\t\t{u}{lbl} = {body};")
                else:
                    out.append(f"\t\t{u}{lbl} = {body};")
            out.append(f"/* End {sec} section */")
        out.append("\t};")
        out.append(f"\trootObject = {root_object_uid}{comment(root_object_comment)};")
        out.append("}")
        out.append("")
        return "\n".join(out)


# --------------------------------------------------------------------------- #
# Target configuration
# --------------------------------------------------------------------------- #
COMMON_BUILD_SETTINGS = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu11",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "MTL_FAST_MATH": "YES",
    "SDKROOT": "iphoneos",
}

DEBUG_PROJECT_SETTINGS = {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": '(\n\t\t\t\t\t"DEBUG=1",\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t)',
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
}

RELEASE_PROJECT_SETTINGS = {
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "VALIDATE_PRODUCT": "YES",
}


def target_settings(target_name: str, config: str) -> Dict[str, str]:
    base = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES" if target_name == "AutoInspectorNetwork" else "NO",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "264U37X2A5",
        "GENERATE_INFOPLIST_FILE": "NO",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SKIP_INSTALL": "NO" if target_name == "AutoInspectorNetwork" else "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "TARGETED_DEVICE_FAMILY": '"1,2"',
        "LD_RUNPATH_SEARCH_PATHS": '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)',
    }
    if target_name == "AutoInspectorNetwork":
        base["LD_RUNPATH_SEARCH_PATHS"] = (
            '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)'
        )
        base["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
        base["CODE_SIGN_ENTITLEMENTS"] = "AutoInspectorNetwork.entitlements"
        base["INFOPLIST_FILE"] = "Info.plist"
        base["IPHONEOS_DEPLOYMENT_TARGET"] = "16.0"
        base["MARKETING_VERSION"] = "0.2.0"
        base["PRODUCT_BUNDLE_IDENTIFIER"] = "com.autoinspectornetwork.ios"
        base["SWIFT_VERSION"] = "5.7"
        base["ENABLE_PREVIEWS"] = "YES"
    elif target_name == "InspectFlowShareExtension":
        base["LD_RUNPATH_SEARCH_PATHS"] = (
            '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t\t"@executable_path/../../Frameworks",\n\t\t\t\t)'
        )
        base["CODE_SIGN_ENTITLEMENTS"] = "InspectFlowShareExtension/InspectFlowShareExtension.entitlements"
        base["INFOPLIST_FILE"] = "InspectFlowShareExtension/Info.plist"
        base["IPHONEOS_DEPLOYMENT_TARGET"] = "16.2"
        base["MARKETING_VERSION"] = "1.0"
        base["PRODUCT_BUNDLE_IDENTIFIER"] = "com.autoinspectornetwork.ios.InspectFlowShareExtension"
        base["SWIFT_VERSION"] = "5.0"
        base["INFOPLIST_KEY_CFBundleDisplayName"] = "InspectFlowShareExtension"
        base["INFOPLIST_KEY_NSHumanReadableCopyright"] = '""'
    elif target_name == "AgendaWidgetExtension":
        base["LD_RUNPATH_SEARCH_PATHS"] = (
            '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t\t"@executable_path/../../Frameworks",\n\t\t\t\t)'
        )
        base["CODE_SIGN_ENTITLEMENTS"] = "AgendaWidgetExtension/AgendaWidgetExtension.entitlements"
        base["INFOPLIST_FILE"] = "AgendaWidgetExtension/Info.plist"
        base["IPHONEOS_DEPLOYMENT_TARGET"] = "16.2"
        base["MARKETING_VERSION"] = "1.0"
        base["PRODUCT_BUNDLE_IDENTIFIER"] = "com.autoinspectornetwork.ios.AgendaWidgetExtension"
        base["SWIFT_VERSION"] = "5.0"
    return base


# --------------------------------------------------------------------------- #
# Helpers for rendering
# --------------------------------------------------------------------------- #
def render_dict(d: Dict[str, str], indent: int = 4) -> str:
    pad = "\t" * indent
    lines = []
    for k in sorted(d.keys()):
        v = d[k]
        lines.append(f"{pad}{k} = {v};")
    return "\n".join(lines)


def render_settings_block(settings: Dict[str, str]) -> str:
    body_lines = ["{", "\t\t\t\tbuildSettings = {"]
    for k in sorted(settings.keys()):
        body_lines.append(f"\t\t\t\t\t{k} = {settings[k]};")
    body_lines.append("\t\t\t\t};")
    return body_lines


# --------------------------------------------------------------------------- #
# Main generator
# --------------------------------------------------------------------------- #
def main() -> int:
    src = discover()
    pbx = PBX()

    # ---- File references for all source/resource/plist/entitlements files ----
    # App-target resources
    app_resources_relative = ["Assets.xcassets", "InspectionModel.xcdatamodeld"]

    # Tree of every file we want visible in Project Navigator.
    tree = Tree()

    # Add app sources
    for f in src["app"]:
        tree.add_file(f)
    # Share sources
    for f in src["share"]:
        tree.add_file(f)
    # Widget sources (some live under Shared/Widget — already added)
    for f in src["widget"]:
        tree.add_file(f)
    # Resources
    for r in app_resources_relative:
        tree.add_file(r)
    # Plists & entitlements
    tree.add_file("Info.plist")
    tree.add_file("AutoInspectorNetwork.entitlements")
    tree.add_file("InspectFlowShareExtension/Info.plist")
    tree.add_file("InspectFlowShareExtension/InspectFlowShareExtension.entitlements")
    # NOTE: MainInterface.storyboard intentionally not added as a plain file —
    # it is represented by a PBXVariantGroup attached to InspectFlowShareExtension below.
    tree.add_file("AgendaWidgetExtension/Info.plist")
    tree.add_file("AgendaWidgetExtension/AgendaWidgetExtension.entitlements")

    tree.assign_uids()

    # Extra (synthetic) children to append to specific groups when emitting the tree.
    extra_group_children: Dict[str, List[Tuple[str, str]]] = {}
    _variant_uid_preview = uid("variantgroup:MainInterface.storyboard")
    extra_group_children["InspectFlowShareExtension"] = [
        (_variant_uid_preview, "MainInterface.storyboard"),
    ]

    # Collect file nodes by path
    file_nodes: Dict[str, Node] = {}

    def collect(n: Node):
        if n.is_file:
            file_nodes[n.path] = n
        else:
            for c in n.children.values():
                collect(c)
    collect(tree.root)

    # ---- Emit PBXFileReference for each file ----
    for path, node in sorted(file_nodes.items()):
        ftype, src_tree = file_type_for(path)
        name = path.rsplit("/", 1)[-1]
        body = (
            "{isa = PBXFileReference; "
            f"lastKnownFileType = {ftype}; "
            f"path = {quote(name)}; "
            f"sourceTree = \"{src_tree}\"; }}"
        )
        pbx.add("PBXFileReference", node.ref_uid, name, body)

    # ---- Product references (one per target) ----
    products = {
        "AutoInspectorNetwork": ("AutoInspectorNetwork.app", "wrapper.application"),
        "InspectFlowShareExtension": ("InspectFlowShareExtension.appex", "wrapper.app-extension"),
        "AgendaWidgetExtension": ("AgendaWidgetExtension.appex", "wrapper.app-extension"),
    }
    product_refs: Dict[str, str] = {}
    for tname, (fname, ftype) in products.items():
        u = uid(f"product:{tname}")
        product_refs[tname] = u
        body = (
            "{isa = PBXFileReference; "
            "explicitFileType = " + ftype + "; "
            "includeInIndex = 0; "
            f"path = {fname}; "
            "sourceTree = BUILT_PRODUCTS_DIR; }"
        )
        pbx.add("PBXFileReference", u, fname, body)

    # ---- PBXGroup tree ----
    def emit_groups(node: Node, is_root: bool = False):
        if node.is_file:
            return
        children_uids: List[Tuple[str, str]] = []
        # files first then groups, alpha by name within
        files = sorted([c for c in node.children.values() if c.is_file], key=lambda c: c.name)
        groups = sorted([c for c in node.children.values() if not c.is_file], key=lambda c: c.name)
        for c in groups + files:
            children_uids.append((c.uid, c.name))
            emit_groups(c)
        # synthetic injections (e.g. PBXVariantGroup)
        for extra in extra_group_children.get(node.path, []):
            children_uids.append(extra)
        # root group gets the Products subgroup appended
        if is_root:
            children_uids.append((PRODUCTS_GROUP_UID, "Products"))
        kids = ",\n\t\t\t\t".join(f"{u}{comment(n)}" for u, n in children_uids)
        if is_root:
            body = (
                "{\n\t\t\tisa = PBXGroup;\n"
                f"\t\t\tchildren = (\n\t\t\t\t{kids},\n\t\t\t);\n"
                "\t\t\tsourceTree = \"<group>\";\n"
                "\t\t}"
            )
            pbx.add("PBXGroup", node.uid, "MainGroup", body)
        else:
            body = (
                "{\n\t\t\tisa = PBXGroup;\n"
                f"\t\t\tchildren = (\n\t\t\t\t{kids},\n\t\t\t);\n"
                f"\t\t\tpath = {quote(node.name)};\n"
                "\t\t\tsourceTree = \"<group>\";\n"
                "\t\t}"
            )
            pbx.add("PBXGroup", node.uid, node.name, body)

    PRODUCTS_GROUP_UID = uid("group:Products")
    # assign mainGroup uid
    tree.root.uid = uid("group:MainGroup")
    emit_groups(tree.root, is_root=True)

    # Products group
    prod_kids = ",\n\t\t\t\t".join(
        f"{product_refs[t]}{comment(products[t][0])}" for t in products
    )
    pbx.add(
        "PBXGroup",
        PRODUCTS_GROUP_UID,
        "Products",
        "{\n\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n\t\t\t\t{prod_kids},\n\t\t\t);\n"
        "\t\t\tname = Products;\n"
        "\t\t\tsourceTree = \"<group>\";\n"
        "\t\t}",
    )

    # ---- PBXBuildFile entries ----
    def add_build_file(target: str, file_ref_uid: str, file_name: str, phase: str) -> str:
        bu = uid(f"buildfile:{target}:{phase}:{file_ref_uid}")
        body = (
            "{isa = PBXBuildFile; "
            f"fileRef = {file_ref_uid}{comment(file_name)}; }}"
        )
        pbx.add("PBXBuildFile", bu, f"{file_name} in {phase}", body)
        return bu

    sources_bf: Dict[str, List[Tuple[str, str]]] = {"AutoInspectorNetwork": [], "InspectFlowShareExtension": [], "AgendaWidgetExtension": []}
    resources_bf: Dict[str, List[Tuple[str, str]]] = {"AutoInspectorNetwork": [], "InspectFlowShareExtension": [], "AgendaWidgetExtension": []}

    for f in src["app"]:
        n = file_nodes[f]
        bu = add_build_file("AutoInspectorNetwork", n.ref_uid, n.name, "Sources")
        sources_bf["AutoInspectorNetwork"].append((bu, n.name))
    for f in src["share"]:
        n = file_nodes[f]
        bu = add_build_file("InspectFlowShareExtension", n.ref_uid, n.name, "Sources")
        sources_bf["InspectFlowShareExtension"].append((bu, n.name))
    for f in src["widget"]:
        n = file_nodes[f]
        bu = add_build_file("AgendaWidgetExtension", n.ref_uid, n.name, "Sources")
        sources_bf["AgendaWidgetExtension"].append((bu, n.name))

    # Resources for app
    for r in app_resources_relative:
        n = file_nodes[r]
        bu = add_build_file("AutoInspectorNetwork", n.ref_uid, n.name, "Resources")
        resources_bf["AutoInspectorNetwork"].append((bu, n.name))

    # MainInterface.storyboard for share extension (as PBXVariantGroup container)
    variant_uid = uid("variantgroup:MainInterface.storyboard")
    # Need a Base lang fileRef inside the variant group
    base_lang_uid = uid("lang:Base:MainInterface.storyboard")
    # Re-purpose: emit a file ref for Base lang pointing at the storyboard
    pbx.add(
        "PBXFileReference",
        base_lang_uid,
        "Base",
        "{isa = PBXFileReference; "
        "lastKnownFileType = file.storyboard; "
        "name = Base; "
        "path = Base.lproj/MainInterface.storyboard; "
        "sourceTree = \"<group>\"; }",
    )
    # Variant group references base_lang
    pbx.add(
        "PBXVariantGroup",
        variant_uid,
        "MainInterface.storyboard",
        "{\n\t\t\tisa = PBXVariantGroup;\n"
        f"\t\t\tchildren = (\n\t\t\t\t{base_lang_uid}{comment('Base')},\n\t\t\t);\n"
        "\t\t\tname = MainInterface.storyboard;\n"
        "\t\t\tsourceTree = \"<group>\";\n"
        "\t\t}",
    )
    # The existing storyboard file node already lives in Project Navigator — keep it as-is.
    # Build file for the variant group goes into Share Resources.
    sb_bf = add_build_file("InspectFlowShareExtension", variant_uid, "MainInterface.storyboard", "Resources")
    resources_bf["InspectFlowShareExtension"].append((sb_bf, "MainInterface.storyboard"))

    # ---- Build phases ----
    phase_uids: Dict[Tuple[str, str], str] = {}
    for tname in products:
        # Sources
        sp = uid(f"phase:sources:{tname}")
        phase_uids[(tname, "Sources")] = sp
        files = ",\n\t\t\t\t".join(f"{bu}{comment(name + ' in Sources')}" for bu, name in sources_bf[tname])
        pbx.add(
            "PBXSourcesBuildPhase",
            sp,
            "Sources",
            "{\n\t\t\tisa = PBXSourcesBuildPhase;\n"
            "\t\t\tbuildActionMask = 2147483647;\n"
            f"\t\t\tfiles = (\n\t\t\t\t{files},\n\t\t\t);\n"
            "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
            "\t\t}" if sources_bf[tname] else
            "{\n\t\t\tisa = PBXSourcesBuildPhase;\n"
            "\t\t\tbuildActionMask = 2147483647;\n"
            "\t\t\tfiles = (\n\t\t\t);\n"
            "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
            "\t\t}",
        )
        # Frameworks (empty)
        fp = uid(f"phase:frameworks:{tname}")
        phase_uids[(tname, "Frameworks")] = fp
        pbx.add(
            "PBXFrameworksBuildPhase",
            fp,
            "Frameworks",
            "{\n\t\t\tisa = PBXFrameworksBuildPhase;\n"
            "\t\t\tbuildActionMask = 2147483647;\n"
            "\t\t\tfiles = (\n\t\t\t);\n"
            "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
            "\t\t}",
        )
        # Resources
        rp = uid(f"phase:resources:{tname}")
        phase_uids[(tname, "Resources")] = rp
        files = ",\n\t\t\t\t".join(f"{bu}{comment(name + ' in Resources')}" for bu, name in resources_bf[tname])
        pbx.add(
            "PBXResourcesBuildPhase",
            rp,
            "Resources",
            "{\n\t\t\tisa = PBXResourcesBuildPhase;\n"
            "\t\t\tbuildActionMask = 2147483647;\n"
            f"\t\t\tfiles = (\n\t\t\t\t{files},\n\t\t\t);\n"
            "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
            "\t\t}" if resources_bf[tname] else
            "{\n\t\t\tisa = PBXResourcesBuildPhase;\n"
            "\t\t\tbuildActionMask = 2147483647;\n"
            "\t\t\tfiles = (\n\t\t\t);\n"
            "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
            "\t\t}",
        )

    # ---- Embed Foundation Extensions (main app) ----
    embed_uid = uid("phase:embed:AutoInspectorNetwork")
    embed_files: List[Tuple[str, str]] = []
    for ext in ("InspectFlowShareExtension", "AgendaWidgetExtension"):
        bu = uid(f"buildfile:Embed:{ext}")
        body = (
            "{isa = PBXBuildFile; "
            f"fileRef = {product_refs[ext]}{comment(products[ext][0])}; "
            "settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; }"
        )
        pbx.add("PBXBuildFile", bu, f"{products[ext][0]} in Embed Foundation Extensions", body)
        embed_files.append((bu, products[ext][0]))

    embed_kids = ",\n\t\t\t\t".join(
        f"{bu}{comment(name + ' in Embed Foundation Extensions')}" for bu, name in embed_files
    )
    pbx.add(
        "PBXCopyFilesBuildPhase",
        embed_uid,
        "Embed Foundation Extensions",
        "{\n\t\t\tisa = PBXCopyFilesBuildPhase;\n"
        "\t\t\tbuildActionMask = 2147483647;\n"
        "\t\t\tdstPath = \"\";\n"
        "\t\t\tdstSubfolderSpec = 13;\n"
        f"\t\t\tfiles = (\n\t\t\t\t{embed_kids},\n\t\t\t);\n"
        "\t\t\tname = \"Embed Foundation Extensions\";\n"
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        "\t\t}",
    )

    # ---- Target dependencies (main app depends on both extensions) ----
    project_uid = uid("project:AutoInspectorNetwork")
    target_uids: Dict[str, str] = {t: uid(f"target:{t}") for t in products}

    dep_uids: Dict[str, str] = {}
    for ext in ("InspectFlowShareExtension", "AgendaWidgetExtension"):
        proxy_uid = uid(f"proxy:{ext}")
        dep_uid = uid(f"dep:{ext}")
        dep_uids[ext] = dep_uid
        pbx.add(
            "PBXContainerItemProxy",
            proxy_uid,
            f"PBXContainerItemProxy",
            "{\n\t\t\tisa = PBXContainerItemProxy;\n"
            f"\t\t\tcontainerPortal = {project_uid}{comment('Project object')};\n"
            "\t\t\tproxyType = 1;\n"
            f"\t\t\tremoteGlobalIDString = {target_uids[ext]};\n"
            f"\t\t\tremoteInfo = {ext};\n"
            "\t\t}",
        )
        pbx.add(
            "PBXTargetDependency",
            dep_uid,
            f"PBXTargetDependency",
            "{\n\t\t\tisa = PBXTargetDependency;\n"
            f"\t\t\ttarget = {target_uids[ext]}{comment(ext)};\n"
            f"\t\t\ttargetProxy = {proxy_uid}{comment('PBXContainerItemProxy')};\n"
            "\t\t}",
        )

    # ---- Build configurations ----
    def make_xcbuildconfig(name: str, settings: Dict[str, str], config: str) -> str:
        u = uid(f"buildconfig:{name}:{config}")
        sett = "\n".join(f"\t\t\t\t{k} = {settings[k]};" for k in sorted(settings.keys()))
        body = (
            "{\n\t\t\tisa = XCBuildConfiguration;\n"
            f"\t\t\tbuildSettings = {{\n{sett}\n\t\t\t}};\n"
            f"\t\t\tname = {config};\n"
            "\t\t}"
        )
        pbx.add("XCBuildConfiguration", u, config, body)
        return u

    # Project-level configs
    proj_debug = dict(COMMON_BUILD_SETTINGS, **DEBUG_PROJECT_SETTINGS)
    proj_debug["IPHONEOS_DEPLOYMENT_TARGET"] = "16.0"
    proj_release = dict(COMMON_BUILD_SETTINGS, **RELEASE_PROJECT_SETTINGS)
    proj_release["IPHONEOS_DEPLOYMENT_TARGET"] = "16.0"

    proj_debug_uid = make_xcbuildconfig("project", proj_debug, "Debug")
    proj_release_uid = make_xcbuildconfig("project", proj_release, "Release")

    proj_config_list_uid = uid("configlist:project")
    pbx.add(
        "XCConfigurationList",
        proj_config_list_uid,
        "Build configuration list for PBXProject \"AutoInspectorNetwork\"",
        "{\n\t\t\tisa = XCConfigurationList;\n"
        "\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{proj_debug_uid}{comment('Debug')},\n"
        f"\t\t\t\t{proj_release_uid}{comment('Release')},\n"
        "\t\t\t);\n"
        "\t\t\tdefaultConfigurationIsVisible = 0;\n"
        "\t\t\tdefaultConfigurationName = Release;\n"
        "\t\t}",
    )

    # Per-target configs
    target_config_lists: Dict[str, str] = {}
    for tname in products:
        dbg = target_settings(tname, "Debug")
        rel = target_settings(tname, "Release")
        dbg_uid = make_xcbuildconfig(f"target:{tname}", dbg, "Debug")
        rel_uid = make_xcbuildconfig(f"target:{tname}", rel, "Release")
        cl = uid(f"configlist:target:{tname}")
        target_config_lists[tname] = cl
        pbx.add(
            "XCConfigurationList",
            cl,
            f"Build configuration list for PBXNativeTarget \"{tname}\"",
            "{\n\t\t\tisa = XCConfigurationList;\n"
            "\t\t\tbuildConfigurations = (\n"
            f"\t\t\t\t{dbg_uid}{comment('Debug')},\n"
            f"\t\t\t\t{rel_uid}{comment('Release')},\n"
            "\t\t\t);\n"
            "\t\t\tdefaultConfigurationIsVisible = 0;\n"
            "\t\t\tdefaultConfigurationName = Release;\n"
            "\t\t}",
        )

    # ---- Native targets ----
    for tname in products:
        phases = [
            phase_uids[(tname, "Sources")],
            phase_uids[(tname, "Frameworks")],
            phase_uids[(tname, "Resources")],
        ]
        if tname == "AutoInspectorNetwork":
            phases.append(embed_uid)
        deps: List[str] = []
        if tname == "AutoInspectorNetwork":
            deps = [dep_uids["InspectFlowShareExtension"], dep_uids["AgendaWidgetExtension"]]
        phase_str = ",\n\t\t\t\t".join(f"{p}{comment(label_for_phase(p, phase_uids, embed_uid))}" for p in phases)
        deps_str = ",\n\t\t\t\t".join(f"{d}{comment('PBXTargetDependency')}" for d in deps)
        ptype = {
            "AutoInspectorNetwork": '"com.apple.product-type.application"',
            "InspectFlowShareExtension": '"com.apple.product-type.app-extension"',
            "AgendaWidgetExtension": '"com.apple.product-type.app-extension"',
        }[tname]
        body = (
            "{\n\t\t\tisa = PBXNativeTarget;\n"
            f"\t\t\tbuildConfigurationList = {target_config_lists[tname]}{comment(f'Build configuration list for PBXNativeTarget \"{tname}\"')};\n"
            f"\t\t\tbuildPhases = (\n\t\t\t\t{phase_str},\n\t\t\t);\n"
            "\t\t\tbuildRules = (\n\t\t\t);\n"
            f"\t\t\tdependencies = (\n" + (f"\t\t\t\t{deps_str},\n" if deps else "") + "\t\t\t);\n"
            f"\t\t\tname = {tname};\n"
            f"\t\t\tproductName = {tname};\n"
            f"\t\t\tproductReference = {product_refs[tname]}{comment(products[tname][0])};\n"
            f"\t\t\tproductType = {ptype};\n"
            "\t\t}"
        )
        pbx.add("PBXNativeTarget", target_uids[tname], tname, body)

    # ---- PBXProject ----
    targets_str = ",\n\t\t\t\t".join(f"{target_uids[t]}{comment(t)}" for t in products)
    target_attrs_lines: List[str] = []
    for tname in products:
        target_attrs_lines.append(f"\t\t\t\t\t{target_uids[tname]} = {{")
        target_attrs_lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
        target_attrs_lines.append("\t\t\t\t\t};")
    target_attrs = "\n".join(target_attrs_lines)
    body = (
        "{\n\t\t\tisa = PBXProject;\n"
        "\t\t\tattributes = {\n"
        "\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
        "\t\t\t\tLastSwiftUpdateCheck = 1500;\n"
        "\t\t\t\tLastUpgradeCheck = 1500;\n"
        "\t\t\t\tTargetAttributes = {\n"
        f"{target_attrs}\n"
        "\t\t\t\t};\n"
        "\t\t\t};\n"
        f"\t\t\tbuildConfigurationList = {proj_config_list_uid}{comment('Build configuration list for PBXProject \"AutoInspectorNetwork\"')};\n"
        "\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
        "\t\t\tdevelopmentRegion = en;\n"
        "\t\t\thasScannedForEncodings = 0;\n"
        "\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n"
        f"\t\t\tmainGroup = {tree.root.uid}{comment('MainGroup')};\n"
        f"\t\t\tproductRefGroup = {PRODUCTS_GROUP_UID}{comment('Products')};\n"
        "\t\t\tprojectDirPath = \"\";\n"
        "\t\t\tprojectRoot = \"\";\n"
        f"\t\t\ttargets = (\n\t\t\t\t{targets_str},\n\t\t\t);\n"
        "\t\t}"
    )
    pbx.add("PBXProject", project_uid, "Project object", body)

    # ---- Render and write ----
    out = pbx.render("1", "56", project_uid, "Project object")
    PBX_PATH.parent.mkdir(parents=True, exist_ok=True)
    PBX_PATH.write_text(out)
    print(f"wrote {PBX_PATH} ({len(out)} bytes, {len(pbx.objects)} objects)")

    # ---- Schemes ----
    SCHEMES_DIR.mkdir(parents=True, exist_ok=True)
    blueprint_id = target_uids["AutoInspectorNetwork"]
    for scheme_name in ("AutoInspectorNetwork", "VehicleInspectorsApp"):
        (SCHEMES_DIR / f"{scheme_name}.xcscheme").write_text(
            scheme_xml(scheme_name, blueprint_id)
        )
        print(f"wrote scheme {scheme_name}.xcscheme")

    return 0


def label_for_phase(p_uid: str, phase_uids: Dict[Tuple[str, str], str], embed_uid: str) -> str:
    if p_uid == embed_uid:
        return "Embed Foundation Extensions"
    for (tname, kind), u in phase_uids.items():
        if u == p_uid:
            return kind
    return ""


def quote(s: str) -> str:
    # Quote if it contains spaces or special chars
    if not s:
        return '""'
    if all(c.isalnum() or c in "._-+/" for c in s):
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def scheme_xml(scheme_name: str, blueprint_id: str) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{blueprint_id}"
               BuildableName = "AutoInspectorNetwork.app"
               BlueprintName = "AutoInspectorNetwork"
               ReferencedContainer = "container:AutoInspectorNetwork.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{blueprint_id}"
            BuildableName = "AutoInspectorNetwork.app"
            BlueprintName = "AutoInspectorNetwork"
            ReferencedContainer = "container:AutoInspectorNetwork.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{blueprint_id}"
            BuildableName = "AutoInspectorNetwork.app"
            BlueprintName = "AutoInspectorNetwork"
            ReferencedContainer = "container:AutoInspectorNetwork.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


if __name__ == "__main__":
    sys.exit(main())
