import UIKit

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func success() { notification(.success) }
    static func error()   { notification(.error) }
    static func light()   { impact(.light) }
    static func medium()  { impact(.medium) }
    static func heavy()   { impact(.heavy) }
}
