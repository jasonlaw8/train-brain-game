import SwiftUI
import UIKit

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ShareCardView

struct ShareCardView: View {
    let gameName: String
    let gameIcon: String
    let gameColor: Color
    let primaryValue: String
    let primaryLabel: String
    let secondaryLine: String?

    private let cardWidth: CGFloat  = 400
    private let cardHeight: CGFloat = 260

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [gameColor.opacity(0.8), gameColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Top row – icon + app name
                HStack(spacing: 10) {
                    Image(systemName: gameIcon)
                        .font(.system(size: 22, weight: .semibold))
                    Text("Brain Train")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(gameName)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.top, 28)

                Spacer()

                // Primary score
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(primaryValue)
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(primaryLabel)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .padding(.bottom, 8)
                }
                .foregroundStyle(.white)

                // Optional secondary line
                if let secondary = secondaryLine {
                    Text(secondary)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .padding(.top, 4)
                }

                Spacer()

                // Watermark
                HStack {
                    Spacer()
                    Text("braintrain.app")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: gameColor.opacity(0.45), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Image Renderer Helper

@MainActor
func renderShareCard(_ card: ShareCardView) -> UIImage {
    let renderer = ImageRenderer(content: card)
    renderer.scale = 3
    return renderer.uiImage ?? UIImage()
}

// MARK: - Reusable share button (generates card, shows share sheet)

struct ShareResultButton: View {
    let gameName: String
    let gameIcon: String
    let gameColor: Color
    let primaryValue: String
    let primaryLabel: String
    let secondaryLine: String?

    @State private var showSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        Button {
            let card = ShareCardView(
                gameName: gameName, gameIcon: gameIcon, gameColor: gameColor,
                primaryValue: primaryValue, primaryLabel: primaryLabel,
                secondaryLine: secondaryLine
            )
            shareImage = renderShareCard(card)
            showSheet = true
        } label: {
            Label("Share Score", systemImage: "square.and.arrow.up")
                .font(.subheadline.bold())
                .foregroundStyle(gameColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(gameColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showSheet) {
            if let img = shareImage {
                ShareSheet(items: [img])
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        ShareCardView(
            gameName: "Memory",
            gameIcon: "square.grid.3x3.fill",
            gameColor: .blue,
            primaryValue: "320",
            primaryLabel: "pts",
            secondaryLine: "Level 8"
        )

        ShareCardView(
            gameName: "Reflex",
            gameIcon: "bolt.fill",
            gameColor: .orange,
            primaryValue: "214",
            primaryLabel: "ms",
            secondaryLine: "Avg 245 ms"
        )

        ShareCardView(
            gameName: "Color",
            gameIcon: "paintpalette.fill",
            gameColor: .purple,
            primaryValue: "18",
            primaryLabel: "pts",
            secondaryLine: nil
        )
    }
    .padding()
}
