import SwiftUI

struct CodexMark: View {
    let statusTint: Color
    var size: CGFloat
    var showsStatus: Bool = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(.separator.opacity(0.45), lineWidth: 1)

                Text("C")
                    .font(.system(size: size * 0.58, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: size, height: size)

            if showsStatus {
                Circle()
                    .fill(statusTint)
                    .frame(width: max(5, size * 0.22), height: max(5, size * 0.22))
                    .offset(x: size * 0.08, y: size * 0.06)
            }
        }
        .frame(width: size + (showsStatus ? size * 0.08 : 0), height: size)
        .accessibilityLabel("Codex 声音提醒")
    }
}
