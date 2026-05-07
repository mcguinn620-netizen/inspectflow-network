import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Security)
import Security
#endif

public final class SessionStore {
    private let config: InspectFlowConfig
    private let lock = NSLock()
    private var cached: InspectFlowSession?

    init(config: InspectFlowConfig) {
        self.config = config
        self.cached = try? read()
    }

    public func current() -> InspectFlowSession? {
        lock.lock(); defer { lock.unlock() }
        return cached
    }

    public func set(_ session: InspectFlowSession?) throws {
        lock.lock(); defer { lock.unlock() }
        cached = session
        if let session {
            let data = try JSONEncoder().encode(session)
            try writeKeychain(data)
        } else {
            deleteKeychain()
        }
    }

    private func read() throws -> InspectFlowSession? {
        guard let data = readKeychain() else { return nil }
        return try JSONDecoder().decode(InspectFlowSession.self, from: data)
    }

    // MARK: - Keychain

    #if canImport(Security)
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: config.keychainService,
            kSecAttrAccount as String: config.keychainAccount
        ]
    }

    private func writeKeychain(_ data: Data) throws {
        var q = baseQuery()
        SecItemDelete(q as CFDictionary)
        q[kSecValueData as String] = data
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func readKeychain() -> Data? {
        var q = baseQuery()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private func deleteKeychain() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
    #else
    private func writeKeychain(_ data: Data) throws {}
    private func readKeychain() -> Data? { nil }
    private func deleteKeychain() {}
    #endif
}
