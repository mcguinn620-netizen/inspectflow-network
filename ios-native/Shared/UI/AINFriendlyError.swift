import Foundation

/// Maps connector / Supabase errors into messages safe to show in the UI.
/// Never returns raw JSON or HTTP bodies.
enum AINFriendlyError {
    static func message(for error: Error, fallback: String? = nil) -> String {
        if let ifError = error as? InspectFlowError {
            switch ifError {
            case .notAuthenticated:
                return "Your session expired. Please sign in again."
            case .http(let status, let body):
                let lower = body.lowercased()
                if status == 401 || lower.contains("jwt expired") || lower.contains("pgrst303") {
                    return "Your session expired. Please sign in again."
                }
                if status == 403 || lower.contains("permission denied") {
                    return "You don't have permission to view this."
                }
                if status == 404 { return "Nothing was found." }
                if (500...599).contains(status) { return "The server is having a problem. Try again in a moment." }
                if status == 0 { return "Couldn't reach the network." }
                return fallback ?? "Something went wrong."
            case .decoding:
                return "Received unexpected data from the server."
            case .invalidResponse:
                return "The server returned an invalid response."
            }
        }
        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain { return "Couldn't reach the network." }
        return fallback ?? error.localizedDescription
    }

    /// True if the error indicates the session is gone and the app should sign-out.
    static func isAuthExpired(_ error: Error) -> Bool {
        if let ifError = error as? InspectFlowError {
            switch ifError {
            case .notAuthenticated: return true
            case .http(let status, let body):
                let lower = body.lowercased()
                return status == 401 && (lower.contains("jwt expired") || lower.contains("pgrst303"))
            default: return false
            }
        }
        return false
    }
}
