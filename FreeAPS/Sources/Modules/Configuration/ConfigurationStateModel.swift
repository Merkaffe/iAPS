import Foundation
import Swinject

extension Configuration {
    final class StateModel: BaseStateModel<Provider> {
        let coredataContext = CoreDataStack.shared.persistentContainer.viewContext

        func save() {
            coredataContext.perform {
                if self.coredataContext.hasChanges {
                    try? self.coredataContext.save()
                }
            }
        }
    }
}
