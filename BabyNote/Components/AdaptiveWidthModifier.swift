import SwiftUI

struct AdaptiveWidthModifier: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func adaptiveContentWidth(_ maxWidth: CGFloat) -> some View {
        modifier(AdaptiveWidthModifier(maxWidth: maxWidth))
    }
}
