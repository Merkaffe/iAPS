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

        @FetchRequest(
            entity: VNr.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)], predicate: NSPredicate(
                format: "nr != %@", "" as String
            )
        ) var fetchedVersionNumber: FetchedResults<VNr>

        var body: some View {
            if state.noLoop == .distantPast, !state.imported {
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
                                Text("NS Upload Profile and Settings")
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
                        Text("Do you have any settings to import?")
                    }
                } else if !imported {
                    Section {
                        TextField("Token", text: $state.token)

                    } header: {
                        Text("Enter your secret token")
                    }

                    Button {
                        state.importSettings(id: state.token)
                        imported.toggle()
                    }
                    label: {
                        Text("Start import")
                    }.disabled(state.token == "")
                } else if !confirm {
                    Section {} header: {
                        Text("\nScroll down to Verify all of your Imported Settings Before Saving").bold()
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if let basals = state.basals {
                        Section {
                            List(basals, id: \.start) {
                                Text($0.start + " " + $0.rate.formatted() + " " + $0.minutes.formatted())
                            }
                        } header: {
                            Text("Basals")
                        }
                    }

                    if let crs = state.crs {
                        Section {
                            List(crs, id: \.start) {
                                Text($0.start + " " + $0.ratio.formatted())
                            }
                        } header: {
                            Text("Carb Ratios")
                        }
                    }

                    if let isfs = state.isfs {
                        Section {
                            List(isfs, id: \.start) {
                                Text($0.start + " " + $0.sensitivity.formatted())
                            }
                        } header: {
                            Text("Insulin Sensitivities")
                        }
                    }

                    if let settings = state.settings {
                        Section {
                            Text(
                                settings.rawJSON.debugDescription
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
                            )
                        } header: {
                            Text("OpenAPS Settings")
                        }
                    }

                    if let freeapsSettings = state.freeapsSettings {
                        Section {
                            Text(
                                freeapsSettings.rawJSON.debugDescription
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
                            )
                        } header: {
                            Text("iAPS Settings")
                        }
                    }

                    Button {
                        confirm.toggle()
                    }
                    label: {
                        Text("Save settings").bold()
                    }.frame(maxWidth: .infinity, alignment: .center)

                } else if !saved {
                    Section {
                        Button {
                            saved.toggle()
                            state.close()
                        }
                        label: {
                            Text("OK")
                        }.frame(maxWidth: .infinity, alignment: .center)
                    } header: {
                        Text("Settings imported")
                    }
                }
            }
            .navigationTitle("Onboarding\n\n")
            .navigationBarItems(trailing: Button("Close", action: state.close))
        }
    }
}
