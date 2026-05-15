# Fix ISO8601 date decoding error in iOS app

## Problem

Simulator decoding fails on `created_at` with:
> "Expected date string to be ISO8601-formatted."

Postgres/Supabase returns timestamps with **fractional seconds** and a `+00:00` offset, e.g. `2026-05-15T01:40:55.123456+00:00`. Swift's default `.iso8601` `JSONDecoder` strategy uses `ISO8601DateFormatter` with no options, which **rejects fractional seconds**, so the first row's `created_at` fails to decode.

Affected decoders (both vendored into the app):
- `ios-native/Core/InspectFlowConnector/Database/QueryBuilder.swift` (`execute<T>`)
- `ios-native/Core/InspectFlowConnector/Functions/FunctionsClient.swift` (`invoke<T>`)

## Fix

Replace `decoder.dateDecodingStrategy = .iso8601` with a **custom strategy** that accepts both formats (with and without fractional seconds), plus a graceful fallback. Centralize in a shared helper so both decoders stay in sync.

### Plan

1. Add `ios-native/Core/InspectFlowConnector/JSONDecoder+Supabase.swift`:
   - Static `JSONDecoder.supabase` factory
   - `dateDecodingStrategy = .custom { ... }` that tries:
     - `ISO8601DateFormatter` with `[.withInternetDateTime, .withFractionalSeconds]`
     - `ISO8601DateFormatter` with `[.withInternetDateTime]`
     - throws `DecodingError.dataCorrupted` with the original context if neither matches
2. Update `QueryBuilder.execute<T>` to use `JSONDecoder.supabase()`.
3. Update `FunctionsClient.invoke<T>` to use `JSONDecoder.supabase()`.
4. Mirror the same change in `swift-connector/Sources/InspectFlowConnector/...` so the standalone package stays in parity (even though the app uses the vendored copy).

No schema, no API surface, no Bitrise changes. Pure decoder fix.

## Technical detail

```swift
extension JSONDecoder {
    static func supabase() -> JSONDecoder {
        let d = JSONDecoder()
        let withFrac = ISO8601DateFormatter(); withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter(); plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = withFrac.date(from: s) ?? plain.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "Unrecognized ISO8601 date: \(s)"))
        }
        return d
    }
}
```
