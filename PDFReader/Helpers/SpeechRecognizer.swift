//
//  SpeechRecognizer.swift
//  PDFReader
//
//  Created by Karthik Dasari on 12/7/25.
//

import SwiftUI
import Combine
import Foundation
import PDFKit
import Speech


@MainActor
class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var onTranscriptionUpdate: ((String) -> Void)?
    
    override init() {
        super.init()
    }
    
    func requestAuthorization() async -> Bool {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        return status == .authorized
    }
    
    func startTranscribing(onUpdate: @escaping (String) -> Void) async {
        // Check authorization status first
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus != .authorized {
            print("Speech recognition not authorized. Status: \(authStatus.rawValue)")
            return
        }
        
        // Check microphone permission
        let audioSession = AVAudioSession.sharedInstance()
        let micStatus = audioSession.recordPermission
        if micStatus != .granted {
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                print("Microphone permission denied")
                return
            }
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        onTranscriptionUpdate = onUpdate
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start failed: \(error)")
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                let transcribedText = result.bestTranscription.formattedString
                self?.onTranscriptionUpdate?(transcribedText)
            }
            
            if let error = error {
                print("Speech recognition error: \(error)")
                // Don't auto-stop on error, let user control it
            }
        }
    }
    
    func stopTranscribing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session to allow other audio (like TTS) to work
        // Use .notifyOthersOnDeactivation to allow smooth transition to playback
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
