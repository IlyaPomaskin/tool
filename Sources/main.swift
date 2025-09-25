import AppKit
import HotKey
import OpenAI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var lmStudioAssistantHotKey = HotKey(key: .m, modifiers: [.control, .option, .command])
    var lmStudoTranslateHotKey = HotKey(key: .n, modifiers: [.control, .option, .command])
    var openAITranslatorHotKey = HotKey(key: .v, modifiers: [.control, .option, .command])
    var screenshotHotKey = HotKey(key: .b, modifiers: [.control, .option, .command])
    var audioRecorder = AudioRecorder()
    var openAIService = OpenAIService()
    var lmStudioService = LMStudioService(baseURL: Constants.LMStudio.defaultBaseURL, model: Constants.LMStudio.defaultModel)
    var whisperService = WhisperService(modelFileName: "ggml-large-v3-turbo.bin")
    var screenshotCapture = ScreenshotCapture()
    var ocrService = OCRService()
    
    var statusItem: NSStatusItem!
    var menuBarMenu: NSMenu!
    var popoverService = PopoverService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalHotkeys()
        
        setupMenuBar()
    }
    
    func setupGlobalHotkeys() {
        var capturedWindowImage: NSImage? = nil

        screenshotHotKey.keyDownHandler = { [weak self] in
            Task {
                if let image = await self?.screenshotCapture.screenshotRegion() {
                    let extractedText = try await self?.ocrService.extractText(from: image) ?? ""
                    self?.popoverService.addMessage("📸 OCR:\n\n\(extractedText)")
                    self?.setClipboard(extractedText)
                }
            }
        }

        lmStudioAssistantHotKey.keyDownHandler = { [weak self] in
            self?.setRecordingIcon()
            self?.audioRecorder.startRecording()
            
            Task {
                capturedWindowImage = await self?.screenshotCapture.screenshotFocusedWindow(compress: true)
            }
        }
        lmStudioAssistantHotKey.keyUpHandler = { [weak self] in
            Task {
                let transcription = await self?.processRecording(translate: false) ?? ""
                self?.setWaitingIcon()
                let response = try await self?.lmStudioService.sendMessage(
                    transcription,
                    systemPrompt: Constants.Prompts.assistant,
                    // image: capturedWindowImage
                ) ?? ""
                self?.setIdleIcon()
                self?.popoverService.addMessage("🎤 LM Assistant:\n\n\(response)")
                self?.setClipboard(response)
                capturedWindowImage = nil
            }
        }

        lmStudoTranslateHotKey.keyDownHandler = { [weak self] in
            Task {
                self?.setRecordingIcon()
                self?.audioRecorder.startRecording()

                capturedWindowImage = await self?.screenshotCapture.screenshotFocusedWindow(compress: true)
            }
        }
        lmStudoTranslateHotKey.keyUpHandler = { [weak self] in
            Task {
                let transcription = await self?.processRecording(translate: false) ?? ""
                self?.setWaitingIcon()
                let response = try await self?.lmStudioService.sendMessage(
                    transcription,
                    systemPrompt: Constants.Prompts.translator,
                    // image: capturedWindowImage
                ) ?? ""
                self?.setIdleIcon()
                self?.popoverService.addMessage("🎤 LM Translator:\n\n\(response)")
                self?.setClipboard(response)
                capturedWindowImage = nil
            }
        }

        openAITranslatorHotKey.keyDownHandler = { [weak self] in
            self?.setRecordingIcon()
            self?.audioRecorder.startRecording()
            
            Task {
                capturedWindowImage = await self?.screenshotCapture.screenshotFocusedWindow(compress: true)
            }
        }
        openAITranslatorHotKey.keyUpHandler = { [weak self] in
            Task {
                let transcription = await self?.processRecording(translate: false) ?? ""
                self?.setWaitingIcon()
                let response = await self?.callOpenAITranslator(transcription: transcription, image: capturedWindowImage) ?? ""
                self?.setIdleIcon()
                self?.popoverService.addMessage("🎤 OpenAI Assistant:\n\n\(response)")
                self?.setClipboard(response)
                capturedWindowImage = nil
            }
        }
    }
    
    func processRecording(translate: Bool = false) async -> String {
        let fileURL = audioRecorder.stopRecording()

        let transcription = await whisperService.transcribe(from: fileURL, translate: translate)

        return transcription
    }

    func callOpenAITranslator(transcription: String, image: NSImage? = nil) async -> String {
        let response: String
        do {
            if let image = image {
                response = try await openAIService.callResponseAPI(with: transcription, instructions: Constants.Prompts.translator, image: image)
            } else {
                response = try await openAIService.callResponseAPI(with: transcription, instructions: Constants.Prompts.translator)
            }
        } catch {
            response = "Error: \(error.localizedDescription)"
        }
        
        return response
    }
    
    func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Create icon from system symbol
        if let button = statusItem.button {
            // Use system microphone icon
            setIdleIcon()
            button.target = self
            
            // Set button in PopoverService
            popoverService.setButton(button)
        }
        
        setupMenu()
    }
    
    private func setIdleIcon() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tuningfork", accessibilityDescription: "Mic GPT")
            button.image?.size = NSSize(width: 18, height: 18)
        }
    }
    
    private func setRecordingIcon() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording...")
            button.image?.size = NSSize(width: 18, height: 18)
            // Make it red to indicate recording
            button.image?.isTemplate = false
        }
    }
    
    private func setWaitingIcon() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Processing...")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }
    }
    
    private func setupMenu() {
        // Create menu
        menuBarMenu = NSMenu()
        
        // Title
        let titleItem = NSMenuItem(title: "Mic GPT", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menuBarMenu.addItem(titleItem)
        
        menuBarMenu.addItem(NSMenuItem.separator())
        
        // Exit
        let quitItem = NSMenuItem(title: "Exit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menuBarMenu.addItem(quitItem)
        
        // Set menu
        statusItem.menu = menuBarMenu
    }

    func setClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Don't close the app, keep it in menu bar
    }
}


// Create application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

