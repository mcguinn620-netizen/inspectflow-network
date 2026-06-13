import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

// MARK: - SwiftData backing (iOS 17+)
//
// Mirrors the same DTO surface as `CoreDataMetadataStore`. We use a thin
// `@Model` class and translate to/from `EventMetadata` at the boundary.

@available(iOS 17.0, macOS 14.0, *)
@Model
final class EventMetadataSD {
    @Attribute(.unique) var eventID: String
    var jobID: UUID?
    var category: String?
    var tagsJSON: String
    var checklistJSON: String
    var richNotes: String
    var updatedAt: Date

    init(
        eventID: String,
        jobID: UUID? = nil,
        category: String? = nil,
        tagsJSON: String = "[]",
        checklistJSON: String = "[]",
        richNotes: String = "",
        updatedAt: Date = Date()
    ) {
        self.eventID = eventID
        self.jobID = jobID
        self.category = category
        self.tagsJSON = tagsJSON
        self.checklistJSON = checklistJSON
        self.richNotes = richNotes
        self.updatedAt = updatedAt
    }
}

@available(iOS 17.0, macOS 14.0, *)
final class SwiftDataMetadataStore: ScheduleMetadataStore {

    static let shared = SwiftDataMetadataStore()

    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: EventMetadataSD.self)
        } catch {
            // In-memory fallback so the app never crashes due to schema issues.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // Force-try here only on the simpler in-memory path; if it still
            // fails the platform is broken and crashing is acceptable.
            container = try! ModelContainer(for: EventMetadataSD.self, configurations: config)
        }
    }

    @MainActor
    private var context: ModelContext { container.mainContext }

    // MARK: Read

    func metadata(for eventID: String) async throws -> EventMetadata? {
        try await MainActor.run {
            var descriptor = FetchDescriptor<EventMetadataSD>(
                predicate: #Predicate { $0.eventID == eventID }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first.map(Self.toDTO)
        }
    }

    func allMetadata() async throws -> [EventMetadata] {
        try await MainActor.run {
            try context.fetch(FetchDescriptor<EventMetadataSD>()).map(Self.toDTO)
        }
    }

    // MARK: Write

    func upsert(_ metadata: EventMetadata) async throws {
        try await MainActor.run {
            let id = metadata.eventID
            var descriptor = FetchDescriptor<EventMetadataSD>(
                predicate: #Predicate { $0.eventID == id }
            )
            descriptor.fetchLimit = 1
            let model = try context.fetch(descriptor).first ?? {
                let m = EventMetadataSD(eventID: metadata.eventID)
                context.insert(m)
                return m
            }()
            Self.apply(metadata, to: model)
            try context.save()
        }
    }

    func delete(eventID: String) async throws {
        try await MainActor.run {
            let descriptor = FetchDescriptor<EventMetadataSD>(
                predicate: #Predicate { $0.eventID == eventID }
            )
            for model in try context.fetch(descriptor) {
                context.delete(model)
            }
            try context.save()
        }
    }

    // MARK: Mapping

    private static func toDTO(_ m: EventMetadataSD) -> EventMetadata {
        let tags = (try? JSONDecoder().decode([String].self, from: Data(m.tagsJSON.utf8))) ?? []
        let checklist = (try? JSONDecoder().decode([ScheduleChecklistItem].self, from: Data(m.checklistJSON.utf8))) ?? []
        return EventMetadata(
            eventID: m.eventID,
            jobID: m.jobID,
            category: m.category,
            tags: tags,
            checklist: checklist,
            richNotes: m.richNotes,
            updatedAt: m.updatedAt
        )
    }

    private static func apply(_ dto: EventMetadata, to model: EventMetadataSD) {
        model.jobID = dto.jobID
        model.category = dto.category
        model.tagsJSON = (try? JSONEncoder().encode(dto.tags))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        model.checklistJSON = (try? JSONEncoder().encode(dto.checklist))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        model.richNotes = dto.richNotes
        model.updatedAt = dto.updatedAt
    }
}
