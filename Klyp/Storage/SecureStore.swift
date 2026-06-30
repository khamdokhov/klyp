import Foundation
import Security

enum SecureStoreError: Error {
    case writeFailed(OSStatus)
    case readFailed(OSStatus)
    case missingItem(UUID)
    case decodeFailed
}

struct SecureStore {
    private let service: String

    init(service: String = "com.klyp.app.secure") {
        self.service = service
    }

    func save(_ representations: [String: Data], for id: UUID) throws {
        let payload = StoredRepresentations(entries: representations)
        let data = try JSONEncoder().encode(payload)
        delete(for: id)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureStoreError.writeFailed(status)
        }
    }

    func load(for id: UUID) throws -> [String: Data] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw SecureStoreError.missingItem(id)
            }
            throw SecureStoreError.readFailed(status)
        }

        guard let data = result as? Data else {
            throw SecureStoreError.decodeFailed
        }

        return try JSONDecoder().decode(StoredRepresentations.self, from: data).entries
    }

    func delete(for id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
