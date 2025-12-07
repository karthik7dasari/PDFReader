//
//  ChatBubble.swift
//  PDFReader
//
//  Created by Karthik Dasari on 12/7/25.
//

import SwiftUI
import Combine
import Foundation

// MARK: - Chat Bubble View
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }
}

// MARK: - Loading Chat Bubble View
struct LoadingChatBubble: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            Spacer(minLength: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color(.systemGray3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                            .opacity(animationPhase == index ? 1.0 : 0.5)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemGray5))
                )
                
                Text(Date(), style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
                    withAnimation(.easeInOut(duration: 0.3)) {
                        animationPhase = (animationPhase + 1) % 3
                    }
                }
            }
        }
    }
}
