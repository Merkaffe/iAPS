import Combine
import SwiftUI

extension Settings {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() private var broadcaster: Broadcaster!
        @Injected() private var fileManager: FileManager!
        @Injected() private var nightscoutManager: NightscoutManager!

        @Published var closedLoop = false
        @Published var debugOptions = false
        @Published var animatedBackground = false
        @Published var disableCGMError = true

        @Published var noLoop: Date = .distantPast

        @Published var imported: Bool = false

        @Published var token: String = ""

        @Published var basals: [BasalProfileEntry]?
        @Published var crs: [CarbRatioEntry]?
        @Published var isfs: [InsulinSensitivityEntry]?
        @Published var settings: Preferences?
        @Published var freeapsSettings: FreeAPSSettings?

        private(set) var buildNumber = ""
        private(set) var versionNumber = ""
        private(set) var branch = ""
        private(set) var copyrightNotice = ""

        override func subscribe() {
            nightscoutManager.fetchVersion()

            noLoop = CoreDataStorage().fetchLoopStats(interval: DateFilter().total).first?.end ?? .distantPast

            subscribeSetting(\.debugOptions, on: $debugOptions) { debugOptions = $0 }
            subscribeSetting(\.closedLoop, on: $closedLoop) { closedLoop = $0 }
            subscribeSetting(\.disableCGMError, on: $disableCGMError) { disableCGMError = $0 }

            broadcaster.register(SettingsObserver.self, observer: self)

            buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

            versionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

            // Read branch information from the branch.txt instead of infoDictionary
            if let branchFileURL = Bundle.main.url(forResource: "branch", withExtension: "txt"),
               let branchFileContent = try? String(contentsOf: branchFileURL)
            {
                let lines = branchFileContent.components(separatedBy: .newlines)
                for line in lines {
                    let components = line.components(separatedBy: "=")
                    if components.count == 2 {
                        let key = components[0].trimmingCharacters(in: .whitespaces)
                        let value = components[1].trimmingCharacters(in: .whitespaces)

                        if key == "BRANCH" {
                            branch = value
                            break
                        }
                    }
                }
            } else {
                branch = "Unknown"
            }

            copyrightNotice = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""

            subscribeSetting(\.animatedBackground, on: $animatedBackground) { animatedBackground = $0 }
        }

        func logItems() -> [URL] {
            var items: [URL] = []

            if fileManager.fileExists(atPath: SimpleLogReporter.logFile) {
                items.append(URL(fileURLWithPath: SimpleLogReporter.logFile))
            }

            if fileManager.fileExists(atPath: SimpleLogReporter.logFilePrev) {
                items.append(URL(fileURLWithPath: SimpleLogReporter.logFilePrev))
            }

            return items
        }

        func uploadProfileAndSettings(_ force: Bool) {
            NSLog("SettingsState Upload Profile and Settings")
            nightscoutManager.uploadProfileAndSettings(force)
        }

        func hideSettingsModal() {
            hideModal()
        }

        func deleteOverrides() {
            nightscoutManager.deleteAllNSoverrrides() // For testing
        }

        func importSettings(id: String) {
            fetchPreferences(token: id)
            fetchSettings(token: id)
        }

        func close() {
            imported = true
        }

        func fetchPreferences(token: String) {
            let nightscout = NightscoutAPI(url: IAPSconfig.statURL)
            DispatchQueue.main.async {
                nightscout.fetchPreferences(token: token)
                    .sink { completion in
                        switch completion {
                        case .finished:
                            debug(.nightscout, "Preferences fetched from " + IAPSconfig.statURL.absoluteString)
                        case let .failure(error):
                            debug(.nightscout, error.localizedDescription)
                        }
                    }
                receiveValue: {
                    self.settings = $0
                }
                .store(in: &self.lifetime)
            }
        }

        func fetchSettings(token: String) {
            let nightscout = NightscoutAPI(url: IAPSconfig.statURL)
            nightscout.fetchSettings(token: token)
                .sink { completion in
                    switch completion {
                    case .finished:
                        debug(.nightscout, "Settings fetched from " + IAPSconfig.statURL.absoluteString)
                    case let .failure(error):
                        debug(.nightscout, error.localizedDescription)
                    }
                }
            receiveValue: { self.freeapsSettings = $0 }
                .store(in: &lifetime)
        }
    }
}

extension Settings.StateModel: SettingsObserver {
    func settingsDidChange(_ settings: FreeAPSSettings) {
        closedLoop = settings.closedLoop
        debugOptions = settings.debugOptions
        disableCGMError = settings.disableCGMError
    }
}
