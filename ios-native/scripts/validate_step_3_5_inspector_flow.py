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
    re.compile(r'AIN(?:Primary|Secondary)Button\([^\n)]*\)\s*\{\s*\}', re.MULTILINE),
    re.compile(r'AIN(?:Primary|Secondary)Button\([^\)]*action:\s*\{\s*\}\s*\)', re.MULTILINE | re.DOTALL),
]
DASHBOARD_COMPONENT_EMPTY_BUTTON_PATTERNS = [
    re.compile(r'AIN(?:Primary|Secondary)Button\([^\)]*action:\s*\{\s*(?://[^\n]*\n\s*)?\}\s*\)', re.MULTILINE | re.DOTALL),
    re.compile(r'AIN(?:Primary|Secondary)Button\([^\n)]*\)\s*\{\s*(?://[^\n]*\n\s*)?\}', re.MULTILINE),
    re.compile(r'Button\([^\)]*action:\s*\{\s*(?://[^\n]*\n\s*)?\}\s*\)', re.MULTILINE | re.DOTALL),
    re.compile(r'Button\([^\)]*\)\s*\{\s*(?://[^\n]*\n\s*)?\}', re.MULTILINE | re.DOTALL),
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


def strip_swift_comments(content: str) -> str:
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    return re.sub(r'//.*', '', content)


def extract_function_body(content: str, function_name: str) -> str:
    match = re.search(rf'func\s+{re.escape(function_name)}\s*\([^)]*\)\s*(?:async\s*)?\{{', content)
    if not match:
        fail(f"Missing function {function_name}()")
    start = match.end() - 1
    depth = 0
    for index in range(start, len(content)):
        char = content[index]
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return content[start + 1:index]
    fail(f"Could not parse function body for {function_name}()")


def assert_start_trip_has_real_body(home: str) -> None:
    body = strip_swift_comments(extract_function_body(home, "startTrip")).strip()
    if not body:
        fail("InspectorDashboardHomeView.startTrip() contains only comments or whitespace")
    required = ["Task", "appState.activeOrganizationID", "SupabaseService.shared.currentUserID"]
    for token in required:
        if token not in body:
            fail(f"InspectorDashboardHomeView.startTrip() does not use required token '{token}'")
    if "viewModel.startTodayTrip" not in body and "viewModel.resumeActiveTrip" not in body:
        fail("InspectorDashboardHomeView.startTrip() must call concrete dashboard trip actions")


def assert_dashboard_buttons_not_empty() -> None:
    component_root = ROOT / "Features" / "Dashboard" / "Components"
    for swift_file in component_root.glob("*.swift"):
        content = swift_file.read_text(encoding="utf-8")
        rel = swift_file.relative_to(ROOT)
        for pattern in DASHBOARD_COMPONENT_EMPTY_BUTTON_PATTERNS:
            match = pattern.search(content)
            if match:
                fail(f"Dashboard component button has an empty action closure in {rel}: {match.group(0)!r}")


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
assert_dashboard_buttons_not_empty()

service = read("Core/Network/SupabaseService.swift")
assert_contains(
    "Core/Network/SupabaseService.swift",
    service,
    [
        "func createTrip(orgId: UUID, userId: UUID, title: String?) async throws -> Trip",
        "func updateTripStatus(tripId: UUID, status: String, extras: [String: Any] = [:]) async throws",
        "func fetchTripStops(tripId: UUID, limit: Int = 50) async throws -> [TripStop]",
        "func updateTripStopStatus(stopId: UUID, status: String, extras: [String: Any] = [:]) async throws",
        'client.db.from("trips")',
        'client.db.from("trip_stops")',
        ".insert(row)",
        ".update(row)",
    ],
)

view_model = read("Features/Dashboard/DashboardViewModel.swift")
assert_contains(
    "Features/Dashboard/DashboardViewModel.swift",
    view_model,
    [
        "@Published var nextTripStop: TripStop?",
        "@Published var nextJob: Job?",
        "func startTodayTrip(orgId: UUID?, userId: UUID?) async",
        "try await SupabaseService.shared.createTrip",
        "TripTrackingController.shared.start",
        "func pauseActiveTrip(orgId: UUID?, userId: UUID?) async",
        "try await SupabaseService.shared.updateTripStatus",
        "func resumeActiveTrip(orgId: UUID?, userId: UUID?) async",
        "func completeActiveStop(orgId: UUID?, userId: UUID?) async",
        "try await SupabaseService.shared.updateTripStopStatus",
        "try await SupabaseService.shared.updateJobStatus",
    ],
)

home = read("Features/Dashboard/InspectorDashboardHomeView.swift")
assert_start_trip_has_real_body(home)
assert_contains(
    "Features/Dashboard/InspectorDashboardHomeView.swift",
    home,
    [
        "StartMyDayCard(",
        "onStartTodayTrip: startTrip",
        "await viewModel.startTodayTrip",
        "await viewModel.resumeActiveTrip",
        "await viewModel.pauseActiveTrip",
        "await viewModel.completeActiveStop",
        "MapsLookupService.shared.open(stop: stop)",
        "MapsLookupService.shared.open(job: job)",
    ],
)

next_stop = read("Features/Dashboard/Components/NextStopCard.swift")
assert_contains(
    "Features/Dashboard/Components/NextStopCard.swift",
    next_stop,
    [
        "struct NextStopCard",
        "let nextTripStop: TripStop?",
        "let nextJob: Job?",
        "let onNavigate: () -> Void",
        "let onCompleteStop: () -> Void",
        'AINSecondaryButton("Navigate", systemImage: "location.fill", action: onNavigate)',
        'AINSecondaryButton("Complete stop", systemImage: "checkmark.circle.fill", action: onCompleteStop)',
    ],
)

active_banner = read("Features/Dashboard/Components/ActiveTripBanner.swift")
assert_contains(
    "Features/Dashboard/Components/ActiveTripBanner.swift",
    active_banner,
    [
        "struct ActiveTripBanner",
        "let onPauseTrip: () -> Void",
        'AINSecondaryButton("Pause", systemImage: "pause.fill", action: onPauseTrip)',
        "Open trips",
    ],
)

settings = read("Features/Settings/SettingsView.swift")
assert_contains("Features/Settings/SettingsView.swift", settings, ["Voice cues while driving"])

main_tab = read("App/MainTabView.swift")
assert_contains("App/MainTabView.swift", main_tab, ["InspectorDashboardHomeView", "role"])

print("OK: Step 3.5 inspector daily flow performs concrete write actions and contains no known no-op placeholders.")
