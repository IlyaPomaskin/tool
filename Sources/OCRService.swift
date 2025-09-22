import Foundation
import AppKit
import Vision

@MainActor
class OCRService: NSObject {
    func extractText(from image: NSImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continuation.resume(throwing: OCRError.invalidImage)
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if recognizedText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: recognizedText)
                }
            }
            
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            // request.recognitionLanguages = ["en", "ru"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func extractText(from imageURL: URL) async throws -> String {
        guard let image = NSImage(contentsOf: imageURL) else {
            throw OCRError.invalidImage
        }
        
        return try await extractText(from: image)
    }
    
    func extractTextFromClipboard() async throws -> String {
        guard let pasteboard = NSPasteboard.general.data(forType: .tiff),
              let image = NSImage(data: pasteboard) else {
            throw OCRError.invalidImage
        }
        
        return try await extractText(from: image)
    }
}

enum OCRError: Error, LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Не удалось загрузить изображение"
        case .noTextFound:
            return "Текст на изображении не найден"
        case .processingFailed:
            return "Ошибка обработки изображения"
        }
    }
}
