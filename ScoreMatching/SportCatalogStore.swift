import Foundation
import Observation
import WhatScoreKit

/// Loads sport definitions from a bundled catalog, a validated local cache, and GitHub.
@MainActor
@Observable
final class SportCatalogStore {
    private static let catalogURL = URL(
        string: "https://raw.githubusercontent.com/mcomisso/What-the-score/main/sports/catalog-v1.json"
    )!

    private let session: URLSession
    private let fileManager: FileManager
    private let cacheURL: URL?

    private(set) var sports: [SportDefinition]

    init(bundle: Bundle = .main, fileManager: FileManager = .default, session: URLSession = .shared) {
        self.session = session
        self.fileManager = fileManager
        self.cacheURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("sport-catalog-v1.json")

        let builtInSports = SportPreset.allCases.filter { $0 != .custom }.map(\.definition)
        if let bundledURL = bundle.url(forResource: "catalog-v1", withExtension: "json"),
           let data = try? Data(contentsOf: bundledURL),
           let catalog = try? SportCatalog.validated(data: data) {
            sports = Self.withCustomSport(catalog.sports)
        } else {
            sports = Self.withCustomSport(builtInSports)
        }

        if let cacheURL,
           let data = try? Data(contentsOf: cacheURL),
           let catalog = try? SportCatalog.validated(data: data) {
            sports = Self.withCustomSport(catalog.sports)
        }
    }

    func refresh() async {
        var request = URLRequest(url: Self.catalogURL)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 200,
                  response.expectedContentLength <= 64 * 1024 else {
                return
            }

            var data = Data()
            data.reserveCapacity(4 * 1024)
            for try await byte in bytes {
                guard data.count < 64 * 1024 else { return }
                data.append(byte)
            }

            let catalog = try SportCatalog.validated(data: data)
            sports = Self.withCustomSport(catalog.sports)

            if let cacheURL {
                try fileManager.createDirectory(
                    at: cacheURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: cacheURL, options: .atomic)
            }
        } catch {
            // Keep the last valid catalog if the network or cache write fails.
        }
    }

    private static func withCustomSport(_ sports: [SportDefinition]) -> [SportDefinition] {
        sports.filter { $0.id != SportPreset.custom.rawValue } + [SportPreset.custom.definition]
    }
}
