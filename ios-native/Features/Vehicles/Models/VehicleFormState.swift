import Foundation

struct VehicleFormState: Equatable {
    var id: UUID?
    var vin: String
    var nickname: String
    var make: String
    var model: String
    var year: Int?
    var trim: String
    var engine: String
    var recallFlag: Bool
    var isArchived: Bool

    var userOverrodeMake: Bool
    var userOverrodeModel: Bool
    var userOverrodeYear: Bool
    var userOverrodeTrim: Bool
    var userOverrodeEngine: Bool

    static let empty = VehicleFormState(
        id: nil,
        vin: "",
        nickname: "",
        make: "",
        model: "",
        year: nil,
        trim: "",
        engine: "",
        recallFlag: false,
        isArchived: false,
        userOverrodeMake: false,
        userOverrodeModel: false,
        userOverrodeYear: false,
        userOverrodeTrim: false,
        userOverrodeEngine: false
    )

    var normalizedVIN: String {
        vin.uppercased().replacingOccurrences(of: " ", with: "")
    }

    var isVINLikelyValid: Bool {
        normalizedVIN.count == 17
    }

    mutating func applyVINIntel(_ intel: VINIntelResult) {
        if !userOverrodeMake { make = intel.make ?? make }
        if !userOverrodeModel { model = intel.model ?? model }
        if !userOverrodeYear { year = intel.year ?? year }
        if !userOverrodeTrim { trim = intel.trim ?? trim }
        if !userOverrodeEngine { engine = intel.engine ?? engine }
        recallFlag = intel.hasOpenRecall ?? recallFlag
    }
}
