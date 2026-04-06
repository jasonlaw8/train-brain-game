import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Image(systemName: "brain")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)
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
                                icon: "square.grid.3x3.fill",
                                color: .blue
                            )
                        }
                        NavigationLink(destination: ColorGameView()) {
                            GameCard(
                                title: "Color",
                                subtitle: "Stroop challenge",
                                icon: "paintpalette.fill",
                                color: .purple
                            )
                        }
                        NavigationLink(destination: ReflexGameView()) {
                            GameCard(
                                title: "Reflex",
                                subtitle: "Tap as fast as you can",
                                icon: "bolt.fill",
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
    let icon: String      // SF Symbol name
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(color)
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
