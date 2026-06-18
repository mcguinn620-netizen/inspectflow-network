import Foundation

#if canImport(SwiftData) && swift(>=5.9)
import SwiftData

// MARK: - SwiftData backing (iOS 17+ / macOS 14+)
//
// Mirrors `CoreDataMetadataStore`'s expanded schema exactly. Translation to
// the public `EventMetadata` DTO happens at the boundary so callers stay
// store-agnostic.

@available(iOS 17.0, macOS 14.0, *)
@Model
final class EventMetadataSD {
    @Attribute(.unique) var eventID: String
    var externalID: String?
    var jobID: UUID?
    var category: String?
    var tagsJSON: String
    var checklistJSON: String
    var richNotes: String
    var priority: String
    var status: String
    var estimatedDuration: Double
    var travelTime: Double
    var contactName: String?
    var contactPhone: String?
    var attachmentsJSON: String
    var customFieldsJSON: String
    var createdAt: Date
    var updatedAt: Date
    var lastSyncedAt: Date?
    var version: Int

    init(
        eventID: String,
        externalID: String? = nil,
        jobID: UUID? = nil,
        category: String? = nil,
        tagsJSON: String = "[]",
        checklistJSON: String = "[]",
        richNotes: String = "",
        priority: String = EventPriority.normal.rawValue,
        status: String = EventStatus.confirmed.rawValue,
        estimatedDuration: Double = 0,
        travelTime: Double = 0,
        contactName: String? = nil,
        contactPhone: String? = nil,
        attachmentsJSON: String = "[]",
        customFieldsJSON: String = "{}",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastSyncedAt: Date? = nil,
        version: Int = 1
    ) {
        self.eventID = eventID
        self.externalID = externalID
        self.jobID = jobID
        self.category = category
        self.tagsJSON = tagsJSON
        self.checklistJSON = checklistJSON
        self.richNotes = richNotes
        self.priority = priority
        self.status = status
        self.estimatedDuration = estimatedDuration
        self.travelTime = travelTime
        self.contactName = contactName
        self.contactPhone = contactPhone
        self.attachmentsJSON = attachmentsJSON
        self.customFieldsJSON = customFieldsJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
        self.version = version
    }
}

@available(iOS 17.0, macOS 14.0, *)
private let _swiftDataMetadataStoreShared = SwiftDataMetadataStore()

@available(iOS 17.0, macOS 14.0, *)
final class SwiftDataMetadataStore: ScheduleMetadataStore {

    static var shared: SwiftDataMetadataStore { _swiftDataMetadataStoreShared }


    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: EventMetadataSD.self)
        } catch {
            // In-memory fallback so the app never crashes due to schema issues.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
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

    func metadata(forExternalID externalID: String) async throws -> EventMetadata? {
        try await MainActor.run {
            var descriptor = FetchDescriptor<EventMetadataSD>(
                predicate: #Predicate { $0.externalID == externalID }
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
            let ext = metadata.externalID
            var descriptor = FetchDescriptor<EventMetadataSD>(
                predicate: #Predicate { row in
                    row.eventID == id || (ext != nil && row.externalID == ext)
                }
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
        let attachments = (try? JSONDecoder().decode([EventAttachment].self, from: Data(m.attachmentsJSON.utf8))) ?? []
        return EventMetadata(
            eventID: m.eventID,
            externalID: m.externalID,
            jobID: m.jobID,
            category: m.category,
            tags: tags,
            checklist: checklist,
            richNotes: m.richNotes,
            priority: EventPriority(rawValue: m.priority) ?? .normal,
            status: EventStatus(rawValue: m.status) ?? .confirmed,
            estimatedDuration: m.estimatedDuration,
            travelTime: m.travelTime,
            contactName: m.contactName,
            contactPhone: m.contactPhone,
            attachments: attachments,
            customFieldsJSON: m.customFieldsJSON,
            createdAt: m.createdAt,
            updatedAt: m.updatedAt,
            lastSyncedAt: m.lastSyncedAt,
            version: m.version
        )
    }

    private static func apply(_ dto: EventMetadata, to model: EventMetadataSD) {
        model.eventID = dto.eventID
        model.externalID = dto.externalID
        model.jobID = dto.jobID
        model.category = dto.category
        model.tagsJSON = encodeJSONString(dto.tags) ?? "[]"
        model.checklistJSON = encodeJSONString(dto.checklist) ?? "[]"
        model.richNotes = dto.richNotes
        model.priority = dto.priority.rawValue
        model.status = dto.status.rawValue
        model.estimatedDuration = dto.estimatedDuration
        model.travelTime = dto.travelTime
        model.contactName = dto.contactName
        model.contactPhone = dto.contactPhone
        model.attachmentsJSON = encodeJSONString(dto.attachments) ?? "[]"
        model.customFieldsJSON = dto.customFieldsJSON
        model.createdAt = dto.createdAt
        model.updatedAt = dto.updatedAt
        model.lastSyncedAt = dto.lastSyncedAt
        model.version = dto.version
    }
}

@available(iOS 17.0, macOS 14.0, *)
@inline(__always)
fileprivate func encodeJSONString<T: Encodable>(_ value: T) -> String? {
    (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
}
#endif // canImport(SwiftData)

