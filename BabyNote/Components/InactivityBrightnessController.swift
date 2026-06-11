import Foundation
import UIKit

@MainActor
final class InactivityBrightnessController: ObservableObject {
    private var dimTimer: Timer?
    private var originalBrightness: CGFloat?
    private var delay: TimeInterval = TimeInterval(InactivityDimDelay.fiveMinutes.rawValue)
    private var dimBrightnessRatio: CGFloat = 0.35
    private var isSceneActive = false

    func configure(delaySeconds: Int, dimBrightnessPercent: Int, scenePhaseIsActive: Bool) {
        delay = TimeInterval(delaySeconds)
        dimBrightnessRatio = CGFloat(dimBrightnessPercent) / 100
        isSceneActive = scenePhaseIsActive
        UIApplication.shared.isIdleTimerDisabled = scenePhaseIsActive

        if scenePhaseIsActive {
            restoreBrightnessIfNeeded()
            scheduleDimTimer()
        } else {
            dimTimer?.invalidate()
            dimTimer = nil
            restoreBrightnessIfNeeded()
        }
    }

    func registerInteraction() {
        guard isSceneActive else { return }
        restoreBrightnessIfNeeded()
        scheduleDimTimer()
    }

    private func scheduleDimTimer() {
        dimTimer?.invalidate()

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dimBrightnessForInactivity()
            }
        }
        dimTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func dimBrightnessForInactivity() {
        guard isSceneActive, originalBrightness == nil else { return }

        let currentBrightness = UIScreen.main.brightness
        originalBrightness = currentBrightness

        let dimmedBrightness = max(currentBrightness * dimBrightnessRatio, 0.03)
        UIScreen.main.brightness = min(currentBrightness, dimmedBrightness)
    }

    private func restoreBrightnessIfNeeded() {
        guard let originalBrightness else { return }
        UIScreen.main.brightness = originalBrightness
        self.originalBrightness = nil
    }
}
