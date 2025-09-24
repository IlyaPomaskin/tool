import Foundation
import AppKit
import CoreGraphics
import CoreFoundation

@MainActor
class ScreenshotCapture: NSObject {
    
    override init() {
        super.init()
    }

    // Common method for performing capture
    private func performScreenshotCapture(arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments
        
        try process.run()
        process.waitUntilExit()
    }
    
    private func getActiveWindowID() -> CGWindowID? {
        // Get list of all windows
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        var candidateWindows: [(CGWindowID, String, Double, Double)] = []
        
        // Collect all suitable windows
        for windowInfo in windowList {
            // Check that window belongs to another application (not ours)
            if let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
               ownerName != "mic-gpt" { // Exclude our application
                
                // Check that window is visible and has size
                if let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                   let width = bounds["Width"] as? Double,
                   let height = bounds["Height"] as? Double,
                   width > 100 && height > 100 { // Minimum window size
                    
                    // Check window level (exclude background windows)
                    if let layer = windowInfo[kCGWindowLayer as String] as? Int,
                       layer == 0 { // 0 = normal window
                        
                        if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
                            candidateWindows.append((windowID, ownerName, width, height))
                        }
                    }
                }
            }
        }
        
        // Sort windows by size (large windows have priority)
        candidateWindows.sort { $0.2 * $0.3 > $1.2 * $1.3 }
        
        // Return largest window (most likely the active window)
        if let bestWindow = candidateWindows.first {
            print("📱 Selected window: \(bestWindow.1), ID: \(bestWindow.0), size: \(Int(bestWindow.2))x\(Int(bestWindow.3))")
            return bestWindow.0
        }
        
        print("❌ No suitable windows found")
        return nil
    }
    
    func screenshotRegion() async -> NSImage? {
        do {
            // Use common method for performing capture
            try await performScreenshotCapture(
                arguments: ["-i", "-c", "-x"]
            )
            
            // Get image from clipboard
            return getImageFromClipboard()
        } catch {
            print("Screenshot capture error: \(error)")
            return nil
        }
    }
    
    func screenshotFocusedWindow(compress: Bool = true) async -> NSImage? {
        // Get active window ID immediately (without delays)
        guard let windowID = self.getActiveWindowID() else {
            print("❌ Failed to get active window ID")
            return nil
        }
        
        print("🔍 Capturing window with ID: \(windowID)")
        
        do {
            // Use common method for performing capture
            try await performScreenshotCapture(
                arguments: ["-l", "\(windowID)", "-c", "-x", "-t", "jpg"]
            )
            
            // Get image from clipboard
            guard let rawImage = getImageFromClipboard() else {
                return nil
            }

            let image = compress ? self.compressImage(rawImage) : rawImage

            // saveDebugScreenshot(image: image, filename: "debug_focused_window.png")

            return image
        } catch {
            print("Window capture error: \(error)")
            return nil
        }
    }

    private func getImageFromClipboard() -> NSImage? {
        guard let pasteboard = NSPasteboard.general.data(forType: .tiff),
              let image = NSImage(data: pasteboard) else {
            print("Failed to get image from clipboard")
            return nil
        }
        
        // saveDebugScreenshot(image: image, filename: "debug_screenshot.png")
        
        return image
    }
    
    private func saveDebugScreenshot(image: NSImage, filename: String) {
        // Convert to PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to convert image to PNG for debugging")
            return
        }
        
        // Save file
        let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            print("🔍 Debug screenshot saved: \(fileURL.path)")
        } catch {
            print("Error saving debug screenshot: \(error)")
        }
    }
    
    func compressImage(_ image: NSImage) -> NSImage {
        // Get image size
        let originalSize = image.size
        print("📏 Original image size: \(Int(originalSize.width))x\(Int(originalSize.height))")
        
        // Determine maximum size (OpenAI recommends up to 2048x2048)
        let maxDimension: CGFloat = 1024 // Reduce for better compression
        let scale: CGFloat
        
        if originalSize.width > originalSize.height {
            scale = min(maxDimension / originalSize.width, 1.0)
        } else {
            scale = min(maxDimension / originalSize.height, 1.0)
        }
        
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
        print("📏 New image size: \(Int(newSize.width))x\(Int(newSize.height))")
        
        // Create new image with reduced size using native methods
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        
        // Use high quality interpolation
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        
        resizedImage.unlockFocus()
        
        return resizedImage
    }
}
