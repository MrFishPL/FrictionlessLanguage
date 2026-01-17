import AppKit

final class NotchPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setFrame(frame, display: true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class TransparentScrollView: NSScrollView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Pass mouse events through to the parent NotchView
        return nil
    }
}

final class NotchView: NSView {
    static let markerToken = "[tab]"
    private let maskLayer = CAShapeLayer()
    private let textView: NSTextView
    private let scrollView: TransparentScrollView
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    private var hoverTrackingArea: NSTrackingArea?
    private(set) var isHovering = false
    private var hoveredWordRange: NSRange?
    private let defaultTextColor = NSColor.white.withAlphaComponent(0.9)
    private let highlightTextColor = NSColor.systemBlue

    // Selection state
    private var isSelecting = false
    private var selectionAnchorRange: NSRange?
    private var selectedRange: NSRange?

    override init(frame frameRect: NSRect) {
        textView = NSTextView(frame: .zero)
        scrollView = TransparentScrollView(frame: .zero)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        layer?.mask = maskLayer

        textView.font = font
        textView.textColor = NSColor.white.withAlphaComponent(0.9)
        textView.alignment = .center
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.string = "Listening..."

        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        autoresizingMask = [.width, .height]

        let lineHeight = font.ascender - font.descender + font.leading
        let textHeight = ceil(lineHeight * AppConfig.visibleLines)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AppConfig.bottomPadding),
            scrollView.heightAnchor.constraint(equalToConstant: textHeight),
            scrollView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: AppConfig.topDeadArea),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func layout() {
        super.layout()
        updateTextLayout()
        updateMaskPath()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        hoverTrackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        sendPlayPauseKey()
        updateHoveredWord(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        sendPlayPauseKey()
        hoveredWordRange = nil
        isSelecting = false
        selectionAnchorRange = nil
        selectedRange = nil
        applyHighlight()
    }

    override func mouseMoved(with event: NSEvent) {
        if !isSelecting {
            updateHoveredWord(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convertEventToTextViewPoint(event)
        if let wordRange = wordRangeAtPoint(point) {
            isSelecting = true
            selectionAnchorRange = wordRange
            selectedRange = wordRange
            hoveredWordRange = nil
            applyHighlight()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelecting, let anchor = selectionAnchorRange else { return }

        let point = convertEventToTextViewPoint(event)
        if let currentWord = wordRangeAtPoint(point) {
            // Create a range spanning from anchor to current word
            let start = min(anchor.location, currentWord.location)
            let end = max(anchor.location + anchor.length, currentWord.location + currentWord.length)
            selectedRange = NSRange(location: start, length: end - start)
            applyHighlight()
        }
    }

    override func mouseUp(with event: NSEvent) {
        isSelecting = false
        // Selection stays visible
    }

    private func convertEventToTextViewPoint(_ event: NSEvent) -> NSPoint {
        let locationInWindow = event.locationInWindow
        let locationInView = scrollView.convert(locationInWindow, from: nil)
        return textView.convert(locationInView, from: scrollView)
    }

    private func updateHoveredWord(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        let locationInView = scrollView.convert(locationInWindow, from: nil)
        let locationInTextView = textView.convert(locationInView, from: scrollView)

        let newRange = wordRangeAtPoint(locationInTextView)
        if newRange != hoveredWordRange {
            hoveredWordRange = newRange
            applyWordHighlight()
        }
    }

    private func wordRangeAtPoint(_ point: NSPoint) -> NSRange? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        let textContainerOffset = CGPoint(
            x: textView.textContainerInset.width,
            y: textView.textContainerInset.height
        )
        let adjustedPoint = CGPoint(x: point.x - textContainerOffset.x, y: point.y - textContainerOffset.y)

        // Check if point is within the text bounds
        let textBounds = layoutManager.usedRect(for: textContainer)
        guard textBounds.contains(adjustedPoint) else { return nil }

        var fraction: CGFloat = 0
        let charIndex = layoutManager.characterIndex(for: adjustedPoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: &fraction)

        guard charIndex < textView.string.count else { return nil }

        // Get the actual glyph rect and check if point is inside it
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)

        // Expand check horizontally to include the character
        guard adjustedPoint.x >= glyphRect.minX && adjustedPoint.x <= glyphRect.maxX else { return nil }

        let string = textView.string as NSString

        // Check if we're on whitespace
        let char = string.character(at: charIndex)
        guard let scalar = Unicode.Scalar(char),
              !CharacterSet.whitespacesAndNewlines.contains(scalar) else {
            return nil
        }

        // Find word boundaries
        var start = charIndex
        var end = charIndex

        // Expand backwards
        while start > 0 {
            let prevChar = string.character(at: start - 1)
            if let scalar = Unicode.Scalar(prevChar),
               CharacterSet.whitespacesAndNewlines.contains(scalar) {
                break
            }
            start -= 1
        }

        // Expand forwards
        while end < string.length - 1 {
            let nextChar = string.character(at: end + 1)
            if let scalar = Unicode.Scalar(nextChar),
               CharacterSet.whitespacesAndNewlines.contains(scalar) {
                break
            }
            end += 1
        }

        return NSRange(location: start, length: end - start + 1)
    }

    private func applyWordHighlight() {
        applyHighlight()
    }

    private func applyHighlight() {
        guard let textStorage = textView.textStorage else { return }

        // Reset all text to default color
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.foregroundColor, value: defaultTextColor, range: fullRange)

        // Apply highlight to selection first (if any)
        if let range = selectedRange, range.location + range.length <= textStorage.length {
            textStorage.addAttribute(.foregroundColor, value: highlightTextColor, range: range)
        }

        // Apply highlight to hovered word (if no selection or hovering outside selection)
        if let range = hoveredWordRange, range.location + range.length <= textStorage.length {
            if selectedRange == nil {
                textStorage.addAttribute(.foregroundColor, value: highlightTextColor, range: range)
            }
        }
    }

    func getSelectedText() -> String? {
        guard let range = selectedRange else { return nil }
        let string = textView.string as NSString
        guard range.location + range.length <= string.length else { return nil }
        return string.substring(with: range)
    }

    func clearSelection() {
        selectedRange = nil
        selectionAnchorRange = nil
        applyHighlight()
    }

    private func sendPlayPauseKey() {
        // Use private MediaRemote framework to toggle play/pause
        typealias MRMediaRemoteSendCommandFunction = @convention(c) (UInt32, UnsafeRawPointer?) -> Bool

        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let sendCommandPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else {
            return
        }

        let sendCommand = unsafeBitCast(sendCommandPointer, to: MRMediaRemoteSendCommandFunction.self)
        // kMRTogglePlayPause = 2
        _ = sendCommand(2, nil)
    }

    func setText(_ text: String) {
        hoveredWordRange = nil
        selectedRange = nil
        selectionAnchorRange = nil
        isSelecting = false
        let displayText = text
        textView.alignment = .center
        let attributed = NSMutableAttributedString(
            string: displayText,
            attributes: [
                .font: font,
                .foregroundColor: defaultTextColor,
            ]
        )

        let marker = NotchView.markerToken
        if !marker.isEmpty {
            var searchRange = NSRange(location: 0, length: attributed.length)
            while true {
                let found = (attributed.string as NSString).range(of: marker, options: [], range: searchRange)
                if found.location == NSNotFound { break }
                let attachment = NSTextAttachment()
                attachment.attachmentCell = MarkerAttachmentCell()
                let replacement = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
                replacement.append(NSAttributedString(string: " ", attributes: [.font: font]))
                attributed.replaceCharacters(in: found, with: replacement)
                let nextLocation = found.location + replacement.length
                searchRange = NSRange(location: nextLocation, length: max(0, attributed.length - nextLocation))
            }
        }

        textView.textStorage?.setAttributedString(attributed)
        updateTextLayout()
    }

    private func updateTextLayout() {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        textView.textContainer?.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        textView.minSize = NSSize(width: width, height: 0)
        textView.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)

        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.frame = NSRect(x: 0, y: 0, width: width, height: textView.frame.height)
        textView.sizeToFit()

        let visibleHeight = ceil((font.ascender - font.descender + font.leading) * AppConfig.visibleLines)
        if let container = textView.textContainer,
           let layout = textView.layoutManager {
            layout.ensureLayout(for: container)
            let contentHeight = layout.usedRect(for: container).height
            let inset = max(0, (visibleHeight - contentHeight) / 2)
            textView.textContainerInset = NSSize(width: 0, height: inset)
            textView.frame = NSRect(x: 0, y: 0, width: width, height: max(visibleHeight, contentHeight + inset * 2))
        }

        textView.scrollToEndOfDocument(nil)
    }

    private func updateMaskPath() {
        let rect = bounds
        let bottomRadius: CGFloat = 14
        let bottomK: CGFloat = 0.55
        let path = CGMutablePath()

        // Top is flat with square corners, bottom is rounded.
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bottomRadius))
        path.addCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.minY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + bottomRadius * (1 - bottomK)),
            control2: CGPoint(x: rect.maxX - bottomRadius * (1 - bottomK), y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + bottomRadius),
            control1: CGPoint(x: rect.minX + bottomRadius * (1 - bottomK), y: rect.minY),
            control2: CGPoint(x: rect.minX, y: rect.minY + bottomRadius * (1 - bottomK))
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        maskLayer.path = path
    }
}

final class MarkerAttachmentCell: NSTextAttachmentCell {
    private let size = NSSize(width: 6, height: 6)

    override func cellSize() -> NSSize {
        size
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let rect = NSRect(
            x: cellFrame.minX,
            y: cellFrame.minY + (cellFrame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        NSColor.systemBlue.setFill()
        rect.fill()
    }
}
