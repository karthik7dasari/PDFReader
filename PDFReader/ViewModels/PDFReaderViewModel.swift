//
//  PDFReaderViewModel.swift
//  PDFReader
//
//  Created by Karthik Dasari on 12/7/25.
//

import SwiftUI
import Combine
import Foundation
import PDFKit

@MainActor
final class PDFReaderViewModel: ObservableObject {
    @Published var selectedFileName: String? = nil
    @Published var userQuestion: String = ""
    @Published var chatResponse: String = ""
    @Published var isProcessing: Bool = false
    @Published var chunks: [Chunk] = []
    @Published var content = ""
    @Published var currentStreamingText: String = ""
    @Published var messages: [ChatMessage] = []
    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    
    // Speech tracking for incremental TTS
    private var hasStartedSpeaking = false
    private var lastSpokenLength = 0
    
    // How many top chunks to include per question
    private let topK: Int = 5
    // Hard cap on total context characters to avoid exceeding model limits
    private let maxContextChars: Int = 12_000
    
    private var agent: LLMAgent?
    private let speechRecognizer = SpeechRecognizer()
    private let textToSpeech = TextToSpeechManager()

    init() {
        self.agent = LLMAgent()
    }
    
    
    // MARK: - Indexing document (create embeddings for chunks)
    func indexDocument(url: URL) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            self.content = try await readDocument(url: url)
            selectedFileName = url.lastPathComponent
            
            print("📄 Document indexed: \(selectedFileName ?? "unknown")")
            print("📄 Content length: \(content.count) characters")
            print("📄 Content preview: \(content.prefix(200))")
            
            guard !content.isEmpty else {
                print("⚠️ Warning: Document content is empty!")
                self.chatResponse = "Warning: The document appears to be empty or could not be read. Please try a different document."
                return
            }
            
            let rawChunks = chunkText(content)
            print("📄 Created \(rawChunks.count) chunks")
            
            // Persist raw chunks for reuse across multiple questions
            self.chunks = rawChunks.map { Chunk(id: UUID(), text: $0, embedding: []) }
            
            if chunks.isEmpty {
                print("⚠️ Warning: No chunks created from document!")
            }
        } catch {
            print("❌ Indexing error: \(error)")
            self.chatResponse = "Indexing error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Document reading (txt + pdf)
    func readDocument(url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else {
                print("❌ Failed to create PDFDocument from URL: \(url)")
                throw NSError(domain: "PDFError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF document"])
            }
            
            print("📄 PDF opened: \(pdf.pageCount) pages")
            var content = ""
            var pagesWithText = 0
            
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i) {
                    if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        content += pageText + "\n"
                        pagesWithText += 1
                    } else {
                        print("⚠️ Page \(i + 1) has no extractable text (might be image-based)")
                    }
                }
            }
            
            print("📄 Extracted text from \(pagesWithText) out of \(pdf.pageCount) pages")
            print("📄 Total extracted text length: \(content.count) characters")
            
            if content.isEmpty {
                throw NSError(domain: "PDFError", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF appears to be image-based or has no extractable text. Please use a PDF with selectable text."])
            }
            
            return content
        } else {
            // For txt/markdown/plain text
            let content = try String(contentsOf: url, encoding: .utf8)
            print("📄 Text file read: \(content.count) characters")
            return content
        }
    }
    
    // MARK: - Chunking (character-based with overlap)
    func chunkText(_ text: String, chunkSize: Int = 2000, overlap: Int = 200) -> [String] {
        guard !text.isEmpty else { return [] }
        var chunks: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty { chunks.append(chunk) }
            if end == text.endIndex { break }
            start = text.index(end, offsetBy: -overlap, limitedBy: text.endIndex) ?? text.endIndex
        }
        return chunks
    }
    
    
    // MARK: - Ask question: build prompt from top chunks and call LLM
    func askQuestion(_ question: String) async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message to chat
        let userMessage = ChatMessage(content: question, isUser: true)
        messages.append(userMessage)
        

        Task { @MainActor in
            self.currentStreamingText = ""
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Make the call stateless: clear any prior conversation history
            self.agent = LLMAgent()
            
            let context = topRelevantContext(for: question)
            
            // Check if we have valid context
            guard !context.isEmpty && !context.contains("No document content available") else {
                let errorMessage = ChatMessage(content: "No document has been indexed yet. Please select a document first.", isUser: false)
                messages.append(errorMessage)
                self.chatResponse = "No document has been indexed yet. Please select a document first."
                return
            }

            var prompt = """
            You are a helpful assistant. Answer the question based on the context provided below. Use the context to provide a comprehensive answer. If the specific answer is not directly in the context, try to infer from the available information or indicate what information is missing. Be helpful and concise.

            Context from document:
            """
            prompt += context
            prompt += "\n\nQuestion: \(question)\n\nAnswer:"

            // Safety: hard-cap the prompt length to avoid context overflow
            let maxPromptChars = maxContextChars + 2_000 // allow room for instructions and question
            if prompt.count > maxPromptChars {
                prompt = String(prompt.suffix(maxPromptChars))
            }

            // Reset speech tracking for new response and clear any pending speech
            await MainActor.run {
                self.hasStartedSpeaking = false
                self.lastSpokenLength = 0
                // Clear any pending speech from previous question
                self.textToSpeech.stopSpeaking()
            }
            
            let minCharsToStartSpeaking = 30 // Start speaking after ~30 characters
            
            try await agent?.streamMessage(prompt: prompt) { token in
                Task { @MainActor in
                    // Check if token is cumulative (contains previous text) or incremental
                    let current = self.currentStreamingText
                    let updatedText: String
                    if !current.isEmpty && token.count >= current.count && token.hasPrefix(current) {
                        // Token is cumulative - contains all previous text, use it directly
                        updatedText = token
                    } else {
                        // Token is incremental - just new text, append it
                        updatedText = current + token
                    }
                    
                    self.currentStreamingText = updatedText
                    
                    // Start speaking as soon as we have enough text
                    if !self.hasStartedSpeaking && updatedText.count >= minCharsToStartSpeaking {
                        // Find a good break point (sentence end, or just use what we have)
                        let textToSpeak = self.findSpeechBreakPoint(in: updatedText, minLength: minCharsToStartSpeaking)
                        if !textToSpeak.isEmpty {
                            self.hasStartedSpeaking = true
                            self.lastSpokenLength = textToSpeak.count
                            Task {
                                // Start new speech (not continuation) for the first chunk
                                await self.textToSpeech.speak(textToSpeak, isContinuation: false)
                            }
                        }
                    } else if self.hasStartedSpeaking {
                        // Continue speaking new content as it arrives
                        let remainingText = String(updatedText.dropFirst(self.lastSpokenLength))
                        if remainingText.count >= 20 { // Speak chunks of at least 20 chars
                            let textToSpeak = self.findSpeechBreakPoint(in: remainingText, minLength: 20)
                            if !textToSpeak.isEmpty {
                                self.lastSpokenLength += textToSpeak.count
                                Task {
                                    await self.textToSpeech.speak(textToSpeak, isContinuation: true)
                                }
                            }
                        }
                    }
                }
            }
            
            // Get the final accumulated response
            let accumulatedResponse = await MainActor.run {
                return self.currentStreamingText
            }

            // When streaming completes, add assistant's message
            let assistantMessage = ChatMessage(content: accumulatedResponse, isUser: false)
            messages.append(assistantMessage)
            self.chatResponse = accumulatedResponse
            
            // Speak any remaining text that hasn't been spoken yet
            await MainActor.run {
                let remainingText = String(accumulatedResponse.dropFirst(self.lastSpokenLength))
                if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task {
                        await self.textToSpeech.speak(remainingText, isContinuation: true)
                    }
                }
                self.currentStreamingText = ""
                // Reset speech tracking
                self.hasStartedSpeaking = false
                self.lastSpokenLength = 0
            }
        } catch {
            let errorMessage = ChatMessage(content: "Agent error: \(error.localizedDescription)", isUser: false)
            messages.append(errorMessage)
            self.chatResponse = "Agent error: \(error.localizedDescription)"
            self.currentStreamingText = ""
        }
    }
    
    // MARK: - Voice Input
    func startListening() async {
        let authorized = await speechRecognizer.requestAuthorization()
        guard authorized else {
            print("Speech recognition authorization denied")
            return
        }
        
        isListening = true
        transcribedText = ""
        
        await speechRecognizer.startTranscribing { [weak self] text in
            Task { @MainActor in
                self?.transcribedText = text
            }
        }
    }
    
    func stopListening() async {
        await speechRecognizer.stopTranscribing()
        isListening = false
        
        // If we have transcribed text, send it as a question
        if !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await askQuestion(transcribedText)
            transcribedText = ""
        }
    }
    
    
    // MARK: - Helper to find good speech break points
    private func findSpeechBreakPoint(in text: String, minLength: Int) -> String {
        guard text.count >= minLength else { return "" }
        
        let searchRange = text.startIndex..<text.index(text.startIndex, offsetBy: min(text.count, 500))
        
        // Look for sentence endings first (. ! ?)
        for char in [".", "!", "?"] {
            if let index = text.range(of: char, range: searchRange)?.upperBound {
                // Check if followed by whitespace
                if index < text.endIndex && text[index].isWhitespace {
                    return String(text[..<index])
                }
            }
        }
        
        // Look for comma or semicolon
        for char in [",", ";", ":"] {
            if let index = text.range(of: char, range: searchRange)?.upperBound {
                // Check if followed by whitespace
                if index < text.endIndex && text[index].isWhitespace {
                    return String(text[..<index])
                }
            }
        }
        
        // Look for word boundaries (spaces) after minLength
        let spaceSearchStart = text.index(text.startIndex, offsetBy: minLength)
        if spaceSearchStart < text.endIndex {
            let spaceRange = spaceSearchStart..<text.endIndex
            if let spaceIndex = text.range(of: " ", range: spaceRange)?.upperBound {
                return String(text[..<spaceIndex])
            }
        }
        
        // If no good break point, return the text up to a reasonable length
        let maxLength = min(text.count, 200)
        return String(text.prefix(maxLength))
    }
    
    // MARK: - Lightweight retrieval without embeddings
    private func topRelevantContext(for question: String) -> String {
        print("🔍 Searching context for question: \(question)")
        print("🔍 Available chunks: \(chunks.count)")
        print("🔍 Content length: \(content.count) characters")
        
        // If no chunks, use the full content (or a prefix if too long)
        guard !chunks.isEmpty else {
            print("⚠️ No chunks available, using full content")
            if content.isEmpty {
                print("❌ Content is also empty!")
                return "No document content available. Please select and index a document first."
            }
            return String(content.prefix(maxContextChars))
        }
        
        // If content is empty but chunks exist, something went wrong
        guard !content.isEmpty else {
            print("⚠️ Content is empty but chunks exist, using chunks")
            // Fall back to using all chunks
            let allChunks = chunks.prefix(10).map { $0.text }.joined(separator: "\n\n---\n\n")
            return String(allChunks.prefix(maxContextChars))
        }

        // Tokenize question into lowercase keywords (very naive)
        let separators = CharacterSet.alphanumerics.inverted
        let qTokens = question
            .lowercased()
            .components(separatedBy: separators)
            .filter { !$0.isEmpty && $0.count > 2 }
        
        print("🔍 Question keywords: \(qTokens)")

        // Score each chunk by keyword overlap count
        let scored = chunks.map { chunk -> (Chunk, Int) in
            let text = chunk.text.lowercased()
            let score = qTokens.reduce(0) { acc, tok in
                acc + (text.contains(tok) ? 1 : 0)
            }
            return (chunk, score)
        }
        .sorted { lhs, rhs in lhs.1 > rhs.1 }
        
        print("🔍 Top chunk scores: \(scored.prefix(5).map { $0.1 })")
        
        // If no chunks have any matches, use the top chunks anyway (might be general question)
        let selectedChunks = scored.prefix(topK)
        let selectedTexts = selectedChunks.map { $0.0.text }
        
        // If all scores are 0, include more chunks or use full content
        let maxScore = selectedChunks.first?.1 ?? 0
        if maxScore == 0 {
            print("⚠️ No keyword matches found, using first \(topK) chunks")
            // Use first chunks as fallback
            let fallbackChunks = chunks.prefix(topK * 2).map { $0.text }
            let joined = fallbackChunks.joined(separator: "\n\n---\n\n")
            if joined.count > maxContextChars {
                return String(joined.prefix(maxContextChars))
            }
            return joined
        }

        // Concatenate and trim to maxContextChars
        let joined = selectedTexts.joined(separator: "\n\n---\n\n")
        let finalContext = joined.count > maxContextChars ? String(joined.prefix(maxContextChars)) : joined
        
        print("🔍 Context length: \(finalContext.count) characters")
        print("🔍 Context preview: \(finalContext.prefix(200))")
        
        return finalContext
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date = Date()
}
