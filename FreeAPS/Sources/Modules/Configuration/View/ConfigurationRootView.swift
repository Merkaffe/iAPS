import Combine
import CoreData
import SwiftUI
import Swinject

extension Configuration {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @Environment(\.managedObjectContext) var moc
        @Environment(\.colorScheme) var colorScheme

        // SwiftData uses @Query instead...
        @FetchRequest(
            entity: Configurations.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
            predicate: NSPredicate(
                format: "name != %@", "Empty" as String
            )
        ) var configurations: FetchedResults<Configurations>

        // Replace with something less taxing
        private var active: String? {
            configurations.first(where: { $0.active })?.name
        }

        @State var selectedProfile = ""
        @State var name = ""

        var body: some View {
            Form {
                // Diplay current configuration as header
                Section {
                    Text(active ?? "Default")
                } header: { Text("Active configuration") }

                // Save new configuration
                Section {
                    TextField("Name", text: $name)
                    Button("Save") {
                        save()
                    }
                    .disabled(name.isEmpty)

                } header: { Text("Save as new profile") }

                // Load saved configuration
                if !configurations.isEmpty {
                    Section {
                        Section {
                            ForEach(configurations) { profile in
                                profilesView(for: profile)
                                    .deleteDisabled(profile.name == "default")
                            }
                            .onDelete(perform: removeConfigurations)
                        }
                    } header: { Text("Load Profile") }

                    // List all settings
                    Section {
                        ForEach(listed(), id: \.id) { item in
                            Text(item.variable).font(.caption)
                        }

                    } header: { Text("Settings") }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .onAppear {
                configureView()
            }
            .navigationTitle("Configurations")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                state.save()
            }
        }

        // List of saved configurations
        @ViewBuilder private func profilesView(for configuration: Configurations) -> some View {
            Text(configuration.name ?? "").foregroundStyle(.blue)
                .onTapGesture {
                    selectedProfile = configuration.name ?? ""
                    select(configuration: configuration)
                }
        }

        private func removeConfigurations(at offsets: IndexSet) {
            for index in offsets {
                let configuration = configurations[index]
                moc.delete(configuration)
                do { try moc.save() } catch { /* To do: add error */ }
            }
        }

        private func save() {
            let newConfiguration = Configurations(context: moc)
            newConfiguration.name = name
            newConfiguration.date = Date.now
            newConfiguration.active = true
            try? moc.save()
            name = ""
        }

        private func select(configuration: Configurations) {
            configuration.active = true
            configuration.date = Date.now
            try? moc.save()
        }

        private func listed() -> [ListSettings] {
            var string = [""]
            let request: NSFetchRequest<Configurations>
            request = Configurations.fetchRequest()
            do {
                let entities = try moc.fetch(request)
                for item in entities {
                    for key in item.entity.propertiesByName.keys {
                        let value: Any? = item.value(forKey: key)

                        if let variable = value {
                            string.append("\(key) = \(variable)")
                        }
                    }
                }
            } catch {}
            let formatted = string.description.components(separatedBy: ";").filter({ !$0.contains(":") })
            let mapped = formatted.map { item in
                let count = item.count
                let trimmed = String(item.suffix(count - 5))
                        .replacingOccurrences(of: "\\", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: "]", with: "")
                return ListSettings(
                    variable: trimmed
                )
            }
            return mapped
        }
    }
}

struct ListSettings {
    var variable: String
    var id = UUID()
}
