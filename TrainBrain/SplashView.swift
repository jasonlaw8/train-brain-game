import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool
    @Environment(\.colorScheme) private var colorScheme

    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 12

    var body: some View {
        ZStack {
            // Adaptive gradient: deep navy in Dark Mode, soft lavender in Light Mode
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.07, green: 0.07, blue: 0.14),
                       Color(red: 0.10, green: 0.08, blue: 0.20)]
                    : [Color(red: 0.93, green: 0.92, blue: 0.98),
                       Color(red: 0.88, green: 0.86, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "brain")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                VStack(spacing: 6) {
                    Text("Train Brain")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Challenge your mind daily")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
            titleOpacity = 1.0
            titleOffset = 0
        }
    }
}
