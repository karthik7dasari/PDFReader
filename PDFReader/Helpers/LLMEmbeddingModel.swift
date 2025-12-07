//
//  LLMEmbeddingModel.swift
//  PDFReader
//
//  Created by Karthik Dasari on 11/27/25.
//

import Foundation
import FoundationModels // iOS 18+, Xcode 16+


class LLMAgent {
    private let session = LanguageModelSession()

    func streamMessage(prompt: String, onToken: @escaping (String) -> Void) async throws {
        let stream = session.streamResponse(to: .init(prompt))
        for try await token in stream {
            onToken(token.content) // token is the chunk of text
        }
    }
}

// MARK: - Simple chunk struct & in-memory vector store
struct Chunk: Identifiable {
    let id: UUID
    let text: String
    let embedding: [Float]
}
