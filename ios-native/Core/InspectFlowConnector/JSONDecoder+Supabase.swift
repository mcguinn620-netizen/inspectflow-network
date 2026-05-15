import Foundation

extension JSONDecoder {
    /// Decoder configured for Supabase/PostgREST responses, accepting ISO8601
    /// timestamps both with and without fractional seconds.
    static func supabase() -> JSONDecoder {
        let decoder = JSONDecoder()
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = withFractional.date(from: raw) ?? plain.date(from: raw) {
                return date
            }
            // Tolerate date-only values (e.g. "2026-05-15") used by some columns.
            let dateOnly = DateFormatter()
            dateOnly.calendar = Calendar(identifier: .iso8601)
            dateOnly.locale = Locale(identifier: "en_US_POSIX")
            dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
            dateOnly.dateFormat = "yyyy-MM-dd"
            if let d = dateOnly.date(from: raw) { return d }

            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unrecognized ISO8601 date: \(raw)")
            )
        }
        return decoder
    }
}
