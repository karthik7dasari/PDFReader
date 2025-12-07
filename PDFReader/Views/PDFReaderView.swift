//
//  PDFReaderView.swift
//  PDFReader
//
//  Created by Karthik Dasari on 11/27/25.
//

import SwiftUI
import Combine
import Foundation
import UniformTypeIdentifiers
import PDFKit
import Vision
import QuickLook

// MARK: - SwiftUI view
struct PDFReaderView: View {
    @StateObject private var vm = PDFReaderViewModel()
    @State private var showPicker = false
    @State private var pendingDocumentURL: URL? = nil
    @State private var showPreview: Bool = false
    @State private var showChatSheet: Bool = false
    @State private var isDocumentIndexed: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background document preview (if document is selected)
                if let url = pendingDocumentURL, isDocumentIndexed {
                    QuickLookPreview(url: url)
                }
                
                // Main content overlay
                VStack {
                    if !isDocumentIndexed {
                        // Centered "Select Document" button
                        VStack(spacing: 20) {
                            Button(action: { showPicker = true }) {
                                VStack(spacing: 16) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 80))
                                        .foregroundColor(.blue)
                                        .symbolEffect(.bounce, value: showPicker)
                                    
                                    Text("Select Document")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text("Choose a PDF or text file to get started")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(40)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.systemGray6))
                                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.9))
                    } else {
                        // Document is indexed - show Agent button in bottom right
                        VStack {
                            Spacer()
                            
                            HStack {
                                Spacer()
                                
                                // Agent button in bottom right
                                Button(action: { showChatSheet = true }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "sparkles")
                                            .font(.title3)
                                        Text("Agent")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 25)
                                            .fill(Color.blue)
                                            .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .navigationTitle("PDF Reader")
            .toolbar {
                if isDocumentIndexed {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            // Reset document
                            pendingDocumentURL = nil
                            isDocumentIndexed = false
                            vm.messages.removeAll()
                            vm.selectedFileName = nil
                            vm.content = ""
                            vm.chunks = []
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in
                    pendingDocumentURL = url
                    showPicker = false
                    showPreview = true
                }
            }
            .sheet(isPresented: $showPreview) {
                if let url = pendingDocumentURL {
                    DocumentPreview(url: url) {
                        // User tapped Done in preview; now index the document.
                        Task {
                            await vm.indexDocument(url: url)
                            isDocumentIndexed = true
                            pendingDocumentURL = url // Keep URL for background preview
                        }
                        showPreview = false
                    } onCancel: {
                        showPreview = false
                        pendingDocumentURL = nil
                    }
                } else {
                    Button("Close") {
                        showPreview = false
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showChatSheet) {
                ChatSheetView(viewModel: vm)
            }
        }
    }
}




// MARK: - Preview
#Preview {
    PDFReaderView()
}
