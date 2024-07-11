import Combine
import Foundation
import LoopKit
import Swinject

extension Restore {
    final class StateModel: BaseStateModel<Provider> {
        // @Injected() var keychain: Keychain!
        @Injected() var storage: FileStorage!
        @Injected() var apsManager: APSManager!

        @Published var name: String = ""
        @Published var backup: Bool = false

        let coreData = CoreDataStorage()

        func save(_ name: String) {
            coreData.saveProfileSettingName(name: name)
        }

        func saveFile(_ file: JSON, filename: String) {
            let s = BaseFileStorage()
            s.save(file, as: filename)
        }

        func apsM(resolver: Resolver) -> APSManager! {
            let a = BaseAPSManager(resolver: resolver)
            return a
        }

        override func subscribe() {
            backup = settingsManager.settings.uploadStats
        }

        func activeProfile(_ selectedProfile: String) {
            coreData.activeProfile(name: selectedProfile)
        }

        func fetchSettingProfileNames() -> [Profiles]? {
            coreData.fetchSettingProfileNames()
        }
    }
}
