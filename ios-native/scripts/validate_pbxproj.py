#!/usr/bin/env python3
"""Lightweight validator for AutoInspectorNetwork.xcodeproj/project.pbxproj.

Checks structural invariants Xcode 26's loader cares about:
  - every UUID referenced from PBXBuildFile.fileRef resolves
  - every UUID in PBXGroup.children resolves
  - every UUID in PBXNativeTarget (buildPhases, buildConfigurationList,
    productReference, dependencies) resolves
  - every UUID in PBXProject.targets resolves
  - every PBXFileReference is reachable from mainGroup (no orphan refs)
  - every PBXNativeTarget.productReference is a member of productRefGroup

Prints the first anomaly and exits non-zero. Otherwise prints OK.
"""

from pathlib import Path
import re
import sys

PROJ = Path(__file__).resolve().parent.parent / "AutoInspectorNetwork.xcodeproj" / "project.pbxproj"

UUID_RE = re.compile(r"\b([0-9A-F]{24}|[A-Z0-9]{20,32})\b")


def parse_objects(text: str) -> dict[str, dict]:
    """Very small OpenStep subset parser: extracts every top-level object
    in the `objects = { ... };` dict as {uuid: raw_body_text}."""
    # Find start of objects dict
    m = re.search(r"objects = \{\n", text)
    if not m:
        sys.exit("could not find objects dict")
    start = m.end()

    objs: dict[str, dict] = {}
    i = start
    n = len(text)
    while i < n:
        # Skip whitespace and comments
        while i < n:
            if text[i] in " \t\n":
                i += 1
            elif text[i:i+2] == "/*":
                end = text.find("*/", i)
                i = end + 2 if end != -1 else n
            else:
                break
        if i >= n or text[i] == "}":
            break
        # Read UUID key
        key_match = re.match(r"([A-Za-z0-9_]+)", text[i:])
        if not key_match:
            sys.exit(f"unexpected char at {i}: {text[i:i+40]!r}")
        uuid = key_match.group(1)
        i += key_match.end()
        # Skip until '{' starting the body
        brace = text.find("{", i)
        eq = text.find("=", i)
        if brace == -1:
            sys.exit("missing { for object body")
        i = brace + 1
        depth = 1
        body_start = i
        while i < n and depth > 0:
            if text[i:i+2] == "/*":
                end = text.find("*/", i)
                i = end + 2 if end != -1 else n
                continue
            if text[i] == '"':
                # skip quoted string
                j = i + 1
                while j < n and text[j] != '"':
                    if text[j] == "\\":
                        j += 2
                    else:
                        j += 1
                i = j + 1
                continue
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        body = text[body_start:i-1]
        # Skip trailing semicolon
        while i < n and text[i] in " \t\n;":
            i += 1
        objs[uuid] = body
    return objs


def isa_of(body: str) -> str | None:
    m = re.search(r"\bisa\s*=\s*([A-Za-z0-9_]+)", body)
    return m.group(1) if m else None


def field(body: str, name: str) -> str | None:
    """Return raw value text for `name = ...;` at top level of body."""
    # Naive: find `name = ` then capture until matching `;` at depth 0.
    idx = re.search(rf"\b{name}\s*=\s*", body)
    if not idx:
        return None
    i = idx.end()
    depth = 0
    start = i
    n = len(body)
    while i < n:
        c = body[i]
        if c == "{" or c == "(":
            depth += 1
        elif c == "}" or c == ")":
            depth -= 1
        elif c == ";" and depth == 0:
            return body[start:i].strip()
        elif c == '"':
            j = i + 1
            while j < n and body[j] != '"':
                j += 2 if body[j] == "\\" else 1
            i = j
        i += 1
    return body[start:].strip()


def uuids_in(value: str) -> list[str]:
    if not value:
        return []
    return [m.group(0) for m in re.finditer(r"\b([A-Z0-9]{20,32})\b", value)]


def main() -> int:
    text = PROJ.read_text()
    objs = parse_objects(text)
    print(f"parsed {len(objs)} objects")

    isa = {u: isa_of(b) for u, b in objs.items()}

    errors: list[str] = []

    def check(cond: bool, msg: str):
        if not cond:
            errors.append(msg)

    # 1. Every PBXBuildFile.fileRef resolves
    for uuid, body in objs.items():
        if isa[uuid] == "PBXBuildFile":
            fr = field(body, "fileRef")
            target = uuids_in(fr or "")[0] if uuids_in(fr or "") else None
            check(target in objs, f"PBXBuildFile {uuid} has unresolved fileRef {target!r}")

    # 2. PBXGroup children resolve
    for uuid, body in objs.items():
        if isa[uuid] in ("PBXGroup", "PBXVariantGroup"):
            children = field(body, "children") or ""
            for cu in uuids_in(children):
                check(cu in objs, f"Group {uuid} has unresolved child {cu}")

    # 3. PBXNativeTarget references
    targets: list[str] = []
    for uuid, body in objs.items():
        if isa[uuid] == "PBXNativeTarget":
            targets.append(uuid)
            for attr in ("buildConfigurationList", "productReference"):
                v = field(body, attr)
                u = uuids_in(v or "")
                check(u and u[0] in objs, f"NativeTarget {uuid}.{attr} -> {v!r} unresolved")
            for attr in ("buildPhases", "dependencies"):
                v = field(body, attr) or ""
                for cu in uuids_in(v):
                    check(cu in objs, f"NativeTarget {uuid}.{attr} child {cu} unresolved")

    # 4. PBXProject.targets resolves
    project = next((u for u, b in objs.items() if isa[u] == "PBXProject"), None)
    check(project is not None, "no PBXProject found")
    if project:
        pt = field(objs[project], "targets") or ""
        for cu in uuids_in(pt):
            check(cu in objs, f"PBXProject.targets child {cu} unresolved")
            check(cu in targets, f"PBXProject.targets child {cu} not a PBXNativeTarget")

        main_group = uuids_in(field(objs[project], "mainGroup") or "")
        prod_group = uuids_in(field(objs[project], "productRefGroup") or "")
        check(main_group and main_group[0] in objs, "mainGroup unresolved")
        check(prod_group and prod_group[0] in objs, "productRefGroup unresolved")

        # 5. Reachability from mainGroup
        reachable: set[str] = set()
        stack = [main_group[0]] if main_group else []
        while stack:
            u = stack.pop()
            if u in reachable or u not in objs:
                continue
            reachable.add(u)
            if isa[u] in ("PBXGroup", "PBXVariantGroup"):
                for cu in uuids_in(field(objs[u], "children") or ""):
                    stack.append(cu)

        # All PBXFileReference must be reachable
        for uuid, body in objs.items():
            if isa[uuid] == "PBXFileReference" and uuid not in reachable:
                errors.append(f"orphan PBXFileReference {uuid} ({field(body, 'path')!r})")

        # 6. Every NativeTarget.productReference must be a child of productRefGroup
        if prod_group:
            pr_children = set(uuids_in(field(objs[prod_group[0]], "children") or ""))
            for t in targets:
                pr = uuids_in(field(objs[t], "productReference") or "")
                if pr and pr[0] not in pr_children:
                    errors.append(
                        f"NativeTarget {t} productReference {pr[0]} not in productRefGroup"
                    )

    if errors:
        for e in errors:
            print("FAIL:", e)
        print(f"\n{len(errors)} issue(s)")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
