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
        
        static let assistant = "Ты полезный ассистент. Отвечай кратко и по делу на русском языке."
    }
}
