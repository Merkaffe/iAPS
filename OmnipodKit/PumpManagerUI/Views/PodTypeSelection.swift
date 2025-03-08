//
//  PodTypeSelection.swift
//  OmnipodKit
//
//  Created by Joe Moran on 1/18/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

struct PodTypeSelection: View {

    @Environment(\.appName) private var appName

    @State private var podType: PodType?
    private var supportedPodTypes: [PodType]
    private var didConfirm: (PodType) -> Void
    private var didCancel: () -> Void

    init(initialValue: PodType, supportedPodTypes: [PodType], didConfirm: @escaping (PodType) -> Void, didCancel: @escaping () -> Void) {
        self.podType = initialValue
        self.supportedPodTypes = supportedPodTypes
        self.didConfirm = didConfirm
        self.didCancel = didCancel
    }

    func continueWithType(_ podType: PodType?) {
        if let podType = podType, podType != unknownOmnipodType {
            didConfirm(podType)
        } else {
            assertionFailure()
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            List {
                Section {
                    Text(String(format: LocalizedString("Select the particular Omnipod pod type to use with %1$@. Be sure to select the correct pod type or %2$@ will not be able to communicate with it.", comment: "Help text for Omnipod pod type selection (1: appName) (2: appName)"), self.appName, self.appName))
                }
                Section {
                    PodTypeChooser(podType: $podType, supportedPodTypes: supportedPodTypes)
                }
                .buttonStyle(PlainButtonStyle()) // Disable row highlighting on selection
            }
            .insetGroupedListStyle()

            Button(action: { self.continueWithType(podType) }) {
                Text(LocalizedString("Confirm Pod Type", comment: "Text for Confirm Pod Type button on PodTypeSelection"))
                    .actionButtonStyle(.primary)
                    .padding()
            }
            .disabled(podType == unknownOmnipodType)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(LocalizedString("Cancel", comment: "Cancel button title"), action: {
                    didCancel()
                })
            }
        }
    }
}

struct PodTypeSelction_Previews: PreviewProvider {
    static var previews: some View {
        PodTypeSelection(initialValue: dashType, supportedPodTypes: [erosType, dashType, omnipod5Type], didConfirm: { (newType) in }, didCancel: { })
    }
}

struct PodTypeChooser: View {

    @Binding private var podType: PodType?

    let supportedPodTypes: [PodType]

    init(podType: Binding<PodType?>, supportedPodTypes: [PodType]) {
        self.supportedPodTypes = supportedPodTypes
        self._podType = podType
    }

    var body: some View {
        ForEach(supportedPodTypes, id: \.rawValue) { podType in
            HStack {
                CheckmarkListItem(
                    title: Text(podType.localizedDescription),
                    description: Text(podType.description),
                    isSelected: Binding(
                                get: { self.podType == podType },
                                set: { isSelected in
                                    if isSelected {
                                        self.podType = podType
                                    }
                                }
                    )
                )
            }
        }
    }
}
