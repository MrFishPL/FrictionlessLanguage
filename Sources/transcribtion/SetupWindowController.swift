import AppKit

struct ApiKeyRequirements: OptionSet {
    let rawValue: Int

    static let elevenLabs = ApiKeyRequirements(rawValue: 1 << 0)
    static let openAI = ApiKeyRequirements(rawValue: 1 << 1)
    static let all: ApiKeyRequirements = [.elevenLabs, .openAI]

    var isEmpty: Bool { rawValue == 0 }
}

final class ApiKeySetupCoordinator {
    static let shared = ApiKeySetupCoordinator()

    private var windowController: SetupWindowController?
    private var completions: [(Bool) -> Void] = []

    func ensureKeys(required: ApiKeyRequirements, completion: @escaping (Bool) -> Void) {
        let missing = missingRequirements(from: required)
        if missing.isEmpty {
            completion(true)
            return
        }

        completions.append(completion)
        if windowController != nil {
            return
        }

        let controller = SetupWindowController(requirements: missing)
        controller.onFinish = { [weak self] success in
            guard let self else { return }
            let pending = self.completions
            self.completions.removeAll()
            self.windowController = nil
            pending.forEach { $0(success) }
        }
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func missingRequirements(from required: ApiKeyRequirements) -> ApiKeyRequirements {
        var missing: ApiKeyRequirements = []
        if required.contains(.elevenLabs), EnvLoader.loadApiKey() == nil {
            missing.insert(.elevenLabs)
        }
        if required.contains(.openAI), EnvLoader.loadOpenAIKey() == nil {
            missing.insert(.openAI)
        }
        return missing
    }
}

final class SetupWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    var onFinish: ((Bool) -> Void)?

    private let requirements: ApiKeyRequirements
    private let elevenLabsField = NSSecureTextField()
    private let openAIField = NSSecureTextField()
    private let saveButton = PaddedButton(title: "Save and Continue", target: nil, action: #selector(saveAndContinue))
    private let quitButton = PaddedButton(title: "Quit", target: nil, action: #selector(quitApp))
    private let statusLabel = NSTextField(labelWithString: "")
    private let statusSpinner = NSProgressIndicator()
    private var didFinish = false
    private let palette = SetupPalette()
    private var fieldContainers: [ObjectIdentifier: NSView] = [:]

    init(requirements: ApiKeyRequirements) {
        self.requirements = requirements

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.center()

        super.init(window: window)
        window.delegate = self
        setupContent()
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

        let titleLabel = NSTextField(labelWithString: "Flungus Setup")
        titleLabel.font = palette.titleFont
        titleLabel.textColor = palette.titleColor
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let subtitleLabel = NSTextField(labelWithString: "Enter your API keys to start live captions and translations.")
        subtitleLabel.font = palette.bodyFont
        subtitleLabel.textColor = palette.subtitleColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = palette.bodyFont
        statusLabel.textColor = palette.subtitleColor
        statusLabel.isHidden = true

        statusSpinner.controlSize = .small
        statusSpinner.style = .spinning
        statusSpinner.isDisplayedWhenStopped = false

        let titleRow = NSStackView(views: [titleLabel, statusSpinner, statusLabel])
        titleRow.orientation = .horizontal
        titleRow.spacing = 10
        titleRow.alignment = .centerY
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(18, after: subtitleLabel)

        var lastFieldBlock: NSView?
        if requirements.contains(.elevenLabs) {
            let block = makeFieldBlock(
                title: "ElevenLabs API Key",
                placeholder: "ELEVENLABS_API_KEY",
                field: elevenLabsField
            )
            stack.addArrangedSubview(block)
            block.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            lastFieldBlock = block
        }

        if requirements.contains(.openAI) {
            let block = makeFieldBlock(
                title: "OpenAI API Key",
                placeholder: "",
                field: openAIField
            )
            stack.addArrangedSubview(block)
            block.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            lastFieldBlock = block
        }

        let buttonRow = NSStackView(views: [quitButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 16
        buttonRow.alignment = .centerY
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self

        quitButton.bezelStyle = .rounded
        quitButton.target = self

        if let lastFieldBlock {
            stack.setCustomSpacing(16, after: lastFieldBlock)
        }
        stack.addArrangedSubview(buttonRow)

        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24),
            card.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),

            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -32),
        ])

        updateSaveButtonState()
        applyButtonStyles()

        if requirements.contains(.elevenLabs) {
            window.initialFirstResponder = elevenLabsField
        } else if requirements.contains(.openAI) {
            window.initialFirstResponder = openAIField
        }
    }

    private func makeFieldBlock(title: String, placeholder: String, field: NSSecureTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = palette.labelFont
        titleLabel.textColor = palette.labelColor

        field.placeholderString = ""
        field.stringValue = ""
        field.font = palette.fieldFont
        field.textColor = palette.fieldText
        field.drawsBackground = false
        field.isBezeled = false
        field.focusRingType = .none
        field.delegate = self
        field.isEditable = true
        field.isSelectable = true
        field.isEnabled = true
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.translatesAutoresizingMaskIntoConstraints = false

        let inputContainer = NSView()
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = palette.fieldBackground.cgColor
        inputContainer.layer?.cornerRadius = 10
        inputContainer.layer?.borderWidth = 1
        inputContainer.layer?.borderColor = palette.fieldBorder.cgColor
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(field)

        fieldContainers[ObjectIdentifier(field)] = inputContainer

        let stack = NSStackView(views: [titleLabel, inputContainer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: 38),

            field.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            field.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            field.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            field.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
        ])

        return stack
    }

    private func updateSaveButtonState() {
        let needsElevenLabs = requirements.contains(.elevenLabs)
        let needsOpenAI = requirements.contains(.openAI)

        let hasElevenLabs = !elevenLabsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasOpenAI = !openAIField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        saveButton.isEnabled = (!needsElevenLabs || hasElevenLabs) && (!needsOpenAI || hasOpenAI)
        applyButtonStyles()
    }

    private func applyButtonStyles() {
        stylePrimaryButton(saveButton, enabled: saveButton.isEnabled)
        styleSecondaryButton(quitButton)
    }

    @objc private func saveAndContinue() {
        let elevenToken = elevenLabsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIToken = openAIField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if requirements.contains(.elevenLabs), elevenToken.isEmpty {
            showStatus("ElevenLabs API key is required.", isError: true)
            return
        }
        if requirements.contains(.openAI), openAIToken.isEmpty {
            showStatus("OpenAI API key is required.", isError: true)
            return
        }

        if requirements.contains(.elevenLabs) && requirements.contains(.openAI) {
            setValidating(true, message: "Checking ElevenLabs key...")
            validateElevenLabsKey(elevenToken) { [weak self] (result: Result<Void, Error>) in
                guard let self else { return }
                self.setValidating(false, message: nil)
                switch result {
                case .success:
                    self.setValidating(true, message: "Checking OpenAI key...")
                    self.validateOpenAIKey(openAIToken) { [weak self] (openAIResult: Result<Void, Error>) in
                        guard let self else { return }
                        self.setValidating(false, message: nil)
                        switch openAIResult {
                        case .success:
                            self.saveKeysAndContinue(elevenToken: elevenToken, openAIToken: openAIToken)
                        case .failure:
                            self.showStatus("OpenAI API key is invalid.", isError: true)
                        }
                    }
                case .failure(let error):
                    self.showStatus(error.localizedDescription, isError: true)
                }
            }
            return
        }

        if requirements.contains(.openAI) {
            setValidating(true, message: "Checking OpenAI key...")
            validateOpenAIKey(openAIToken) { [weak self] (result: Result<Void, Error>) in
                guard let self else { return }
                self.setValidating(false, message: nil)
                switch result {
                case .success:
                    self.saveKeysAndContinue(elevenToken: elevenToken, openAIToken: openAIToken)
                case .failure(let error):
                    self.showStatus(error.localizedDescription, isError: true)
                }
            }
            return
        }

        saveKeysAndContinue(elevenToken: elevenToken, openAIToken: openAIToken)
    }

    @objc private func quitApp() {
        finish(success: false)
    }

    func windowWillClose(_ notification: Notification) {
        finish(success: false)
    }

    func controlTextDidChange(_ obj: Notification) {
        statusLabel.isHidden = true
        updateSaveButtonState()
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        updateFieldFocus(for: obj.object, focused: true)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        updateFieldFocus(for: obj.object, focused: false)
    }

    private func finish(success: Bool) {
        guard !didFinish else { return }
        didFinish = true
        if window?.isVisible == true {
            window?.orderOut(nil)
        }
        window?.close()
        onFinish?(success)
    }

    private func stylePrimaryButton(_ button: NSButton, enabled: Bool) {
        button.isBordered = false
        button.font = palette.buttonFont
        button.wantsLayer = true
        button.layer?.cornerRadius = 9
        button.layer?.backgroundColor = (enabled ? palette.accent : palette.disabled).cgColor
        button.contentTintColor = palette.buttonText
        if let padded = button as? PaddedButton {
            padded.contentInsets = NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        }
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

    private func updateFieldFocus(for object: Any?, focused: Bool) {
        guard let field = object as? NSSecureTextField else { return }
        guard let container = fieldContainers[ObjectIdentifier(field)] else { return }
        container.layer?.borderColor = (focused ? palette.accent : palette.fieldBorder).cgColor
        container.layer?.borderWidth = focused ? 1.5 : 1
    }

    private func setValidating(_ validating: Bool, message: String?) {
        if validating {
            saveButton.isEnabled = false
            quitButton.isEnabled = false
        } else {
            quitButton.isEnabled = true
            updateSaveButtonState()
        }

        if let message {
            showStatus(message, isError: false)
        } else {
            statusLabel.isHidden = true
        }

        if validating {
            statusSpinner.startAnimation(nil)
        } else {
            statusSpinner.stopAnimation(nil)
        }
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? NSColor.systemRed : palette.subtitleColor
        statusLabel.isHidden = false
    }

    private func saveKeysAndContinue(elevenToken: String, openAIToken: String) {
        if requirements.contains(.elevenLabs) {
            EnvLoader.saveApiKey(elevenToken)
        }
        if requirements.contains(.openAI) {
            EnvLoader.saveOpenAIKey(openAIToken)
        }
        finish(success: true)
    }

    private func validateOpenAIKey(_ token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            completion(.failure(ValidationError("Unable to validate OpenAI key.")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(ValidationError("OpenAI validation failed: \(error.localizedDescription)")))
                }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(ValidationError("OpenAI validation failed.")))
                }
                return
            }

            DispatchQueue.main.async {
                if (200...299).contains(http.statusCode) {
                    completion(.success(()))
                } else if http.statusCode == 401 {
                    completion(.failure(ValidationError("OpenAI key is invalid.")))
                } else {
                    completion(.failure(ValidationError("OpenAI validation failed (HTTP \(http.statusCode)).")))
                }
            }
        }.resume()
    }

    private func validateElevenLabsKey(_ token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/user/subscription") else {
            completion(.failure(ValidationError("Unable to validate ElevenLabs key.")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "xi-api-key")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(ValidationError("ElevenLabs validation failed: \(error.localizedDescription)")))
                }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(ValidationError("ElevenLabs validation failed.")))
                }
                return
            }

            DispatchQueue.main.async {
                if (200...299).contains(http.statusCode) {
                    completion(.success(()))
                } else if http.statusCode == 401 {
                    completion(.failure(ValidationError("ElevenLabs key is invalid.")))
                } else {
                    completion(.failure(ValidationError("ElevenLabs validation failed (HTTP \(http.statusCode)).")))
                }
            }
        }.resume()
    }
}

private struct ValidationError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct SetupPalette {
    let accent = NSColor(calibratedRed: 0.16, green: 0.52, blue: 0.44, alpha: 1)
    let disabled = NSColor(calibratedWhite: 0.78, alpha: 1)
    let buttonText = NSColor(calibratedWhite: 0.98, alpha: 1)
    let secondaryBackground = NSColor(calibratedWhite: 0.95, alpha: 1)
    let secondaryBorder = NSColor(calibratedWhite: 0.82, alpha: 1)
    let secondaryText = NSColor(calibratedWhite: 0.25, alpha: 1)
    let titleColor = NSColor(calibratedWhite: 0.12, alpha: 1)
    let subtitleColor = NSColor(calibratedWhite: 0.38, alpha: 1)
    let labelColor = NSColor(calibratedWhite: 0.18, alpha: 1)
    let fieldText = NSColor(calibratedWhite: 0.12, alpha: 1)
    let fieldBackground = NSColor(calibratedWhite: 0.99, alpha: 1)
    let fieldBorder = NSColor(calibratedWhite: 0.86, alpha: 1)
    let cardBackground = NSColor(calibratedWhite: 0.98, alpha: 0.98)
    let cardShadow = NSColor(calibratedWhite: 0.1, alpha: 1)

    let titleFont = NSFont(name: "Avenir Next Demi Bold", size: 22) ?? NSFont.systemFont(ofSize: 22, weight: .semibold)
    let bodyFont = NSFont(name: "Avenir Next", size: 13) ?? NSFont.systemFont(ofSize: 13)
    let labelFont = NSFont(name: "Avenir Next Medium", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .medium)
    let fieldFont = NSFont(name: "Avenir Next", size: 13) ?? NSFont.systemFont(ofSize: 13)
    let buttonFont = NSFont(name: "Avenir Next Medium", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .medium)
}

final class SetupBackgroundView: NSView {
    private let palette: SetupPalette
    private let gradientLayer = CAGradientLayer()
    private let glowLayer = CALayer()

    init(palette: SetupPalette) {
        self.palette = palette
        super.init(frame: .zero)
        wantsLayer = true

        gradientLayer.colors = [
            NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.90, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.93, green: 0.96, blue: 0.94, alpha: 1).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 1)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        layer?.addSublayer(gradientLayer)

        glowLayer.backgroundColor = palette.accent.withAlphaComponent(0.12).cgColor
        glowLayer.cornerRadius = 180
        layer?.addSublayer(glowLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
        let glowSize = CGSize(width: bounds.width * 0.7, height: bounds.height * 0.7)
        glowLayer.frame = CGRect(
            x: bounds.width * 0.55,
            y: bounds.height * 0.35,
            width: glowSize.width,
            height: glowSize.height
        )
    }
}

final class PaddedButton: NSButton {
    var contentInsets = NSEdgeInsetsZero {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
