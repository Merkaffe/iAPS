import HealthKit
import SwiftUI
import Swinject

extension Settings {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var showShareSheet = false
        // @State private var imported = false
        @State private var token = false
        @State private var confirm = false
        @State private var imported = false
        @State private var saved = false

        @State private var b: [BasalProfileEntry]?

        @FetchRequest(
            entity: VNr.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)], predicate: NSPredicate(
                format: "nr != %@", "" as String
            )
        ) var fetchedVersionNumber: FetchedResults<VNr>

        var body: some View {
            // First run (onboarding)
            if state.firstRun {
                onboarding
            } else {
                settingsView
            }
        }

        var settingsView: some View {
            Form {
                Section {
                    Toggle("Closed loop", isOn: $state.closedLoop)
                }
                header: {
                    VStack(alignment: .leading) {
                        if let expirationDate = Bundle.main.profileExpiration {
                            Text(
                                "iAPS v\(state.versionNumber) (\(state.buildNumber))\nBranch: \(state.branch) \(state.copyrightNotice)" +
                                    "\nBuild Expires: " + expirationDate
                            ).textCase(nil)
                        } else {
                            Text(
                                "iAPS v\(state.versionNumber) (\(state.buildNumber))\nBranch: \(state.branch) \(state.copyrightNotice)"
                            )
                        }

                        if let latest = fetchedVersionNumber.first,
                           ((latest.nr ?? "") > state.versionNumber) ||
                           ((latest.nr ?? "") < state.versionNumber && (latest.dev ?? "") > state.versionNumber)
                        {
                            Text(
                                "Latest version on GitHub: " +
                                    ((latest.nr ?? "") < state.versionNumber ? (latest.dev ?? "") : (latest.nr ?? "")) + "\n"
                            )
                            .foregroundStyle(.orange).bold()
                            .multilineTextAlignment(.leading)
                        }
                    }
                }

                Section {
                    Text("Pump").navigationLink(to: .pumpConfig, from: self)
                    Text("CGM").navigationLink(to: .cgm, from: self)
                    Text("Watch").navigationLink(to: .watch, from: self)
                } header: { Text("Devices") }

                Section {
                    Text("Nightscout").navigationLink(to: .nighscoutConfig, from: self)
                    if HKHealthStore.isHealthDataAvailable() {
                        Text("Apple Health").navigationLink(to: .healthkit, from: self)
                    }
                    Text("Notifications").navigationLink(to: .notificationsConfig, from: self)
                } header: { Text("Services") }

                Section {
                    Text("Pump Settings").navigationLink(to: .pumpSettingsEditor, from: self)
                    Text("Basal Profile").navigationLink(to: .basalProfileEditor, from: self)
                    Text("Insulin Sensitivities").navigationLink(to: .isfEditor, from: self)
                    Text("Carb Ratios").navigationLink(to: .crEditor, from: self)
                    Text("Target Glucose").navigationLink(to: .targetsEditor, from: self)
                } header: { Text("Configuration") }

                Section {
                    Text("OpenAPS").navigationLink(to: .preferencesEditor, from: self)
                    Text("Autotune").navigationLink(to: .autotuneConfig, from: self)
                } header: { Text("OpenAPS") }

                Section {
                    Text("UI/UX").navigationLink(to: .statisticsConfig, from: self)
                    Text("App Icons").navigationLink(to: .iconConfig, from: self)
                    Text("Bolus Calculator").navigationLink(to: .bolusCalculatorConfig, from: self)
                    Text("Fat And Protein Conversion").navigationLink(to: .fpuConfig, from: self)
                    Text("Dynamic ISF").navigationLink(to: .dynamicISF, from: self)
                    Text("Sharing").navigationLink(to: .sharing, from: self)
                    Text("Contact Image").navigationLink(to: .contactTrick, from: self)
                } header: { Text("Extra Features") }

                Section {
                    Toggle("Debug options", isOn: $state.debugOptions)
                    if state.debugOptions {
                        Group {
                            HStack {
                                Text("Upload Profile and Settings")
                                Button("Upload") { state.uploadProfileAndSettings(true) }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .buttonStyle(.borderedProminent)
                            }
                            /*
                             HStack {
                                 Text("Delete All NS Overrides")
                                 Button("Delete") { state.deleteOverrides() }
                                     .frame(maxWidth: .infinity, alignment: .trailing)
                                     .buttonStyle(.borderedProminent)
                                     .tint(.red)
                             }*/

                            HStack {
                                Toggle("Ignore flat CGM readings", isOn: $state.disableCGMError)
                            }

                            HStack {
                                Text("Start Onboarding")
                                Button("Start") { state.firstRun = true }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                        Group {
                            Text("Preferences")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.preferences), from: self)
                            Text("Pump Settings")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.settings), from: self)
                            Text("Autosense")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.autosense), from: self)
                            Text("Pump History")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.pumpHistory), from: self)
                            Text("Basal profile")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.basalProfile), from: self)
                            Text("Targets ranges")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.bgTargets), from: self)
                            Text("Temp targets")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.tempTargets), from: self)
                            Text("Meal")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.meal), from: self)
                        }

                        Group {
                            Text("Pump profile")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.pumpProfile), from: self)
                            Text("Profile")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.profile), from: self)
                            Text("Carbs")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.carbHistory), from: self)
                            Text("Enacted")
                                .navigationLink(to: .configEditor(file: OpenAPS.Enact.enacted), from: self)
                            Text("Announcements")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.announcements), from: self)
                            Text("Enacted announcements")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.announcementsEnacted), from: self)
                            Text("Overrides Not Uploaded")
                                .navigationLink(to: .configEditor(file: OpenAPS.Nightscout.notUploadedOverrides), from: self)
                            Text("Autotune")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.autotune), from: self)
                            Text("Glucose")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.glucose), from: self)
                        }

                        Group {
                            Text("Target presets")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.tempTargetsPresets), from: self)
                            Text("Calibrations")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.calibrations), from: self)
                            Text("Middleware")
                                .navigationLink(to: .configEditor(file: OpenAPS.Middleware.determineBasal), from: self)
                            Text("Statistics")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.statistics), from: self)
                            Text("Edit settings json")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.settings), from: self)
                        }
                    }
                } header: { Text("Developer") }

                Section {
                    Toggle("Animated Background", isOn: $state.animatedBackground)
                }

                Section {
                    Text("Share logs")
                        .onTapGesture {
                            showShareSheet = true
                        }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: state.logItems())
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .onAppear(perform: configureView)
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Close", action: state.hideSettingsModal))
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear(perform: { state.uploadProfileAndSettings(false) })
        }

        var onboarding: some View {
            Form {
                if !token {
                    Section {
                        HStack {
                            Button { token.toggle() }
                            label: {
                                Text("Yes")
                            }.buttonStyle(.borderless)
                            Spacer()
                            Button { state.close() }
                            label: {
                                Text("No")
                            }
                            .buttonStyle(.borderless)
                            .tint(.red)
                        }
                    } header: {
                        Text("Welcome to iAPS, v\(state.versionNumber)!\nDo you have any settings you want to import?")
                            .foregroundStyle(.primary)
                            .textCase(nil)
                    }
                } else if !imported {
                    Section {
                        TextField("Token", text: $state.token)
                    } header: { Text("Enter your unique identifier").foregroundStyle(.primary).textCase(nil) }

                    Button {
                        state.importSettings(id: state.token)
                        imported.toggle()
                    }
                    label: {
                        Text("Start import").frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(state.token == "")
                    .listRowBackground(!(state.token == "") ? Color(.systemBlue) : Color(.systemGray4))
                    .tint(.white)
                } else if !confirm {
                    Section {} header: {
                        Text(
                            "\nSettings fetched. Now please scroll down and check that all of your imported settings below are correct."
                        )
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .textCase(nil)
                        .font(.previewNormal)
                    }

                    if let profiles = state.profiles {
                        if let defaultProfiles = profiles.store["default"] {
                            // Basals
                            let basals_ = defaultProfiles.basal.map({
                                basal in
                                BasalProfileEntry(
                                    start: basal.time + ":00",
                                    minutes: state.offset(basal.time) / 60,
                                    rate: basal.value
                                )
                            })

                            Section {
                                ForEach(basals_, id: \.start) { item in
                                    HStack {
                                        Text(item.start)
                                        Spacer()
                                        Text(item.rate.formatted())
                                        Text("U/h")
                                    }
                                }
                            } header: {
                                Text("Basals").foregroundStyle(.blue).textCase(nil)
                            }

                            Section {
                                let crs_ = defaultProfiles.carbratio.map({
                                    cr in
                                    CarbRatioEntry(start: cr.time, offset: (cr.timeAsSeconds ?? 0) / 60, ratio: cr.value)
                                })
                                ForEach(crs_, id: \.start) { item in
                                    HStack {
                                        Text(item.start)
                                        Spacer()
                                        Text(item.ratio.formatted())
                                    }
                                }
                            } header: { Text("Carb Ratios").foregroundStyle(.blue).textCase(nil) }

                            Section {
                                let isfs_ = defaultProfiles.sens.map({
                                    isf in
                                    InsulinSensitivityEntry(
                                        sensitivity: isf.value,
                                        offset: (isf.timeAsSeconds ?? 0) / 60,
                                        start: isf.time
                                    )
                                })

                                ForEach(isfs_, id: \.start) { item in
                                    HStack {
                                        Text(item.start)
                                        Spacer()
                                        Text(item.sensitivity.formatted())
                                    }
                                }
                            } header: {
                                Text("Insulin Sensitivities").foregroundStyle(.blue).textCase(nil)
                            }

                            // Targets
                            Section {
                                let targets_ = defaultProfiles.target_low.map({
                                    target in
                                    BGTargetEntry(
                                        low: target.value,
                                        high: target.value,
                                        start: target.time,
                                        offset: (target.timeAsSeconds ?? 0) / 60
                                    )
                                })

                                ForEach(targets_, id: \.start) { item in
                                    HStack {
                                        Text(item.start)
                                        Spacer()
                                        Text(item.low.formatted())
                                    }
                                }
                            } header: { Text("Targets").foregroundStyle(.blue).textCase(nil) }
                        }
                    }

                    if let freeapsSettings = state.freeapsSettings {
                        Section {
                            Text(
                                trim(freeapsSettings.rawJSON.debugDescription)
                            )
                        } header: {
                            Text("iAPS Settings").foregroundStyle(.blue).textCase(nil)
                        }
                    }

                    if let settings = state.settings {
                        Section {
                            Text(
                                trim(settings.rawJSON.debugDescription)
                            )
                        } header: {
                            Text("OpenAPS Settings").foregroundStyle(.blue).textCase(nil)
                        }
                    }

                    Button {
                        confirm.toggle()
                        state.onboardingDone()
                    }
                    label: {
                        Text("Save settings")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color(.systemBlue))
                    .tint(.white)
                } else if !saved {
                    Section {
                        Button {
                            saved.toggle()
                            state.close()
                        }
                        label: {
                            Text("OK")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color(.systemBlue))
                        .tint(.white)
                    } header: {
                        Text("Settings saved").foregroundStyle(.primary).textCase(nil)
                            .frame(maxWidth: .infinity, alignment: .center) }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Onboarding\n\n")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                state.close()
                token = false
            })
        }

        private func trim(_ string: String) -> String {
            let trim = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\n", with: "")
                .replacingOccurrences(of: "\\", with: "")
                .replacingOccurrences(of: "}", with: "")
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(
                    of: "\"",
                    with: "",
                    options: NSString.CompareOptions.literal,
                    range: nil
                )
                .replacingOccurrences(of: ",", with: "\n")
                .replacingOccurrences(of: "[", with: "\n")
                .replacingOccurrences(of: "]", with: "\n")
                .replacingOccurrences(of: "basal", with: "Basal Rates")
                .replacingOccurrences(of: "sens", with: "Sensitivities")
                .replacingOccurrences(of: "dia", with: "DIA")
                .replacingOccurrences(of: "carbratio", with: "Carb ratios")

            return trim
        }
    }
}
