import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class IntakeInboxViewModel: ObservableObject {
    @Published var items: [IntakeItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var filter: String = "needs_review"
    @Published var urlInput: String = ""
    @Published var isFetchingUrl = false
    @Published var isUploadingPdf = false

    private let service = SupabaseService.shared
    private let appState: AppState

    init(appState: AppState) { self.appState = appState }

    func load() async {
        guard let orgId = appState.activeOrganizationID else { return }
        isLoading = true; defer { isLoading = false }
        do {
            items = try await service.fetchIntakeItems(
                orgId: orgId,
                status: filter == "all" ? nil : filter
            )
            error = nil
        } catch {
            self.error = AINFriendlyError.message(for: error)
        }
    }

    func submitUrl() async {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isFetchingUrl = true; defer { isFetchingUrl = false }
        do {
            try await service.ingestUrl(url: trimmed)
            urlInput = ""
            await load()
        } catch {
            self.error = AINFriendlyError.message(for: error)
        }
    }

    func uploadPdf(fileURL: URL) async {
        guard let orgId = appState.activeOrganizationID else { return }
        isUploadingPdf = true; defer { isUploadingPdf = false }
        let didStart = fileURL.startAccessingSecurityScopedResource()
        defer { if didStart { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: fileURL)
            try await service.ingestPdf(orgId: orgId, fileName: fileURL.lastPathComponent, data: data)
            await load()
        } catch {
            self.error = AINFriendlyError.message(for: error)
        }
    }

    func dismiss(_ item: IntakeItem) async {
        do {
            try await service.updateIntakeItemStatus(itemId: item.id, status: "dismissed")
            await load()
        } catch { self.error = AINFriendlyError.message(for: error) }
    }
}

struct IntakeInboxView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: IntakeInboxViewModel
    @StateObject private var sort = AINSortState(storageKey: "intake", defaultID: "created_at")
    @State private var selected: IntakeItem?
    @State private var showPdfPicker = false

    init(appState: AppState) {
        _vm = StateObject(wrappedValue: IntakeInboxViewModel(appState: appState))
    }

    private static let sortOptions: [AINSortOption] = [
        .init(id: "created_at", label: "Date added"),
        .init(id: "status", label: "Status"),
        .init(id: "confidence", label: "Confidence"),
        .init(id: "channel", label: "Channel"),
    ]

    private var sortedItems: [IntakeItem] {
        let items = vm.items
        let asc = sort.ascending
        switch sort.selectedID {
        case "status":
            return items.sorted { asc ? $0.status < $1.status : $0.status > $1.status }
        case "confidence":
            return items.sorted {
                let a = $0.confidence ?? -1, b = $1.confidence ?? -1
                return asc ? a < b : a > b
            }
        case "channel":
            return items.sorted { asc ? $0.channel < $1.channel : $0.channel > $1.channel }
        default:
            return items.sorted {
                let a = $0.createdAt ?? .distantPast, b = $1.createdAt ?? .distantPast
                return asc ? a < b : a > b
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("https://auction-site.com/listing/...", text: $vm.urlInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button {
                            Task { await vm.submitUrl() }
                        } label: {
                            if vm.isFetchingUrl { ProgressView() } else { Text("Fetch") }
                        }
                        .disabled(vm.urlInput.trimmingCharacters(in: .whitespaces).isEmpty || vm.isFetchingUrl)
                    }
                    Button {
                        showPdfPicker = true
                    } label: {
                        Label(vm.isUploadingPdf ? "Uploading PDF…" : "Import PDF", systemImage: "doc.richtext")
                    }
                    .disabled(vm.isUploadingPdf)
                } header: { Text("Add by URL or PDF") }

                Section {
                    Picker("Filter", selection: $vm.filter) {
                        Text("Needs review").tag("needs_review")
                        Text("Auto-created").tag("auto_created")
                        Text("Converted").tag("converted")
                        Text("Errors").tag("error")
                        Text("All").tag("all")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: vm.filter) { _ in Task { await vm.load() } }
                }

                Section {
                    if vm.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if sortedItems.isEmpty {
                        Text("No items in this view.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(sortedItems) { item in
                            Button { selected = item } label: {
                                IntakeRow(item: item)
                            }
                            .swipeActions {
                                if item.status != "dismissed" && item.status != "converted" {
                                    Button(role: .destructive) {
                                        Task { await vm.dismiss(item) }
                                    } label: { Label("Dismiss", systemImage: "trash") }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Intake Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AINSortMenu(storageKey: "intake",
                                options: Self.sortOptions,
                                selectedID: $sort.selectedID,
                                ascending: $sort.ascending)
                        .onChange(of: sort.selectedID) { _ in sort.persist() }
                        .onChange(of: sort.ascending) { _ in sort.persist() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await vm.load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .sheet(item: $selected) { item in
                IntakeReviewView(item: item) {
                    selected = nil
                    Task { await vm.load() }
                }
                .environmentObject(appState)
            }
            .fileImporter(isPresented: $showPdfPicker, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result {
                    Task { await vm.uploadPdf(fileURL: url) }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) { Button("OK") { vm.error = nil } } message: { Text(vm.error ?? "") }
        }
    }
}

private struct IntakeRow: View {
    let item: IntakeItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: channelIcon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.subject ?? item.parsedData?.vin ?? "(no subject)")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.channel.uppercased())
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    Text(item.status.replacingOccurrences(of: "_", with: " "))
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                    if let c = item.confidence {
                        Text("\(Int(c * 100))%")
                            .font(.caption2)
                            .foregroundStyle(c >= 0.85 ? Color.green : Color.orange)
                    }
                    Text(item.sourceAddress ?? "—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var channelIcon: String {
        switch item.channel {
        case "gmail", "outlook": return "envelope.fill"
        case "telegram": return "message.fill"
        case "web_link": return "link"
        case "manual_pdf": return "doc.richtext"
        default: return "tray.fill"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case "auto_created", "converted": return .green
        case "needs_review": return .orange
        case "error": return .red
        default: return .secondary
        }
    }
}
