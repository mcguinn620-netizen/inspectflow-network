#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
BANNED_STRINGS = [
    "Placeholder for native",
    "Step 3.5 scaffold",
    'Button("Save") { dismiss() }',
]
EMPTY_ACTION_PATTERNS = [
    re.compile(r'Button\("[^"]+"\)\s*\{\s*\}', re.MULTILINE),
    re.compile(r'AINSecondaryButton\([^\n)]*(?:\)[^\{]*)?\)\s*\{\s*\}', re.MULTILINE),
]


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    sys.exit(1)


def read(relative_path: str) -> str:
    file_path = ROOT / relative_path
    if not file_path.exists():
        fail(f"Missing file: {relative_path}")
    return file_path.read_text(encoding="utf-8")


def assert_contains(relative_path: str, content: str, tokens: list[str]) -> None:
    for token in tokens:
        if token not in content:
            fail(f"Missing semantic token '{token}' in {relative_path}")


def assert_no_known_placeholders() -> None:
    for swift_file in ROOT.rglob("*.swift"):
        content = swift_file.read_text(encoding="utf-8")
        rel = swift_file.relative_to(ROOT)
        for banned in BANNED_STRINGS:
            if banned in content:
                fail(f"Known placeholder/no-op string '{banned}' found in {rel}")
        for pattern in EMPTY_ACTION_PATTERNS:
            match = pattern.search(content)
            if match:
                fail(f"Empty action closure found in {rel}: {match.group(0)!r}")


assert_no_known_placeholders()

service = read("Core/Network/SupabaseService.swift")
assert_contains(
    "Core/Network/SupabaseService.swift",
    service,
    [
        "func assignJob(jobId: UUID, inspectorId: UUID) async throws",
        'client.db.from("jobs")',
        '"assigned_inspector_id"',
        '.eq("id", jobId.uuidString)',
    ],
)

view_model = read("Features/Jobs/JobsViewModel.swift")
assert_contains(
    "Features/Jobs/JobsViewModel.swift",
    view_model,
    [
        "func assign(job: Job, inspectorId: UUID, orgId: UUID?) async",
        "try await SupabaseService.shared.assignJob",
        "func reschedule(job: Job, scheduledAt: Date, orgId: UUID?) async",
        "try await SupabaseService.shared.updateJobSchedule",
    ],
)

schedule = read("Features/Schedule/ScheduleView.swift")
assert_contains(
    "Features/Schedule/ScheduleView.swift",
    schedule,
    [
        "ScheduleWeekCalendarView",
        "CalendarKitDayView",
        "onLongPressGesture",
        "Scheduling conflicts detected",
        "DispatcherAssignSheet",
        "Assign inspector",
        "await viewModel.reschedule(job:",
        "await viewModel.assign(job:",
        "TextField(\"Inspector UUID\"",
        "onAssign(inspectorId)",
    ],
)

print("OK: Step 3.4 schedule/dispatch flow performs concrete write actions and contains no known no-op placeholders.")
