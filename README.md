# PDFReader

An intelligent iOS app that transforms document interaction through AI-powered conversational interfaces. Ask questions about your PDFs and text documents, get instant answers, and interact using voice commands.

## ✨ Features

### 📄 Document Processing
- **Multi-format Support**: Read and process PDF and text documents
- **Smart Text Extraction**: Automatically extracts text from PDFs using PDFKit
- **Intelligent Chunking**: Breaks documents into manageable chunks with overlap for better context retention
- **Document Preview**: Preview documents before indexing

### 🤖 AI-Powered Q&A
- **Contextual Answers**: Ask questions about your documents and receive accurate, context-aware responses
- **Real-time Streaming**: Watch answers stream in as the AI processes your document
- **Smart Retrieval**: Uses keyword-based semantic search to find the most relevant document sections
- **On-device Processing**: Leverages iOS 18+ FoundationModels for privacy-focused AI

### 🎤 Voice Interaction
- **Speech Recognition**: Speak your questions naturally using built-in speech recognition
- **Text-to-Speech**: Listen to responses as they're generated in real-time
- **Incremental TTS**: Starts speaking responses as soon as enough text is available
- **Smart Break Points**: Intelligently finds sentence boundaries for natural speech flow

### 💬 Chat Interface
- **Conversational UI**: Clean, modern chat interface for document Q&A
- **Message History**: View your conversation history with the document
- **Streaming Indicators**: Visual feedback during AI processing
- **Voice Status**: Real-time indicators for listening and speaking states

## 🛠️ Technologies

- **SwiftUI**: Modern declarative UI framework
- **FoundationModels**: iOS 18+ on-device LLM capabilities
- **PDFKit**: Robust PDF document parsing and text extraction
- **Speech Framework**: Speech recognition for voice input
- **AVFoundation**: Audio session management and text-to-speech
- **Combine**: Reactive programming for state management

## 📋 Requirements

- iOS 26.0 or later
- Xcode 26.0 or later
- Swift 6.0+
- Device with microphone access (for voice features)
- Speech recognition permissions

## 🚀 Getting Started

### Installation

1. Clone the repository:
```bash
git clone https://github.com/karthik7dasari/PDFReader
cd PDFReader
```

2. Open the project in Xcode:
```bash
open PDFReader.xcodeproj
```

3. Build and run the project:
   - Select your target device or simulator
   - Press `Cmd + R` or click the Run button

### First Launch

1. **Grant Permissions**: 
   - Allow microphone access when prompted (for voice input)
   - Allow speech recognition permissions

2. **Select a Document**:
   - Tap "Select Document" to choose a PDF or text file
   - Preview the document
   - Tap "Done" to index the document

3. **Start Chatting**:
   - Tap the "Agent" button to open the chat interface
   - Type a question or use the microphone button for voice input
   - Get instant answers about your document!

## 📱 Usage

### Document Selection
1. Tap the "Select Document" button on the home screen
2. Choose a PDF or text file from your device
3. Preview the document to confirm it's the right one
4. Tap "Done" to index the document

### Asking Questions
- **Text Input**: Type your question in the text field and tap send
- **Voice Input**: Tap the microphone button, speak your question, then tap again to stop and send
- **View Responses**: Answers stream in real-time and can be read aloud automatically

### Managing Conversations
- **Clear Chat**: Tap the trash icon to clear conversation history
- **Reset Document**: Tap the refresh icon to select a new document
- **Close Chat**: Tap "Close" to return to the document view

## 🏗️ Architecture

### Project Structure
```
PDFReader/
├── Views/
│   ├── PDFReaderApp.swift          # App entry point
│   ├── PDFReaderView.swift          # Main view with document selection
│   ├── ChatSheetView.swift          # Chat interface modal
│   ├── ChatBubble.swift             # Individual chat message component
│   ├── DocumentPicker.swift         # Document selection UI
│   └── DocumentPreview.swift        # Document preview UI
├── ViewModels/
│   └── PDFReaderViewModel.swift     # Business logic and state management
└── Helpers/
    ├── LLMEmbeddingModel.swift      # LLM agent wrapper
    ├── SpeechRecognizer.swift       # Speech recognition handler
    └── TextToSpeechManager.swift         # Text-to-speech handler
```

### Key Components

**PDFReaderViewModel**
- Manages document indexing and chunking
- Handles Q&A interactions with the LLM
- Coordinates voice input/output
- Implements keyword-based retrieval

**LLMAgent**
- Wraps FoundationModels LanguageModelSession
- Streams responses token by token
- Handles prompt construction and context management

**SpeechRecognizer**
- Manages speech recognition authorization
- Handles audio session configuration
- Provides real-time transcription updates

**TextToSpeechManager**
- Manages AVSpeechSynthesizer
- Handles incremental speech for streaming responses
- Manages audio session transitions


## 🔮 Future Enhancements

- [ ] Vector embeddings for more accurate semantic search
- [ ] Support for image-based PDFs using OCR
- [ ] Multiple document support
- [ ] Export conversation history
- [ ] Custom chunking strategies
- [ ] Dark mode optimizations
- [ ] iPad support with split view
- [ ] Document bookmarking and favorites

## 📝 Notes

- The app uses keyword-based retrieval (not vector embeddings) for simplicity and performance
- On-device AI processing ensures privacy - your documents never leave your device
- Speech recognition requires internet connection for processing
- Large documents may take time to index depending on length

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is available for personal and educational use.

## 👤 Author

**Karthik Dasari**
