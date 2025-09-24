import AppKit
import HotKey
import OpenAI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var recordingHotKey = HotKey(key: .m, modifiers: [.control, .option, .command])
    var openAIHotKey = HotKey(key: .v, modifiers: [.control, .option, .command])
    var translateHotKey = HotKey(key: .n, modifiers: [.control, .option, .command])
    var screenshotHotKey = HotKey(key: .b, modifiers: [.control, .option, .command])
    var audioRecorder = AudioRecorder()
    var openAIService = OpenAIService()
    var lmStudioService = LMStudioService(baseURL: Constants.LMStudio.defaultBaseURL, model: Constants.LMStudio.defaultModel)
    var whisperService = WhisperService(modelFileName: "ggml-large-v3-turbo.bin")
    var screenshotCapture = ScreenshotCapture()
    var ocrService = OCRService()
    // var capturedWindowImage: NSImage? = nil
    
    var statusItem: NSStatusItem!
    var menuBarMenu: NSMenu!
    var popoverService = PopoverService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalHotkeys()
        
        setupMenuBar()
    }
    
    func setupGlobalHotkeys() {
        var capturedWindowImage: NSImage? = nil

        recordingHotKey.keyDownHandler = { [weak self] in
            self?.audioRecorder.startRecording()
            
            Task {
                capturedWindowImage = await self?.screenshotCapture.screenshotFocusedWindow(compress: true)
            }
        }
        recordingHotKey.keyUpHandler = { [weak self] in
            Task {
                let transcription = await self?.processRecording(translate: false) ?? ""
                self?.popoverService.addMessage("🎤 Local Transcription:\n\n\(transcription)")
                self?.setClipboard(transcription)
                
                // Call LM Studio instead of OpenAI
                let response = await self?.callLMStudio(transcription: transcription) ?? ""
                self?.setClipboard(response)
                capturedWindowImage = nil
            }
        }

        openAIHotKey.keyDownHandler = { [weak self] in
            self?.audioRecorder.startRecording()
            
            Task {
                capturedWindowImage = await self?.screenshotCapture.screenshotFocusedWindow(compress: true)
            }
        }
        openAIHotKey.keyUpHandler = { [weak self] in
            Task {
                let transcription = await self?.processRecording(translate: false) ?? ""
                self?.popoverService.addMessage("🎤 Local Transcription:\n\n\(transcription)")
                self?.setClipboard(transcription)
                
                // Call OpenAI with image context
                let response = await self?.callOpenAI(transcription: transcription, image: capturedWindowImage) ?? ""
                self?.setClipboard(response)
                capturedWindowImage = nil
            }
        }

        screenshotHotKey.keyDownHandler = { [weak self] in
            Task {
                if let image = await self?.screenshotCapture.screenshotRegion() {
                    await self?.screenshotOcr(image)
                }
            }
        }

        translateHotKey.keyDownHandler = { [weak self] in
            Task {
                self?.audioRecorder.startRecording()
            }
        }
        translateHotKey.keyUpHandler = { [weak self] in
            Task {
                let transcription = await self?.processRecording(translate: false) ?? ""
                self?.popoverService.addMessage("🎤 Local Translation:\n\n\(transcription)")
                self?.setClipboard(transcription)
            }
        }
    }
    
    func processRecording(translate: Bool = false) async -> String {
        guard statusItem != nil else { return "" }
        
        let fileURL = audioRecorder.stopRecording()

        self.popoverService.addMessage("🎤 Processing audio...")
        
        let transcription = await whisperService.transcribe(from: fileURL, translate: translate)
        if transcription.isEmpty {
            self.popoverService.addMessage("🎤 No transcription available")
            return ""
        }

        self.popoverService.addMessage("🎤 Local Transcription:\n\n\(transcription)")

        return transcription
    }

    func callOpenAI(transcription: String, image: NSImage? = nil) async -> String {
        guard statusItem != nil else { return "" }
        
        let response: String
        do {
            if let image = image {
                response = try await openAIService.callResponseAPI(with: transcription, instructions: Constants.Prompts.translator, image: image)
            } else {
                response = try await openAIService.callResponseAPI(with: transcription, instructions: Constants.Prompts.assistant)
            }
        } catch {
            response = "Error: \(error.localizedDescription)"
        }
        
        self.popoverService.addMessage("🤖 Response:\n\n\(response)")
        return response
    }
    
    func callLMStudio(transcription: String) async -> String {
        guard statusItem != nil else { return "" }
        
        let response: String
        do {
            // Check if LM Studio is available first
            let isAvailable = await lmStudioService.checkAvailability()
            if !isAvailable {
                response = "❌ LM Studio not available. Make sure it's running on \(Constants.LMStudio.defaultBaseURL)"
            } else {
                response = try await lmStudioService.sendMessage(transcription, systemPrompt: Constants.Prompts.translator)
            }
        } catch {
            response = "Error: \(error.localizedDescription)"
        }
        
        self.popoverService.addMessage("🤖 LM Studio Response:\n\n\(response)")
        return response
    }
    
    func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Create icon from system symbol
        if let button = statusItem.button {
            // Use system microphone icon
            button.image = NSImage(systemSymbolName: "tuningfork", accessibilityDescription: "Mic GPT")
            button.image?.size = NSSize(width: 18, height: 18)
            button.target = self
            
            // Set button in PopoverService
            popoverService.setButton(button)
        }
        
        // Create menu
        menuBarMenu = NSMenu()
        
        // Title
        let titleItem = NSMenuItem(title: "Mic GPT", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menuBarMenu.addItem(titleItem)
        
        menuBarMenu.addItem(NSMenuItem.separator())
        
        // Voice recording with LM Studio
        let recordItem = NSMenuItem(title: "🎤 LM Studio: Control + Option + Command + M", action: nil, keyEquivalent: "")
        recordItem.target = self
        menuBarMenu.addItem(recordItem)
        
        // Voice recording with OpenAI
        let openAIItem = NSMenuItem(title: "🎤 OpenAI: Control + Option + Command + O", action: nil, keyEquivalent: "")
        openAIItem.target = self
        menuBarMenu.addItem(openAIItem)
        
        // Screenshot
        let screenshotItem = NSMenuItem(title: "📸 OCR: Control + Option + Command + B", action: nil, keyEquivalent: "")
        screenshotItem.target = self
        menuBarMenu.addItem(screenshotItem)
        
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

    private func screenshotOcr(_ image: NSImage) async {
        do {
            let extractedText = try await ocrService.extractText(from: image)
            print("Extracted text: \(extractedText)")
            
            setClipboard(extractedText)
            
            await MainActor.run {
                // Show popover with OCR results
                self.popoverService.addMessage("📸 Extracted text:\n\n\(extractedText)")
            }
        } catch {
            print("OCR error: \(error.localizedDescription)")
            let errorMessage = "❌ Text recognition error: \(error.localizedDescription)"
            
            await MainActor.run {
                self.popoverService.addMessage(errorMessage)
            }
        }
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

