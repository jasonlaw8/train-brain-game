import UIKit

enum Haptics {
    static var isEnabled: Bool {
        // Default true — only disabled if the user has explicitly set it to false
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func success() { notification(.success) }
    static func error()   { notification(.error) }
    static func light()   { impact(.light) }
    static func medium()  { impact(.medium) }
    static func heavy()   { impact(.heavy) }
}
