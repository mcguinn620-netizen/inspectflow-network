import Foundation

/// Payload shared between the main app and the Share Extension via the
/// `group.com.inspectflow.shared` App Group. Both targets compile their own
/// copy because the extension cannot import the app module.
public struct SharedImport: Identifiable, Codable, Hashable {
    public enum Kind: String, Codable {
        case webLink = "web_link"
        case pdf = "pdf"
    }

    public let id: UUID
    public let kind: Kind
    public let title: String
    public let url: String?
    public let localFile: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        url: String? = nil,
        localFile: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.url = url
        self.localFile = localFile
        self.createdAt = createdAt
    }
}
