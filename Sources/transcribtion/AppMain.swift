import AppKit

@main
@available(macOS 14.4, *)
struct CaptionLayerApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let panelSize = AppConfig.panelSize
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height
        )

        let panel = NotchPanel(frame: NSRect(origin: origin, size: panelSize))
        let notchView = NotchView(frame: NSRect(origin: .zero, size: panelSize))
        panel.contentView = notchView
        panel.makeKeyAndOrderFront(nil)

        let translator = TranslationController()
        notchView.translationHandler = { fragment, context, completion in
            translator.translate(
                fragment: fragment,
                context: context,
                targetLanguage: AppConfig.targetLanguage,
                completion: completion
            )
        }

        let transcription = TranscriptionController(notchView: notchView)
        notchView.hoverChangedHandler = { isHovering in
            transcription.setUIUpdatesPaused(isHovering)
        }
        let statusBar = StatusBarController(panel: panel, transcription: transcription, translator: translator)
        _ = statusBar

        requestKeysAndStart(transcription: transcription, translator: translator)

        app.run()
    }

    private static func requestKeysAndStart(
        transcription: TranscriptionController,
        translator: TranslationController
    ) {
        transcription.requestApiKeyIfNeeded { success in
            guard success else { return }
            translator.requestApiKeyIfNeeded { translatorSuccess in
                guard translatorSuccess else { return }
                transcription.start()
            }
        }
    }
}
