import Foundation
import AppKit
import CoreGraphics
import CoreFoundation

@MainActor
class ScreenshotCapture: NSObject {
    
    override init() {
        super.init()
    }
    
    
    func screenshotFocusedWindow() async -> NSImage? {
        // Получаем ID активного окна сразу (без задержек)
        guard let windowID = self.getActiveWindowID() else {
            print("❌ Не удалось получить ID активного окна")
            return nil
        }
        
        print("🔍 Захватываем окно с ID: \(windowID)")
        
        do {
            // Используем общий метод для выполнения захвата
            try await performScreenshotCapture(
                arguments: ["-l", "\(windowID)", "-c", "-x", "-t", "jpg"]
            )
            
            // Получаем изображение из буфера обмена
            if let pasteboard = NSPasteboard.general.data(forType: .tiff),
               let image = NSImage(data: pasteboard) {
                
                // Сохраняем скриншот для отладки
                saveDebugScreenshot(image: image, filename: "debug_focused_window.png")
                
                return image
            } else {
                return nil
            }
        } catch {
            print("Ошибка захвата окна: \(error)")
            return nil
        }
    }

    // Общий метод для выполнения захвата
    private func performScreenshotCapture(arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments
        
        try process.run()
        process.waitUntilExit()
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
    
    func screenshotRegion() async -> NSImage? {
        do {
            // Используем общий метод для выполнения захвата
            try await performScreenshotCapture(
                arguments: ["-i", "-c", "-x"]
            )
            
            // Получаем изображение из буфера обмена
            return getImageFromClipboard()
        } catch {
            print("Ошибка захвата скриншота: \(error)")
            return nil
        }
    }
    
    private func getImageFromClipboard() -> NSImage? {
        guard let pasteboard = NSPasteboard.general.data(forType: .tiff),
              let image = NSImage(data: pasteboard) else {
            print("Не удалось получить изображение из буфера обмена")
            return nil
        }
        
        // Сохраняем скриншот для отладки
        saveDebugScreenshot(image: image, filename: "debug_screenshot.png")
        
        return image
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
    
    func compressImage(_ image: NSImage) -> NSImage? {
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
        
        return resizedImage
    }
}
