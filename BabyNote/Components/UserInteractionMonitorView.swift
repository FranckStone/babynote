import SwiftUI
import UIKit

struct UserInteractionMonitorView: UIViewRepresentable {
    var onInteraction: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onInteraction: onInteraction)
    }

    func makeUIView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: MonitorView, context: Context) {
        context.coordinator.onInteraction = onInteraction
        uiView.coordinator = context.coordinator
        uiView.installIfNeeded()
    }

    final class MonitorView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installIfNeeded()
        }

        func installIfNeeded() {
            guard let window, let coordinator else { return }
            coordinator.installIfNeeded(on: window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onInteraction: () -> Void

        private weak var installedWindow: UIWindow?
        private var recognizers: [UIGestureRecognizer] = []

        init(onInteraction: @escaping () -> Void) {
            self.onInteraction = onInteraction
        }

        deinit {
            uninstall()
        }

        func installIfNeeded(on window: UIWindow) {
            guard installedWindow !== window else { return }
            uninstall()

            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleInteraction))
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delaysTouchesBegan = false
            tapRecognizer.delaysTouchesEnded = false
            tapRecognizer.delegate = self

            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleInteraction))
            panRecognizer.cancelsTouchesInView = false
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.delaysTouchesEnded = false
            panRecognizer.delegate = self

            window.addGestureRecognizer(tapRecognizer)
            window.addGestureRecognizer(panRecognizer)

            installedWindow = window
            recognizers = [tapRecognizer, panRecognizer]
        }

        func uninstall() {
            recognizers.forEach { recognizer in
                recognizer.view?.removeGestureRecognizer(recognizer)
            }
            recognizers = []
            installedWindow = nil
        }

        @objc private func handleInteraction() {
            onInteraction()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
