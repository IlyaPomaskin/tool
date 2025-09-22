import Foundation
import AppKit
import CoreGraphics

@MainActor
class ScreenshotCapture: NSObject {
    var ocrService: OCRService
    var onTextExtracted: ((String) -> Void)?
    
    override init() {
        self.ocrService = OCRService()
        super.init()
    }
    
    func startScreenshot() {
        // Используем системную команду для скриншота
        captureScreenshotWithSystemCommand()
    }
    
    private func captureScreenshotWithSystemCommand() {
        // Скрываем приложение
        NSApp.hide(nil)
        
        // Небольшая задержка
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Используем системную команду screencapture
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-c", "-x"]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // Показываем приложение обратно
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Сохраняем из буфера обмена и выполняем OCR
                    self.saveFromClipboardAndExtractText()
                }
            } catch {
                print("Ошибка выполнения screencapture: \(error)")
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    private func saveFromClipboardAndExtractText() {
        guard let pasteboard = NSPasteboard.general.data(forType: .tiff),
              let image = NSImage(data: pasteboard) else {
            print("Не удалось получить изображение из буфера обмена")
            return
        }
        
        // Выполняем OCR напрямую с изображением из буфера обмена
        Task {
            await extractTextFromScreenshot(image: image)
        }
    }
    
    private func extractTextFromScreenshot(image: NSImage) async {
        do {
            let extractedText = try await ocrService.extractText(from: image)
            print("Извлеченный текст: \(extractedText)")
            
            // Сохраняем текст в буфер обмена
            saveTextToClipboard(extractedText)
            
            // Вызываем callback с извлеченным текстом
            onTextExtracted?(extractedText)
            
        } catch {
            print("Ошибка OCR: \(error.localizedDescription)")
            let errorMessage = "❌ Ошибка распознавания текста: \(error.localizedDescription)"
            saveTextToClipboard(errorMessage)
            onTextExtracted?(errorMessage)
        }
    }
    
    private func saveTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("Текст сохранен в буфер обмена")
    }
    
}
