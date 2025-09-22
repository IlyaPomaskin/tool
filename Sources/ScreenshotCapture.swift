import Foundation
import AppKit
import CoreGraphics

@MainActor
class ScreenshotCapture: NSObject {
    override init() {
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
                    
                    // Сохраняем из буфера обмена
                    self.saveFromClipboard()
                }
            } catch {
                print("Ошибка выполнения screencapture: \(error)")
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    private func saveFromClipboard() {
        guard let pasteboard = NSPasteboard.general.data(forType: .tiff),
              let image = NSImage(data: pasteboard) else {
            print("Не удалось получить изображение из буфера обмена")
            return
        }
        
        // Конвертируем в PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Не удалось конвертировать изображение в PNG")
            return
        }
        
        // Сохраняем файл
        let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("screenshot.png")
        
        do {
            try pngData.write(to: fileURL)
            print("Скриншот сохранен: \(fileURL.path)")
        } catch {
            print("Ошибка сохранения скриншота: \(error)")
        }
    }
    
}
