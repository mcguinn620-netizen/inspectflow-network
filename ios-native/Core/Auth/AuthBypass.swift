import Foundation

/// Toggle the auth bypass without recompiling by setting `AUTH_BYPASS` in
/// Info.plist to `NO`. Default: ON in every configuration so the app opens
/// straight into the test-user picker with no Supabase login. Flip to `NO`
/// (or remove `AuthBypass.swift` gating) to restore real Supabase auth.
enum AuthBypass {
    static let isEnabled: Bool = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "AUTH_BYPASS") {
            if let b = raw as? Bool { return b }
            if let s = raw as? String {
                let v = s.lowercased()
                if ["no", "false", "0", "off"].contains(v) { return false }
                if ["yes", "true", "1", "on"].contains(v) { return true }
            }
            if let n = raw as? NSNumber { return n.boolValue }
        }
        return true
    }()
}
