import Foundation
import OpenAI

class OpenAIService: @unchecked Sendable {
    // OpenAI клиент
    private var openAI: OpenAI?
    
    // Переменная для хранения предыдущего responseId
    private var previousResponseId: String?
    
    // Callback для результатов транскрипции
    var onTranscriptionReceived: ((String) -> Void)?
    var onTranscriptionError: ((String) -> Void)?
    
    // Callback для результатов ResponseAPI
    var onResponseReceived: ((String) -> Void)?
    var onResponseError: ((String) -> Void)?
    
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
    
    func transcribeAudio(from fileURL: URL) {
        guard let openAI = openAI else {
            DispatchQueue.main.async {
                self.onTranscriptionError?("OpenAI клиент не инициализирован")
            }
            return
        }
        
        // Читаем файл с диска
        do {
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
            
            // Выполняем транскрипцию в фоновом потоке
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                openAI.audioTranscriptions(query: query) { result in
                    switch result {
                    case .success(let transcription):
                        print("✅ Транскрипция получена: \(transcription.text)")
                        DispatchQueue.main.async {
                            self.onTranscriptionReceived?(transcription.text)
                        }                        
                    case .failure(let error):
                        print("❌ Ошибка транскрипции: \(error)")
                        let errorMessage = error.localizedDescription
                        DispatchQueue.main.async {
                            self.onTranscriptionError?("Ошибка: \(errorMessage)")
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Ошибка чтения файла: \(error)")
            let errorMessage = error.localizedDescription
            DispatchQueue.main.async {
                self.onTranscriptionError?("Ошибка чтения файла: \(errorMessage)")
            }
        }
    }
    
    // Метод для вызова ResponseAPI
    func callResponseAPI(with transcription: String) {
        guard let openAI = openAI else {
            DispatchQueue.main.async {
                self.onResponseError?("OpenAI клиент не инициализирован")
            }
            return
        }
        
        print("🤖 Вызываем ResponseAPI с транскрипцией: \(transcription)")
        
        // Создаем запрос к ResponseAPI
        let query = CreateModelResponseQuery(
            input: .textInput(transcription),
            model: .gpt5_mini,
            instructions: "Ты полезный ассистент. Отвечай кратко и по делу на русском языке.",
            previousResponseId: previousResponseId
        )
        
        // Выполняем запрос в фоновом потоке
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            openAI.responses.createResponse(query: query) { result in
                switch result {
                case .success(let response):
                    let responseText = self.getResponseText(from: response)
                    print("✅ Ответ получен: \(responseText)")
                    
                    // Сохраняем responseId для следующего вызова
                    self.previousResponseId = response.id
                    print("💾 Сохранен responseId: \(response.id)")
                    
                    DispatchQueue.main.async {
                        self.onResponseReceived?(responseText)
                    }
                    
                case .failure(let error):
                    print("❌ Ошибка ResponseAPI: \(error)")
                    let errorMessage = error.localizedDescription
                    DispatchQueue.main.async {
                        self.onResponseError?("Ошибка ResponseAPI: \(errorMessage)")
                    }
                }
            }
        }
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
