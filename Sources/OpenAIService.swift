import Foundation
import OpenAI

class OpenAIService: @unchecked Sendable {
    // OpenAI клиент
    private var openAI: OpenAI?
    
    // Переменная для хранения предыдущего responseId
    private var previousResponseId: String?
    
    
    init() {
        setupOpenAI()
    }
    
    private func setupOpenAI() {
        // Получаем API ключ из переменной окружения или используем placeholder
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "your-api-key-here"
        
        if apiKey != "your-api-key-here" {
            openAI = OpenAI(apiToken: apiKey)
            print("OpenAI клиент инициализирован")
        } else {
            print("⚠️  Установите OPENAI_API_KEY в переменных окружения")
        }
    }
    
    func transcribeAudio(from fileURL: URL) async throws -> String {
        guard let openAI = openAI else {
            throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI клиент не инициализирован"])
        }
        
        // Читаем файл с диска
        let audioData = try Data(contentsOf: fileURL)
        print("Прочитан файл: \(fileURL.path) (\(audioData.count) байт)")
        
        print("Отправляем M4A аудио на транскрипцию...")
        
        // Отправляем в OpenAI для транскрипции
        let query = AudioTranscriptionQuery(
            file: audioData,
            fileType: .m4a,
            model: .whisper_1,
            language: "ru" // Русский язык
        )
        
        // Выполняем транскрипцию
        let transcription = try await openAI.audioTranscriptions(query: query)
        print("✅ Транскрипция получена: \(transcription.text)")
        
        return transcription.text
    }
    
    // Метод для вызова ResponseAPI
    func callResponseAPI(with transcription: String) async throws -> String {
        guard let openAI = openAI else {
            throw NSError(domain: "OpenAIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "OpenAI клиент не инициализирован"])
        }
        
        print("🤖 Вызываем ResponseAPI с транскрипцией: \(transcription)")
        
        // Создаем запрос к ResponseAPI
        let query = CreateModelResponseQuery(
            input: .textInput(transcription),
            model: .gpt5_mini,
            instructions: "Ты полезный ассистент. Отвечай кратко и по делу на русском языке.",
            previousResponseId: previousResponseId
        )
        
        // Выполняем запрос
        let response = try await openAI.responses.createResponse(query: query)
        let responseText = getResponseText(from: response)
        print("✅ Ответ получен: \(responseText)")
        
        // Сохраняем responseId для следующего вызова
        previousResponseId = response.id
        print("💾 Сохранен responseId: \(response.id)")
        
        return responseText
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
                        print("Отказ: \(refusalContent.refusal)")
                    }
                }
            default:
                print("Необработанный тип вывода")
            }
        }
        
        // Объединяем все текстовые элементы в одну строку
        return allTexts.isEmpty ? "Нет ответа" : allTexts.joined(separator: " ")
    }
}
