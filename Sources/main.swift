import AppKit
import HotKey
import OpenAI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var recordingHotKey = HotKey(key: .m, modifiers: [.control, .option, .command])
    var screenshotHotKey = HotKey(key: .b, modifiers: [.control, .option, .command])
    var audioRecorder = AudioRecorder()
    var openAIService = OpenAIService()
    var whisperService = WhisperService(modelFileName: "ggml-large-v3-turbo-q8_0.bin")
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
            // Start audio recording immediately
            self?.audioRecorder.startRecording()
            
            // Capture active window in parallel
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
                    await self?.screenshotOcr(image)
                }
            }
        }
    }
    
    func processRecording() async {
        guard statusItem != nil else { return }
        
        do {
            let fileURL = audioRecorder.stopRecording()

            self.popoverService.addMessage("🎤 Processing audio...")
            
            let transcription = try await whisperService.transcribe(from: fileURL)
            
            if transcription.isEmpty {
                self.popoverService.addMessage("🎤 No transcription available")
                return
            } 

            self.popoverService.addMessage("🎤 Local Transcription:\n\n\(transcription)")

            let response: String
            if let windowImage = capturedWindowImage {
                response = try await openAIService.callResponseAPI(with: transcription, instructions: Constants.Prompts.translator, image: windowImage)
            } else {
                response = try await openAIService.callResponseAPI(with: transcription)
            }
            self.popoverService.addMessage("🤖 Response:\n\n\(response)")

            self.capturedWindowImage = nil
            
        } catch {
            self.popoverService.addMessage("❌ Error:\n\n\(error.localizedDescription)")
        }
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
        
        // Voice recording
        let recordItem = NSMenuItem(title: "🎤 GPT: Control + Option + Command + M", action: nil, keyEquivalent: "")
        recordItem.target = self
        menuBarMenu.addItem(recordItem)
        
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

    private func screenshotOcr(_ image: NSImage) async {
        do {
            let extractedText = try await ocrService.extractText(from: image)
            print("Extracted text: \(extractedText)")
            
            // Save text to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(extractedText, forType: .string)
            
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

