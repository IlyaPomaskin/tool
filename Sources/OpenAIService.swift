import Foundation
import AppKit
import OpenAI

class OpenAIService: @unchecked Sendable {
    // OpenAI client
    private var openAI: OpenAI?
    
    // Variable to store previous responseId
    private var previousResponseId: String?
    
    
    init() {
        setupOpenAI()
    }
    
    private func setupOpenAI() {
        // Get API key from environment variable or use placeholder
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "your-api-key-here"
        
        if apiKey != "your-api-key-here" {
            openAI = OpenAI(apiToken: apiKey)
            print("OpenAI client initialized")
        } else {
            print("⚠️  Set OPENAI_API_KEY in environment variables")
        }
    }
    
    func transcribeAudio(from fileURL: URL) async throws -> String {
        guard let openAI = openAI else {
            throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI client not initialized"])
        }
        
        // Read file from disk
        let audioData = try Data(contentsOf: fileURL)
        
        print("Sending M4A audio for transcription...")
        
        // Send to OpenAI for transcription
        let query = AudioTranscriptionQuery(
            file: audioData,
            fileType: .m4a,
            model: .gpt_4o_transcribe,
            language: "en"
        )
        
        // Perform transcription
        let transcription = try await openAI.audioTranscriptions(query: query)
        print("✅ Transcription received: \(transcription.text)")
        
        return transcription.text
    }
    
    // Method for calling ResponseAPI
    func callResponseAPI(with transcription: String, instructions: String) async throws -> String {
        let query = CreateModelResponseQuery(
            input: .textInput(transcription),
            model: .gpt5_mini,
            instructions: instructions,
            previousResponseId: previousResponseId
        )
        
        return try await executeResponseQuery(query, description: "with transcription: \(transcription)")
    }
    
    // Method for calling ResponseAPI with image
    func callResponseAPI(with transcription: String, instructions: String, image: NSImage) async throws -> String {
        let inputMessage = try createInputMessageWithImage(transcription: transcription, image: image)
        
        let query = CreateModelResponseQuery(
            input: .inputItemList([InputItem.inputMessage(inputMessage)]),
            model: .gpt5_mini,
            instructions: instructions,
            previousResponseId: previousResponseId
        )
        
        return try await executeResponseQuery(query, description: "with transcription and image: \(transcription)")
    }

    // Common method for executing ResponseAPI request
    private func executeResponseQuery(_ query: CreateModelResponseQuery, description: String) async throws -> String {
        guard let openAI = openAI else {
            throw NSError(domain: "OpenAIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "OpenAI client not initialized"])
        }
        
        print("🤖 Calling ResponseAPI \(description)")
        
        // Execute request
        let response = try await openAI.responses.createResponse(query: query)
        let responseText = getResponseText(from: response)
        print("✅ Response received: \(responseText)")
        
        // Save responseId for next call
        previousResponseId = response.id
        print("💾 Saved responseId: \(response.id)")
        
        return responseText
    }
    
    // Creating message with image
    private func createInputMessageWithImage(transcription: String, image: NSImage) throws -> EasyInputMessage {
        // Convert NSImage to Data (already compressed image)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw NSError(domain: "OpenAIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        // Encode image to base64
        let base64Image = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64Image)"
        
        // Create message with text and image
        return EasyInputMessage(
            role: .user,
            content: .inputItemContentList([
                .inputText(Components.Schemas.InputTextContent(_type: .inputText, text: transcription)),
                .inputImage(InputImage(
                    _type: .inputImage,
                    imageUrl: dataURL,
                    fileId: nil,
                    detail: .auto
                ))
            ])
        )
    }

    private func getResponseText(from response: ResponseObject) -> String {
        var allTexts: [String] = []
        
        for output in response.output {
            switch output {
            case .outputMessage(let outputMessage):
                for content in outputMessage.content {
                    switch content {
                    case .OutputTextContent(let textContent):
                        allTexts.append(textContent.text)
                    case .RefusalContent(let refusalContent):
                        print("Refusal: \(refusalContent.refusal)")
                    }
                }
            default:
                print("Unhandled output type")
            }
        }
        
        // Combine all text elements into one string
        return allTexts.isEmpty ? "No response" : allTexts.joined(separator: " ")
    }
}
