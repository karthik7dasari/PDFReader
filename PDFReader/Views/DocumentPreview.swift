//
//  DocumentPreview.swift
//  PDFReader
//
//  Created by Karthik Dasari on 12/7/25.
//

import SwiftUI
import Combine
import Foundation
import PDFKit
import QuickLook

// MARK: - Document Preview Wrapper
struct DocumentPreview: View {
    let url: URL
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            QuickLookPreview(url: url)
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onCancel() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone() }
                    }
                }
        }
    }
}

// A minimal Quick Look wrapper for SwiftUI
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.reloadData()
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let originalURL: URL
        private var resolvedURL: URL
        private var didStartAccess = false

        init(url: URL) {
            self.originalURL = url
            // Default resolvedURL to original; may be replaced if not accessible
            self.resolvedURL = url
            super.init()

            // Start security-scoped access if available
            self.didStartAccess = url.startAccessingSecurityScopedResource()

            // Ensure the file is locally readable; if not, copy to a temp location
            self.resolvedURL = Coordinator.ensureLocalURL(from: url)
        }

        deinit {
            if didStartAccess {
                originalURL.stopAccessingSecurityScopedResource()
            }
        }

        // Provide 1 item
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        // Return a QLPreviewItem pointing to the resolved local URL
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return resolvedURL as NSURL
        }

        // Helper: ensure we have a readable local URL. If the file doesn't exist or isn't reachable,
        // copy it into a temporary location and return that URL.
        private static func ensureLocalURL(from url: URL) -> URL {
            let fm = FileManager.default

            // If the file exists at path and is reachable, use it directly
            if fm.fileExists(atPath: url.path) {
                return url
            }

            // Attempt to download if it's an ubiquitous (iCloud) item
            var isUbiquitous: ObjCBool = false
            if fm.isUbiquitousItem(at: url) {
                do {
                    try fm.startDownloadingUbiquitousItem(at: url)
                } catch {
                    // Ignore; we'll fall back to copying
                }
            }

            // Fallback: copy into a temporary location
            let tempDir = fm.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)

            // Remove any existing file at tempURL
            try? fm.removeItem(at: tempURL)

            do {
                // Attempt to copy; if this fails, return the original URL anyway
                try fm.copyItem(at: url, to: tempURL)
                return tempURL
            } catch {
                return url
            }
        }
    }
}
