import SwiftUI

struct InspectionDetailView: View {
    @StateObject private var viewModel: InspectionDetailViewModel
    @State private var photoEntryId: UUID?
    @State private var showCamera = false
    @Environment(\.dismiss) private var dismiss

    init(request: InspectionRequest, orgId: UUID) {
        _viewModel = StateObject(wrappedValue: InspectionDetailViewModel(request: request, orgId: orgId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView("Loading checklist")
            } else if viewModel.entries.isEmpty {
                ContentUnavailableCompat(
                    title: "No checklist",
                    message: viewModel.errorMessage ?? "This request has no template assigned."
                )
            } else {
                List {
                    ForEach(viewModel.sections.sorted(by: { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) })) { section in
                        Section(header: Text(section.name)) {
                            ForEach(viewModel.entries(for: section)) { entry in
                                ChecklistRow(
                                    entry: entry,
                                    onResult: { result in
                                        viewModel.update(entryId: entry.id) { $0.result = result }
                                    },
                                    onNotes: { notes in
                                        viewModel.update(entryId: entry.id) { $0.notes = notes }
                                    },
                                    onAddPhoto: {
                                        photoEntryId = entry.id
                                        showCamera = true
                                    }
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.submit()
                        if viewModel.didSubmit { dismiss() }
                    }
                } label: {
                    if viewModel.isSubmitting { ProgressView() } else { Text("Submit") }
                }
                .disabled(viewModel.isSubmitting || viewModel.entries.allSatisfy { $0.result == .unset })
            }
        }
        .sheet(isPresented: $showCamera) {
            PhotoCapture(
                source: .camera,
                onPicked: { data in
                    showCamera = false
                    if let id = photoEntryId {
                        Task { await viewModel.attachPhoto(entryId: id, data: data) }
                    }
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .task {
            await viewModel.load(templateId: viewModel.request.templateID)
        }
    }
}

private struct ChecklistRow: View {
    let entry: ChecklistItemEntry
    let onResult: (ChecklistItemResult) -> Void
    let onNotes: (String) -> Void
    let onAddPhoto: () -> Void

    @State private var notesDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.item.label).font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                pill("Pass", color: .green, isOn: entry.result == .pass) { onResult(.pass) }
                pill("Warn", color: .orange, isOn: entry.result == .warning) { onResult(.warning) }
                pill("Fail", color: .red, isOn: entry.result == .fail) { onResult(.fail) }
                Spacer()
                Button(action: onAddPhoto) {
                    Image(systemName: "camera.fill")
                }
                .buttonStyle(.bordered)
            }
            if !entry.photoPaths.isEmpty {
                Text("\(entry.photoPaths.count) photo\(entry.photoPaths.count == 1 ? "" : "s") attached")
                    .font(.caption2).foregroundColor(.secondary)
            }
            TextField("Notes", text: $notesDraft, axis: .vertical)
                .font(.caption)
                .textFieldStyle(.roundedBorder)
                .onChange(of: notesDraft) { _, new in onNotes(new) }
                .onAppear { notesDraft = entry.notes }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func pill(_ title: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(isOn ? color.opacity(0.85) : color.opacity(0.15), in: Capsule())
                .foregroundColor(isOn ? .white : color)
        }
        .buttonStyle(.plain)
    }
}
