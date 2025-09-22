import AppKit
import HotKey
import OpenAI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var recordingHotKey = HotKey(key: .m, modifiers: [.control, .option, .command])
    var screenshotHotKey = HotKey(key: .b, modifiers: [.control, .option, .command])
    var audioRecorder = AudioRecorder()
    var openAIService = OpenAIService()
    var screenshotCapture = ScreenshotCapture()
    var ocrService = OCRService()
    var capturedWindowImage: NSImage?
    
    var statusItem: NSStatusItem!
    var menuBarMenu: NSMenu!
    var popoverService = PopoverService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalHotkeys()
        
        setupMenuBar()
    }
    
    func setupGlobalHotkeys() {
        recordingHotKey.keyDownHandler = { [weak self] in
            // Начинаем запись звука сразу же
            self?.audioRecorder.startRecording()
            
            // Захватываем активное окно параллельно
            Task {
                self?.capturedWindowImage = await self?.screenshotCapture.screenshotFocusedWindow(compress: true)
            }
        }
        
        recordingHotKey.keyUpHandler = { [weak self] in
            Task {
                await self?.processRecording()
            }
        }

        screenshotHotKey.keyDownHandler = { [weak self] in
            Task {
                if let image = await self?.screenshotCapture.screenshotRegion() {
                    await self?.processScreenshotImage(image)
                }
            }
        }
    }
    
    func processRecording() async {
        guard let statusItem = statusItem,
              let button = statusItem.button else { return }
        
        do {
            // Останавливаем запись и получаем URL файла
            let fileURL = audioRecorder.stopRecording()
            
            // Показываем сообщение об обработке
            self.popoverService.addMessage("🎤 Обработка аудио...", relativeTo: button)
            
            // Транскрибируем аудио
            let transcription = try await openAIService.transcribeAudio(from: fileURL)
            
            // Показываем транскрипцию
            self.popoverService.addMessage("🎤 Транскрипция:\n\n\(transcription)", relativeTo: button)
            
            // Получаем ответ от AI (с изображением если есть)
            let response: String

            if let windowImage = capturedWindowImage {
                response = try await openAIService.callResponseAPI(with: transcription, instructions: Constants.Prompts.translator, image: windowImage)
            } else {
                response = try await openAIService.callResponseAPI(with: transcription)
            }

            self.popoverService.addMessage("🤖 Ответ:\n\n\(response)", relativeTo: button)
            self.capturedWindowImage = nil
            
        } catch {
            self.popoverService.addMessage("❌ Ошибка:\n\n\(error.localizedDescription)", relativeTo: button)
        }
    }
    
    
    func setupMenuBar() {
        // Создаем status item в menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Создаем иконку из системного символа
        if let button = statusItem.button {
            // Используем системную иконку микрофона
            button.image = NSImage(systemSymbolName: "tuningfork", accessibilityDescription: "Mic GPT")
            button.image?.size = NSSize(width: 18, height: 18)
            button.target = self
        }
        
        // Создаем меню
        menuBarMenu = NSMenu()
        
        // Заголовок
        let titleItem = NSMenuItem(title: "Mic GPT", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menuBarMenu.addItem(titleItem)
        
        menuBarMenu.addItem(NSMenuItem.separator())
        
        // Запись голоса
        let recordItem = NSMenuItem(title: "🎤 GPT: Control + Option + Command + M", action: nil, keyEquivalent: "")
        recordItem.target = self
        menuBarMenu.addItem(recordItem)
        
        // Скриншот
        let screenshotItem = NSMenuItem(title: "📸 OCR: Control + Option + Command + B", action: nil, keyEquivalent: "")
        screenshotItem.target = self
        menuBarMenu.addItem(screenshotItem)
        
        menuBarMenu.addItem(NSMenuItem.separator())
        
        // Выход
        let quitItem = NSMenuItem(title: "Выход", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menuBarMenu.addItem(quitItem)
        
        // Устанавливаем меню
        statusItem.menu = menuBarMenu
    }

    private func processScreenshotImage(_ image: NSImage) async {
        do {
            let extractedText = try await ocrService.extractText(from: image)
            print("Извлеченный текст: \(extractedText)")
            
            // Сохраняем текст в буфер обмена
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(extractedText, forType: .string)
            
            await MainActor.run {
                // Показываем popover с результатами OCR
                if let button = self.statusItem.button {
                    self.popoverService.showOCRResult(extractedText, relativeTo: button)
                }
            }
        } catch {
            print("Ошибка OCR: \(error.localizedDescription)")
            let errorMessage = "❌ Ошибка распознавания текста: \(error.localizedDescription)"
            
            await MainActor.run {
                if let button = self.statusItem.button {
                    self.popoverService.showOCRResult(errorMessage, relativeTo: button)
                }
            }
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Не закрываем приложение, оставляем в menu bar
    }
}


// Создаем приложение
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

