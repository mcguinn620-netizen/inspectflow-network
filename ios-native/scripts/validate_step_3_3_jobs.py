#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = {
    ROOT / "Features/Jobs/JobDetailView.swift": ["struct JobDetailView", "OpenInMapsButton", "Quick Actions"],
    ROOT / "Features/Jobs/JobEditSheet.swift": ["struct JobEditSheet", "DatePicker", "TextField(\"Notes\""],
    ROOT / "Features/Jobs/JobsView.swift": ["NavigationLink", "JobDetailView"],
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

print("OK: Step 3.3 jobs read+write UI scaffolding is present.")
