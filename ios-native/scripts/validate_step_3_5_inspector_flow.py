#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = {
    ROOT / "Features/Dashboard/Components/StartMyDayCard.swift": [
        "struct StartMyDayCard",
        "Start my day",
        "Resume trip",
    ],
    ROOT / "Features/Dashboard/Components/NextStopCard.swift": [
        "struct NextStopCard",
        "Next stop",
        "Complete stop",
    ],
    ROOT / "Features/Dashboard/Components/ActiveTripBanner.swift": [
        "struct ActiveTripBanner",
        "Open trips",
        "Pause",
    ],
    ROOT / "Features/Settings/SettingsView.swift": [
        "Voice cues while driving",
    ],
    ROOT / "App/MainTabView.swift": [
        "InspectorDashboardHomeView",
        "role",
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

print("OK: Step 3.5 inspector daily flow scaffolding is present.")
