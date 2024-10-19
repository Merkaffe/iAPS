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

                    Section {
                        if let settings = configurations.first(where: { $0.active }), let oref0 = settings.settings_oref0 {
                            Text("Max IOB: \(oref0.maxIOB ?? 0)")
                        }

                        if let settings = configurations.first(where: { $0.active }), let iAPS = settings.settings_iAPS {
                            Text("Max Carbs: \(iAPS.maxCarbs ?? 0)")
                        }

                    } header: { Text("Settings") }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .onAppear { configureView() }
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
    }
}
