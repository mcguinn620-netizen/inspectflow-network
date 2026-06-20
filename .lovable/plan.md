## Problem

Bitrise fails with:
```
lstat .../AutoInspectorNetwork.xcworkspace/contents.xcworkspacedata: not a directory
```

`ios-native/AutoInspectorNetwork.xcworkspace` is on disk as a **1343-byte regular file** (actually a ZIP archive — `PK` header visible), not the directory bundle Xcode/Bitrise expects. `bitrise.yml` points `BITRISE_PROJECT_PATH` at this workspace, so every Xcode step fails before it begins.

## Fix

Replace the broken file with a proper workspace bundle that references the existing `AutoInspectorNetwork.xcodeproj`. Smallest change, no `bitrise.yml` edits needed.

### Steps

1. `rm ios-native/AutoInspectorNetwork.xcworkspace` (the corrupt zip-as-file).
2. Create `ios-native/AutoInspectorNetwork.xcworkspace/contents.xcworkspacedata` with:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <Workspace version = "1.0">
      <FileRef location = "group:AutoInspectorNetwork.xcodeproj"></FileRef>
   </Workspace>
   ```
3. Verify by listing the directory and confirming `contents.xcworkspacedata` is present.

### Out of scope

- No changes to `bitrise.yml`, `project.yml`, or the `.xcodeproj`.
- Not regenerating the workspace via XcodeGen (project.yml has no `schemes`-level workspace block; keeping it minimal and explicit).
