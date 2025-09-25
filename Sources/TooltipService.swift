import AppKit
import SwiftUI

// MARK: -  Tooltip Service
@MainActor
class TooltipService {
    private weak var statusButton: NSStatusBarButton?
    private var tooltipWindow: NSWindow?
    private var autoHideTimer: Timer?
    
    func setStatusButton(_ button: NSStatusBarButton) {
        self.statusButton = button
    }
    
    func showTooltip(_ message: String, title: String) {
        guard let button = statusButton,
              let buttonWindow = button.window else {
            return
        }

        let tooltip = TooltipInfo(
            title: title,
            description: message,
            duration: 4.0
        )

        let tooltipView = TooltipView(tooltip: tooltip) { [weak self] in
            self?.hideCurrentTooltip()
        }
        
        let hostingView = NSHostingView(rootView: tooltipView)
        hostingView.frame = CGRect(origin: .zero, size: CGSize(width: 300, height: 160))
        
        tooltipWindow = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        tooltipWindow?.contentView = hostingView
        tooltipWindow?.backgroundColor = .clear
        tooltipWindow?.isOpaque = false
        tooltipWindow?.level = .floating
        tooltipWindow?.ignoresMouseEvents = false
        
        // Position tooltip near status bar button
        let buttonFrame = button.convert(button.bounds, to: nil)
        let buttonScreenFrame = buttonWindow.convertToScreen(buttonFrame)
        
        let tooltipX = buttonScreenFrame.midX - hostingView.frame.width / 2
        let tooltipY = buttonScreenFrame.minY - hostingView.frame.height - 10
        
        tooltipWindow?.setFrameOrigin(CGPoint(x: tooltipX, y: tooltipY))
        tooltipWindow?.makeKeyAndOrderFront(nil)
        
        // Auto-hide after duration
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: tooltip.duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideCurrentTooltip()
            }
        }
    }
    
    private func hideCurrentTooltip() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        tooltipWindow?.orderOut(nil)
        tooltipWindow = nil
    }
}

// MARK: - Tooltip Info Model
struct TooltipInfo {
    let title: String
    let description: String  
    let duration: TimeInterval
}

// MARK: -  Tooltip SwiftUI View
struct TooltipView: View {
    let tooltip: TooltipInfo
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tooltip.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            Text(tooltip.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onAppear {
            isVisible = true
        }
    }
}
