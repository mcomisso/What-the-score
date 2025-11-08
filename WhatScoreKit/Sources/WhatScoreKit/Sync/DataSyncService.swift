import Foundation
import SwiftData

/// Protocol for syncing data between devices
public protocol DataSyncService {
    /// Send data to paired device
    func sendData(_ syncData: SyncData)

    /// Send preferences to paired device
    func sendPreferences(_ preferences: [String: Any])

    /// Callback when data is received from paired device
    var onDataReceived: ((SyncData) -> Void)? { get set }

    /// Callback when preferences are received from paired device
    var onPreferencesReceived: (([String: Any]) -> Void)? { get set }

    /// Callback when session becomes activated
    var onSessionActivated: (() -> Void)? { get set }
}

/// Service for converting SwiftData models to/from sync data
public protocol DataConversionService {
    /// Convert SwiftData models to SyncData
    func createSyncData(from context: ModelContext) throws -> SyncData

    /// Update SwiftData models from SyncData
    func updateModels(with syncData: SyncData, in context: ModelContext) throws
}
