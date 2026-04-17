import SwiftUI

enum Theme {
    static let accent = Color(red: 0.14, green: 0.46, blue: 0.95)
    static let systemAccent = Color.accentColor
    static let success = Color(red: 0.12, green: 0.63, blue: 0.27)
    static let failure = Color(red: 0.82, green: 0.22, blue: 0.22)
    static let border = Color.white.opacity(0.20)
    static let softBorder = Color.primary.opacity(0.10)
    static let panelShadow = Color.black.opacity(0.12)

    static var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    static var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    @ViewBuilder
    static var windowBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: -240, y: -220)

            Circle()
                .fill(success.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: 260, y: 240)
        }
        .ignoresSafeArea()
    }
}
