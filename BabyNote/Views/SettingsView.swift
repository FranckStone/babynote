import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var feedingAlarmController: FeedingAlarmController
    @AppStorage("inactivityDimDelaySeconds") private var inactivityDimDelaySeconds = InactivityDimDelay.fiveMinutes.rawValue
    @AppStorage("inactivityDimBrightnessPercent") private var inactivityDimBrightnessPercent = 35
    @AppStorage("feedingOverdueAlarmEnabled") private var feedingOverdueAlarmEnabled = false
    @AppStorage("feedingOverdueDelayMinutes") private var feedingOverdueDelayMinutes = 180

    private var selectedDelay: InactivityDimDelay {
        InactivityDimDelay.value(for: inactivityDimDelaySeconds)
    }

    private var feedingReminderDelayText: String {
        let hours = feedingOverdueDelayMinutes / 60
        let minutes = feedingOverdueDelayMinutes % 60

        if hours > 0, minutes > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        if hours > 0 {
            return "\(hours)小时"
        }
        return "\(feedingOverdueDelayMinutes)分钟"
    }

    private var dimBrightnessBinding: Binding<Double> {
        Binding(
            get: { Double(inactivityDimBrightnessPercent) },
            set: { inactivityDimBrightnessPercent = Int($0.rounded()) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("屏幕") {
                    Picker("无人操作后调暗", selection: $inactivityDimDelaySeconds) {
                        ForEach(InactivityDimDelay.allCases) { delay in
                            Text(delay.displayName).tag(delay.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("当前设置", value: selectedDelay.displayName)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("调暗后亮度")
                            Spacer()
                            Text("\(inactivityDimBrightnessPercent)%")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: dimBrightnessBinding, in: 10...70, step: 5) {
                            Text("调暗后亮度")
                        } minimumValueLabel: {
                            Text("更暗")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Text("更亮")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("常亮", value: "开启")
                }

                Section("喂奶闹钟") {
                    Toggle("开启超时闹钟", isOn: $feedingOverdueAlarmEnabled)

                    Stepper(value: $feedingOverdueDelayMinutes, in: 30...360, step: 15) {
                        LabeledContent("最后一次喂奶后", value: feedingReminderDelayText)
                    }
                    .disabled(!feedingOverdueAlarmEnabled)

                    Text("到时间后会持续响铃和震动；保存新的喂奶记录后会自动重新计算。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        feedingAlarmController.startTestAlarm()
                    } label: {
                        Label("测试持续闹钟", systemImage: "bell.and.waves.left.and.right")
                    }
                    .buttonStyle(.bordered)

                    if feedingAlarmController.isAlarmActive {
                        Button(role: .destructive) {
                            feedingAlarmController.stopAlarm()
                        } label: {
                            Label("停止闹钟", systemImage: "stop.circle.fill")
                        }
                    }

                    Text("点击后会立即持续响铃和震动，直到手动停止。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }
}
