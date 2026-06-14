import AppKit
import SwiftUI

enum PreferencesPane: String, CaseIterable, Identifiable {
    case general
    case sounds
    case limits

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
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "监听、菜单栏、启动"
        case .sounds:
            return "提醒音与安静时段"
        case .limits:
            return "阈值与用量"
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
        }
    }
}

struct PreferencesSidebar: View {
    @Binding var selectedPane: PreferencesPane
    let isRunning: Bool
    let filesWatched: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Codex Monitor")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text("Preferences")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            VStack(spacing: 2) {
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
        .frame(width: 196)
        .background(.bar)
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
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(pane.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(pane.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
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
                .fill(Color.primary.opacity(isRunning ? 0.72 : 0.30))
                .frame(width: 7, height: 7)

            Text(isRunning ? "监听中" : "已暂停")
                .font(.caption.weight(.medium))

            Spacer(minLength: 6)

            Text("\(filesWatched)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PreferencesHeader: View {
    let pane: PreferencesPane

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(pane.title)
                .font(.system(size: 28, weight: .semibold))
                .lineLimit(1)

            Text(pane.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.bottom, 2)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.56), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.18), lineWidth: 1)
            }
        }
    }
}

struct SettingsControlRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.callout)
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
                    .font(.callout)

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
                .font(.callout)
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
                    .font(.callout)
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
                    .font(.callout)
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
                    .lineLimit(1)
            }
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
                        .font(.callout)
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
            }

            HStack(spacing: 8) {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: testAction) {
                    Image(systemName: "play.fill")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .disabled(!isEnabled)
                .help("试听")

                Button(action: chooseAction) {
                    Image(systemName: "folder")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
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

struct QuietHourPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("时间", selection: $selection) {
            ForEach(Self.timeOptions, id: \.self) { minute in
                Text(Self.timeLabel(for: minute)).tag(minute)
            }
        }
        .labelsHidden()
        .frame(width: 92)
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
                    .font(.callout)

                Spacer(minLength: 16)

                Text("\(Int(value))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Slider(value: $value, in: 5...80, step: 5)
                ProgressView(value: value, total: 100)
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
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.separator.opacity(0.24))
                    .frame(height: 1)
                    .padding(.leading, 14)
            }
    }
}
