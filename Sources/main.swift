import AppKit
import HotKey
import OpenAI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var textLabel: NSTextField!
    var hotKey: HotKey?
    var screenshotHotKey: HotKey?
    var audioRecorder: AudioRecorder!
    var openAIService: OpenAIService!
    var screenshotCapture: ScreenshotCapture!
    
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
        
        // Создаем текстовое поле для отображения транскрипции
        textLabel = NSTextField(frame: NSRect(x: 50, y: 50, width: 400, height: 200))
        textLabel.stringValue = "Нажмите и удерживайте Control + Option + Command + M для записи голоса\n\nНажмите Control + Option + Command + B для создания скриншота\n\nТранскрипция появится здесь..."
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
        window.contentView?.addSubview(textLabel)
        
        // Показываем окно и выводим на передний план
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Инициализируем аудио рекордер
        setupAudioRecorder()
        
        // Настраиваем глобальные хоткеи
        setupGlobalHotkeys()
    }
    
    func setupAudioRecorder() {
        // Инициализируем сервисы
        audioRecorder = AudioRecorder()
        openAIService = OpenAIService()
        screenshotCapture = ScreenshotCapture()
    }
    
    func setupGlobalHotkeys() {
        // Создаем хоткей Control + Option + Command + M для записи
        hotKey = HotKey(key: .m, modifiers: [.control, .option, .command])
        
        // Обработчик нажатия для записи
        hotKey?.keyDownHandler = { [weak self] in
            self?.audioRecorder.startRecording()
        }
        
        // Обработчик отпускания для записи
        hotKey?.keyUpHandler = { [weak self] in
            Task {
                await self?.processRecording()
            }
        }
        
        // Создаем хоткей Control + Option + Command + B для скриншотов
        screenshotHotKey = HotKey(key: .b, modifiers: [.control, .option, .command])
        
        // Обработчик для скриншотов
        screenshotHotKey?.keyDownHandler = { [weak self] in
            self?.screenshotCapture.startScreenshot()
        }
    }
    
    func processRecording() async {
        guard let audioRecorder = audioRecorder,
              let openAIService = openAIService else { return }
        
        do {
            // Останавливаем запись и получаем URL файла
            let fileURL = audioRecorder.stopRecording()
            
            // Обновляем UI
            await MainActor.run {
                self.textLabel.stringValue = "🎤 Обработка аудио..."
            }
            
            // Транскрибируем аудио
            let transcription = try await openAIService.transcribeAudio(from: fileURL)
            
            // Обновляем UI с транскрипцией
            await MainActor.run {
                self.textLabel.stringValue = "🎤 Транскрипция:\n\n\(transcription)"
            }
            
            // Получаем ответ от AI
            let response = try await openAIService.callResponseAPI(with: transcription)
            
            // Обновляем UI с ответом
            await MainActor.run {
                self.textLabel.stringValue = "🤖 Ответ:\n\n\(response)"
            }
            
        } catch {
            // Обрабатываем ошибки
            await MainActor.run {
                self.textLabel.stringValue = "❌ Ошибка:\n\n\(error.localizedDescription)"
            }
        }
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

