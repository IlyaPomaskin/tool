import Foundation
import AppKit

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
            let content: MessageContent
        }
    }
    
    // Content can be either string or array of content items
    private enum MessageContent: Codable {
        case text(String)
        case contentArray([ContentItem])
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .contentArray(let items):
                try container.encode(items)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let items = try? container.decode([ContentItem].self) {
                self = .contentArray(items)
            } else {
                throw DecodingError.typeMismatch(MessageContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode MessageContent"))
            }
        }
    }
    
    // Content item for multimodal messages
    private struct ContentItem: Codable {
        let type: String
        let text: String?
        let image_url: ImageURL?
        
        enum CodingKeys: String, CodingKey {
            case type, text, image_url
        }
    }
    
    // Image URL structure
    private struct ImageURL: Codable {
        let url: String
        let detail: String?
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
            messages.append(ChatRequest.Message(role: "system", content: .text(systemPrompt)))
        }
        
        // Add user message
        messages.append(ChatRequest.Message(role: "user", content: .text(message)))
        
        let requestBody = ChatRequest(
            model: model,
            messages: messages,
            temperature: 0.2,
            max_tokens: 1000,
            stream: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
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
            
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            
            guard let firstChoice = chatResponse.choices.first else {
                throw NSError(domain: "LMStudioService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No response choices available"])
            }
            
            let responseText = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ LM Studio response received: \(responseText)")
            
            return responseText
            
        } catch {
            throw NSError(domain: "LMStudioService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
        }
    }
    
    // Send transcribed text to LM Studio with image support
    func sendMessage(_ message: String, systemPrompt: String? = nil, image: NSImage? = nil) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        
        var messages: [ChatRequest.Message] = []
        
        // Add system prompt if provided
        if let systemPrompt = systemPrompt {
            messages.append(ChatRequest.Message(role: "system", content: .text(systemPrompt)))
        }
        
        // Add user message with optional image
        if let image = image {
            // Create multimodal message with text and image
            let imageBase64 = try convertImageToBase64(image)
            let contentItems = [
                ContentItem(type: "text", text: message, image_url: nil),
                ContentItem(type: "image_url", text: nil, image_url: ImageURL(url: imageBase64, detail: "auto"))
            ]
            messages.append(ChatRequest.Message(role: "user", content: .contentArray(contentItems)))
        } else {
            // Text-only message
            messages.append(ChatRequest.Message(role: "user", content: .text(message)))
        }
        
        let requestBody = ChatRequest(
            model: model,
            messages: messages,
            temperature: 0.2,
            max_tokens: 1000,
            stream: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let messageDescription = image != nil ? "message with image" : "message"
        print("🤖 Sending \(messageDescription) to LM Studio: \(message)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "LMStudioService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "LMStudioService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"])
            }
            
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            
            guard let firstChoice = chatResponse.choices.first else {
                throw NSError(domain: "LMStudioService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No response choices available"])
            }
            
            let responseText = firstChoice.message.content
            print("✅ LM Studio response received: \(responseText)")
            
            return responseText
        } catch {
            throw NSError(domain: "LMStudioService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
        }
    }
    
    // Convert NSImage to base64 data URL
    private func convertImageToBase64(_ image: NSImage) throws -> String {
        // Convert NSImage to Data
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw NSError(domain: "LMStudioService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }
        
        // Encode to base64 and create data URL
        let base64String = imageData.base64EncodedString()
        return "data:image/jpeg;base64,\(base64String)"
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
