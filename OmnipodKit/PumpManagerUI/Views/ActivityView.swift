//
//  ActivityView.swift
//  OmnipodKit
//
//  From OmniBLE/PumpManageUI/Views/ActivityView.swift
//  Created by Joe Moran on 9/17/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI


struct ActivityView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let activityItems: [Any]

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { (_, _, _, _) in
            self.isPresented = false
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {
    }
}

fileprivate struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

// Initialize a suitiably named temp file with the given text.
// Returns the temp file URL or an IO error string on failure.
func initializeTempFile(baseName: String, text: String) -> Any {
    let dateString = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withSpaceBetweenDateAndTime, .withInternetDateTime])
    let tempFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(baseName) \(dateString).txt")

    // Catch any IO errors and return an error string to prevent possible hangs when sharing
    do {
        if FileManager.default.fileExists(atPath: tempFileUrl.path) {
            try FileManager.default.removeItem(at: tempFileUrl)
        }
        try text.write(to: tempFileUrl, atomically: true, encoding: .utf8)
    } catch let error {
        return String(format: "Initialization of %@ failed: %@", tempFileUrl.lastPathComponent, String(describing: error))
    }
    return tempFileUrl
}
