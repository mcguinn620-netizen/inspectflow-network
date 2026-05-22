#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = {
    ROOT / "Features/Schedule/ScheduleView.swift": [
        "LazyVGrid",
        "onLongPressGesture",
        "Scheduling conflicts detected",
        "DispatcherAssignSheet",
        "Assign to inspector",
    ],
}

for file_path, required_tokens in checks.items():
    if not file_path.exists():
        print(f"ERROR: Missing file: {file_path.relative_to(ROOT)}")
        sys.exit(1)
    content = file_path.read_text(encoding="utf-8")
    for token in required_tokens:
        if token not in content:
            print(f"ERROR: Missing token '{token}' in {file_path.relative_to(ROOT)}")
            sys.exit(1)

print("OK: Step 3.4 schedule + dispatch scaffolding is present.")
