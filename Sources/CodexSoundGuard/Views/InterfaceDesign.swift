import SwiftUI

enum InterfaceDesign {
    static let accent = Color(nsColor: .controlAccentColor)
    static let window = Color(nsColor: .windowBackgroundColor)
    static let basePanel = Color(nsColor: .controlBackgroundColor)
    static let elevatedPanel = Color(nsColor: .textBackgroundColor)
    static let border = Color.primary.opacity(0.07)
    static let separator = Color.primary.opacity(0.07)

    static let panelRadius: CGFloat = 8
    static let controlRadius: CGFloat = 7
}
