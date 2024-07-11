import Combine
import CoreData
import SwiftUI
import Swinject

extension ProfilePicker {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @Environment(\.managedObjectContext) var moc
        @Environment(\.colorScheme) var colorScheme

        @FetchRequest(
            entity: Profiles.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
            predicate: NSPredicate(
                format: "name != %@", "" as String
            )
        ) var profiles: FetchedResults<Profiles>

        @FetchRequest(
            entity: ActiveProfile.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
            predicate: NSPredicate(
                format: "active == true"
            )
        ) var currentProfile: FetchedResults<ActiveProfile>

        @State var onboardingView = false
        @State var selectedProfile = ""
        @State var int = 2
        @State var inSitu = true
        @State var id = ""

        @State var lifetime = Lifetime()

        var body: some View {
            Form {
                let uploaded = profiles.filter({ $0.uploaded == true })
                Section {
                    HStack {
                        Text("Current profile:").foregroundStyle(.secondary)
                        Spacer()
                        if let p = currentProfile.first {
                            Text(p.name ?? "default")

                            if profiles.first(where: { $0.name == (p.name ?? "default") && $0.uploaded }) != nil {
                                Image(systemName: "cloud")
                            }

                        } else { Text("default") }
                    }
                } header: {
                    Text("Active settings")
                }

                Section {
                    TextField("Name", text: $state.name)

                    Button("Save") {
                        state.save(state.name)
                        state.activeProfile(state.name)
                    }.disabled(state.name.isEmpty)

                } header: {
                    Text("Save as new profile")
                }

                Section {
                    Section {
                        if profiles.isEmpty { Text("No profiles saved")
                        } else if profiles.first == uploaded.last, profiles.count == 1 {
                            Text("No other profiles saved")
                        } else {
                            ForEach(uploaded) { profile in
                                profilesView(for: profile)
                            }.onDelete(perform: removeProfile)
                        }
                    }
                } header: {
                    HStack {
                        Text("Load Profile from")
                        Image(systemName: "cloud").textCase(nil).foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }

                Section {}
                footer: {
                    VStack {
                        Text(
                            "Your active profile is updated and uploaded automatically whenever settings are changed and on a daily basis, provided backup is enabled in Sharing settings."
                        )
                        if !state.backup {
                            Text("\n\nBackup disabled in Sharing settings").foregroundStyle(.orange)
                        }
                    }
                }.textCase(nil)
                    .font(.previewNormal)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .onAppear { configureView() }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $onboardingView) {
                Restore.RootView(
                    resolver: resolver,
                    int: $int,
                    profile: $selectedProfile,
                    inSitu: $inSitu,
                    id_: $id,
                    uniqueID: id
                )
            }
        }

        @ViewBuilder private func profilesView(for preset: Profiles) -> some View {
            if (preset.name ?? "") == (currentProfile.first?.name ?? "BlaBlaXX") {
                Text(preset.name ?? "").foregroundStyle(.secondary)
            } else {
                Text(preset.name ?? "")
                    .foregroundStyle(.blue)
                    .padding(.trailing, 40)
                    .onTapGesture {
                        selectedProfile = preset.name ?? ""
                        id = state.getIdentifier()
                        onboardingView.toggle()
                    }
            }
        }

        private func removeProfile(at offsets: IndexSet) {
            let database = Database(token: state.getIdentifier())
            for index in offsets {
                let profile = profiles[index]
                database.deleteProfile(profile.name ?? "")
                    .sink { completion in
                        switch completion {
                        case .finished:
                            debug(.service, "Profiles \(profile.name ?? "") deleted from database")
                            self.moc.delete(profile)
                            do { try moc.save() } catch { /* To do: add error */ }
                        case let .failure(error):
                            debug(.service, "Failed deleting \(profile.name ?? "") from database. " + error.localizedDescription)
                        }
                    }
                receiveValue: {}
                    .store(in: &lifetime)
            }
        }
    }
}
