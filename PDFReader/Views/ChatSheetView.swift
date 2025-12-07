//
//  ChatSheetView.swift
//  PDFReader
//
//  Created by Karthik Dasari on 12/7/25.
//

import SwiftUI
import Combine
import Foundation


// MARK: - Chat Sheet View (Modal)
struct ChatSheetView: View {
    @ObservedObject var viewModel: PDFReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isQuestionFocused: Bool
    @State private var streamingMessageId = UUID()
    @State private var scrollTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 12) {
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "message.circle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text("Start a conversation")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Tap the microphone or type a message")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            }
                            
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                                                
                            // Show streaming response
                            if !viewModel.currentStreamingText.isEmpty {
                                ChatBubble(message: ChatMessage(content: viewModel.currentStreamingText, isUser: false))
                                    .id(streamingMessageId)
                            }
                            
                            // Show transcribed text while listening
                            if viewModel.isListening && !viewModel.transcribedText.isEmpty {
                                ChatBubble(message: ChatMessage(content: viewModel.transcribedText, isUser: true))
                                    .opacity(0.7)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { oldCount, newCount in
                        // Only scroll if a new message was added (not removed)
                        if newCount > oldCount, let lastMessage = viewModel.messages.last {
                            // Small delay to ensure view is rendered, then smooth scroll
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                                withAnimation(.easeOut(duration: 0.25)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onChange(of: viewModel.currentStreamingText) { oldValue, newValue in
                        // Cancel previous scroll task to debounce rapid updates
                        scrollTask?.cancel()
                        
                        // When streaming completes (text becomes empty), scroll to last message
                        if oldValue.isEmpty == false && newValue.isEmpty {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                if let lastMessage = viewModel.messages.last {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                            return
                        }
                        
                        // Only scroll if text actually changed and is not empty
                        guard !newValue.isEmpty, newValue != oldValue else { return }
                        
                        // Debounce rapid streaming updates - scroll after a short delay
                        // This prevents janky scrolling during fast token streaming
                        scrollTask = Task { @MainActor in
                            // Wait a bit to batch rapid updates
                            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
                            
                            guard !Task.isCancelled else { return }
                            
                            // Smooth scroll to streaming message
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(streamingMessageId, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        // Reset streaming message ID when view appears
                        streamingMessageId = UUID()
                    }
                    .onDisappear {
                        // Cancel any pending scroll tasks
                        scrollTask?.cancel()
                    }
                }
                
                // Input area
                VStack(spacing: 8) {
                    // Transcribed text display
                    if viewModel.isListening {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.red)
                            Text("Listening...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    if !viewModel.transcribedText.isEmpty && viewModel.isListening {
                        Text(viewModel.transcribedText)
                            .font(.body)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        // Voice input button
                        Button(action: {
                            Task {
                                if viewModel.isListening {
                                    await viewModel.stopListening()
                                } else {
                                    await viewModel.startListening()
                                }
                            }
                        }) {
                            Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                                .font(.title2)
                                .foregroundColor(viewModel.isListening ? .red : .blue)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(viewModel.isListening ? Color.red.opacity(0.1) : Color.blue.opacity(0.1)))
                        }
                        .disabled(viewModel.isProcessing)
                        
                        // Text input with capsule shape
                        TextField("Type a message...", text: $viewModel.userQuestion, axis: .vertical)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .lineLimit(1...5)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            )
                            .focused($isQuestionFocused)
                            .disabled(viewModel.isProcessing || viewModel.isListening)
                            .onSubmit {
                                if !viewModel.userQuestion.isEmpty {
                                    Task {
                                        await viewModel.askQuestion(viewModel.userQuestion)
                                        viewModel.userQuestion = ""
                                    }
                                }
                            }
                        
                        // Send button
                        Button(action: {
                            Task {
                                await viewModel.askQuestion(viewModel.userQuestion)
                                viewModel.userQuestion = ""
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(viewModel.userQuestion.isEmpty ? .gray : .blue)
                        }
                        .disabled(viewModel.userQuestion.isEmpty || viewModel.isProcessing || viewModel.isListening)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                }
                .background(Color(.systemGray6))
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.messages.removeAll()
                        viewModel.userQuestion = ""
                        viewModel.chatResponse = ""
                    }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}
