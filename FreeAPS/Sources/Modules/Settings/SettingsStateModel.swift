import Combine
import LoopKit
import SwiftUI

extension Settings {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() private var broadcaster: Broadcaster!
        @Injected() private var fileManager: FileManager!
        @Injected() private var nightscoutManager: NightscoutManager!
        @Injected() var storage: FileStorage!
        @Injected() var apsManager: APSManager!

        @Published var closedLoop = false
        @Published var debugOptions = false
        @Published var animatedBackground = false
        @Published var disableCGMError = true
        @Published var firstRun: Bool = true
        @Published var imported: Bool = false
        @Published var token: String = ""

        @Published var basals: [BasalProfileEntry]?
        @Published var basalsOK: Bool = false

        @Published var crs: [CarbRatioEntry]?
        @Published var crsOK: Bool = false

        @Published var isfs: [InsulinSensitivityEntry]?
        @Published var isfsOK: Bool = false

        @Published var settings: Preferences?
        @Published var settingsOK: Bool = false

        @Published var freeapsSettings: FreeAPSSettings?
        @Published var freeapsSettingsOK: Bool = false

        @Published var profiles: DatabaseProfileStore?
        @Published var profilesOK: Bool = false

        @Published var targets: BGTargetEntry?
        @Published var targetsOK: Bool = false

        private(set) var buildNumber = ""
        private(set) var versionNumber = ""
        private(set) var branch = ""
        private(set) var copyrightNotice = ""

        override func subscribe() {
            nightscoutManager.fetchVersion()

            firstRun = CoreDataStorage().fetchOnbarding()

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
            fetchProfiles(token: id)
        }

        func close() {
            firstRun = false
            token = ""
        }

        func fetchPreferences(token: String) {
            let nightscout = NightscoutAPI(url: IAPSconfig.statURL)
            // DispatchQueue.main.async {
            nightscout.fetchPreferences(token: token)
                .sink { completion in
                    switch completion {
                    case .finished:
                        debug(.nightscout, "Preferences fetched from " + IAPSconfig.statURL.absoluteString)
                        self.verifyPreferences()
                    case let .failure(error):
                        debug(.nightscout, error.localizedDescription)
                    }
                }
            receiveValue: {
                self.settings = $0
            }
            .store(in: &lifetime)
        }

        func fetchSettings(token: String) {
            let nightscout = NightscoutAPI(url: IAPSconfig.statURL)
            nightscout.fetchSettings(token: token)
                .sink { completion in
                    switch completion {
                    case .finished:
                        debug(.nightscout, "Settings fetched from " + IAPSconfig.statURL.absoluteString)
                        self.verifySettings()
                    case let .failure(error):
                        debug(.nightscout, error.localizedDescription)
                    }
                }
            receiveValue: {
                self.freeapsSettings = $0
            }
            .store(in: &lifetime)
        }

        func fetchProfiles(token: String) {
            let nightscout = NightscoutAPI(url: IAPSconfig.statURL)
            nightscout.fetchProfile(token)
                .sink { completion in
                    switch completion {
                    case .finished:
                        debug(.nightscout, "Profiles fetched from " + IAPSconfig.statURL.absoluteString)
                        self.verifyProfiles()
                    case let .failure(error):
                        debug(.nightscout, error.localizedDescription)
                    }
                }
            receiveValue: { self.profiles = $0 }
                .store(in: &lifetime)
        }

        func verifyProfiles() {
            if let fecthedProfiles = profiles {
                if let defaultProfiles = profiles?.store["default"] {
                    // Basals
                    let basals_ = defaultProfiles.basal.map({
                        basal in
                        BasalProfileEntry(
                            start: basal.time + ":00",
                            minutes: self.offset(basal.time) / 60,
                            rate: basal.value
                        )
                    })
                    let syncValues = basals_.map {
                        RepeatingScheduleValue(startTime: TimeInterval($0.minutes * 60), value: Double($0.rate))
                    }
                    guard let pump = apsManager.pumpManager else {
                        storage.save(basals_, as: OpenAPS.Settings.basalProfile)
                        debug(.service, "Imported Basals have been saved to file storage.")
                        return
                    }
                    pump.syncBasalRateSchedule(items: syncValues) { result in
                        switch result {
                        case .success:
                            self.storage.save(basals_, as: OpenAPS.Settings.basalProfile)
                            debug(.service, "Basals saved to pump!")
                            self.basalsOK = true
                        case .failure:
                            debug(.service, "Basals couldn't be save to pump")
                        }
                    }

                    // ISFs
                    let isfs_ = defaultProfiles.sens.map({
                        isf in
                        InsulinSensitivityEntry(sensitivity: isf.value, offset: (isf.timeAsSeconds ?? 0) / 60, start: isf.time)
                    })
                    storage.save(isfs_, as: OpenAPS.Settings.insulinSensitivities)
                    debug(.service, "Imported ISFs have been saved to file storage.")
                    isfsOK = true

                    // CRs
                    let crs_ = defaultProfiles.carbratio.map({
                        cr in
                        CarbRatioEntry(start: cr.time, offset: (cr.timeAsSeconds ?? 0) / 60, ratio: cr.value)
                    })
                    storage.save(crs_, as: OpenAPS.Settings.carbRatios)
                    debug(.service, "Imported CRs have been saved to file storage.")
                    crsOK = true

                    // Targets
                    let targets_ = defaultProfiles.target_low.map({
                        target in
                        BGTargetEntry(
                            low: target.value,
                            high: target.value,
                            start: target.time,
                            offset: (target.timeAsSeconds ?? 0) / 60
                        )
                    })
                    storage.save(targets_, as: OpenAPS.Settings.bgTargets)
                    debug(.service, "Imported Targets have been saved to file storage.")
                    targetsOK = true
                }
            }
        }

        func verifySettings() {
            if let fetchedSettings = freeapsSettings {
                storage.save(fetchedSettings, as: OpenAPS.FreeAPS.settings)
                debug(.service, "iAPS Settings have been saved to file storage.")
            }
        }

        func verifyPreferences() {
            if let fetchedSettings = settings {
                storage.save(fetchedSettings, as: OpenAPS.Settings.preferences)
                debug(.service, "Prefereces have been saved to file storage.")
            }
        }

        func onboardingDone() {
            CoreDataStorage().saveOnbarding()
            imported = true
        }

        func offset(_ string: String) -> Int {
            let hours = Int(string.prefix(2)) ?? 0
            let minutes = Int(string.suffix(2)) ?? 0
            return ((hours * 60) + minutes) * 60
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
