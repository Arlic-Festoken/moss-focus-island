import CloudKit
import Combine
import Foundation

enum CloudSyncStatus: Equatable {
    case disabled
    case checking
    case ready
    case syncing
    case synced(Date)
    case unavailable(String)
    case failed(String)

    var title: String {
        switch self {
        case .disabled: "未启用"
        case .checking: "正在检查 iCloud"
        case .ready: "等待同步"
        case .syncing: "正在同步"
        case .synced: "已同步"
        case .unavailable: "iCloud 不可用"
        case .failed: "同步遇到问题"
        }
    }

    var detail: String {
        switch self {
        case .disabled:
            "数据仍安全保存在这台设备。"
        case .checking:
            "正在确认账户和 CloudKit 权限。"
        case .ready:
            "本地数据已就绪，系统会自动选择合适时机同步。"
        case let .synced(date):
            "最近同步：\(date.formatted(date: .omitted, time: .shortened))"
        case .syncing:
            "本地保存不会等待网络。"
        case let .unavailable(message), let .failed(message):
            message
        }
    }

    var symbol: String {
        switch self {
        case .disabled: "icloud.slash"
        case .checking, .syncing: "arrow.triangle.2.circlepath.icloud"
        case .ready: "icloud"
        case .synced: "checkmark.icloud.fill"
        case .unavailable, .failed: "exclamationmark.icloud"
        }
    }
}

@MainActor
final class CloudSyncController: ObservableObject {
    static let enabledDefaultsKey = "iCloudSyncEnabled"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var status: CloudSyncStatus

    private let dataStore: DataStore
    private let stateURL: URL
    private var engine: MossCloudSyncEngine?
    private var startTask: Task<Void, Never>?
    private var isApplyingRemoteChanges = false

    init(dataStore: DataStore, defaults: UserDefaults = .standard) {
        self.dataStore = dataStore
        let enabled = defaults.bool(forKey: Self.enabledDefaultsKey)
        isEnabled = enabled
        status = enabled ? .checking : .disabled

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        stateURL = applicationSupport
            .appendingPathComponent("Moss", isDirectory: true)
            .appendingPathComponent("cloud-sync-state.json")
        dataStore.configureCloudSync(self)
    }

    deinit {
        startTask?.cancel()
    }

    func startIfEnabled() {
        guard isEnabled else { return }
        start()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)
        if enabled {
            start()
        } else {
            startTask?.cancel()
            let previousEngine = engine
            engine = nil
            status = .disabled
            Task {
                await previousEngine?.stop()
            }
        }
    }

    func syncNow() {
        guard isEnabled else { return }
        guard let engine else {
            start()
            return
        }
        Task {
            await engine.syncNow()
        }
    }

    func databaseDidChange(_ database: MossDatabase) {
        guard isEnabled, !isApplyingRemoteChanges else { return }
        do {
            let entities = try CloudSyncCodec.entities(from: database)
            let engine = self.engine
            Task {
                await engine?.capture(entities, markAsUserChanges: true)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func start() {
        startTask?.cancel()
        status = .checking
        startTask = Task { [weak self] in
            guard let self else { return }
            do {
                let accountStatus = try await CKContainer(
                    identifier: MossCloudSyncEngine.containerIdentifier
                ).accountStatus()
                guard accountStatus == .available else {
                    self.status = .unavailable(Self.message(for: accountStatus))
                    return
                }

                let entities = try CloudSyncCodec.entities(from: self.dataStore.databaseSnapshot())
                let newEngine = MossCloudSyncEngine(
                    stateURL: self.stateURL,
                    remoteChangeHandler: { [weak self] changes in
                        await self?.applyRemoteChanges(changes)
                    },
                    noticeHandler: { [weak self] notice in
                        await self?.handleNotice(notice)
                    }
                )
                self.engine = newEngine
                self.status = .ready
                await newEngine.start(with: entities)
            } catch {
                self.status = .failed(Self.message(for: error))
            }
        }
    }

    private func applyRemoteChanges(_ changes: [CloudSyncRemoteChange]) async {
        guard isEnabled, !changes.isEmpty else { return }
        isApplyingRemoteChanges = true
        defer { isApplyingRemoteChanges = false }
        do {
            try dataStore.applyCloudChanges(changes)
        } catch {
            status = .failed("云端数据未写入本地：\(error.localizedDescription)")
        }
    }

    private func handleNotice(_ notice: CloudSyncEngineNotice) {
        guard isEnabled else { return }
        switch notice {
        case .syncing:
            status = .syncing
        case let .synced(date):
            status = .synced(date)
        case let .failed(message):
            status = .failed(message)
        case .accountChanged:
            status = .checking
        }
    }

    private static func message(for status: CKAccountStatus) -> String {
        switch status {
        case .noAccount:
            "请先在系统设置中登录 iCloud。"
        case .restricted:
            "当前设备限制了 iCloud 访问。"
        case .couldNotDetermine:
            "暂时无法确认 iCloud 账户状态，请稍后重试。"
        case .temporarilyUnavailable:
            "iCloud 暂时不可用，本地数据仍然安全。"
        case .available:
            ""
        @unknown default:
            "当前无法使用 iCloud。"
        }
    }

    private static func message(for error: Error) -> String {
        if let cloudError = error as? CKError {
            switch cloudError.code {
            case .notAuthenticated:
                return "请先在系统设置中登录 iCloud。"
            case .networkFailure, .networkUnavailable:
                return "当前网络不可用，本地数据已保留。"
            case .permissionFailure, .badContainer, .missingEntitlement:
                return "当前 Moss 安装包尚未配置 iCloud 权限。"
            default:
                return cloudError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
