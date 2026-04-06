import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("🧠")
                            .font(.system(size: 72))
                        Text("Train Brain")
                            .font(.largeTitle.bold())
                        Text("Challenge your mind")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 64)
                    .padding(.bottom, 48)

                    VStack(spacing: 16) {
                        NavigationLink(destination: MemoryGameView()) {
                            GameCard(
                                title: "Memory",
                                subtitle: "Repeat the sequence",
                                icon: "🔢",
                                color: .blue
                            )
                        }
                        NavigationLink(destination: ColorGameView()) {
                            GameCard(
                                title: "Color",
                                subtitle: "Stroop challenge",
                                icon: "🎨",
                                color: .purple
                            )
                        }
                        NavigationLink(destination: ReflexGameView()) {
                            GameCard(
                                title: "Reflex",
                                subtitle: "Tap as fast as you can",
                                icon: "⚡️",
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct GameCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 36))
                .frame(width: 60, height: 60)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.subheadline.bold())
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
