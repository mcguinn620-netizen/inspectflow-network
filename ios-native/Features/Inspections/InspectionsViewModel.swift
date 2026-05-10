import Foundation

@MainActor
final class InspectionsViewModel: ObservableObject {
    @Published var requests: [InspectionRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var realtime: RealtimeSubscription?

    func load(orgId: UUID?) async {
        guard let orgId else { return }

        if let cached: [InspectionRequest] = CoreDataCache.shared.load([InspectionRequest].self, for: CacheKeys.inspectionRequests(orgId)) {
            requests = cached
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await SupabaseService.shared.fetchInspectionRequests(orgId: orgId)
            requests = fresh
            CoreDataCache.shared.save(fresh, for: CacheKeys.inspectionRequests(orgId))
            errorMessage = nil
            await ensureRealtime(orgId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureRealtime(orgId: UUID) async {
        guard realtime == nil else { return }
        realtime = await RealtimeSubscriptions.inspectionRequests(orgId: orgId) { [weak self] _ in
            Task { @MainActor in await self?.load(orgId: orgId) }
        }
    }
}

@MainActor
final class InspectionDetailViewModel: ObservableObject {
    @Published var sections: [TemplateSection] = []
    @Published var entries: [ChecklistItemEntry] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var didSubmit = false

    let request: InspectionRequest
    let orgId: UUID

    init(request: InspectionRequest, orgId: UUID) {
        self.request = request
        self.orgId = orgId
    }

    var sectionsById: [UUID: TemplateSection] {
        Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0) })
    }

    func entries(for section: TemplateSection) -> [ChecklistItemEntry] {
        entries.filter { $0.item.sectionId == section.id }
    }

    func load(templateId: UUID?) async {
        guard let templateId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            sections = try await SupabaseService.shared.fetchTemplateSections(templateId: templateId)
            let items = try await SupabaseService.shared.fetchTemplateItems(sectionIds: sections.map { $0.id })
            entries = items.map { ChecklistItemEntry(item: $0) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(entryId: UUID, transform: (inout ChecklistItemEntry) -> Void) {
        guard let idx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        var e = entries[idx]
        transform(&e)
        entries[idx] = e
    }

    func attachPhoto(entryId: UUID, data: Data) async {
        do {
            let path = try await SupabaseService.shared.uploadInspectionPhoto(
                orgId: orgId, requestId: request.id, data: data
            )
            update(entryId: entryId) { $0.photoPaths.append(path) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let score = InspectionScoring.compute(entries: entries, sectionsById: sectionsById)
        do {
            try await SupabaseService.shared.submitInspectionScore(requestId: request.id, score: score)
            AuditLogger.log(
                action: "update",
                entityType: "inspection_request",
                entityId: request.id,
                changes: [
                    "status": "awaiting_review",
                    "overall_score": score.overallScore,
                ]
            )
            didSubmit = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
