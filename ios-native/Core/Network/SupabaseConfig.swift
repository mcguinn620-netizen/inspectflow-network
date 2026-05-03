import Foundation

struct SupabaseConfig {
    let url: URL
    let anonKey: String

    static let current = SupabaseConfig.loadFromBundle()

    private static func loadFromBundle(bundle: Bundle = .main) -> SupabaseConfig {
        let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        let anonKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""

        guard
            let url = URL(string: urlString),
            !anonKey.isEmpty
        else {
#if DEBUG
            print("⚠️ Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY in ios-native/Config/Secrets.xcconfig.")
#endif
            return SupabaseConfig(url: URL(string: "https://example.supabase.co/rest/v1/")!, anonKey: "DEV_PLACEHOLDER_KEY")
        }

        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}
