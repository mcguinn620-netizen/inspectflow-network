import Foundation

struct SupabaseConfig {
    let url: String
    let anonKey: String

    static let current = SupabaseConfig(
        url: "https://YOUR_PROJECT.supabase.co/rest/v1/",
        anonKey: "YOUR_SUPABASE_PUBLISHABLE_KEY"
    )
}
