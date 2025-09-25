import Foundation
import AppKit
import CoreGraphics
import CoreFoundation

@MainActor
class ScreenshotCapture: NSObject {
    
    override init() {
        super.init()
    }

    // Common method for performing capture to temporary file
    private func performScreenshotCapture(arguments: [String], tempFilename: String) async throws -> NSImage? {
        // Create temporary file path
        let tempURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(tempFilename)
        
        // Add temp file path to arguments (remove -c flag for clipboard)
        var fileArguments = arguments.filter { $0 != "-c" }
        fileArguments.append(tempURL.path)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = fileArguments
        
        try process.run()
        process.waitUntilExit()
        
        // Check if file was created
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            print("Failed to create screenshot file at: \(tempURL.path)")
            return nil
        }
        
        // Load image from file
        guard let image = NSImage(contentsOf: tempURL) else {
            print("Failed to load image from file: \(tempURL.path)")
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
        
        return image
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
            return try await performScreenshotCapture(
                arguments: ["-i", "-x", "-t", "jpg"],
                tempFilename: "temp_screenshot_region_\(UUID().uuidString).jpg"
            )
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
            return try await performScreenshotCapture(
                arguments: ["-l", "\(windowID)", "-x", "-t", "jpg"],
                tempFilename: "temp_screenshot_window_\(UUID().uuidString).jpg"
            )
        } catch {
            print("Window capture error: \(error)")
            return nil
        }
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
}
