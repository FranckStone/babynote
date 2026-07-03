import Foundation
import UIKit

@MainActor
final class InactivityBrightnessController: ObservableObject {
    private var heartbeatTimer: Timer?
    private var lastInteractionAt = Date()
    private var originalBrightness: CGFloat?
    private var dimmedBrightnessTarget: CGFloat?
    private var delay: TimeInterval = TimeInterval(InactivityDimDelay.fiveMinutes.rawValue)
    private var dimBrightnessRatio: CGFloat = 0.35
    private var isSceneActive = false

    func configure(delaySeconds: Int, dimBrightnessPercent: Int, scenePhaseIsActive: Bool) {
        delay = TimeInterval(delaySeconds)
        dimBrightnessRatio = CGFloat(dimBrightnessPercent) / 100
        UIApplication.shared.isIdleTimerDisabled = scenePhaseIsActive

        if scenePhaseIsActive {
            if !isSceneActive {
                // 回到前台从零开始计时，不带上后台期间累计的闲置时间。
                lastInteractionAt = Date()
            }
            isSceneActive = true
            restoreBrightnessIfNeeded()
            startHeartbeatIfNeeded()
        } else {
            isSceneActive = false
            stopHeartbeat()
            restoreBrightnessIfNeeded()
        }
    }

    func registerInteraction() {
        guard isSceneActive else { return }
        lastInteractionAt = Date()
        restoreBrightnessIfNeeded()
    }

    private func startHeartbeatIfNeeded() {
        guard heartbeatTimer == nil else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.heartbeatTick()
            }
        }
        timer.tolerance = 0.2
        heartbeatTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func heartbeatTick() {
        guard isSceneActive else { return }

        if let dimmedBrightnessTarget {
            // 已调暗后用户在控制中心手动调亮：以新亮度为基准重新计时，
            // 否则内部状态一直是“已调暗”，之后永远不会再自动变暗。
            if UIScreen.main.brightness > dimmedBrightnessTarget + 0.05 {
                originalBrightness = nil
                self.dimmedBrightnessTarget = nil
                lastInteractionAt = Date()
            }
            return
        }

        guard Date().timeIntervalSince(lastInteractionAt) >= delay else { return }
        dimBrightnessForInactivity()
    }

    private func dimBrightnessForInactivity() {
        let currentBrightness = UIScreen.main.brightness
        originalBrightness = currentBrightness

        let dimmedBrightness = min(currentBrightness, max(currentBrightness * dimBrightnessRatio, 0.01))
        dimmedBrightnessTarget = dimmedBrightness
        UIScreen.main.brightness = dimmedBrightness
    }

    private func restoreBrightnessIfNeeded() {
        dimmedBrightnessTarget = nil
        guard let originalBrightness else { return }
        UIScreen.main.brightness = originalBrightness
        self.originalBrightness = nil
    }
}
