import Foundation

struct Constants {
    
    // MARK: - Prompts
    struct Prompts {
        static let translator = """
You are a translator. 
Translate Russian speech-to-text into English with minimal rephrasing so it's clear to English speakers. 
Smooth only obvious recognition errors.
Use image context if provided.
Do not add or omit content.
Respond with translated text only.
"""
        
        static let assistant = "You are a helpful assistant. Answer VERY briefly and to the point in English."
        
        static let localAssistant = "You are a helpful AI assistant. Provide clear, concise, and accurate responses to user queries."
    }
    
    // MARK: - LM Studio Configuration
    struct LMStudio {
        static let defaultBaseURL = "http://localhost:1234/v1"
        static let defaultModel = "local-model"
        static let timeout: TimeInterval = 30.0
    }
}
