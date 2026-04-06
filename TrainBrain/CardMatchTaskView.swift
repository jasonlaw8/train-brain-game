import SwiftUI

// MARK: - CardMatchViewModel
// Task 3: Working Memory (1-back paradigm).
// 25 cards shown one at a time. User taps Match or New.
// Exactly 8 matches in the sequence. First card = New only.

@MainActor
class CardMatchViewModel: ObservableObject {

    struct Card: Equatable {
        let rank: String  // A 2 3 4 5 6 7 8 9 10 J Q K
        let suit: String  // hearts diamonds clubs spades
        var isMatch: Bool // true if same as previous card
    }

    enum TaskState { case showing, intercard, finished }

    @Published var taskState: TaskState = .showing
    @Published var currentCard: Card? = nil
    @Published var cardIndex: Int = 0          // 0-based (0 = first card)
    @Published var showMatchButton: Bool = false
    @Published var cardVisible: Bool = true

    let totalCards = 25
    var onComplete: (([TrialRecord]) -> Void)?

    private var sequence: [Card] = []
    private var trials: [TrialRecord] = []
    private var cardAppearTime: Date?
    private var autoAdvanceTask: Task<Void, Never>?
    private var responded: Bool = false

    // MARK: - Card data

    private let ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
    private let suits = ["hearts","diamonds","clubs","spades"]

    // MARK: - Start

    func startTask() {
        sequence = buildSequence()
        trials = []
        cardIndex = 0
        showCard(at: 0)
    }

    // MARK: - Sequence generation

    private func buildSequence() -> [Card] {
        var seq: [Card] = []
        var matchCount = 0
        let targetMatches = 8

        for i in 0..<totalCards {
            if i == 0 {
                // First card: always a new card
                seq.append(randomCard(excluding: nil))
            } else {
                let prev = seq[i - 1]
                let canMatch = matchCount < targetMatches
                let remaining = totalCards - i
                let neededMatches = targetMatches - matchCount
                let mustMatch = canMatch && neededMatches == remaining

                // Avoid 3 consecutive matches
                let twoConsecMatches = i >= 2 && seq[i-1].isMatch && seq[i-2].isMatch

                let useMatch: Bool
                if mustMatch && !twoConsecMatches {
                    useMatch = true
                } else if twoConsecMatches {
                    useMatch = false
                } else if canMatch {
                    useMatch = Bool.random() && !twoConsecMatches
                } else {
                    useMatch = false
                }

                if useMatch {
                    var card = prev
                    card.isMatch = true
                    seq.append(card)
                    matchCount += 1
                } else {
                    var newCard = randomCard(excluding: prev)
                    newCard.isMatch = false
                    seq.append(newCard)
                }
            }
        }

        return seq
    }

    private func randomCard(excluding prev: Card?) -> Card {
        var rank: String
        var suit: String
        repeat {
            rank = ranks.randomElement()!
            suit = suits.randomElement()!
        } while prev != nil && rank == prev!.rank && suit == prev!.suit
        return Card(rank: rank, suit: suit, isMatch: false)
    }

    // MARK: - Card display

    private func showCard(at index: Int) {
        guard index < sequence.count else { finish(); return }
        let card = sequence[index]
        currentCard = card
        cardVisible = true
        cardAppearTime = Date()
        responded = false
        showMatchButton = index > 0   // First card: no Match button
        taskState = .showing

        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task {
            try? await Task.sleep(for: .milliseconds(2000))
            guard !Task.isCancelled, !responded else { return }
            handleNoResponse()
        }
    }

    // MARK: - User response

    func userTapped(response: String) {
        guard taskState == .showing, !responded, let card = currentCard,
              let t0 = cardAppearTime else { return }
        responded = true
        autoAdvanceTask?.cancel()

        let rtMs = Int(Date().timeIntervalSince(t0) * 1000)
        let isMatch = card.isMatch
        let isCorrect: Bool
        if cardIndex == 0 {
            // First card: always correct regardless
            isCorrect = true
        } else {
            isCorrect = (response == "match" && isMatch) || (response == "new" && !isMatch)
        }

        if isCorrect { Haptics.medium() } else { Haptics.error() }
        appendTrial(card: card, response: response, rtMs: rtMs, correct: isCorrect, lapse: false)
        advanceToNext()
    }

    private func handleNoResponse() {
        guard let card = currentCard else { return }
        responded = true
        let isCorrect = cardIndex == 0  // First card = always "new", no response acceptable
        appendTrial(card: card, response: "none", rtMs: 2001, correct: isCorrect, lapse: true)
        advanceToNext()
    }

    private func advanceToNext() {
        cardVisible = false
        taskState = .intercard

        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            cardIndex += 1
            showCard(at: cardIndex)
        }
    }

    // MARK: - Record

    private func appendTrial(card: Card, response: String, rtMs: Int, correct: Bool, lapse: Bool) {
        let record = TrialRecord(
            trialNumber: trials.count + 1,
            taskName: "cardMatch",
            phase: nil, orbColor: nil,
            trialType: nil, centerDirection: nil,
            cardRank: card.rank, cardSuit: card.suit,
            isTargetMatch: card.isMatch,
            block: nil, currentRule: nil,
            stimulusColor: nil, stimulusShape: nil, isSwitchTrial: nil,
            userResponse: response,
            reactionTimeMs: rtMs,
            isCorrect: correct,
            isAnticipatory: false,
            isLapse: lapse
        )
        trials.append(record)
    }

    private func finish() {
        taskState = .finished
        onComplete?(trials)
    }

    // MARK: - Display helpers

    func suitColor(_ suit: String) -> Color {
        switch suit {
        case "hearts", "diamonds": return .red
        default: return .primary
        }
    }

    func suitSymbol(_ suit: String) -> String {
        switch suit {
        case "hearts":   return "♥"
        case "diamonds": return "♦"
        case "clubs":    return "♣"
        default:         return "♠"
        }
    }
}

// MARK: - CardMatchTaskView

struct CardMatchTaskView: View {
    @StateObject private var vm = CardMatchViewModel()
    let onComplete: ([TrialRecord]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Match the card if it's identical to the last one")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Card \(min(vm.cardIndex + 1, vm.totalCards)) / \(vm.totalCards)")
                        .font(.subheadline.bold())
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Spacer()

            // Card
            cardArea

            Spacer()

            // Response buttons
            responseButtons
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
        .onAppear {
            vm.onComplete = onComplete
            vm.startTask()
        }
    }

    var cardArea: some View {
        Group {
            if let card = vm.currentCard, vm.cardVisible {
                VStack(spacing: 8) {
                    // Card face
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)

                        VStack(spacing: 4) {
                            Text(card.rank)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(vm.suitColor(card.suit))
                            Text(vm.suitSymbol(card.suit))
                                .font(.system(size: 48))
                                .foregroundStyle(vm.suitColor(card.suit))
                        }
                    }
                    .frame(width: 140, height: 190)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            } else {
                // Inter-card blank (back of card)
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.indigo.opacity(0.15))
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                    Image(systemName: "questionmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.indigo.opacity(0.3))
                }
                .frame(width: 140, height: 190)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.cardVisible)
    }

    var responseButtons: some View {
        HStack(spacing: 16) {
            // Match button (always visible after card 1)
            Button { vm.userTapped(response: "match") } label: {
                Text("Match")
                    .font(.title3.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(vm.showMatchButton ? Color.green : Color(.systemGray4))
                    )
            }
            .disabled(!vm.showMatchButton || vm.taskState != .showing)

            // New button
            Button { vm.userTapped(response: "new") } label: {
                Text("New")
                    .font(.title3.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(vm.taskState != .showing)
        }
    }
}
