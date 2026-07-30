import CloudKit
import CryptoKit
import Foundation

enum CloudSyncEntityKind: String, Codable, CaseIterable, Sendable {
    case project
    case task
    case session
    case interruption
    case reflection
    case snapshot
    case plan
    case journal
}

struct CloudSyncEntity: Hashable, Sendable {
    static let maximumPayloadBytes = 850_000

    let kind: CloudSyncEntityKind
    let id: UUID
    let payload: Data
    let payloadHash: String
    let modificationHint: Date

    var recordName: String { "\(kind.rawValue).\(id.uuidString.lowercased())" }
}

enum CloudSyncRemoteChange: Sendable {
    case upsert(kind: CloudSyncEntityKind, id: UUID, payload: Data)
    case delete(kind: CloudSyncEntityKind, id: UUID)
}

struct CloudSyncEntityMetadata: Codable, Sendable {
    var payloadHash: String
    var userModificationDate: Date
    var lastKnownRecordData: Data?
}

struct CloudSyncPersistentState: Codable, Sendable {
    var engineState: CKSyncEngine.State.Serialization?
    var entities: [String: CloudSyncEntityMetadata] = [:]
    var initialFetchCompleted = false
}

enum CloudSyncCodecError: LocalizedError {
    case payloadTooLarge(kind: CloudSyncEntityKind, id: UUID, bytes: Int)
    case invalidRecordName(String)

    var errorDescription: String? {
        switch self {
        case let .payloadTooLarge(kind, id, bytes):
            "\(kind.rawValue) \(id.uuidString) 的同步数据为 \(bytes) 字节，超过安全上限。"
        case let .invalidRecordName(name):
            "无法识别 iCloud 记录：\(name)"
        }
    }
}

enum CloudSyncCodec {
    static func entities(from database: MossDatabase) throws -> [CloudSyncEntity] {
        var result: [CloudSyncEntity] = []
        result.reserveCapacity(
            database.projects.count
                + database.tasks.count
                + database.sessions.count
                + database.interruptions.count
                + database.reflections.count
                + database.snapshots.count
                + database.plans.count
                + database.journalRecords.count
        )

        try database.projects.forEach {
            try append($0, kind: .project, id: $0.id, modifiedAt: $0.createdAt, to: &result)
        }
        try database.tasks.forEach {
            try append($0, kind: .task, id: $0.id, modifiedAt: $0.createdAt, to: &result)
        }
        try database.sessions.forEach {
            try append(
                $0,
                kind: .session,
                id: $0.id,
                modifiedAt: $0.endedAt ?? $0.startedAt,
                to: &result
            )
        }
        try database.interruptions.forEach {
            try append(
                $0,
                kind: .interruption,
                id: $0.id,
                modifiedAt: $0.endedAt ?? $0.startedAt,
                to: &result
            )
        }
        try database.reflections.forEach {
            try append($0, kind: .reflection, id: $0.id, modifiedAt: $0.createdAt, to: &result)
        }
        try database.snapshots.forEach {
            try append($0, kind: .snapshot, id: $0.id, modifiedAt: $0.date, to: &result)
        }
        try database.plans.forEach {
            try append($0, kind: .plan, id: $0.id, modifiedAt: $0.updatedAt, to: &result)
        }
        try database.journalRecords.forEach {
            try append($0, kind: .journal, id: $0.id, modifiedAt: $0.updatedAt, to: &result)
        }
        return result
    }

    static func identity(from recordName: String) throws -> (CloudSyncEntityKind, UUID) {
        guard let separator = recordName.firstIndex(of: "."),
              let kind = CloudSyncEntityKind(rawValue: String(recordName[..<separator])),
              let id = UUID(uuidString: String(recordName[recordName.index(after: separator)...])) else {
            throw CloudSyncCodecError.invalidRecordName(recordName)
        }
        return (kind, id)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    private static func append<T: Encodable>(
        _ value: T,
        kind: CloudSyncEntityKind,
        id: UUID,
        modifiedAt: Date,
        to result: inout [CloudSyncEntity]
    ) throws {
        let payload = try encoder.encode(value)
        guard payload.count <= CloudSyncEntity.maximumPayloadBytes else {
            throw CloudSyncCodecError.payloadTooLarge(
                kind: kind,
                id: id,
                bytes: payload.count
            )
        }
        result.append(
            CloudSyncEntity(
                kind: kind,
                id: id,
                payload: payload,
                payloadHash: SHA256.hash(data: payload)
                    .map { String(format: "%02x", $0) }
                    .joined(),
                modificationHint: modifiedAt
            )
        )
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension MossDatabase {
    mutating func apply(_ changes: [CloudSyncRemoteChange]) throws {
        for change in changes {
            switch change {
            case let .upsert(kind, _, payload):
                switch kind {
                case .project:
                    let value = try CloudSyncCodec.decode(FocusProject.self, from: payload)
                    replace(value, in: &projects)
                    for index in tasks.indices where tasks[index].projectID == value.id {
                        tasks[index].category = value.title
                    }
                case .task:
                    replace(
                        try CloudSyncCodec.decode(FocusTask.self, from: payload),
                        in: &tasks
                    )
                case .session:
                    replace(
                        try CloudSyncCodec.decode(FocusSession.self, from: payload),
                        in: &sessions
                    )
                case .interruption:
                    replace(
                        try CloudSyncCodec.decode(Interruption.self, from: payload),
                        in: &interruptions
                    )
                case .reflection:
                    replace(
                        try CloudSyncCodec.decode(Reflection.self, from: payload),
                        in: &reflections
                    )
                case .snapshot:
                    replace(
                        try CloudSyncCodec.decode(DailySnapshot.self, from: payload),
                        in: &snapshots
                    )
                case .plan:
                    replace(
                        try CloudSyncCodec.decode(PlanEntry.self, from: payload),
                        in: &plans
                    )
                case .journal:
                    replace(
                        try CloudSyncCodec.decode(JournalRecord.self, from: payload),
                        in: &journalRecords
                    )
                }

            case let .delete(kind, id):
                switch kind {
                case .project:
                    projects.removeAll { $0.id == id }
                    for index in tasks.indices where tasks[index].projectID == id {
                        tasks[index].projectID = nil
                        tasks[index].category = "未分类"
                    }
                case .task:
                    tasks.removeAll { $0.id == id }
                    for index in plans.indices where plans[index].linkedTaskID == id {
                        plans[index].linkedTaskID = nil
                        plans[index].updatedAt = .now
                    }
                case .session:
                    sessions.removeAll { $0.id == id }
                    interruptions.removeAll { $0.sessionID == id }
                    reflections.removeAll { $0.sessionID == id }
                case .interruption:
                    interruptions.removeAll { $0.id == id }
                case .reflection:
                    reflections.removeAll { $0.id == id }
                case .snapshot:
                    snapshots.removeAll { $0.id == id }
                case .plan:
                    plans.removeAll { $0.id == id }
                case .journal:
                    journalRecords.removeAll { $0.id == id }
                }
            }
        }
    }
}

private func replace<T: Identifiable>(_ value: T, in values: inout [T]) where T.ID == UUID {
    if let index = values.firstIndex(where: { $0.id == value.id }) {
        values[index] = value
    } else {
        values.append(value)
    }
}
