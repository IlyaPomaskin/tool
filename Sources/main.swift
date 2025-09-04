import AppKit
import HotKey
import OpenAI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var button: NSButton!
    var textLabel: NSTextField!
    var hotKey: HotKey?
    var audioRecorder: AudioRecorder!
    var openAIService: OpenAIService!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Создаем окно
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Mic GPT - Голосовой помощник"
        window.center()
        
        // Создаем кнопку
        button = NSButton(frame: NSRect(x: 200, y: 300, width: 100, height: 40))
        button.title = "Hello World"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(buttonClicked)
        
        // Создаем текстовое поле для отображения транскрипции
        textLabel = NSTextField(frame: NSRect(x: 50, y: 50, width: 400, height: 200))
        textLabel.stringValue = "Нажмите и удерживайте Control + Option + Command + M для записи голоса\n\nТранскрипция появится здесь..."
        textLabel.isEditable = false
        textLabel.isSelectable = true
        textLabel.font = NSFont.systemFont(ofSize: 14)
        textLabel.textColor = NSColor.labelColor
        textLabel.backgroundColor = NSColor.controlBackgroundColor
        textLabel.alignment = .left
        textLabel.maximumNumberOfLines = 0
        textLabel.cell?.wraps = true
        textLabel.cell?.isScrollable = true
        
        // Добавляем элементы в окно
        window.contentView?.addSubview(button)
        window.contentView?.addSubview(textLabel)
        
        // Показываем окно
        window.makeKeyAndOrderFront(nil)
        
        // Инициализируем аудио рекордер
        setupAudioRecorder()
        
        // Настраиваем глобальные хоткеи
        setupGlobalHotkeys()
    }
    
    func setupAudioRecorder() {
        // Инициализируем сервисы
        audioRecorder = AudioRecorder()
        openAIService = OpenAIService()
        
        // Настраиваем callback для передачи файла в OpenAI после записи
        audioRecorder.onRecordingCompleted = { [weak self] fileURL in
            self?.openAIService.transcribeAudio(from: fileURL)
        }
        
        // Настраиваем callback'и OpenAI сервиса для обновления UI
        openAIService.onTranscriptionReceived = { [weak self] transcription in
            self?.textLabel.stringValue = "🎤 Транскрипция:\n\n\(transcription)"
            self?.button.title = "Hello World"
            self?.openAIService.callResponseAPI(with: transcription)
        }
        
        openAIService.onTranscriptionError = { [weak self] error in
            self?.textLabel.stringValue = "❌ Ошибка:\n\n\(error)"
            self?.button.title = "Hello World"
        }
        
        // Настраиваем callback'и ResponseAPI для обновления UI
        openAIService.onResponseReceived = { [weak self] response in
            self?.textLabel.stringValue = "🤖 Ответ:\n\n\(response)"
            self?.button.title = "Hello World"
        }
        
        openAIService.onResponseError = { [weak self] error in
            self?.textLabel.stringValue = "❌ Ошибка ResponseAPI:\n\n\(error)"
            self?.button.title = "Hello World"
        }
    }
    
    func setupGlobalHotkeys() {
        // Создаем хоткей Control + Option + Command + M
        hotKey = HotKey(key: .m, modifiers: [.control, .option, .command])
        
        // Обработчик нажатия
        hotKey?.keyDownHandler = { [weak self] in
            self?.audioRecorder.startRecording()
        }
        
        // Обработчик отпускания
        hotKey?.keyUpHandler = { [weak self] in
            self?.audioRecorder.stopRecording()
        }
    }
    
    @objc func buttonClicked() {
        let alert = NSAlert()
        alert.messageText = "Mic GPT"
        alert.informativeText = "Голосовой помощник с OpenAI транскрипцией\n\nИспользуйте хоткей Control + Option + Command + M для записи голоса"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Создаем приложение
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

