import Foundation

/// Tax-deduction math for driver trips. Mirrors the per-mile portion of
/// `src/lib/taxCalculator.ts` so the iOS Mileage screen reports the same numbers
/// the web app does. Federal/state/SE calculations stay on the web for now —
/// this type owns only the standard-mileage deduction.
enum MileageDeduction {
    /// IRS standard mileage rates ($/mi) by tax year.
    /// Source: IRS Notice 2024-08, 2025-03. Update annually when the IRS posts new rates.
    private static let irsRatesByYear: [Int: Double] = [
        2023: 0.655,
        2024: 0.670,
        2025: 0.700,
        2026: 0.700, // placeholder; refresh when IRS publishes 2026 rate
    ]

    /// Fallback when a per-user `mileage_rate` is unset in `earnings_settings`.
    static var currentIRSRate: Double {
        let year = Calendar.current.component(.year, from: Date())
        return rate(forYear: year)
    }

    static func rate(forYear year: Int) -> Double {
        if let r = irsRatesByYear[year] { return r }
        // For years beyond the table, hold the most recent known rate.
        let latest = irsRatesByYear.keys.max() ?? 2025
        return irsRatesByYear[latest] ?? 0.67
    }

    /// Deduction in dollars for a single trip.
    static func amount(forMiles miles: Double, ratePerMile: Double) -> Double {
        max(0, miles) * max(0, ratePerMile)
    }

    /// Total deduction across the given trips at a single per-mile rate.
    static func total(forTrips trips: [Trip], ratePerMile: Double) -> Double {
        trips.reduce(0) { $0 + amount(forMiles: $1.totalMiles ?? 0, ratePerMile: ratePerMile) }
    }

    /// Sum of miles across the given trips.
    static func totalMiles(_ trips: [Trip]) -> Double {
        trips.reduce(0) { $0 + ($1.totalMiles ?? 0) }
    }
}
