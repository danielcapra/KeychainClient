import XCTest
@testable import KeychainClient

// MARK: Mocks
class MockKeychain: KeychainProtocol {

    var retrievedItem: Any? = nil
    var query: [CFString: Any] = [:]
    var attrsToUpdate: [CFString: Any] = [:]

    func readItem<T>(
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes?
    ) throws -> T where T : Decodable {
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

        self.query = query
        return retrievedItem as! T
    }
    
    func saveItem<T>(
        _ item: T,
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes?
    ) throws where T : Encodable {
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

        self.query = query
    }
    
    func updateItem<T>(
        _ item: T,
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes?
    ) throws where T : Encodable {
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

        self.query = query

        let attrsToUpdate: [CFString: Any] = [
            kSecValueData: itemData
        ]

        self.attrsToUpdate = attrsToUpdate
    }
    
    func deleteItem(
        ofClass itemClass: KeychainItemClass,
        atKey key: String,
        withAttributes attributes: KeychainItemAttributes?
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

        self.query = query
    }
    
    func deleteAllItems() throws {
        return
    }
}

// MARK: Tests
final class KeychainClientTests: XCTestCase {
    var keychainClient: KeychainClient!
    var mockKeychain: MockKeychain!

    override func setUp() {
        self.mockKeychain = MockKeychain()
        self.keychainClient = KeychainClient(keychain: mockKeychain)
    }

    func test_upsert_query() {
        mockKeychain.retrievedItem = "elpmaxe"
        let item = "Example"

        guard let itemData = try? JSONEncoder().encode(item) else { XCTFail(); return }

        let expectedQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "com.example",
            kSecValueData: itemData
        ]

        do {
            try keychainClient.upsertItem(item, ofClass: .generic, atKey: "com.example")
        } catch {
            XCTFail()
        }

        for (key, value) in expectedQuery {
            if key == kSecValueData {
                let valueData = expectedQuery[key] as! Data
                guard
                    let valueString = try? JSONDecoder().decode(String.self, from: valueData)
                else { XCTFail(); return }
                XCTAssertEqual(item, valueString)
            } else {
                XCTAssertEqual(value as! String, expectedQuery[key] as! String)
            }
        }
    }

    func test_read_query() {
        mockKeychain.retrievedItem = "elpmaxe"

        let expectedQuery: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecAttrAccount: "com.example",
            kSecReturnAttributes: true,
            kSecReturnData: true
        ]

        do {
            let item: String = try keychainClient.readItem(ofClass: .identity, atKey: "com.example")

            XCTAssertEqual(mockKeychain.retrievedItem as? String, item)
        } catch {
            XCTFail()
        }

        for item in expectedQuery {
            if [kSecClass, kSecAttrAccount].contains(item.key) {
                XCTAssertEqual(item.value as! String, mockKeychain.query[item.key] as! String)
            } else {
                XCTAssertEqual(item.value as! Bool, mockKeychain.query[item.key] as! Bool)
            }
        }
    }

    func test_delete_query() {
        XCTAssertNoThrow(
            try keychainClient.deleteItem(
                ofClass: .cryptoKey,
                atKey: "example.key",
                withAttributes: [kSecAttrService: "com.example.service"]
            )
        )

        let expectedQuery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrAccount: "example.key",
            kSecAttrService: "com.example.service"
        ]

        for item in expectedQuery {
            XCTAssertEqual(item.value as! String, mockKeychain.query[item.key] as! String)
        }
    }

}
