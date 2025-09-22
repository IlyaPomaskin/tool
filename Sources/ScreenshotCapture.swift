import Foundation
import AppKit
import CoreGraphics
import CoreFoundation

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
    
    func captureFocusedWindow() async -> NSImage? {
        return await withCheckedContinuation { continuation in
            // Получаем ID активного окна сразу (без задержек)
            if let windowID = self.getActiveWindowID() {
                print("🔍 Захватываем окно с ID: \(windowID)")
                
                // Скрываем приложение только на время захвата
                NSApp.hide(nil)
                
                // Минимальная задержка для скрытия приложения
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Используем системную команду screencapture с конкретным window ID и сжатием
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    process.arguments = ["-l", "\(windowID)", "-c", "-x", "-t", "jpg"] // -t jpg для сжатия
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        
                        // Показываем приложение обратно
                        DispatchQueue.main.async {
                            NSApp.activate(ignoringOtherApps: true)
                            
                            // Получаем изображение из буфера обмена
                            if let pasteboard = NSPasteboard.general.data(forType: .tiff),
                               let image = NSImage(data: pasteboard) {
                                
                                // Сохраняем скриншот для отладки
                                self.saveDebugScreenshot(image: image, filename: "debug_focused_window.png")
                                
                                continuation.resume(returning: image)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                    } catch {
                        print("Ошибка выполнения screencapture: \(error)")
                        DispatchQueue.main.async {
                            NSApp.activate(ignoringOtherApps: true)
                            continuation.resume(returning: nil)
                        }
                    }
                }
            } else {
                print("❌ Не удалось получить ID активного окна")
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func getActiveWindowID() -> CGWindowID? {
        // Получаем список всех окон
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        var candidateWindows: [(CGWindowID, String, Double, Double)] = []
        
        // Собираем все подходящие окна
        for windowInfo in windowList {
            // Проверяем, что окно принадлежит другому приложению (не нашему)
            if let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
               ownerName != "mic-gpt" { // Исключаем наше приложение
                
                // Проверяем, что окно видимо и имеет размер
                if let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                   let width = bounds["Width"] as? Double,
                   let height = bounds["Height"] as? Double,
                   width > 100 && height > 100 { // Минимальный размер окна
                    
                    // Проверяем уровень окна (исключаем фоновые окна)
                    if let layer = windowInfo[kCGWindowLayer as String] as? Int,
                       layer == 0 { // 0 = обычное окно
                        
                        if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
                            candidateWindows.append((windowID, ownerName, width, height))
                        }
                    }
                }
            }
        }
        
        // Сортируем окна по размеру (большие окна имеют приоритет)
        candidateWindows.sort { $0.2 * $0.3 > $1.2 * $1.3 }
        
        // Возвращаем самое большое окно (скорее всего это активное окно)
        if let bestWindow = candidateWindows.first {
            print("📱 Выбрано окно: \(bestWindow.1), ID: \(bestWindow.0), размер: \(Int(bestWindow.2))x\(Int(bestWindow.3))")
            return bestWindow.0
        }
        
        print("❌ Не найдено подходящих окон")
        return nil
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
        
        // Сохраняем скриншот для отладки
        saveDebugScreenshot(image: image, filename: "debug_screenshot.png")
        
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
    
    private func saveDebugScreenshot(image: NSImage, filename: String) {
        // Конвертируем в PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Не удалось конвертировать изображение в PNG для отладки")
            return
        }
        
        // Сохраняем файл
        let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            print("🔍 Отладочный скриншот сохранен: \(fileURL.path)")
        } catch {
            print("Ошибка сохранения отладочного скриншота: \(error)")
        }
    }
    
    func compressImageForOpenAI(_ image: NSImage) -> NSImage? {
        // Получаем размер изображения
        let originalSize = image.size
        print("📏 Оригинальный размер изображения: \(Int(originalSize.width))x\(Int(originalSize.height))")
        
        // Определяем максимальный размер (OpenAI рекомендует до 2048x2048)
        let maxDimension: CGFloat = 1024 // Уменьшаем для лучшего сжатия
        let scale: CGFloat
        
        if originalSize.width > originalSize.height {
            scale = min(maxDimension / originalSize.width, 1.0)
        } else {
            scale = min(maxDimension / originalSize.height, 1.0)
        }
        
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
        print("📏 Новый размер изображения: \(Int(newSize.width))x\(Int(newSize.height))")
        
        // Создаем новое изображение с уменьшенным размером используя нативные методы
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        
        // Используем высокое качество интерполяции
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        
        resizedImage.unlockFocus()
        
        // Сохраняем сжатую версию для отладки
        saveCompressedDebugScreenshot(resizedImage, filename: "debug_compressed_window.jpg")
        
        return resizedImage
    }
    
    private func saveCompressedDebugScreenshot(_ image: NSImage, filename: String) {
        // Конвертируем в JPEG с сжатием
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("Не удалось конвертировать изображение для сжатия")
            return
        }
        
        // Используем JPEG с качеством 0.7 (хороший баланс между качеством и размером)
        let compressionProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: 0.7
        ]
        
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: compressionProperties) else {
            print("Не удалось создать JPEG данные")
            return
        }
        
        // Сохраняем файл
        let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(filename)
        
        do {
            try jpegData.write(to: fileURL)
            let sizeKB = jpegData.count / 1024
            print("🗜️ Сжатый отладочный скриншот сохранен: \(fileURL.path) (\(sizeKB)KB)")
        } catch {
            print("Ошибка сохранения сжатого скриншота: \(error)")
        }
    }
    
}
