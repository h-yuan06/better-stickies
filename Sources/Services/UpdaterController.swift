import Foundation
import Observation
import Sparkle
import os

/// Wraps Sparkle so the rest of the app never imports it directly.
///
/// The updater is only started when a real EdDSA public key is baked into the bundle.
/// A development build still carries the placeholder, and starting Sparkle with an
/// unusable key produces a stream of errors and a broken "Check for Updates" menu
/// item rather than an honest "not configured".
@MainActor
@Observable
final class UpdaterController {
    private(set) var isConfigured: Bool
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private let logger = Logger(subsystem: NoteStore.subsystem, category: "Updater")

    /// Written into Info.plist by the build; replaced at release time.
    static let placeholderPublicKey = "REPLACE_WITH_PUBLIC_ED_KEY"

    init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        isConfigured = (key?.isEmpty == false) && key != Self.placeholderPublicKey

        guard isConfigured else {
            logger.notice("Sparkle not configured (placeholder public key); updates disabled.")
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var lastUpdateCheckDate: Date? {
        controller?.updater.lastUpdateCheckDate
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    func checkForUpdates() {
        controller?.updater.checkForUpdates()
    }
}
