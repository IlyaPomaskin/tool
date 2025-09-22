import AppKit

// Сервис для создания и управления popover с очередью сообщений
@MainActor
class PopoverService {
    private var popover: NSPopover?
    private var messageQueue: [String] = []
    private var isShowing = false
    private var currentMessageTimer: Timer?
    private var isProcessingQueue = false
    
    init() {
        setupPopover()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.animates = true
    }
    
    func showOCRResult(_ text: String, relativeTo button: NSButton) {
        addMessage("📸 Извлеченный текст:\n\n\(text)", relativeTo: button)
    }
    
    // Добавляет сообщение в очередь и запускает обработку очереди
    func addMessage(_ message: String, relativeTo button: NSButton) {
        messageQueue.append(message)
        
        // Если очередь не обрабатывается, начинаем обработку
        if !isProcessingQueue {
            processMessageQueue(relativeTo: button)
        }
    }
    
    // Обрабатывает очередь сообщений поочередно
    private func processMessageQueue(relativeTo button: NSButton) {
        guard !messageQueue.isEmpty else {
            isProcessingQueue = false
            return
        }
        
        isProcessingQueue = true
        
        // Берем первое сообщение из очереди
        let currentMessage = messageQueue.removeFirst()
        
        // Показываем сообщение
        showMessage(currentMessage, relativeTo: button)
        
        // Устанавливаем таймер на 3 секунды для текущего сообщения
        currentMessageTimer?.invalidate()
        currentMessageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                // Скрываем текущее сообщение
                self?.popover?.performClose(nil)
                self?.isShowing = false
                
                // Обрабатываем следующее сообщение если есть
                self?.processMessageQueue(relativeTo: button)
            }
        }
    }
    
    // Показывает конкретное сообщение
    private func showMessage(_ text: String, relativeTo button: NSButton) {
        guard let popover = popover else { return }
        
        // Создаем кастомный view controller с обработкой кликов
        let viewController = PopoverViewController()
        viewController.onClick = { [weak self] in
            // При клике закрываем текущее сообщение и переходим к следующему
            self?.currentMessageTimer?.invalidate()
            self?.popover?.performClose(nil)
            self?.isShowing = false
            
            // Если есть еще сообщения, обрабатываем их
            self?.processMessageQueue(relativeTo: button)
        }
        
        // Создаем контейнер view с отступами
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        
        // Адаптивные цвета для светлой/темной темы
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
        
        // Добавляем адаптивную тень
        containerView.shadow = NSShadow()
        // В темной теме тень должна быть более заметной
        let shadowAlpha: CGFloat = isDarkMode ? 0.4 : 0.2
        containerView.shadow?.shadowColor = NSColor.black.withAlphaComponent(shadowAlpha)
        containerView.shadow?.shadowOffset = NSSize(width: 0, height: -2)
        containerView.shadow?.shadowBlurRadius = 8
        
        // Создаем text view с красивым шрифтом
        let textView = NSTextView()
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = false // Делаем текст невыделяемым
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textView.backgroundColor = NSColor.clear
        textView.textColor = NSColor.labelColor
        textView.alignment = .left
        
        // Убираем отступы у text view
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        
        // Вычисляем размер popover на основе текста
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let textSize = text.size(withAttributes: [.font: font])
        let lines = text.components(separatedBy: .newlines).count
        let lineHeight: CGFloat = 18
        
        // Размеры с отступами
        let padding: CGFloat = 16
        
        // Более точный расчет ширины - учитываем максимальную длину строки
        let maxLineWidth = text.components(separatedBy: .newlines)
            .map { $0.size(withAttributes: [.font: font]).width }
            .max() ?? textSize.width
        
        // Более точный расчет высоты
        let estimatedHeight = max(CGFloat(lines) * lineHeight, 20)
        
        // Адаптивные минимальные размеры в зависимости от длины текста
        let minWidth: CGFloat = text.count < 20 ? 100 : 120
        let minHeight: CGFloat = lines == 1 ? 50 : 60
        
        let popoverSize = NSSize(
            width: min(max(maxLineWidth + padding * 2, minWidth), 300),
            height: min(max(estimatedHeight + padding * 2, minHeight), 200) // Увеличиваем максимальную высоту
        )
        
        // Определяем, нужно ли обрезать текст и получаем отображаемый текст
        let (displayText, isTextTruncated) = calculateTextFitting(
            text: text,
            popoverSize: popoverSize,
            padding: padding,
            lineHeight: lineHeight
        )
        
        textView.string = displayText
        
        // Настраиваем контейнер
        containerView.frame = NSRect(origin: .zero, size: popoverSize)
        
        // Настраиваем text view с отступами
        let textViewFrame = NSRect(
            x: padding,
            y: padding,
            width: popoverSize.width - padding * 2,
            height: popoverSize.height - padding * 2
        )
        textView.frame = textViewFrame
        
        // Добавляем text view в контейнер
        containerView.addSubview(textView)
        
        // Добавляем градиентную тень внизу, если текст обрезан
        if isTextTruncated {
            addGradientFadeToContainer(containerView, popoverSize: popoverSize)
        }
        
        // Настраиваем view controller
        viewController.view = containerView
        
        // Устанавливаем content view controller
        popover.contentViewController = viewController
        popover.contentSize = popoverSize
        
        // Настраиваем popover для наследования системной темы
        popover.appearance = nil // nil означает наследование системной темы
        
        // Показываем popover рядом с иконкой menu bar
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isShowing = true
    }
    
    // Скрывает popover и очищает очередь
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
        // Подсчитываем количество строк в тексте
        let lines = text.components(separatedBy: .newlines).count
        
        // Вычисляем доступное пространство для текста
        let availableTextHeight = popoverSize.height - padding * 2
        let maxLinesInPopover = Int(availableTextHeight / lineHeight)
        
        // Определяем, нужно ли обрезать текст
        let isTextTruncated = lines > maxLinesInPopover
        
        // Обрезаем текст если он не помещается
        let displayText: String
        if isTextTruncated {
            // Берем только те строки, которые помещаются
            let textLines = text.components(separatedBy: .newlines)
            let visibleLines = Array(textLines.prefix(maxLinesInPopover - 1)) // -1 для "..."
            displayText = visibleLines.joined(separator: "\n") + "\n..."
        } else {
            displayText = text
        }
        
        return (displayText, isTextTruncated)
    }
    
    private func addGradientFadeToContainer(_ containerView: NSView, popoverSize: NSSize) {
        // Создаем кастомный view с градиентом
        let gradientView = GradientFadeView()
        gradientView.frame = NSRect(
            x: 0,
            y: 0,
            width: popoverSize.width,
            height: 30
        )
        
        // Добавляем градиент в контейнер поверх текста
        containerView.addSubview(gradientView)
    }
}

// Кастомный view controller для обработки кликов в popover
class PopoverViewController: NSViewController {
    var onClick: (() -> Void)?
    
    override func loadView() {
        super.loadView()
        
        // Добавляем обработчик кликов
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        view.addGestureRecognizer(clickGesture)
    }
    
    @objc private func handleClick() {
        onClick?()
    }
}

// Кастомный view для отрисовки градиентной тени
class GradientFadeView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Определяем цвета для градиента в зависимости от темы
        let isDarkMode = NSAppearance.currentDrawing().name == .darkAqua || NSAppearance.currentDrawing().name == .vibrantDark
        let backgroundColor = isDarkMode ? 
            NSColor.controlBackgroundColor.withAlphaComponent(0.9) : 
            NSColor.controlBackgroundColor.withAlphaComponent(0.95)
        
        // Создаем градиент с NSGradient
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
        
        // Рисуем градиент вертикально
        let startPoint = NSPoint(x: bounds.midX, y: bounds.maxY)
        let endPoint = NSPoint(x: bounds.midX, y: bounds.minY)
        
        gradient.draw(from: startPoint, to: endPoint, options: [])
    }
}
