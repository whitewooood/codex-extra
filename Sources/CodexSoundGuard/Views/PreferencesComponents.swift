import AppKit
import SwiftUI

enum PreferencesPane: String, CaseIterable, Identifiable {
    case general
    case sounds
    case limits
    case diagnostics

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .sounds:
            return "声音"
        case .limits:
            return "额度"
        case .diagnostics:
            return "诊断"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "运行与启动"
        case .sounds:
            return "提示音与静音"
        case .limits:
            return "阈值与数据"
        case .diagnostics:
            return "状态与隐私"
        }
    }

    var iconName: String {
        switch self {
        case .general:
            return "switch.2"
        case .sounds:
            return "speaker.wave.2"
        case .limits:
            return "gauge.with.dots.needle.50percent"
        case .diagnostics:
            return "stethoscope"
        }
    }
}

struct PreferencesSidebar: View {
    @Binding var selectedPane: PreferencesPane
    let isRunning: Bool
    let filesWatched: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                CodexUsageMeter(statusIntensity: isRunning ? 0.76 : 0.34, usage: nil)
                    .frame(width: 28, height: 28)
                    .padding(7)
                    .background(InterfaceDesign.elevatedPanel.opacity(0.56), in: RoundedRectangle(cornerRadius: InterfaceDesign.panelRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: InterfaceDesign.panelRadius, style: .continuous)
                            .strokeBorder(InterfaceDesign.border, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Codex Monitor")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text("设置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

            VStack(spacing: 4) {
                ForEach(PreferencesPane.allCases) { pane in
                    SidebarRow(
                        pane: pane,
                        isSelected: pane == selectedPane
                    ) {
                        selectedPane = pane
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            SidebarStatusPill(isRunning: isRunning, filesWatched: filesWatched)
                .padding([.horizontal, .bottom], 12)
        }
        .frame(width: 212)
        .background(InterfaceDesign.basePanel.opacity(0.38))
    }
}

private struct SidebarRow: View {
    let pane: PreferencesPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? InterfaceDesign.accent : Color.secondary)
                    .frame(width: 25, height: 25)
                    .background(isSelected ? InterfaceDesign.accent.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(pane.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(pane.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous)
                        .fill(InterfaceDesign.accent.opacity(0.055))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(InterfaceDesign.accent)
                        .frame(width: 3, height: 24)
                        .padding(.leading, 2)
                }
            }
        }
    }
}

private struct SidebarStatusPill: View {
    let isRunning: Bool
    let filesWatched: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isRunning ? InterfaceDesign.accent : Color.primary.opacity(0.30))
                .frame(width: 7, height: 7)

            Text(isRunning ? "监听中" : "已暂停")
                .font(.caption.weight(.medium))

            Spacer(minLength: 6)

            Text("\(filesWatched)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(InterfaceDesign.elevatedPanel.opacity(0.50), in: RoundedRectangle(cornerRadius: InterfaceDesign.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: InterfaceDesign.panelRadius, style: .continuous)
                .strokeBorder(InterfaceDesign.border, lineWidth: 1)
        }
    }
}

struct PreferencesHeader: View {
    let pane: PreferencesPane

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(pane.title)
                .font(.system(size: 26, weight: .semibold))
                .lineLimit(1)

            Text(pane.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.bottom, 4)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 3)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InterfaceDesign.elevatedPanel.opacity(0.54), in: RoundedRectangle(cornerRadius: InterfaceDesign.panelRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: InterfaceDesign.panelRadius, style: .continuous)
                    .strokeBorder(InterfaceDesign.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.025), radius: 8, x: 0, y: 2)
        }
    }
}

struct SettingsControlRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 24)

            control
        }
        .settingsRow()
    }
}

struct SettingsPickerRow<Control: View>: View {
    let title: String
    let value: String
    @ViewBuilder var control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.callout.weight(.medium))

                Spacer(minLength: 16)

                Text(value)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            control
        }
        .settingsRow()
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.callout.weight(.medium))
            Spacer(minLength: 24)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .settingsRow()
    }
}

struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 24)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(InterfaceDesign.accent)
        }
        .settingsRow()
    }
}

struct SettingsButtonRow: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 24)

            Button(action: action) {
                Label(buttonTitle, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
            }
            .buttonStyle(SettingsActionButtonStyle())
            .disabled(isDisabled)
        }
        .settingsRow()
    }
}

struct SoundSettingsRow: View {
    let title: String
    let detail: String
    @Binding var isEnabled: Bool
    let path: String
    let testAction: () -> Void
    let chooseAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 24)

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(InterfaceDesign.accent)
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 9)
                .frame(height: 26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(InterfaceDesign.basePanel.opacity(0.52), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))

                Button(action: testAction) {
                    Image(systemName: "play.fill")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(SettingsIconButtonStyle())
                .disabled(!isEnabled)
                .help("试听")

                Button(action: chooseAction) {
                    Image(systemName: "folder")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(SettingsIconButtonStyle())
                .help("选择声音")
            }
        }
        .settingsRow()
    }
}

struct SettingsFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .settingsRow(verticalPadding: 8)
    }
}

struct SettingsInfoBox: View {
    let title: String
    let text: String
    var iconName = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(InterfaceDesign.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .settingsRow(verticalPadding: 10)
    }
}

struct DiagnosticStatusRow: View {
    enum Status {
        case ok
        case warning
        case neutral

        var iconName: String {
            switch self {
            case .ok:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .neutral:
                return "circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .ok:
                return InterfaceDesign.accent
            case .warning:
                return Color.orange
            case .neutral:
                return Color.secondary.opacity(0.70)
            }
        }
    }

    let title: String
    let detail: String
    let status: Status
    var actionTitle: String?
    var actionIcon: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: status.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionIcon ?? "arrow.right")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                }
                .buttonStyle(SettingsActionButtonStyle())
            }
        }
        .settingsRow()
    }
}

struct QuietHourPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("时间", selection: $selection) {
            ForEach(Self.timeOptions, id: \.self) { minute in
                Text(Self.timeLabel(for: minute)).tag(minute)
            }
        }
        .labelsHidden()
        .frame(width: 96)
        .tint(InterfaceDesign.accent)
    }

    private static let timeOptions = Array(stride(from: 0, through: 23 * 60 + 30, by: 30))

    private static func timeLabel(for minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}

struct ThresholdSettingsRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.callout.weight(.medium))

                Spacer(minLength: 16)

                Text("\(Int(value))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Slider(value: $value, in: 5...80, step: 5)
                    .tint(InterfaceDesign.accent)
                ProgressView(value: value, total: 100)
                    .tint(InterfaceDesign.accent)
                    .frame(width: 82)
            }
        }
        .settingsRow()
    }
}

private extension View {
    func settingsRow(verticalPadding: CGFloat = 12) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(InterfaceDesign.separator)
                    .frame(height: 1)
                    .padding(.leading, 14)
            }
    }
}

private struct SettingsActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(InterfaceDesign.basePanel.opacity(configuration.isPressed ? 0.90 : 0.60), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous)
                    .strokeBorder(InterfaceDesign.border, lineWidth: 1)
            }
    }
}

private struct SettingsIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .background(InterfaceDesign.basePanel.opacity(configuration.isPressed ? 0.92 : 0.58), in: RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: InterfaceDesign.controlRadius, style: .continuous)
                    .strokeBorder(InterfaceDesign.border, lineWidth: 1)
            }
    }
}
