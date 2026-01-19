import AppKit

final class SavedWordsCoordinator {
    static let shared = SavedWordsCoordinator()

    fileprivate var windowController: SavedWordsWindowController?

    private init() {}

    func showWindow() {
        if let existing = windowController, existing.window?.isVisible == true {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = SavedWordsWindowController()
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class SavedWordsWindowController: NSWindowController, NSWindowDelegate {
    private let palette = SetupPalette()
    private var stackView: NSStackView!
    private var emptyStateView: NSView!
    private var scrollView: NSScrollView!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 450, height: 350)
        window.center()

        super.init(window: window)
        window.delegate = self
        setupContent()
        loadFragments()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        guard let window else { return }

        let background = SetupBackgroundView(palette: palette)
        background.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = background

        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = palette.cardBackground.cgColor
        card.layer?.cornerRadius = 16
        card.layer?.shadowColor = palette.cardShadow.cgColor
        card.layer?.shadowOpacity = 0.25
        card.layer?.shadowRadius = 18
        card.layer?.shadowOffset = CGSize(width: 0, height: -6)
        card.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(card)

        // Title
        let titleLabel = NSTextField(labelWithString: "Saved Words")
        titleLabel.font = palette.titleFont
        titleLabel.textColor = palette.titleColor

        // Close button
        let closeButton = PaddedButton(title: "Close", target: self, action: #selector(closeWindow))
        styleSecondaryButton(closeButton)

        let titleRow = NSStackView(views: [titleLabel, closeButton])
        titleRow.orientation = .horizontal
        titleRow.distribution = .equalSpacing
        titleRow.alignment = .centerY
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Your translated fragments")
        subtitleLabel.font = palette.bodyFont
        subtitleLabel.textColor = palette.subtitleColor

        // Header stack
        let headerStack = NSStackView(views: [titleRow, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(headerStack)

        // Scroll view for word list
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Stack view for word cards
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.documentView = stackView
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        card.addSubview(scrollView)

        // Empty state
        emptyStateView = createEmptyStateView()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24),
            card.topAnchor.constraint(equalTo: background.topAnchor, constant: 24),
            card.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -24),

            headerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            headerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            headerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 26),

            titleRow.leadingAnchor.constraint(equalTo: headerStack.leadingAnchor),
            titleRow.trailingAnchor.constraint(equalTo: headerStack.trailingAnchor),

            scrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            scrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 20),
            scrollView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28),

            stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: clipView.topAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 20),
        ])
    }

    private func createEmptyStateView() -> NSView {
        let container = NSView()

        let titleLabel = NSTextField(labelWithString: "No saved words yet")
        titleLabel.font = NSFont(name: "Avenir Next Medium", size: 16) ?? NSFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = palette.labelColor
        titleLabel.alignment = .center

        let subtitleLabel = NSTextField(labelWithString: "Select text in the caption panel to translate and save")
        subtitleLabel.font = palette.bodyFont
        subtitleLabel.textColor = palette.subtitleColor
        subtitleLabel.alignment = .center

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
        ])

        return container
    }

    private func loadFragments() {
        let fragments = SavedFragmentStore.shared.load()
        updateUI(with: fragments)
    }

    private func updateUI(with fragments: [SavedFragment]) {
        // Clear existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if fragments.isEmpty {
            emptyStateView.isHidden = false
            scrollView.isHidden = true
        } else {
            emptyStateView.isHidden = true
            scrollView.isHidden = false

            for fragment in fragments {
                let rowView = SavedWordRowView(fragment: fragment, palette: palette)
                rowView.onDelete = { [weak self] in
                    self?.deleteFragment(fragment)
                }
                rowView.translatesAutoresizingMaskIntoConstraints = false
                stackView.addArrangedSubview(rowView)
                rowView.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            }
        }
    }

    private func deleteFragment(_ fragment: SavedFragment) {
        var fragments = SavedFragmentStore.shared.load()
        fragments.removeAll { $0.id == fragment.id }
        SavedFragmentStore.shared.save(fragments)

        // Animate removal
        if let rowView = stackView.arrangedSubviews.first(where: { ($0 as? SavedWordRowView)?.fragment.id == fragment.id }) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                rowView.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                rowView.removeFromSuperview()
                if self?.stackView.arrangedSubviews.isEmpty == true {
                    self?.updateUI(with: [])
                }
            })
        }
    }

    @objc private func closeWindow() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        SavedWordsCoordinator.shared.windowController = nil
    }

    private func styleSecondaryButton(_ button: NSButton) {
        button.isBordered = false
        button.font = palette.buttonFont
        button.wantsLayer = true
        button.layer?.cornerRadius = 9
        button.layer?.borderWidth = 1
        button.layer?.borderColor = palette.secondaryBorder.cgColor
        button.layer?.backgroundColor = palette.secondaryBackground.cgColor
        button.contentTintColor = palette.secondaryText
        if let padded = button as? PaddedButton {
            padded.contentInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        }
    }
}


final class SavedWordRowView: NSView {
    let fragment: SavedFragment
    var onDelete: (() -> Void)?

    private let palette: SetupPalette
    private let deleteButton: PaddedButton
    private var trackingArea: NSTrackingArea?

    init(fragment: SavedFragment, palette: SetupPalette) {
        self.fragment = fragment
        self.palette = palette
        self.deleteButton = PaddedButton(title: "Delete", target: nil, action: nil)
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1).cgColor
        layer?.cornerRadius = 10

        // Original text
        let originalLabel = NSTextField(labelWithString: "\"\(fragment.originalText)\"")
        originalLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 14) ?? NSFont.systemFont(ofSize: 14, weight: .semibold)
        originalLabel.textColor = palette.titleColor
        originalLabel.lineBreakMode = .byTruncatingTail
        originalLabel.maximumNumberOfLines = 1

        // Translation
        let translationLabel = NSTextField(labelWithString: "\u{2192} \(fragment.translationText)")
        translationLabel.font = NSFont(name: "Avenir Next Medium", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .medium)
        translationLabel.textColor = palette.accent
        translationLabel.lineBreakMode = .byTruncatingTail
        translationLabel.maximumNumberOfLines = 1

        // Context with highlighted fragment
        let contextLabel = NSTextField(labelWithString: "")
        contextLabel.attributedStringValue = createContextAttributedString()
        contextLabel.lineBreakMode = .byTruncatingTail
        contextLabel.maximumNumberOfLines = 1

        // Delete button
        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)
        deleteButton.alphaValue = 0
        styleDeleteButton()

        // Top row with original text and delete button
        let topRow = NSStackView(views: [originalLabel, deleteButton])
        topRow.orientation = .horizontal
        topRow.distribution = .fill
        topRow.alignment = .centerY
        topRow.spacing = 8
        originalLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        deleteButton.setContentHuggingPriority(.required, for: .horizontal)

        // Main stack
        let stack = NSStackView(views: [topRow, translationLabel, contextLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            topRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func styleDeleteButton() {
        deleteButton.isBordered = false
        deleteButton.font = NSFont(name: "Avenir Next Medium", size: 11) ?? NSFont.systemFont(ofSize: 11, weight: .medium)
        deleteButton.wantsLayer = true
        deleteButton.layer?.cornerRadius = 6
        deleteButton.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
        deleteButton.contentTintColor = NSColor.systemRed
        deleteButton.contentInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
    }

    private func createContextAttributedString() -> NSAttributedString {
        guard !fragment.contextText.isEmpty else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Avenir Next Italic", size: 12) ?? NSFont.systemFont(ofSize: 12),
                .foregroundColor: palette.subtitleColor
            ]
            return NSAttributedString(string: "No context available", attributes: attrs)
        }

        let context = fragment.contextText
        let original = fragment.originalText

        // Truncate context around the highlighted fragment (max ~60 chars on each side)
        let maxContextLength = 80
        let truncatedContext: String
        let highlightRange: Range<String.Index>?

        if let range = context.range(of: original, options: .caseInsensitive) {
            let startDistance = context.distance(from: context.startIndex, to: range.lowerBound)
            let endDistance = context.distance(from: range.upperBound, to: context.endIndex)

            var prefix = ""
            var suffix = ""

            if startDistance > maxContextLength / 2 {
                let prefixStart = context.index(range.lowerBound, offsetBy: -(maxContextLength / 2))
                prefix = "..." + String(context[prefixStart..<range.lowerBound])
            } else {
                prefix = String(context[context.startIndex..<range.lowerBound])
            }

            if endDistance > maxContextLength / 2 {
                let suffixEnd = context.index(range.upperBound, offsetBy: maxContextLength / 2)
                suffix = String(context[range.upperBound..<suffixEnd]) + "..."
            } else {
                suffix = String(context[range.upperBound..<context.endIndex])
            }

            truncatedContext = prefix + String(context[range]) + suffix
            let highlightStart = truncatedContext.index(truncatedContext.startIndex, offsetBy: prefix.count)
            let highlightEnd = truncatedContext.index(highlightStart, offsetBy: original.count)
            highlightRange = highlightStart..<highlightEnd
        } else {
            // Original not found in context, just truncate
            if context.count > maxContextLength {
                truncatedContext = String(context.prefix(maxContextLength)) + "..."
            } else {
                truncatedContext = context
            }
            highlightRange = nil
        }

        let baseFont = NSFont(name: "Avenir Next", size: 12) ?? NSFont.systemFont(ofSize: 12)
        let boldFont = NSFont(name: "Avenir Next Demi Bold", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .semibold)

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: palette.subtitleColor
        ]

        let highlightAttrs: [NSAttributedString.Key: Any] = [
            .font: boldFont,
            .foregroundColor: palette.accent,
            .backgroundColor: palette.accent.withAlphaComponent(0.12)
        ]

        let attributed = NSMutableAttributedString(string: truncatedContext, attributes: baseAttrs)

        if let range = highlightRange {
            let nsRange = NSRange(range, in: truncatedContext)
            attributed.addAttributes(highlightAttrs, range: nsRange)
        }

        return attributed
    }

    @objc private func deleteTapped() {
        onDelete?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            layer?.backgroundColor = NSColor(calibratedWhite: 0.93, alpha: 1).cgColor
            deleteButton.animator().alphaValue = 1
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1).cgColor
            deleteButton.animator().alphaValue = 0
        }
    }
}
