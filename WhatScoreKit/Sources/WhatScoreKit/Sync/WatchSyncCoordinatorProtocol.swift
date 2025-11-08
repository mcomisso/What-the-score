import Foundation
import SwiftData

/// Protocol defining the interface for watch synchronization coordinators
/// Implemented separately for iOS and watchOS platforms
@MainActor
public protocol WatchSyncCoordinatorProtocol: AnyObject, Observable {

    /// Initialize the coordinator with a model container
    init(
        modelContainer: ModelContainer,
        syncService: (any DataSyncService)?,
        conversionService: (any DataConversionService)?
    )

    /// Send current data to the paired device
    func sendData()

    /// Send preferences to the paired device
    func sendPreferences(_ preferences: [String: Any])
}
