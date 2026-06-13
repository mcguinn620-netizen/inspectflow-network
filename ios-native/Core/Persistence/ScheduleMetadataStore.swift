import Foundation
import CoreData

// MARK: - Shared DTO

struct ScheduleChecklistItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var done: Bool = false
}

/// App-specific metadata mirrored next to a system calendar event.
///
/// Keyed by the EKEvent's `eventIdentifier`; `jobID` ties back to the
/// Supabase `Job` when one exists.
struct EventMetadata: Identifiable, Equatable {
    var id: String { eventID }
    var eventID: String
    var jobID: UUID?
    var category: String?
    var tags: [String]
    var checklist: [ScheduleChecklistItem]
    var richNotes: String
    var updatedAt: Date

    init(
        eventID: String,
        jobID: UUID? = nil,
        category: String? = nil,
        tags: [String] = [],
        checklist: [ScheduleChecklistItem] = [],
        richNotes: String = "",
        updatedAt: Date = Date()
    ) {
        self.eventID = eventID
        self.jobID = jobID
        self.category = category
        self.tags = tags
        self.checklist = checklist
        self.richNotes = richNotes
        self.updatedAt = updatedAt
    }
}

// MARK: - Protocol facade

protocol ScheduleMetadataStore: AnyObject {
    func metadata(for eventID: String) async throws -> EventMetadata?
    func allMetadata() async throws -> [EventMetadata]
    func upsert(_ metadata: EventMetadata) async throws
    func delete(eventID: String) async throws
}

enum ScheduleMetadataStoreFactory {
    /// Returns the best available backing store for the current OS.
    /// On iOS 17+ we use SwiftData; on iOS 16 we fall back to Core Data.
    static func make() -> ScheduleMetadataStore {
        if #available(iOS 17.0, *) {
            return SwiftDataMetadataStore.shared
        } else {
            return CoreDataMetadataStore.shared
        }
    }
}

// MARK: - Core Data fallback (iOS 16+)
//
// A programmatic NSManagedObjectModel avoids bundling an extra .xcdatamodeld
// resource. The schema mirrors `EventMetadata`.

final class CoreDataMetadataStore: ScheduleMetadataStore {

    static let shared = CoreDataMetadataStore()

    private let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "ScheduleMetadata", managedObjectModel: model)
        if inMemory, let desc = container.persistentStoreDescriptions.first {
            desc.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { print("ScheduleMetadata store load failed:", error) }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: Schema

    private static func makeModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "EventMetadataCD"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = true) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            return a
        }

        entity.properties = [
            attr("eventID", .stringAttributeType, optional: false),
            attr("jobID", .UUIDAttributeType),
            attr("category", .stringAttributeType),
            attr("tagsJSON", .stringAttributeType),
            attr("checklistJSON", .stringAttributeType),
            attr("richNotes", .stringAttributeType),
            attr("updatedAt", .dateAttributeType, optional: false),
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }

    // MARK: Read

    func metadata(for eventID: String) async throws -> EventMetadata? {
        try await context { ctx in
            let req = NSFetchRequest<NSManagedObject>(entityName: "EventMetadataCD")
            req.predicate = NSPredicate(format: "eventID == %@", eventID)
            req.fetchLimit = 1
            return try ctx.fetch(req).first.map { Self.toDTO($0) }
        }
    }

    func allMetadata() async throws -> [EventMetadata] {
        try await context { ctx in
            let req = NSFetchRequest<NSManagedObject>(entityName: "EventMetadataCD")
            return try ctx.fetch(req).map { Self.toDTO($0) }
        }
    }

    // MARK: Write

    func upsert(_ metadata: EventMetadata) async throws {
        try await context { ctx in
            let req = NSFetchRequest<NSManagedObject>(entityName: "EventMetadataCD")
            req.predicate = NSPredicate(format: "eventID == %@", metadata.eventID)
            req.fetchLimit = 1
            let obj = try ctx.fetch(req).first ?? NSEntityDescription.insertNewObject(
                forEntityName: "EventMetadataCD", into: ctx
            )
            Self.apply(metadata, to: obj)
            try ctx.save()
        }
    }

    func delete(eventID: String) async throws {
        try await context { ctx in
            let req = NSFetchRequest<NSManagedObject>(entityName: "EventMetadataCD")
            req.predicate = NSPredicate(format: "eventID == %@", eventID)
            for obj in try ctx.fetch(req) {
                ctx.delete(obj)
            }
            try ctx.save()
        }
    }

    // MARK: Mapping

    private static func toDTO(_ obj: NSManagedObject) -> EventMetadata {
        let tags = (obj.value(forKey: "tagsJSON") as? String)
            .flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? []
        let checklist = (obj.value(forKey: "checklistJSON") as? String)
            .flatMap { try? JSONDecoder().decode([ScheduleChecklistItem].self, from: Data($0.utf8)) } ?? []
        return EventMetadata(
            eventID: obj.value(forKey: "eventID") as? String ?? "",
            jobID: obj.value(forKey: "jobID") as? UUID,
            category: obj.value(forKey: "category") as? String,
            tags: tags,
            checklist: checklist,
            richNotes: (obj.value(forKey: "richNotes") as? String) ?? "",
            updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? Date()
        )
    }

    private static func apply(_ m: EventMetadata, to obj: NSManagedObject) {
        obj.setValue(m.eventID, forKey: "eventID")
        obj.setValue(m.jobID, forKey: "jobID")
        obj.setValue(m.category, forKey: "category")
        obj.setValue(
            (try? JSONEncoder().encode(m.tags)).flatMap { String(data: $0, encoding: .utf8) },
            forKey: "tagsJSON"
        )
        obj.setValue(
            (try? JSONEncoder().encode(m.checklist)).flatMap { String(data: $0, encoding: .utf8) },
            forKey: "checklistJSON"
        )
        obj.setValue(m.richNotes, forKey: "richNotes")
        obj.setValue(m.updatedAt, forKey: "updatedAt")
    }

    private func context<T>(_ work: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            container.performBackgroundTask { ctx in
                do { cont.resume(returning: try work(ctx)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}
