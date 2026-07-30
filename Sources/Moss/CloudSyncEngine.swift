import CloudKit
import CryptoKit
import Foundation

enum CloudSyncEngineNotice: Sendable {
    case syncing
    case synced(Date)
    case failed(String)
    case accountChanged
}

actor MossCloudSyncEngine: CKSyncEngineDelegate {
    static let containerIdentifier = "iCloud.com.zhikanghuang.moss"
    static let zoneName = "MossDataV1"
    static let recordType = "MossEntity"

    private let stateURL: URL
    private let backupURL: URL
    private let container: CKContainer
    private let remoteChangeHandler: @Sendable ([CloudSyncRemoteChange]) async -> Void
    private let noticeHandler: @Sendable (CloudSyncEngineNotice) async -> Void
    private var persistentState: CloudSyncPersistentState
    private var currentEntities: [String: CloudSyncEntity] = [:]
    private var syncEngine: CKSyncEngine?

    init(
        stateURL: URL,
        remoteChangeHandler: @escaping @Sendable ([CloudSyncRemoteChange]) async -> Void,
        noticeHandler: @escaping @Sendable (CloudSyncEngineNotice) async -> Void
    ) {
        self.stateURL = stateURL
        backupURL = stateURL
            .deletingPathExtension()
            .appendingPathExtension("backup.json")
        container = CKContainer(identifier: Self.containerIdentifier)
        self.remoteChangeHandler = remoteChangeHandler
        self.noticeHandler = noticeHandler
        persistentState = Self.loadState(from: stateURL) ?? CloudSyncPersistentState()
    }

    func start(with entities: [CloudSyncEntity]) async {
        capture(entities, markAsUserChanges: false)
        initializeEngine()
        await syncNow()
    }

    func stop() async {
        await syncEngine?.cancelOperations()
        syncEngine = nil
    }

    func capture(_ entities: [CloudSyncEntity], markAsUserChanges: Bool) {
        let previousNames = Set(currentEntities.keys)
        let next = Dictionary(uniqueKeysWithValues: entities.map { ($0.recordName, $0) })
        currentEntities = next

        guard let syncEngine else {
            seedMetadataIfNeeded(for: entities)
            persistState()
            return
        }

        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        let now = Date()
        for entity in entities {
            let name = entity.recordName
            if var metadata = persistentState.entities[name] {
                guard metadata.payloadHash != entity.payloadHash else { continue }
                metadata.payloadHash = entity.payloadHash
                if markAsUserChanges {
                    metadata.userModificationDate = now
                }
                persistentState.entities[name] = metadata
                if markAsUserChanges && persistentState.initialFetchCompleted {
                    pending.append(.saveRecord(recordID(for: entity)))
                }
            } else {
                persistentState.entities[name] = CloudSyncEntityMetadata(
                    payloadHash: entity.payloadHash,
                    userModificationDate: markAsUserChanges ? now : entity.modificationHint,
                    lastKnownRecordData: nil
                )
                if markAsUserChanges && persistentState.initialFetchCompleted {
                    pending.append(.saveRecord(recordID(for: entity)))
                }
            }
        }

        if markAsUserChanges && persistentState.initialFetchCompleted {
            let removedNames = previousNames.subtracting(next.keys)
            for name in removedNames {
                guard let identity = try? CloudSyncCodec.identity(from: name) else { continue }
                pending.append(.deleteRecord(recordID(kind: identity.0, id: identity.1)))
            }
        }

        if !pending.isEmpty {
            syncEngine.state.add(pendingRecordZoneChanges: pending)
        }
        persistState()
    }

    func syncNow() async {
        guard let syncEngine else { return }
        await noticeHandler(.syncing)
        do {
            if !persistentState.initialFetchCompleted {
                syncEngine.state.add(
                    pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneName: Self.zoneName))]
                )
                try await syncEngine.sendChanges()
            }
            try await syncEngine.fetchChanges()
            try await syncEngine.sendChanges()
            await noticeHandler(.synced(.now))
        } catch {
            await noticeHandler(.failed(Self.message(for: error)))
        }
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case let .stateUpdate(update):
            persistentState.engineState = update.stateSerialization
            persistState()

        case .accountChange:
            persistentState.engineState = nil
            persistentState.initialFetchCompleted = false
            for name in persistentState.entities.keys {
                persistentState.entities[name]?.lastKnownRecordData = nil
            }
            persistState()
            await noticeHandler(.accountChanged)

        case let .fetchedDatabaseChanges(changes):
            if changes.deletions.contains(where: { $0.zoneID.zoneName == Self.zoneName }) {
                persistentState.initialFetchCompleted = false
                for name in persistentState.entities.keys {
                    persistentState.entities[name]?.lastKnownRecordData = nil
                }
                syncEngine.state.add(
                    pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneName: Self.zoneName))]
                )
                persistState()
            }

        case let .fetchedRecordZoneChanges(changes):
            await handleFetchedRecordZoneChanges(changes, syncEngine: syncEngine)

        case let .sentRecordZoneChanges(changes):
            await handleSentRecordZoneChanges(changes, syncEngine: syncEngine)

        case .sentDatabaseChanges:
            break

        case .willFetchChanges, .willFetchRecordZoneChanges, .willSendChanges:
            await noticeHandler(.syncing)

        case .didFetchChanges:
            if !persistentState.initialFetchCompleted {
                persistentState.initialFetchCompleted = true
                let pending = currentEntities.values.compactMap { entity in
                    let metadata = persistentState.entities[entity.recordName]
                    return metadata?.lastKnownRecordData == nil
                        ? CKSyncEngine.PendingRecordZoneChange.saveRecord(recordID(for: entity))
                        : nil
                }
                syncEngine.state.add(pendingRecordZoneChanges: pending)
                persistState()
            }

        case .didFetchRecordZoneChanges, .didSendChanges:
            break

        @unknown default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter {
            context.options.scope.contains($0)
        }
        let entities = currentEntities
        let metadataByName = persistentState.entities
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            guard let entity = entities[recordID.recordName],
                  let metadata = metadataByName[recordID.recordName] else {
                syncEngine.state.remove(
                    pendingRecordZoneChanges: [.saveRecord(recordID)]
                )
                return nil
            }

            let record = Self.decodeRecord(from: metadata.lastKnownRecordData)
                ?? CKRecord(recordType: Self.recordType, recordID: recordID)
            record.encryptedValues[.mossKind] = entity.kind.rawValue
            record.encryptedValues[.mossPayload] = entity.payload
            record.encryptedValues[.mossUserModificationDate] = metadata.userModificationDate
            return record
        }
    }

    private func initializeEngine() {
        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: persistentState.engineState,
            delegate: self
        )
        configuration.automaticallySync = true
        syncEngine = CKSyncEngine(configuration)
    }

    private func handleFetchedRecordZoneChanges(
        _ event: CKSyncEngine.Event.FetchedRecordZoneChanges,
        syncEngine: CKSyncEngine
    ) async {
        var remoteChanges: [CloudSyncRemoteChange] = []

        for modification in event.modifications {
            let record = modification.record
            guard record.recordType == Self.recordType,
                  let payload = record.encryptedValues[.mossPayload] as? Data,
                  let kindRaw = record.encryptedValues[.mossKind] as? String,
                  let kind = CloudSyncEntityKind(rawValue: kindRaw),
                  let userModificationDate =
                    record.encryptedValues[.mossUserModificationDate] as? Date,
                  let identity = try? CloudSyncCodec.identity(from: record.recordID.recordName),
                  identity.0 == kind else {
                continue
            }

            let name = record.recordID.recordName
            let isPendingDeletion = syncEngine.state.pendingRecordZoneChanges.contains(
                .deleteRecord(record.recordID)
            )
            if isPendingDeletion { continue }

            let payloadHash = Self.hash(payload)
            let localEntity = currentEntities[name]
            let localDate = persistentState.entities[name]?.userModificationDate
                ?? localEntity?.modificationHint
                ?? .distantPast

            if localEntity == nil || userModificationDate >= localDate {
                let entity = CloudSyncEntity(
                    kind: kind,
                    id: identity.1,
                    payload: payload,
                    payloadHash: payloadHash,
                    modificationHint: userModificationDate
                )
                currentEntities[name] = entity
                persistentState.entities[name] = CloudSyncEntityMetadata(
                    payloadHash: payloadHash,
                    userModificationDate: userModificationDate,
                    lastKnownRecordData: Self.encodeSystemFields(record)
                )
                remoteChanges.append(.upsert(kind: kind, id: identity.1, payload: payload))
            } else {
                persistentState.entities[name]?.lastKnownRecordData =
                    Self.encodeSystemFields(record)
                syncEngine.state.add(
                    pendingRecordZoneChanges: [.saveRecord(record.recordID)]
                )
            }
        }

        for deletion in event.deletions {
            let recordID = deletion.recordID
            let isPendingSave = syncEngine.state.pendingRecordZoneChanges.contains(
                .saveRecord(recordID)
            )
            if isPendingSave { continue }
            guard let identity = try? CloudSyncCodec.identity(from: recordID.recordName) else {
                continue
            }
            currentEntities[recordID.recordName] = nil
            persistentState.entities[recordID.recordName] = nil
            remoteChanges.append(.delete(kind: identity.0, id: identity.1))
        }

        persistState()
        if !remoteChanges.isEmpty {
            await remoteChangeHandler(remoteChanges)
        }
    }

    private func handleSentRecordZoneChanges(
        _ event: CKSyncEngine.Event.SentRecordZoneChanges,
        syncEngine: CKSyncEngine
    ) async {
        var remoteChanges: [CloudSyncRemoteChange] = []
        for record in event.savedRecords {
            let name = record.recordID.recordName
            persistentState.entities[name]?.lastKnownRecordData =
                Self.encodeSystemFields(record)
        }
        for recordID in event.deletedRecordIDs {
            persistentState.entities[recordID.recordName] = nil
        }

        var pendingRecordChanges: [CKSyncEngine.PendingRecordZoneChange] = []
        var pendingDatabaseChanges: [CKSyncEngine.PendingDatabaseChange] = []
        for failure in event.failedRecordSaves {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failure.error.serverRecord,
                      let payload = serverRecord.encryptedValues[.mossPayload] as? Data,
                      let kindRaw = serverRecord.encryptedValues[.mossKind] as? String,
                      let kind = CloudSyncEntityKind(rawValue: kindRaw),
                      let serverDate =
                        serverRecord.encryptedValues[.mossUserModificationDate] as? Date,
                      let identity = try? CloudSyncCodec.identity(
                          from: serverRecord.recordID.recordName
                      ) else {
                    continue
                }
                let localDate = persistentState.entities[recordID.recordName]?
                    .userModificationDate ?? .distantPast
                if serverDate >= localDate {
                    let payloadHash = Self.hash(payload)
                    currentEntities[recordID.recordName] = CloudSyncEntity(
                        kind: kind,
                        id: identity.1,
                        payload: payload,
                        payloadHash: payloadHash,
                        modificationHint: serverDate
                    )
                    persistentState.entities[recordID.recordName] =
                        CloudSyncEntityMetadata(
                            payloadHash: payloadHash,
                            userModificationDate: serverDate,
                            lastKnownRecordData: Self.encodeSystemFields(serverRecord)
                        )
                    remoteChanges.append(
                        .upsert(kind: kind, id: identity.1, payload: payload)
                    )
                } else {
                    persistentState.entities[recordID.recordName]?.lastKnownRecordData =
                        Self.encodeSystemFields(serverRecord)
                    pendingRecordChanges.append(.saveRecord(recordID))
                }
            case .zoneNotFound:
                pendingDatabaseChanges.append(
                    .saveZone(CKRecordZone(zoneID: recordID.zoneID))
                )
                pendingRecordChanges.append(.saveRecord(recordID))
                persistentState.entities[recordID.recordName]?.lastKnownRecordData = nil
            case .unknownItem:
                pendingRecordChanges.append(.saveRecord(recordID))
                persistentState.entities[recordID.recordName]?.lastKnownRecordData = nil
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                    .notAuthenticated, .accountTemporarilyUnavailable, .requestRateLimited,
                    .operationCancelled:
                break
            default:
                Task {
                    await noticeHandler(.failed(Self.message(for: failure.error)))
                }
            }
        }

        for (recordID, error) in event.failedRecordDeletes {
            switch error.code {
            case .unknownItem:
                persistentState.entities[recordID.recordName] = nil
            case .zoneNotFound:
                pendingDatabaseChanges.append(
                    .saveZone(CKRecordZone(zoneID: recordID.zoneID))
                )
                pendingRecordChanges.append(.deleteRecord(recordID))
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                    .notAuthenticated, .accountTemporarilyUnavailable, .requestRateLimited,
                    .operationCancelled:
                break
            default:
                Task {
                    await noticeHandler(.failed(Self.message(for: error)))
                }
            }
        }

        syncEngine.state.add(pendingDatabaseChanges: pendingDatabaseChanges)
        syncEngine.state.add(pendingRecordZoneChanges: pendingRecordChanges)
        persistState()
        if !remoteChanges.isEmpty {
            await remoteChangeHandler(remoteChanges)
        }
    }

    private func seedMetadataIfNeeded(for entities: [CloudSyncEntity]) {
        for entity in entities where persistentState.entities[entity.recordName] == nil {
            persistentState.entities[entity.recordName] = CloudSyncEntityMetadata(
                payloadHash: entity.payloadHash,
                userModificationDate: entity.modificationHint,
                lastKnownRecordData: nil
            )
        }
    }

    private func persistState() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(persistentState)
            try FileManager.default.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: stateURL.path) {
                let previous = try Data(contentsOf: stateURL)
                try previous.write(to: backupURL, options: .atomic)
            }
            try data.write(to: stateURL, options: .atomic)
        } catch {
            Task {
                await noticeHandler(.failed("iCloud 同步状态保存失败：\(error.localizedDescription)"))
            }
        }
    }

    private func recordID(for entity: CloudSyncEntity) -> CKRecord.ID {
        recordID(kind: entity.kind, id: entity.id)
    }

    private func recordID(kind: CloudSyncEntityKind, id: UUID) -> CKRecord.ID {
        CKRecord.ID(
            recordName: "\(kind.rawValue).\(id.uuidString.lowercased())",
            zoneID: CKRecordZone.ID(zoneName: Self.zoneName)
        )
    }

    private static func loadState(from url: URL) -> CloudSyncPersistentState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CloudSyncPersistentState.self, from: data)
    }

    private static func encodeSystemFields(_ record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        return archiver.encodedData
    }

    private static func decodeRecord(from data: Data?) -> CKRecord? {
        guard let data else { return nil }
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = true
            return CKRecord(coder: unarchiver)
        } catch {
            return nil
        }
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func message(for error: Error) -> String {
        if let cloudError = error as? CKError {
            switch cloudError.code {
            case .notAuthenticated:
                return "请先在系统设置中登录 iCloud。"
            case .networkFailure, .networkUnavailable:
                return "当前网络不可用，本地数据已保留，联网后会自动重试。"
            case .quotaExceeded:
                return "iCloud 空间不足，本地数据仍然安全。"
            case .permissionFailure, .badContainer:
                return "当前安装包尚未获得 Moss 的 iCloud 容器权限。"
            default:
                return cloudError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

extension CKRecord.FieldKey {
    static let mossKind = "kind"
    static let mossPayload = "payload"
    static let mossUserModificationDate = "userModificationDate"
}
