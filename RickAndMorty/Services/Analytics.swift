//
//  Analytics.swift
//  RickAndMorty
//
//  Created by Juliano on 12/10/25.
//

import Foundation
import SwiftData
import CloudKit
import OSLog

// MARK: - AnyCodable
public struct AnyCodable: Codable {
    public let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self.value = () }
        else if let bool = try? container.decode(Bool.self) { self.value = bool }
        else if let int = try? container.decode(Int.self) { self.value = int }
        else if let double = try? container.decode(Double.self) { self.value = double }
        else if let string = try? container.decode(String.self) { self.value = string }
        else if let array = try? container.decode([AnyCodable].self) { self.value = array.map { $0.value } }
        else if let dict = try? container.decode([String: AnyCodable].self) { self.value = dict.mapValues { $0.value } }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is Void: try container.encodeNil()
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let array as [Any]: try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type: \(type(of: value))")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - Encodable -> [String: AnyCodable]

extension Encodable {
    func asDictionary() throws -> [String: AnyCodable] {
        let data = try JSONEncoder().encode(self)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AcademyAnalytics", code: 0, userInfo: [NSLocalizedDescriptionKey: "Formato inválido"])
        }
        return json.mapValues { AnyCodable($0) }
    }
}

// MARK: - Data -> String

public extension Data {
    func toString(encoding: String.Encoding = .utf8) -> String {
        String(data: self, encoding: encoding) ?? "{}"
    }
}

// MARK: - Analytics Models

@Model
final class AnalyticsRecord {
    var id: UUID = UUID()
    var eventName: String = ""
    var parametersJSON: String = "{}"
    var timestamp: Date = Date()

    init(eventName: String, parametersJSON: String) {
        self.id = UUID()
        self.eventName = eventName
        self.parametersJSON = parametersJSON
        self.timestamp = Date()
    }
}

//@Model
//final class PendingEvent {
//    var id: UUID = UUID()
//    var name: String = ""
//    var parametersJSON: String = "{}"
//    var createdAt: Date = Date()
//
//    init(name: String, parameters: [String: AnyCodable]) throws {
//        self.id = UUID()
//        self.name = name
//        self.createdAt = Date()
//        self.parametersJSON = try JSONEncoder().encode(parameters).toString()
//    }
//}

// MARK: - Events

enum AnalyticsEvent {
    case characterSelection(CharacterSelectedEvent)
//    case favoriteCharacterSelection
    case screenView(ScreenViewEvent)
    case actionPerformed(ActionEvent)
    case custom(name: String, parameters: [String: AnyCodable] = [:])

    var eventName: String {
        switch self {
        case .characterSelection: return "CharacterSelected"
//        case  .favoriteCharacterSelection: return "favoriteCharacterSelected"
        case .screenView: return "ScreenView"
        case .actionPerformed: return "ActionPerformed"
        case .custom(let name, _): return name
        }
    }

    func parameters() throws -> [String: AnyCodable] {
        switch self {
        case .characterSelection(let event): return try event.asDictionary()
//        case .favoriteCharacterSelection(let event): return try event.asDictionary()
        case .screenView(let event): return try event.asDictionary()
        case .actionPerformed(let event): return try event.asDictionary()
        case .custom(_, let params): return params
        }
    }
    
// MARK: - Event Payloads (Event Structs)
    
    struct CharacterSelectedEvent: Codable {
        let name: String
        let origin: String
        let date: String
    }
    
//    struct CharacterFavoriteSelectedEvent: Codable {
//        let name: String
//        let date: Double
//    }
    
    struct ScreenViewEvent: Codable {
        let screenName: String
        let duration: Double
        let userTier: String
    }

    struct ActionEvent: Codable {
        let actionName: String
        let context: String
        let success: Bool
    }

}

// MARK: - Enum de telas

enum Screens: String {
    case home = "Rick and Morty List (all characters)"
    case character = "Character Details"
}

// MARK: - AnalyticsError

enum AnalyticsError: Error {
    case encoding(String),
         invalidDictionary(String)
}

// MARK: - Tranformação Encodable -> [String: String]

extension Encodable {
    func asStringDictionary() throws -> [String:String] {
        do {
            let data = try JSONEncoder().encode(self)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AnalyticsError.invalidDictionary("JSON não é dicionário de topo.")
            }
            return dict.mapValues { "\($0)" }
        } catch let e as EncodingError {
            throw AnalyticsError.encoding("Falha ao codificar: \(e)")
        } catch {
            throw AnalyticsError.invalidDictionary("Falha: \(error.localizedDescription)")
        }
    }
}

// MARK: - SwiftData Stack

@MainActor
enum SwiftDataStack {

    public static func makeContainer() throws -> ModelContainer {
        let schema = Schema([Favorite.self, AnalyticsRecord.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            
            
            
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}

// MARK: - AnalyticsService

enum AnalyticsService {
    #if DEBUG
    private static let logger = Logger(subsystem: "br.ufpe.academy.analytics", category: "Analytics")
    #endif

    /// When true, events will also be forwarded to the PUBLIC CloudKit database (AcademyEvent recordType).
    /// Enable in the App when you want exportability via CloudKit Dashboard.
    /// 
    public static var cloudKitContainer: CKContainer = .default()

    /// Logs an analytics event into the provided ModelContext.
    public static func log(event: AnalyticsEvent, context: ModelContext) {
        Task { @MainActor in
            do {
                let parameters = try event.parameters()
                let jsonData = try JSONEncoder().encode(parameters)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

                let record = AnalyticsRecord(eventName: event.eventName, parametersJSON: jsonString)
                context.insert(record)
                try context.save()

                #if DEBUG
                logger.info("✅ Event '\(event.eventName, privacy: .public)' saved with params: \(jsonString, privacy: .public)")
                #endif

                
                Task { await sendToCloudKit(event: event) }

            } catch {
                #if DEBUG
                logger.error("❌ Failed to save analytics event \(event.eventName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }
    }

    private static func sendToCloudKit(event: AnalyticsEvent) async {
        // Escolhe o banco automaticamente
        let database: CKDatabase = {
            #if DEBUG
            return cloudKitContainer.privateCloudDatabase
            #else
            return cloudKitContainer.publicCloudDatabase
            #endif
        }()

        do {
            let params = try event.parameters()
            let jsonData = try JSONEncoder().encode(params)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            let record = CKRecord(recordType: "AcademyEvent")
            record["name"] = event.eventName as NSString
            record["ts"] = Date() as NSDate
            record["params"] = jsonString as NSString

            try await database.save(record)
            #if DEBUG
            logger.info("✅ CloudKit: saved event '\(event.eventName, privacy: .public)' to \(database.databaseScope == .private ? "PRIVATE" : "PUBLIC") DB")
            #endif
        } catch {
            #if DEBUG
            logger.error("❌ CloudKit save failed (\(database.databaseScope == .private ? "PRIVATE" : "PUBLIC")): \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }
}

