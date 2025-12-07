//
//  TextToSpeechManager.swift
//  PDFReader
//
//  Created by Karthik Dasari on 12/7/25.
//


import Combine
import Foundation
import Speech

class TextToSpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var speechQueue: [String] = []
    private var isConfigured = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String, isContinuation: Bool = false) async {
        guard !text.isEmpty else {
            print("TTS: Empty text, skipping")
            return
        }
        
        // Always ensure audio session is configured and active for each speech request
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use .playback category for text-to-speech
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
            if !isConfigured {
                isConfigured = true
                print("TTS: Audio session configured for playback")
            }
        } catch {
            print("TTS: Failed to configure audio session: \(error)")
            // Try to reactivate even if configuration fails
            do {
                try audioSession.setActive(true)
            } catch {
                print("TTS: Failed to activate audio session: \(error)")
                return
            }
        }
        
        // If it's not a continuation, clear the queue and stop current speech
        if !isContinuation {
            speechQueue.removeAll()
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
                // Small delay to ensure previous speech is fully stopped
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        } else {
            // If it's a continuation and we're already speaking, queue it
            if synthesizer.isSpeaking {
                speechQueue.append(text)
                print("TTS: Queued continuation: \(text.prefix(50))...")
                return
            }
            // If it's a continuation but not speaking, just speak it directly
        }
        
        // Double-check audio session is active before speaking
        do {
            try audioSession.setActive(true)
        } catch {
            print("TTS: Warning - could not activate audio session: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8 // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        print("TTS: Starting to speak (isContinuation: \(isContinuation), isSpeaking: \(synthesizer.isSpeaking)): \(text.prefix(50))...")
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechQueue.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    private func speakNextInQueue() {
        guard !speechQueue.isEmpty else { return }
        
        let nextText = speechQueue.removeFirst()
        let utterance = AVSpeechUtterance(string: nextText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        print("TTS: Speaking next in queue: \(nextText.prefix(50))...")
        synthesizer.speak(utterance)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("TTS: Started speaking")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("TTS: Finished speaking")
        // Speak next item in queue if available
        speakNextInQueue()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("TTS: Speech cancelled")
        // Still try to speak next in queue
        speakNextInQueue()
    }
}
