import Foundation
import CoreData

// MARK: - Shared DTOs

public struct ScheduleChecklistItem: Codable, Hashable, Identifiable {
    public var id: UUID = UUID()
    public var title: String
    public var done: Bool = false

    public init(id: UUID = UUID(), title: String, done: Bool = false) {
        self.id = id
        self.title = title
        self.done = done
    }
}

public enum EventPriority: String, Codable, CaseIterable, Sendable {
    case none, low, normal, high, urgent
}

public enum EventStatus: String, Codable, CaseIterable, Sendable {
    case tentative, confirmed, inProgress, completed, cancelled
}

public struct EventAttachment: Codable, Hashable, Identifiable {
    public var id: UUID = UUID()
    public var filename: String
    public var urlString: String
    public var byteSize: Int64

    public init(id: UUID = UUID(), filename: String, urlString: String, byteSize: Int64 = 0) {
        self.id = id
        self.filename = filename
        self.urlString = urlString
        self.byteSize = byteSize
    }
}

/// App-specific metadata mirrored next to a system calendar event.
///
/// The record is keyed primarily by `externalID`
/// (`EKEvent.calendarItemExternalIdentifier`) and secondarily by
/// `eventIdentifier`, which lets us survive sync churn that rewrites the
/// per-store id without losing the link to the user's annotations.
public struct EventMetadata: Identifiable, Equatable {
    public var id: String { externalID ?? eventID }

    // Identity
    public var eventID: String
    public var externalID: String?

    // Linkage
    public var jobID: UUID?

    // Classification
    public var category: String?
    public var tags: [String]

    // Body
    public var checklist: [ScheduleChecklistItem]
    public var richNotes: String

    // Extended schema
    public var priority: EventPriority
    public var status: EventStatus
    public var estimatedDuration: TimeInterval
    public var travelTime: TimeInterval
    public var contactName: String?
    public var contactPhone: String?
    public var attachments: [EventAttachment]
    public var customFieldsJSON: String

    // Bookkeeping
    public var createdAt: Date
    public var updatedAt: Date
    public var lastSyncedAt: Date?
    public var version: Int

    public init(
        eventID: String,
        externalID: String? = nil,
        jobID: UUID? = nil,
        category: String? = nil,
        tags: [String] = [],
        checklist: [ScheduleChecklistItem] = [],
        richNotes: String = "",
        priority: EventPriority = .normal,
        status: EventStatus = .confirmed,
        estimatedDuration: TimeInterval = 0,
        travelTime: TimeInterval = 0,
        contactName: String? = nil,
        contactPhone: String? = nil,
        attachments: [EventAttachment] = [],
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
        self.tags = tags
        self.checklist = checklist
        self.richNotes = richNotes
        self.priority = priority
        self.status = status
        self.estimatedDuration = estimatedDuration
        self.travelTime = travelTime
        self.contactName = contactName
        self.contactPhone = contactPhone
        self.attachments = attachments
        self.customFieldsJSON = customFieldsJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
        self.version = version
    }

    public var identity: EventIdentity {
        EventIdentity(eventIdentifier: eventID, externalID: externalID)
    }
}

// MARK: - Protocol facade

public protocol ScheduleMetadataStore: AnyObject {
    func metadata(for eventID: String) async throws -> EventMetadata?
    func metadata(forExternalID externalID: String) async throws -> EventMetadata?
    func allMetadata() async throws -> [EventMetadata]
    func upsert(_ metadata: EventMetadata) async throws
    func delete(eventID: String) async throws
}

public enum ScheduleMetadataStoreFactory {
    /// Returns the best available backing store for the current OS.
    /// On iOS 17+ we use SwiftData; on iOS 16 we fall back to Core Data.
    public static func make() -> ScheduleMetadataStore {
        if #available(iOS 17.0, macOS 14.0, *) {
            return SwiftDataMetadataStore.shared
        } else {
            return CoreDataMetadataStore.shared
        }
    }
}

// MARK: - Core Data fallback (iOS 16+)
//
// A programmatic NSManagedObjectModel avoids bundling an extra .xcdatamodeld
// resource. New attributes are optional so lightweight migration succeeds
// against stores written by the previous schema.

public final class CoreDataMetadataStore: ScheduleMetadataStore {

    public static let shared = CoreDataMetadataStore()

    private let container: NSPersistentContainer

    public init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "ScheduleMetadata", managedObjectModel: model)
        if let desc = container.persistentStoreDescriptions.first {
            if inMemory {
                desc.url = URL(fileURLWithPath: "/dev/null")
            }
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
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

        func attr(
            _ name: String,
            _ type: NSAttributeType,
            optional: Bool = true,
            defaultValue: Any? = nil
        ) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            if let defaultValue { a.defaultValue = defaultValue }
            return a
        }

        entity.properties = [
            attr("eventID", .stringAttributeType, optional: false),
            attr("externalID", .stringAttributeType),
            attr("jobID", .UUIDAttributeType),
            attr("category", .stringAttributeType),
            attr("tagsJSON", .stringAttributeType, defaultValue: "[]"),
            attr("checklistJSON", .stringAttributeType, defaultValue: "[]"),
            attr("richNotes", .stringAttributeType, defaultValue: ""),
            attr("priority", .stringAttributeType, defaultValue: EventPriority.normal.rawValue),
            attr("status", .stringAttributeType, defaultValue: EventStatus.confirmed.rawValue),
            attr("estimatedDuration", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attr("travelTime", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attr("contactName", .stringAttributeType),
            attr("contactPhone", .stringAttributeType),
            attr("attachmentsJSON", .stringAttributeType, defaultValue: "[]"),
            attr("customFieldsJSON", .stringAttributeType, defaultValue: "{}"),
            attr("createdAt", .dateAttributeType, optional: false),
            attr("updatedAt", .dateAttributeType, optional: false),
            attr("lastSyncedAt", .dateAttributeType),
            attr("version", .integer64AttributeType, optional: false, defaultValue: 1),
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }

    // MARK: Read

    public func metadata(for eventID: String) async throws -> EventMetadata? {
        try await context { ctx in
            let req = NSFetchRequest<NSManagedObject>(entityName: "EventMetadataCD")
            req.predicate = NSPredicate(format: "eventID == %@", eventID)
            req.fetchLimit = 1
            return try ctx.fetch(req).first.map { Self.toDTO($0) }
        }
    }

    public func metadata(forExternalID externalID: String) async throws -> EventMetadata? {
        try await context { ctx in
            let req = NSFetchRequest<NSManagedObject>(entityName: "EventMetadataCD")
            req.predicate = NSPredicate(format: "externalID == %@", externalID)
            req.fetchLimit = 1
            return try ctx.fetch(req).first.map { Self.toDTO($0) }
        }
    }

    public func allMetadata() async throws -> [EventMetadata] {
        try await context { ctx in
            let req = NSFetchRequest<NSManagedObject>(entityName: "EventMetadataCD")
            return try ctx.fetch(req).map { Self.toDTO($0) }
        }
    }

    // MARK: Write

    public func upsert(_ metadata: EventMetadata) async throws {
        try await context { ctx in
            let req = NSFetchRequest<NSManagedObject>(entityName: "EventMetadataCD")
            if let externalID = metadata.externalID, !externalID.isEmpty {
                req.predicate = NSPredicate(
                    format: "externalID == %@ OR eventID == %@",
                    externalID, metadata.eventID
                )
            } else {
                req.predicate = NSPredicate(format: "eventID == %@", metadata.eventID)
            }
            req.fetchLimit = 1
            let obj = try ctx.fetch(req).first ?? NSEntityDescription.insertNewObject(
                forEntityName: "EventMetadataCD", into: ctx
            )
            Self.apply(metadata, to: obj)
            try ctx.save()
        }
    }

    public func delete(eventID: String) async throws {
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
        func string(_ key: String) -> String? { obj.value(forKey: key) as? String }
        let tags = string("tagsJSON")
            .flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? []
        let checklist = string("checklistJSON")
            .flatMap { try? JSONDecoder().decode([ScheduleChecklistItem].self, from: Data($0.utf8)) } ?? []
        let attachments = string("attachmentsJSON")
            .flatMap { try? JSONDecoder().decode([EventAttachment].self, from: Data($0.utf8)) } ?? []
        let priority = EventPriority(rawValue: string("priority") ?? "") ?? .normal
        let status = EventStatus(rawValue: string("status") ?? "") ?? .confirmed
        return EventMetadata(
            eventID: string("eventID") ?? "",
            externalID: string("externalID"),
            jobID: obj.value(forKey: "jobID") as? UUID,
            category: string("category"),
            tags: tags,
            checklist: checklist,
            richNotes: string("richNotes") ?? "",
            priority: priority,
            status: status,
            estimatedDuration: (obj.value(forKey: "estimatedDuration") as? Double) ?? 0,
            travelTime: (obj.value(forKey: "travelTime") as? Double) ?? 0,
            contactName: string("contactName"),
            contactPhone: string("contactPhone"),
            attachments: attachments,
            customFieldsJSON: string("customFieldsJSON") ?? "{}",
            createdAt: (obj.value(forKey: "createdAt") as? Date) ?? Date(),
            updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? Date(),
            lastSyncedAt: obj.value(forKey: "lastSyncedAt") as? Date,
            version: (obj.value(forKey: "version") as? Int) ?? 1
        )
    }

    private static func apply(_ m: EventMetadata, to obj: NSManagedObject) {
        obj.setValue(m.eventID, forKey: "eventID")
        obj.setValue(m.externalID, forKey: "externalID")
        obj.setValue(m.jobID, forKey: "jobID")
        obj.setValue(m.category, forKey: "category")
        obj.setValue(encodeJSON(m.tags) ?? "[]", forKey: "tagsJSON")
        obj.setValue(encodeJSON(m.checklist) ?? "[]", forKey: "checklistJSON")
        obj.setValue(m.richNotes, forKey: "richNotes")
        obj.setValue(m.priority.rawValue, forKey: "priority")
        obj.setValue(m.status.rawValue, forKey: "status")
        obj.setValue(m.estimatedDuration, forKey: "estimatedDuration")
        obj.setValue(m.travelTime, forKey: "travelTime")
        obj.setValue(m.contactName, forKey: "contactName")
        obj.setValue(m.contactPhone, forKey: "contactPhone")
        obj.setValue(encodeJSON(m.attachments) ?? "[]", forKey: "attachmentsJSON")
        obj.setValue(m.customFieldsJSON, forKey: "customFieldsJSON")
        obj.setValue(m.createdAt, forKey: "createdAt")
        obj.setValue(m.updatedAt, forKey: "updatedAt")
        obj.setValue(m.lastSyncedAt, forKey: "lastSyncedAt")
        obj.setValue(m.version, forKey: "version")
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

@inline(__always)
fileprivate func encodeJSON<T: Encodable>(_ value: T) -> String? {
    (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
}
