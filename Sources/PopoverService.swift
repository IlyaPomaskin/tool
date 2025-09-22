import AppKit

// Service for creating and managing popover with message queue
@MainActor
class PopoverService {
    private var popover: NSPopover?
    private var messageQueue: [String] = []
    private var isShowing = false
    private var currentMessageTimer: Timer?
    private var isProcessingQueue = false
    private weak var button: NSButton?
    
    init() {
        setupPopover()
    }
    
    func setButton(_ button: NSButton) {
        self.button = button
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.animates = true
    }

    // Adds message to queue and starts queue processing
    func addMessage(_ message: String) {
        messageQueue.append(message)
        
        // If queue is not being processed, start processing
        if !isProcessingQueue {
            processMessageQueue()
        }
    }
    
    // Processes message queue sequentially
    private func processMessageQueue() {
        guard !messageQueue.isEmpty else {
            isProcessingQueue = false
            return
        }
        
        isProcessingQueue = true
        
        // Take first message from queue
        let currentMessage = messageQueue.removeFirst()
        
        // Show message
        showMessage(currentMessage)
        
        // Set timer for 3 seconds for current message
        currentMessageTimer?.invalidate()
        currentMessageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                // Hide current message
                self?.popover?.performClose(nil)
                self?.isShowing = false
                
                // Process next message if available
                self?.processMessageQueue()
            }
        }
    }
    
    // Shows specific message
    private func showMessage(_ text: String) {
        guard let popover = popover else { return }
        
        // Create custom view controller with click handling
        let viewController = PopoverViewController()
        viewController.onClick = { [weak self] in
            // On click, close current message and move to next
            self?.currentMessageTimer?.invalidate()
            self?.popover?.performClose(nil)
            self?.isShowing = false
            
            // If there are more messages, process them
            self?.processMessageQueue()
        }
        
        // Create container view with padding
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        
        // Adaptive colors for light/dark theme
        let isDarkMode = NSAppearance.currentDrawing().name == .darkAqua || NSAppearance.currentDrawing().name == .vibrantDark
        let backgroundColor = isDarkMode ? 
            NSColor.controlBackgroundColor.withAlphaComponent(0.9) : 
            NSColor.controlBackgroundColor.withAlphaComponent(0.95)
        let borderColor = isDarkMode ?
            NSColor.separatorColor.withAlphaComponent(0.4) :
            NSColor.separatorColor.withAlphaComponent(0.3)
        
        containerView.layer?.backgroundColor = backgroundColor.cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = borderColor.cgColor
        
        // Add adaptive shadow
        containerView.shadow = NSShadow()
        // In dark theme, shadow should be more visible
        let shadowAlpha: CGFloat = isDarkMode ? 0.4 : 0.2
        containerView.shadow?.shadowColor = NSColor.black.withAlphaComponent(shadowAlpha)
        containerView.shadow?.shadowOffset = NSSize(width: 0, height: -2)
        containerView.shadow?.shadowBlurRadius = 8
        
        // Create text view with beautiful font
        let textView = NSTextView()
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = false // Make text non-selectable
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textView.backgroundColor = NSColor.clear
        textView.textColor = NSColor.labelColor
        textView.alignment = .left
        
        // Remove text view margins
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        
        // Calculate popover size based on text
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let textSize = text.size(withAttributes: [.font: font])
        let lines = text.components(separatedBy: .newlines).count
        let lineHeight: CGFloat = 18
        
        // Sizes with padding
        let padding: CGFloat = 16
        
        // More accurate width calculation - consider maximum line length
        let maxLineWidth = text.components(separatedBy: .newlines)
            .map { $0.size(withAttributes: [.font: font]).width }
            .max() ?? textSize.width
        
        // More accurate height calculation
        let estimatedHeight = max(CGFloat(lines) * lineHeight, 20)
        
        // Adaptive minimum sizes depending on text length
        let minWidth: CGFloat = text.count < 20 ? 100 : 120
        let minHeight: CGFloat = lines == 1 ? 50 : 60
        
        let popoverSize = NSSize(
            width: min(max(maxLineWidth + padding * 2, minWidth), 300),
            height: min(max(estimatedHeight + padding * 2, minHeight), 200) // Increase maximum height
        )
        
        // Determine if text needs to be truncated and get display text
        let (displayText, isTextTruncated) = calculateTextFitting(
            text: text,
            popoverSize: popoverSize,
            padding: padding,
            lineHeight: lineHeight
        )
        
        textView.string = displayText
        
        // Configure container
        containerView.frame = NSRect(origin: .zero, size: popoverSize)
        
        // Configure text view with padding
        let textViewFrame = NSRect(
            x: padding,
            y: padding,
            width: popoverSize.width - padding * 2,
            height: popoverSize.height - padding * 2
        )
        textView.frame = textViewFrame
        
        // Add text view to container
        containerView.addSubview(textView)
        
        // Add gradient fade at bottom if text is truncated
        if isTextTruncated {
            addGradientFadeToContainer(containerView, popoverSize: popoverSize)
        }
        
        // Configure view controller
        viewController.view = containerView
        
        // Set content view controller
        popover.contentViewController = viewController
        popover.contentSize = popoverSize
        
        // Configure popover for system theme inheritance
        popover.appearance = nil // nil means system theme inheritance
        
        guard let button = self.button else {
            print("⚠️ Button not set in PopoverService")
            return
        }

        // Show popover next to menu bar icon
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isShowing = true
    }
    
    // Hides popover and clears queue
    private func hidePopover() {
        popover?.performClose(nil)
        messageQueue.removeAll()
        isShowing = false
        isProcessingQueue = false
        currentMessageTimer?.invalidate()
        currentMessageTimer = nil
    }
    
    func close() {
        hidePopover()
    }
    
    private func calculateTextFitting(
        text: String,
        popoverSize: NSSize,
        padding: CGFloat,
        lineHeight: CGFloat
    ) -> (displayText: String, isTruncated: Bool) {
        // Count number of lines in text
        let lines = text.components(separatedBy: .newlines).count
        
        // Calculate available space for text
        let availableTextHeight = popoverSize.height - padding * 2
        let maxLinesInPopover = Int(availableTextHeight / lineHeight)
        
        // Determine if text needs to be truncated
        let isTextTruncated = lines > maxLinesInPopover
        
        // Truncate text if it doesn't fit
        let displayText: String
        if isTextTruncated {
            // Take only lines that fit
            let textLines = text.components(separatedBy: .newlines)
            let visibleLines = Array(textLines.prefix(maxLinesInPopover - 1)) // -1 for "..."
            displayText = visibleLines.joined(separator: "\n") + "\n..."
        } else {
            displayText = text
        }
        
        return (displayText, isTextTruncated)
    }
    
    private func addGradientFadeToContainer(_ containerView: NSView, popoverSize: NSSize) {
        // Create custom view with gradient
        let gradientView = GradientFadeView()
        gradientView.frame = NSRect(
            x: 0,
            y: 0,
            width: popoverSize.width,
            height: 30
        )
        
        // Add gradient to container over text
        containerView.addSubview(gradientView)
    }
}

// Custom view controller for handling clicks in popover
class PopoverViewController: NSViewController {
    var onClick: (() -> Void)?
    
    override func loadView() {
        super.loadView()
        
        // Add click handler
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        view.addGestureRecognizer(clickGesture)
    }
    
    @objc private func handleClick() {
        onClick?()
    }
}

// Custom view for rendering gradient shadow
class GradientFadeView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Determine gradient colors based on theme
        let isDarkMode = NSAppearance.currentDrawing().name == .darkAqua || NSAppearance.currentDrawing().name == .vibrantDark
        let backgroundColor = isDarkMode ? 
            NSColor.controlBackgroundColor.withAlphaComponent(0.9) : 
            NSColor.controlBackgroundColor.withAlphaComponent(0.95)
        
        // Create gradient with NSGradient
        let colors = [
            backgroundColor.withAlphaComponent(0.0),
            backgroundColor.withAlphaComponent(0.1),
            backgroundColor.withAlphaComponent(0.25),
            backgroundColor.withAlphaComponent(0.45),
            backgroundColor.withAlphaComponent(0.65),
            backgroundColor.withAlphaComponent(0.8),
            backgroundColor.withAlphaComponent(0.9),
            backgroundColor
        ]
        
        let locations: [CGFloat] = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]
        
        guard let gradient = NSGradient(colors: colors, atLocations: locations, colorSpace: NSColorSpace.deviceRGB) else {
            return
        }
        
        // Draw gradient vertically
        let startPoint = NSPoint(x: bounds.midX, y: bounds.maxY)
        let endPoint = NSPoint(x: bounds.midX, y: bounds.minY)
        
        gradient.draw(from: startPoint, to: endPoint, options: [])
    }
}
