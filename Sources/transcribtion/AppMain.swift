import AppKit

@main
@available(macOS 14.4, *)
struct FlungusApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // Set up main menu with Edit menu for keyboard shortcuts (Cmd+V, Cmd+A, etc.)
        app.mainMenu = createMainMenu()

        let panelSize = AppConfig.panelSize
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height
        )

        let panel = NotchPanel(frame: NSRect(origin: origin, size: panelSize))
        let notchView = NotchView(frame: NSRect(origin: .zero, size: panelSize))
        panel.contentView = notchView

        let translator = TranslationController()
        notchView.translationHandler = { fragment, context, completion in
            let targetLanguage = EnvLoader.loadTargetLanguage() ?? AppConfig.defaultTargetLanguage
            translator.translate(
                fragment: fragment,
                context: context,
                targetLanguage: targetLanguage,
                completion: completion
            )
        }

        let transcription = TranscriptionController(notchView: notchView)
        notchView.hoverChangedHandler = { isHovering in
            transcription.setUIUpdatesPaused(isHovering)
        }
        let statusBar = StatusBarController(panel: panel, transcription: transcription, translator: translator)
        _ = statusBar

        requestKeysAndStart(transcription: transcription, translator: translator, panel: panel)

        app.run()
    }

    private static func requestKeysAndStart(
        transcription: TranscriptionController,
        translator: TranslationController,
        panel: NSPanel
    ) {
        ApiKeySetupCoordinator.shared.ensureKeys(required: .all) { success in
            guard success else {
                NSApplication.shared.terminate(nil)
                return
            }
            transcription.requestApiKeyIfNeeded { transcriptionSuccess in
                guard transcriptionSuccess else {
                    NSApplication.shared.terminate(nil)
                    return
                }
                translator.requestApiKeyIfNeeded { translatorSuccess in
                    guard translatorSuccess else {
                        NSApplication.shared.terminate(nil)
                        return
                    }
                    panel.makeKeyAndOrderFront(nil)
                    transcription.start()
                }
            }
        }
    }

    private static func createMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // Edit menu with standard text editing commands
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = createEditMenu()
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

    private static func createEditMenu() -> NSMenu {
        let editMenu = NSMenu(title: "Edit")

        // Undo
        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(undoItem)

        // Redo
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(NSMenuItem.separator())

        // Cut
        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(cutItem)

        // Copy
        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(copyItem)

        // Paste
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(pasteItem)

        // Paste and Match Style
        let pasteMatchItem = NSMenuItem(title: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "V")
        pasteMatchItem.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(pasteMatchItem)

        // Delete
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(deleteItem)

        // Select All
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(selectAllItem)

        return editMenu
    }
}
