import Foundation

// Template + sections + items (read-only snapshot used by the checklist UI)

struct InspectionTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let description: String?
    let inspectionType: String?
    let version: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description, version
        case inspectionType = "inspection_type"
    }
}

struct TemplateSection: Codable, Identifiable, Equatable {
    let id: UUID
    let templateId: UUID
    let name: String
    let description: String?
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case templateId = "template_id"
        case sortOrder = "sort_order"
    }
}

struct TemplateChecklistItem: Codable, Identifiable, Equatable {
    let id: UUID
    let sectionId: UUID
    let label: String
    let inputType: String?
    let weight: Double?
    let isRequired: Bool?
    let requiresPhoto: Bool?
    let requiresVideo: Bool?
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, label, weight
        case sectionId = "section_id"
        case inputType = "input_type"
        case isRequired = "is_required"
        case requiresPhoto = "requires_photo"
        case requiresVideo = "requires_video"
        case sortOrder = "sort_order"
    }
}

// Per-item runtime state in the checklist UI.
enum ChecklistItemResult: String, Codable {
    case unset, pass, warning, fail
}

struct ChecklistItemEntry: Identifiable, Equatable {
    let item: TemplateChecklistItem
    var result: ChecklistItemResult = .unset
    var notes: String = ""
    var photoPaths: [String] = []
    var id: UUID { item.id }
}

struct InspectionScoreResult: Codable, Equatable {
    let overallScore: Double
    let conditionRating: String
    let sectionScores: [String: Double]

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case conditionRating = "vehicle_condition_rating"
        case sectionScores = "section_scores"
    }
}

enum InspectionScoring {
    /// Weighted condition score 0-100, mirroring `mem://features/scoring-system`.
    /// pass = 100, warning = 70, fail = 0. `weight` defaults to 1.
    static func compute(entries: [ChecklistItemEntry], sectionsById: [UUID: TemplateSection]) -> InspectionScoreResult {
        var totalWeight: Double = 0
        var weightedSum: Double = 0
        var sectionAggregate: [UUID: (Double, Double)] = [:]

        for entry in entries where entry.result != .unset {
            let weight = entry.item.weight ?? 1
            let value: Double = {
                switch entry.result {
                case .pass: return 100
                case .warning: return 70
                case .fail: return 0
                case .unset: return 0
                }
            }()
            totalWeight += weight
            weightedSum += weight * value
            let agg = sectionAggregate[entry.item.sectionId] ?? (0, 0)
            sectionAggregate[entry.item.sectionId] = (agg.0 + weight * value, agg.1 + weight)
        }

        let overall = totalWeight > 0 ? weightedSum / totalWeight : 0
        let rating: String = {
            switch overall {
            case 90...: return "excellent"
            case 75..<90: return "good"
            case 60..<75: return "fair"
            default: return "poor"
            }
        }()

        var sectionScores: [String: Double] = [:]
        for (sectionId, agg) in sectionAggregate {
            let key = sectionsById[sectionId]?.name ?? sectionId.uuidString
            sectionScores[key] = agg.1 > 0 ? agg.0 / agg.1 : 0
        }

        return InspectionScoreResult(
            overallScore: (overall * 10).rounded() / 10,
            conditionRating: rating,
            sectionScores: sectionScores
        )
    }
}
