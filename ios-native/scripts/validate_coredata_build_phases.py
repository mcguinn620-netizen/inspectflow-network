#!/usr/bin/env python3
import pathlib
import re
import sys

pbxproj = pathlib.Path('ios-native/AutoInspectorNetwork.xcodeproj/project.pbxproj')
text = pbxproj.read_text()
lines = text.splitlines()

buildfile_re = re.compile(r'^\s*([A-F0-9]{24}) /\* (.+?) \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})')
fileref_re = re.compile(r'^\s*([A-F0-9]{24}) /\* (.+?) \*/ = \{isa = PBXFileReference; .*lastKnownFileType = ([^;]+);')

buildfiles = {}
for i, line in enumerate(lines, 1):
    m = buildfile_re.match(line)
    if m:
        buildfiles[m.group(1)] = {"name": m.group(2), "fileRef": m.group(3), "line": i}

filerefs = {}
for i, line in enumerate(lines, 1):
    m = fileref_re.match(line)
    if m:
        filerefs[m.group(1)] = {"name": m.group(2), "type": m.group(3), "line": i}

def phase_files(section_begin: str, section_end: str):
    in_section = False
    result = []
    for i, line in enumerate(lines, 1):
        if section_begin in line:
            in_section = True
        elif section_end in line:
            in_section = False
        elif in_section:
            m = re.search(r'\b([A-F0-9]{24}) /\*', line)
            if m and m.group(1) in buildfiles:
                bf = buildfiles[m.group(1)]
                fr = filerefs.get(bf['fileRef'], {"type": "unknown", "name": "unknown"})
                result.append((bf['name'], fr['type'], i))
    return result

resource_entries = phase_files('/* Begin PBXResourcesBuildPhase section */', '/* End PBXResourcesBuildPhase section */')
source_entries = phase_files('/* Begin PBXSourcesBuildPhase section */', '/* End PBXSourcesBuildPhase section */')

bad_resource_swift = [e for e in resource_entries if e[0].endswith('.swift in Resources') or e[1] == 'sourcecode.swift']
has_model_resource = any('xcdatamodeld in Resources' in e[0] for e in resource_entries)

if bad_resource_swift:
    print('ERROR: Swift files found in Copy Bundle Resources:')
    for name, _, line in bad_resource_swift:
        print(f' - {name} (line {line})')
    sys.exit(1)

if not has_model_resource:
    print('ERROR: Missing InspectionModel.xcdatamodeld in Resources build phase')
    sys.exit(1)

print('OK: No Swift files in Copy Bundle Resources.')
print('OK: InspectionModel.xcdatamodeld remains in Resources.')
print(f'Info: Resources entries = {len(resource_entries)}, Source entries = {len(source_entries)}')
