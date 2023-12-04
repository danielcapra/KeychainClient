// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public class KeychainClient {
    /**
     Read an item previously stored to the Keychain.

     - Author: Daniel Capra

     - returns: Decodable generic of type T

     - throws: An error of type `KeychainError`

     - parameters:
        - ofClass: The class of type `KeychainItemClass` with which the item was initially stored
        - atKey: The key of type `String` with which the item was initially stored
        - withAttributes: Any additional attributes to be included in the `CFDictionary`

     The following example shows how to retrieve a previously stored item of type `String` with the `KeychainItemClass.generic` class at "example" key with no additional attributes.

     ```
     let item: String = try KeychainClient().readItem(
         ofClass: .generic,
         atKey: "example",
         withAttributes: nil
     )
     ```
     */
    public func readItem<T: Decodable>(
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: [CFString: Any] = [:]
    ) throws -> T {
        try keychain.readItem(ofClass: itemClass, atKey: key, withAttributes: attributes)
    }

    /**
     Update an item from the keychain, or create it, if it doesn't already exist.

     - Author: Daniel Capra

     - throws: An error of type `KeychainError`

     - parameters:
        - item: Codable generic of type `T`
        - ofClass: The class of type `KeychainItemClass` with which the item was / will be stored
        - atKey: The key of type `String` with which the item was / will be stored
        - withAttributes: Any additional attributes to be included in the `CFDictionary`

     The following example shows how to upsert an item of type `Int` with the `KeychainItemClass.cryptoKey` class at "example" key with 1 additional attribute.

     ```
     try KeychainClient().upsertItem(
         item,
         ofClass: .cryptoKey,
         atKey: "example",
         withAttributes: [kSecAttrService: "com.example.service"]
     )
     ```
     */
    public func upsertItem<T: Codable>(
        _ item: T,
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: [CFString: Any] = [:]
    ) throws {
        do {
            let _: T = try keychain.readItem(ofClass: itemClass, atKey: key, withAttributes: attributes)
            // Item already exists
            // Update it
            try keychain.updateItem(item, ofClass: itemClass, atKey: key, withAttributes: attributes)
        } catch KeychainError.itemNotFound {
            // Item doesn't exist
            // Create it
            try keychain.saveItem(item, ofClass: itemClass, atKey: key, withAttributes: attributes)
        }
    }

    /**
     Delete an item from the keychain.

     - Author: Daniel Capra

     - throws: An error of type `KeychainError`

     - parameters:
        - ofClass: The class of type `KeychainItemClass` with which the item was stored
        - atKey: The key of type `String` with which the item was stored
        - withAttributes: Any additional attributes to be included in the `CFDictionary`

     The following example shows how to delete an item of type `Int` with the `KeychainItemClass.cryptoKey` class at "example" key with 1 additional attribute.

     ```
     try KeychainClient().deleteItem(
         ofClass: .cryptoKey,
         atKey: "example",
         withAttributes: [kSecAttrService: "com.example.service"]
     )
     ```
     */
    public func deleteItem(
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: [CFString: Any] = [:]
    ) throws {
        do {
            try keychain.deleteItem(ofClass: itemClass, atKey: key, withAttributes: attributes)
        } catch KeychainError.itemNotFound { return }
    }

    /**
     Delete all items from the keychain.

     - Author: Daniel Capra

     - throws: An error of type `KeychainError`
     */
    public func deleteAllItems() throws {
        try keychain.deleteAllItems()
    }

    // Stored properties
    private let keychain: KeychainProtocol

    // Mockable init
    public init(keychain: KeychainProtocol = Keychain()) {
        self.keychain = keychain
    }
}

public enum KeychainItemClass: RawRepresentable, CaseIterable {
    public typealias RawValue = CFString

    case generic
    case certificate
    case cryptoKey
    case identity

    public init?(rawValue: CFString) {
        switch rawValue {
        case kSecClassGenericPassword:
            self = .generic
        case kSecClassCertificate:
            self = .certificate
        case kSecClassKey:
            self = .cryptoKey
        case kSecClassIdentity:
            self = .identity
        default:
            return nil
        }
    }

    public var rawValue: CFString {
        switch self {
        case .generic:
            return kSecClassGenericPassword
        case .certificate:
            return kSecClassCertificate
        case .cryptoKey:
            return kSecClassKey
        case .identity:
            return kSecClassIdentity
        }
    }
}

public enum KeychainError: LocalizedError {
    case invalidData
    case itemNotFound
    case duplicateItem
    case incorrectAttributeForClass
    case unexpected(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data"
        case .itemNotFound:
            return "Item not found"
        case .duplicateItem:
            return "Duplicate Item"
        case .incorrectAttributeForClass:
            return "Incorrect Attribute for Class"
        case .unexpected(let oSStatus):
            return "Unexpected error - \(oSStatus)"
        }
    }

    init(_ error: OSStatus) {
        switch error {
        case errSecItemNotFound:
            self = .itemNotFound
        case errSecDataTooLarge:
            self = .invalidData
        case errSecDuplicateItem:
            self = .duplicateItem
        default:
            self = .unexpected(error)
        }
    }
}


public protocol KeychainProtocol {
    typealias KeychainItemAttributes = [CFString: Any]

    func readItem<T: Decodable>(
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes?
    ) throws -> T

    func saveItem<T: Encodable>(
        _ item: T,
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes?
    ) throws

    func updateItem<T: Encodable>(
        _ item: T,
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes?
    ) throws

    func deleteItem(
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes?
    ) throws

    func deleteAllItems() throws
}

public final class Keychain: KeychainProtocol {
    public init() {}
}

extension Keychain {
    /// Read a Decodable value from the keychain.
    ///
    /// - Parameters:
    ///   - ofClass: The kSecClass under which the item was initially saved
    ///   - key: The kSecAttrAccount under which the item was initially saved
    ///   - attributes: Any additional attributes
    /// - Throws: A KeychainError if something fails
    public func readItem<T: Decodable>(
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes? = nil
    ) throws -> T {
        var query: KeychainItemAttributes = [
            kSecClass: itemClass.rawValue,
            kSecAttrAccount: key,
            kSecReturnAttributes: true,
            kSecReturnData: true
        ]

        if let itemAttributes = attributes {
            for (key, value) in itemAttributes {
                query[key] = value
            }
        }

        var item: CFTypeRef?

        let result = SecItemCopyMatching(query as CFDictionary, &item)

        if result != errSecSuccess {
            throw KeychainError(result)
        }

        guard 
            let item = item as? [CFString: Any],
            let data = item[kSecValueData] as? Data
        else {
            throw KeychainError.invalidData
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension Keychain {
    /// Save an Encodable value to the keychain.
    ///
    /// - Parameters:
    ///   - item: Encodable value to save to keychain
    ///   - ofClass: The kSecClass under which the item will be saved
    ///   - key: The kSecAttrAccount under which the item will be saved
    ///   - attributes: Any additional attributes
    /// - Throws: A KeychainError if something fails
    public func saveItem<T: Encodable>(
        _ item: T,
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes? = nil
    ) throws {
        let itemData = try JSONEncoder().encode(item)

        var query: [CFString: Any] = [
            kSecClass: itemClass.rawValue,
            kSecAttrAccount: key,
            kSecValueData: itemData
        ]

        if let attributes = attributes {
            for (key, value) in attributes {
                query[key] = value
            }
        }

        let result = SecItemAdd(query as CFDictionary, nil)

        if result != errSecSuccess {
            throw KeychainError.init(result)
        }
    }
}

extension Keychain {
    /// Update a previously stored value from the keychain.
    ///
    /// - Parameters:
    ///   - item: Encodable value to save to keychain
    ///   - ofClass: The kSecClass we wish to update
    ///   - key: The kSecAttrAccount we wish to update
    ///   - attributes: Any additional attributes
    /// - Throws: A KeychainError if something fails
    public func updateItem<T: Encodable>(
        _ item: T,
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes? = nil
    ) throws {
        let itemData = try JSONEncoder().encode(item)

        var query: [CFString: Any] = [
            kSecClass: itemClass.rawValue,
            kSecAttrAccount: key
        ]

        if let attributes = attributes {
            for (key, value) in attributes {
                query[key] = value
            }
        }

        let attrsToUpdate: [CFString: Any] = [
            kSecValueData: itemData
        ]

        let result = SecItemUpdate(query as CFDictionary, attrsToUpdate as CFDictionary)

        if result != errSecSuccess {
            throw KeychainError(result)
        }
    }
}

extension Keychain {
    /// Delete a previously stored value from the keychain.
    ///
    /// - Parameters:
    ///   - ofClass: The kSecClass we wish to delete
    ///   - key: The kSecAttrAccount we wish to delete
    ///   - attributes: Any additional attributes
    /// - Throws: A KeychainError if something fails
    public func deleteItem(
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes? = nil
    ) throws {
        var query: [CFString: Any] = [
            kSecClass: itemClass.rawValue,
            kSecAttrAccount: key
        ]

        if let attributes = attributes {
            for (key, value) in attributes {
                query[key] = value
            }
        }

        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            throw KeychainError(result)
        }
    }
}


extension Keychain {
    /// Delete all the values accessible to the app from the keychain.
    ///
    /// - Throws: An error of type `KeychainError`
    public func deleteAllItems() throws {
        for itemClass in KeychainItemClass.allCases {
            let secItemClass = itemClass.rawValue
            let dict: KeychainItemAttributes = [kSecClass: secItemClass]
            let result = SecItemDelete(dict as CFDictionary)
            if result != errSecSuccess && result != errSecItemNotFound {
                throw KeychainError(result)
            }
        }
    }
}
