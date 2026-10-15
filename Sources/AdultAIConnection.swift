import Foundation
import Observation
import Security

enum AdultAIConnectionError: LocalizedError {
    case invalidKey, storage, noKey, credentialLocked, unavailable, invalidResponse, refused, quota, network, invalidInput
    var errorDescription: String? {
        switch self {
        case .invalidKey: "Enter a valid OpenAI API key."
        case .storage: "The connection could not be saved securely. Try again."
        case .noKey: "Connect OpenAI in Assistant settings first."
        case .credentialLocked: "Unlock your device, then run this task again. Your API key stays protected while the device is locked."
        case .unavailable: "Apple Intelligence is unavailable. Enable it in system Settings or connect OpenAI."
        case .invalidResponse: "The assistant could not finish a complete plan. No actions were applied. Try a smaller task."
        case .refused: "The provider could not help with this request. Try a different task."
        case .quota: "This OpenAI account has reached its usage limit. Check billing or try again later."
        case .network: "The assistant could not connect. Your saved plans are available. Try again."
        case .invalidInput: "Describe one task in up to 2,000 characters."
        }
    }
}

protocol AdultAIKeyStorage {
    func containsKey() -> Bool
    func read() throws -> String
    func save(_ value: String) throws
    func remove() throws
}

struct AdultAPIKeyStore: AdultAIKeyStorage {
    private let service = "com.nathanfennel.How-To-Adult.AI"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "openai-api-key", kSecAttrSynchronizable as String: false]
    }
    func containsKey() -> Bool {
        var search = query
        search[kSecReturnAttributes as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(search as CFDictionary, nil) == errSecSuccess
    }
    func read() throws -> String {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &result)
        if status == errSecInteractionNotAllowed || status == errSecNotAvailable || status == errSecAuthFailed { throw AdultAIConnectionError.credentialLocked }
        if status == errSecItemNotFound { throw AdultAIConnectionError.noKey }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty
        else { throw AdultAIConnectionError.storage }
        return key
    }
    func save(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("sk-"), key.count >= 20, key.count <= 512,
              key.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }) else { throw AdultAIConnectionError.invalidKey }
        let data = Data(key.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw AdultAIConnectionError.storage }
        } else if status != errSecSuccess { throw AdultAIConnectionError.storage }
    }
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AdultAIConnectionError.storage }
    }
}

@MainActor @Observable
final class AdultAIConnection {
    private(set) var hasOpenAIKey: Bool
    var provider: AdultAIProvider { didSet { preferences.set(provider.rawValue, forKey: "adult.ai.provider") } }
    var model: String { didSet { preferences.set(model, forKey: "adult.ai.model") } }
    var useWebResearch: Bool { didSet { preferences.set(useWebResearch, forKey: "adult.ai.research") } }
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let keys: any AdultAIKeyStorage
    @ObservationIgnored private let isPrivateQA: Bool

    init(preferences: UserDefaults = .standard, isPrivateQA: Bool = false, keys: any AdultAIKeyStorage = AdultAPIKeyStore()) {
        self.preferences = preferences
        self.isPrivateQA = isPrivateQA
        self.keys = keys
        hasOpenAIKey = false
        provider = AdultAIProvider(rawValue: preferences.string(forKey: "adult.ai.provider") ?? "") ?? .onDevice
        model = preferences.string(forKey: "adult.ai.model") ?? "gpt-6-luna"
        useWebResearch = preferences.bool(forKey: "adult.ai.research")
        if !isPrivateQA { hasOpenAIKey = keys.containsKey() }
    }
    var canGenerate: Bool {
        isPrivateQA || (provider == .openAI ? hasOpenAIKey : AdultAIService.onDeviceAvailable)
    }
    func refreshAvailability() { if !isPrivateQA { hasOpenAIKey = keys.containsKey() } }
    func saveKey(_ key: String) throws {
        guard !isPrivateQA else { throw AdultAIConnectionError.storage }
        try keys.save(key)
        hasOpenAIKey = true
        provider = .openAI
    }
    func disconnect() throws {
        guard !isPrivateQA else { return }
        try keys.remove()
        hasOpenAIKey = false
        provider = .onDevice
        useWebResearch = false
    }
    func apiKey() throws -> String {
        guard !isPrivateQA else { throw AdultAIConnectionError.noKey }
        let key = try keys.read()
        hasOpenAIKey = true
        return key
    }
}
