import Foundation

class LMStudioService: @unchecked Sendable {
    private let baseURL: String
    private let model: String
    private let session: URLSession
    
    init(baseURL: String = "http://localhost:1234/v1", model: String = "local-model") {
        self.baseURL = baseURL
        self.model = model
        self.session = URLSession.shared
    }
    
    // Structure for LM Studio API request
    private struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int?
        let stream: Bool
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
    
    // Structure for LM Studio API response
    private struct ChatResponse: Codable {
        let id: String?
        let object: String?
        let created: Int?
        let model: String?
        let choices: [Choice]
        
        struct Choice: Codable {
            let index: Int
            let message: Message
            let finish_reason: String?
            
            struct Message: Codable {
                let role: String
                let content: String
            }
        }
    }
    
    // Send transcribed text to LM Studio
    func sendMessage(_ message: String, systemPrompt: String? = nil) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        
        var messages: [ChatRequest.Message] = []
        
        // Add system prompt if provided
        if let systemPrompt = systemPrompt {
            messages.append(ChatRequest.Message(role: "system", content: systemPrompt))
        }
        
        // Add user message
        messages.append(ChatRequest.Message(role: "user", content: message))
        
        let requestBody = ChatRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            max_tokens: 1000,
            stream: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw NSError(domain: "LMStudioService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request: \(error.localizedDescription)"])
        }
        
        print("🤖 Sending message to LM Studio: \(message)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "LMStudioService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "LMStudioService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"])
            }
            
            do {
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                
                guard let firstChoice = chatResponse.choices.first else {
                    throw NSError(domain: "LMStudioService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No response choices available"])
                }
                
                let responseText = firstChoice.message.content
                print("✅ LM Studio response received: \(responseText)")
                
                return responseText
                
            } catch let decodingError {
                let errorData = String(data: data, encoding: .utf8) ?? "No data"
                throw NSError(domain: "LMStudioService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(decodingError.localizedDescription). Response data: \(errorData)"])
            }
            
        } catch {
            throw NSError(domain: "LMStudioService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
        }
    }
    
    // Check if LM Studio is available
    func checkAvailability() async -> Bool {
        let url = URL(string: "\(baseURL)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("❌ LM Studio not available: \(error.localizedDescription)")
            return false
        }
    }
}
