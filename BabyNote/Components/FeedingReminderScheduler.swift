import AudioToolbox
import AVFoundation
import Foundation

@MainActor
final class FeedingAlarmController: ObservableObject {
    @Published private(set) var isAlarmActive = false
    @Published private(set) var alarmTitle = ""
    @Published private(set) var alarmMessage = ""
    @Published private(set) var nextReminderDate: Date?

    private var reminderTimer: Timer?
    private var alarmTimer: Timer?
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var chimeBuffer: AVAudioPCMBuffer?
    private var alarmVolume: Float = 0.16
    private var alarmStartedAt: Date?
    private var activeAlarmShouldSnoozeAfterDismiss = false
    private var activeAlarmFeedingDate: Date?
    private var latestEnabled = false
    private var latestDelayMinutes = 180
    private var latestFeedingDate: Date?
    private var snoozedFeedingDate: Date?
    private var snoozedUntil: Date?

    private let minimumAlarmVolume: Float = 0.16
    private let maximumAlarmVolume: Float = 0.9
    private let alarmVolumeStep: Float = 0.08
    private let userInteractionStopGraceSeconds: TimeInterval = 0.6
    private let manualDismissSnoozeSeconds: TimeInterval = 60 * 60

    func update(enabled: Bool, delayMinutes: Int, latestFeedingDate: Date?) {
        latestEnabled = enabled
        latestDelayMinutes = delayMinutes
        self.latestFeedingDate = latestFeedingDate

        reminderTimer?.invalidate()
        reminderTimer = nil

        guard enabled, let latestFeedingDate else {
            snoozedFeedingDate = nil
            snoozedUntil = nil
            nextReminderDate = nil
            stopAlarm()
            return
        }

        if let snoozedFeedingDate, latestFeedingDate > snoozedFeedingDate {
            self.snoozedFeedingDate = nil
            snoozedUntil = nil
        }

        scheduleReminder()
    }

    func startTestAlarm() {
        startAlarm(
            title: "喂奶闹钟测试",
            message: "这是持续闹钟测试，点击停止闹钟后结束。",
            shouldSnoozeAfterDismiss: false,
            feedingDate: nil
        )
    }

    func stopAlarm() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        isAlarmActive = false
        alarmTitle = ""
        alarmMessage = ""
        alarmStartedAt = nil
        activeAlarmShouldSnoozeAfterDismiss = false
        activeAlarmFeedingDate = nil
        audioPlayer?.stop()
        audioEngine?.stop()
        audioPlayer = nil
        audioEngine = nil
        chimeBuffer = nil
        alarmVolume = minimumAlarmVolume
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func stopAlarmAfterUserInteraction() {
        guard isAlarmActive else { return }
        guard let alarmStartedAt else {
            stopAlarm()
            return
        }

        guard Date().timeIntervalSince(alarmStartedAt) >= userInteractionStopGraceSeconds else { return }

        let shouldSnooze = activeAlarmShouldSnoozeAfterDismiss
        let feedingDate = activeAlarmFeedingDate
        stopAlarm()

        if shouldSnooze, let feedingDate {
            snoozedFeedingDate = feedingDate
            snoozedUntil = Date().addingTimeInterval(manualDismissSnoozeSeconds)
            scheduleReminder()
        }
    }

    private func scheduleReminder() {
        reminderTimer?.invalidate()
        reminderTimer = nil

        guard latestEnabled, let latestFeedingDate else {
            nextReminderDate = nil
            return
        }

        let normalFireDate = latestFeedingDate.addingTimeInterval(TimeInterval(latestDelayMinutes * 60))
        let fireDate: Date

        if let snoozedFeedingDate,
           let snoozedUntil,
           latestFeedingDate <= snoozedFeedingDate {
            fireDate = max(normalFireDate, snoozedUntil)
        } else {
            self.snoozedFeedingDate = nil
            snoozedUntil = nil
            fireDate = normalFireDate
        }

        nextReminderDate = fireDate
        let timeInterval = max(fireDate.timeIntervalSinceNow, 1)

        let timer = Timer(timeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.snoozedFeedingDate = nil
                self?.snoozedUntil = nil
                self?.nextReminderDate = nil
                self?.startAlarm(
                    title: "该喂奶了",
                    message: "距离上次喂奶已经超过 \(Self.delayText(minutes: self?.latestDelayMinutes ?? 0))。",
                    shouldSnoozeAfterDismiss: true,
                    feedingDate: self?.latestFeedingDate
                )
            }
        }
        reminderTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startAlarm(
        title: String,
        message: String,
        shouldSnoozeAfterDismiss: Bool,
        feedingDate: Date?
    ) {
        alarmTimer?.invalidate()
        alarmTitle = title
        alarmMessage = message
        isAlarmActive = true
        alarmStartedAt = Date()
        activeAlarmShouldSnoozeAfterDismiss = shouldSnoozeAfterDismiss
        activeAlarmFeedingDate = feedingDate

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        alarmVolume = minimumAlarmVolume
        prepareGentleChimeIfNeeded()

        playAlarmPulse()

        let timer = Timer(timeInterval: 2.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.playAlarmPulse()
            }
        }
        alarmTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func playAlarmPulse() {
        playGentleChime()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        alarmVolume = min(alarmVolume + alarmVolumeStep, maximumAlarmVolume)
    }

    private func prepareGentleChimeIfNeeded() {
        if audioEngine != nil, audioPlayer != nil, chimeBuffer != nil {
            return
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try? engine.start()

        audioEngine = engine
        audioPlayer = player
        chimeBuffer = makeGentleChimeBuffer(format: format)
    }

    private func playGentleChime() {
        prepareGentleChimeIfNeeded()

        guard let audioPlayer, let chimeBuffer else { return }

        if !audioPlayer.isPlaying {
            audioPlayer.play()
        }

        audioPlayer.volume = alarmVolume
        audioPlayer.scheduleBuffer(chimeBuffer, at: nil, options: [], completionHandler: nil)
    }

    private func makeGentleChimeBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 1.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let fadeIn = min(time / 0.08, 1)
            let fadeOut = min((duration - time) / 0.35, 1)
            let envelope = max(min(fadeIn, fadeOut), 0)
            let primaryTone = sin(2 * Double.pi * 523.25 * time)
            let softOvertone = sin(2 * Double.pi * 659.25 * time) * 0.35
            channel[frame] = Float((primaryTone + softOvertone) * envelope * 0.45)
        }

        return buffer
    }

    private static func delayText(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0, remainingMinutes > 0 {
            return "\(hours)小时\(remainingMinutes)分钟"
        }
        if hours > 0 {
            return "\(hours)小时"
        }
        return "\(minutes)分钟"
    }
}
