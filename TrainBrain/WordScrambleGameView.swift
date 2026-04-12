import SwiftUI
import SwiftData

// Word Hunt — Swipe between letters in a circle to form words.
// Daily puzzle: same letters for all players on the same calendar day.

// MARK: - Word List

private let wordHuntWordSet: Set<String> = {
    if let url = Bundle.main.url(forResource: "words", withExtension: "txt"),
       let raw = try? String(contentsOf: url, encoding: .utf8) {
        let words = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { w in w.count >= 3 && w.count <= 8 && w.allSatisfy { $0.isLetter } }
        if !words.isEmpty { return Set(words) }
    }
    return Set(fallbackWords)
}()

private let fallbackWords: [String] = [
    "the","and","are","can","has","his","was","had","one","all","not","you","she","get","its",
    "him","how","now","day","see","two","way","who","man","old","put","say","but","did","let",
    "age","ago","aim","air","ant","art","ask","ate","bad","bag","bar","bat","bed","big","bit",
    "bow","box","bug","bus","buy","cap","car","cat","cup","cut","dig","dot","dry","dug","ear",
    "eat","egg","end","eye","fan","far","fat","few","fit","fly","fog","fun","fur","gap","gas",
    "gem","gun","guy","hat","hay","hen","hit","hop","hot","hug","ice","jar","jet","job","joy",
    "jug","key","kid","kit","lap","law","lay","leg","lip","log","lot","low","mad","map","mat",
    "mud","nap","net","nut","oak","odd","oil","ore","pad","pan","paw","pay","pen","pet","pie",
    "pig","pin","pit","pop","pot","pub","rag","ran","rap","rat","raw","ray","red","rib","rid",
    "rip","rod","rot","row","rub","rug","rum","run","sad","sat","saw","sip","sit","sky","sob",
    "son","sun","tab","tan","tap","tar","tea","ten","tip","toe","top","toy","tug","van","war",
    "wax","web","wet","win","wit","yam","zip","able","aged","area","army","aunt","back","ball",
    "band","bank","barn","base","bath","bear","beat","bell","belt","best","bike","bill","bird",
    "bite","blow","blue","body","bold","bolt","bone","book","bore","born","bull","burn","bush",
    "cage","cake","call","calm","came","camp","card","care","cart","case","cave","cell","chin",
    "chip","clam","clap","clay","clip","club","clue","coat","code","coil","coin","cold","colt",
    "comb","come","cone","cook","cool","cope","cord","core","corn","cost","cove","crew","crop",
    "crow","cube","cure","curl","dare","dark","data","dawn","dead","dear","deep","deer","deny",
    "desk","diet","disk","dome","done","door","dose","dove","down","drag","draw","drip","drop",
    "drum","dull","dump","dune","dust","duty","earn","ease","east","easy","edge","even","face",
    "fact","fade","fail","fair","fake","fall","fame","farm","fast","fate","fear","feel","fell",
    "felt","file","fill","film","find","fine","fire","firm","fish","fist","flag","flat","flaw",
    "flee","flew","flip","flow","foam","fold","folk","fond","font","food","foot","ford","form",
    "fort","foul","four","free","frog","fuel","full","fume","fuse","gain","gate","gave","gaze",
    "gear","give","glad","glow","glue","goal","gold","golf","gone","good","gown","grab","gray",
    "grid","grin","grip","grit","grow","gulf","gust","half","hall","halt","hang","hard","harm",
    "hash","hate","haul","heal","heap","heat","heel","held","helm","help","herb","here","hero",
    "hide","high","hill","hint","hire","hold","hole","home","hood","hook","hope","horn","hose",
    "host","hour","huge","hunt","hurt","inch","iron","jade","jest","join","joke","jump","just",
    "keen","keep","kept","kick","kill","kind","king","kiss","knee","knew","lack","laid","lake",
    "lamb","lamp","land","lane","lash","late","lawn","lead","leaf","lean","leap","left","like",
    "lime","line","link","lion","list","live","load","loan","lock","loft","lone","long","loop",
    "lord","lore","lose","loss","lost","love","luck","lump","lung","maid","mail","main","make",
    "mark","mask","mass","mast","meal","mean","meat","meet","melt","menu","mesh","mild","milk",
    "mill","mine","mint","miss","mode","mole","mood","moon","moor","more","most","move","much",
    "mule","muse","must","mute","nail","name","navy","near","neck","need","nest","next","nice",
    "nine","node","noon","nose","note","oath","once","open","over","pace","pack","page","pain",
    "pair","pale","palm","park","part","pass","past","path","peak","peel","pine","pink","pipe",
    "plan","play","plot","plow","ploy","plug","plus","poem","pole","poll","pond","poor","pore",
    "port","pose","post","pour","pray","prey","prod","prop","pull","pump","pure","push","race",
    "rack","raid","rail","rain","rake","ramp","rang","rank","rant","rash","rate","real","reap",
    "reed","reef","reel","rely","rent","rest","rice","rich","ride","ring","riot","rise","risk",
    "rite","road","roam","roar","robe","rock","role","roll","roof","rope","rose","rout","rove",
    "rude","ruin","rule","rush","rust","safe","sage","sail","sale","same","sand","sang","sane",
    "sash","save","scan","scar","seam","seat","seed","seek","seem","self","sell","send","sent",
    "shed","shin","ship","shop","shot","show","shut","sick","side","sign","silk","sing","sink",
    "site","size","skin","skip","slam","slim","slip","slow","snap","snow","soak","soar","sock",
    "soft","soil","sold","sole","some","song","sore","sort","soul","soup","sour","span","spin",
    "spit","spot","spur","star","stay","stem","step","stew","stop","stub","suit","sung","sunk",
    "sure","surf","tail","tale","talk","tall","tame","task","team","tend","tent","term","tide",
    "till","time","tire","told","toll","tome","tone","tore","torn","toss","tour","town","trap",
    "trim","trip","true","tube","tune","turn","twin","type","vale","vary","veil","vein","verb",
    "very","vest","view","vine","vote","wade","wake","walk","wall","wand","want","ward","warm",
    "warn","wave","weak","wear","weed","week","well","went","were","west","wide","wild","will",
    "wind","wine","wing","wire","wise","wish","wolf","wood","wore","work","worm","worn","wrap",
    "yard","year","yell","zeal","about","above","abuse","acute","adapt","adept","adopt","adore",
    "after","again","agent","agree","alarm","alien","align","alone","along","alter","amaze","angel",
    "angle","angry","apart","apply","arena","argue","arise","array","arrow","beach","began","begin",
    "being","below","bench","black","blade","blame","blank","blast","blaze","bleed","bless","blind",
    "block","blood","bloom","blunt","board","boost","brace","brain","brand","brave","break","breed",
    "bring","brook","broom","broth","brown","brush","build","built","bunch","burst","camel","canal",
    "candy","carry","carve","catch","cause","chain","chair","chase","cheap","cheat","check","cheek",
    "cheer","chess","child","chill","choke","chord","chose","chunk","claim","clean","clear","click",
    "cliff","cling","close","cloud","coast","color","coral","count","court","cover","crack","craft",
    "crane","crash","crave","cream","crisp","cross","crowd","crown","crush","crust","curve","cycle",
    "daily","dance","delay","dense","depth","drive","drove","eager","early","earth","erase","error",
    "event","every","exact","extra","fable","faith","fancy","feast","fence","ferry","fetch","fever",
    "fiber","field","fight","final","flame","flash","flesh","flock","flood","floor","flute","force",
    "forge","found","frame","frank","fresh","front","frost","froth","fruit","fully","globe","gloom",
    "glory","gloss","glove","grace","grade","grain","grand","grant","graph","grasp","grass","grave",
    "great","green","greet","grief","grill","grind","groan","gross","group","grove","guard","guess",
    "guest","guide","guild","guise","hedge","heavy","hence","herbs","hinge","honor","horse","hotel",
    "house","human","humor","hurry","image","imply","index","inner","input","issue","jewel","judge",
    "karma","knack","label","large","laser","later","layer","learn","lease","ledge","legal","lemon",
    "level","light","limit","linen","liver","local","lodge","logic","loose","lower","lucky","lying",
    "magic","major","maker","manor","maple","march","marry","match","mayor","media","merge","merit",
    "metal","minor","model","moist","money","moral","motor","motto","mound","mount","mouse","mouth",
    "movie","music","naive","nerve","never","night","noble","noise","north","novel","nudge","nurse",
    "occur","offer","often","onion","order","other","outer","oxide","paint","panel","panic","paper",
    "party","pause","peace","pearl","peach","perch","phase","piece","pilot","pitch","place","plain",
    "plane","plant","plate","point","polar","power","price","pride","prime","print","prize","probe",
    "proud","prove","prune","pulse","purse","query","quest","raise","range","rapid","raven","reach",
    "realm","rebel","refer","reign","right","risen","rival","river","rivet","robin","robot","rough",
    "round","route","royal","ruler","salad","scene","scent","score","scout","shade","shake","shame",
    "shape","share","shark","sharp","sheet","shelf","shell","shift","shine","shirt","shock","shore",
    "short","shout","shove","sight","since","skill","skull","slack","slant","slave","sleep","slide",
    "slope","smart","smash","smell","smile","smoke","snake","solve","sound","south","space","spare",
    "spark","speak","spear","speed","spill","spite","sport","spray","stack","staff","stage","stain",
    "stale","stamp","stand","stare","stark","start","state","steel","stern","stick","still","sting",
    "stone","store","storm","story","straw","stray","strip","stuck","study","stump","stung","style",
    "sugar","surge","swamp","swept","swift","sword","table","taste","teach","tease","there","thick",
    "thing","think","third","thorn","three","tiger","tight","title","today","touch","tough","trace",
    "track","trade","trail","train","trait","tread","treat","trial","tribe","trick","trout","truck",
    "truly","trust","truth","twist","under","union","unite","unity","until","upper","upset","usual",
    "utter","vague","valid","valor","value","vapor","verse","video","vigor","virus","visit","vital",
    "vocal","voice","voter","wedge","weird","whale","wheat","wheel","where","while","white","whole",
    "whose","world","worse","worst","worth","would","wound","yield","young","youth"
]

// MARK: - Puzzle

private struct WordHuntPuzzle {
    let letters: [String]
    let requiredWords: [String]     // words the puzzle is built around, grouped by length
    let allValidWords: Set<String>  // every formable word from the letter set
}

// Anchor words for daily puzzle generation
private let anchorWords = [
    "GARDEN","PLANET","BRIDGE","TRAVEL","SIMPLE","MASTER","CASTLE","PRINCE","SQUARE","WINTER",
    "FOREST","SILVER","ORANGE","STREAM","BROKEN","GLANCE","SPRING","TENDER","HIDDEN","MIRROR",
    "STRONG","GRAPES","FLAMES","STABLE","CLOUDS","HEARTS","ROUNDS","LISTEN","FRIEND","CANDLE",
    "MARKET","BREEZE","BUNDLE","COBALT","DANGER","EDITOR","FAMOUS","GATHER","INTAKE","JIGSAW"
]

private func canForm(_ word: String, from letters: [String]) -> Bool {
    var pool = letters.map { $0.uppercased() }
    for ch in word.uppercased() {
        let s = String(ch)
        if let idx = pool.firstIndex(of: s) {
            pool.remove(at: idx)
        } else { return false }
    }
    return true
}

private func dailyPuzzle() -> WordHuntPuzzle {
    let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    let seed = (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
    let anchor = anchorWords[seed % anchorWords.count]
    let letters = Array(anchor).map { String($0) }
    // Deterministic shuffle using seed
    var rng = SeededRNG(seed: UInt64(seed))
    let shuffled = letters.shuffled(using: &rng)

    let valid = wordHuntWordSet.filter { canForm($0, from: shuffled) && $0.count >= 3 }
    let required = Array(valid.sorted { a, b in
        a.count != b.count ? a.count < b.count : a < b
    }.prefix(20))
    return WordHuntPuzzle(letters: shuffled, requiredWords: required, allValidWords: Set(valid))
}

// Simple seeded random number generator (LCG)
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - ViewModel

@MainActor
class WordScrambleViewModel: ObservableObject {
    enum GameState { case idle, playing, gameOver }

    @Published var gameState: GameState = .idle
    @Published var selectedIndices: [Int] = []
    @Published var foundWords: Set<String> = []
    @Published var bonusWordsList: [String] = []
    @Published var score: Int = 0
    @Published var timeRemaining: Double = 90
    @Published var lastResult: LastWordResult? = nil
    @Published var finalScore: Int = 0
    @Published var finalBrainScore: Int = 0

    struct LastWordResult: Equatable {
        let word: String
        let isBonus: Bool
        let isInvalid: Bool
        let points: Int
    }

    var onGameOver: ((Int) -> Void)?
    let combo = ComboTracker()
    private(set) var puzzle = dailyPuzzle()
    private var timerTask: Task<Void, Never>?
    private var difficulty: Difficulty = .medium

    var letters: [String] { puzzle.letters }

    var currentWord: String {
        selectedIndices.map { letters[$0] }.joined()
    }

    var wordsFound: Int { foundWords.count }

    var requiredByLength: [[String]] {
        var grouped: [Int: [String]] = [:]
        for w in puzzle.requiredWords {
            grouped[w.count, default: []].append(w)
        }
        return grouped.keys.sorted().map { grouped[$0]! }
    }

    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        let params = EloSystem.wordHuntParams(1000)
        timeRemaining = params.timerSeconds
        score = 0
        foundWords = []
        bonusWordsList = []
        selectedIndices = []
        lastResult = nil
        combo.reset()
        gameState = .playing
        startTimer()
    }

    func addLetterToPath(index: Int) {
        guard gameState == .playing else { return }
        guard !selectedIndices.contains(index) else { return }
        selectedIndices.append(index)
        Haptics.light()
    }

    func submitCurrentWord() {
        guard gameState == .playing else { return }
        let word = currentWord.lowercased()
        defer { selectedIndices = [] }
        guard word.count >= 3 else { return }
        guard !foundWords.contains(word) else { return }

        if puzzle.allValidWords.contains(word) {
            let isRequired = puzzle.requiredWords.contains(word)
            let base = word.count * 10
            let pts = combo.apply(isRequired ? base : base / 2)
            score += pts
            foundWords.insert(word)
            if !isRequired { bonusWordsList.append(word.uppercased()) }
            combo.markCorrect()
            SoundEngine.shared.playCorrect(streak: combo.streak)
            lastResult = LastWordResult(word: word.uppercased(), isBonus: !isRequired, isInvalid: false, points: pts)
            Task { try? await Task.sleep(for: .milliseconds(1200)); lastResult = nil }
        } else {
            combo.markWrong()
            SoundEngine.shared.playWrong()
            lastResult = LastWordResult(word: word.uppercased(), isBonus: false, isInvalid: true, points: 0)
            Task { try? await Task.sleep(for: .milliseconds(700)); lastResult = nil }
        }
    }

    func resetPath() { selectedIndices = [] }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while timeRemaining > 0 && gameState == .playing {
                try? await Task.sleep(for: .milliseconds(100))
                timeRemaining = max(0, timeRemaining - 0.1)
            }
            if gameState == .playing { endGame() }
        }
    }

    private func endGame() {
        timerTask?.cancel()
        finalScore = score
        finalBrainScore = max(70, min(145, 40 + wordsFound * 15))
        gameState = .gameOver
        onGameOver?(finalScore)
    }

    deinit { timerTask?.cancel() }
}

// MARK: - Main View

struct WordScrambleGameView: View {
    @StateObject private var vm = WordScrambleViewModel()
    @Query private var statsQuery: [PlayerStats]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("wordScrambleDifficulty") private var difficulty: Difficulty = .medium

    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats(); modelContext.insert(s); return s
    }

    @State private var showNewBest = false
    @State private var leveledUpTo: Int? = nil
    @State private var unlockedAchievement: Achievement? = nil

    var body: some View {
        ZStack {
            switch vm.gameState {
            case .idle:     preGameScreen
            case .playing:  playingScreen
            case .gameOver: gameOverScreen
            }
        }
        .navigationTitle("Word Hunt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.onGameOver = { finalScore in
                let prevBest = stats.wordScrambleBestScore
                let leveledUp = stats.recordWordScrambleGame(score: vm.wordsFound)
                let newAchievements = Achievement.allAchievements
                    .filter { !stats.isAchievementUnlocked($0.id) && $0.condition(stats) }
                for ach in newAchievements { _ = stats.unlockAchievement(ach.id) }
                modelContext.insert(GameSession(
                    gameType: "wordscramble", rawScore: finalScore,
                    brainScore: vm.finalBrainScore, difficulty: difficulty.rawValue
                ))
                stats.wordHuntEloRating = EloSystem.updated(
                    stats.wordHuntEloRating, correct: vm.wordsFound >= 8
                )
                if finalScore > prevBest { showNewBest = true }
                if leveledUp { leveledUpTo = stats.playerLevel }
                unlockedAchievement = newAchievements.first
            }
        }
    }

    // MARK: Pre-game

    private var preGameScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "text.word.spacing")
                    .font(.system(size: 52)).foregroundStyle(.mint)
                Text("Word Hunt").font(.largeTitle.bold())
                Text("Swipe between letters to form words")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 12) {
                Label("90 seconds to find as many words as possible", systemImage: "timer")
                Label("Swipe from letter to letter to spell words", systemImage: "hand.draw")
                Label("3+ letters. Longer words score more points", systemImage: "star.fill")
                Label("Find bonus words for extra points", systemImage: "sparkles")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.mint)
                Text("Daily Puzzle").font(.subheadline.bold())
                Spacer()
                Text("Same puzzle for everyone today").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Button {
                vm.startGame(difficulty: difficulty)
            } label: {
                Text("Start Word Hunt")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.mint.gradient, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
        }
        .padding(24)
    }

    // MARK: Playing

    private var playingScreen: some View {
        VStack(spacing: 0) {
            timerBar
            topStatsBar
            wordSlotsSection
            Spacer()
            currentWordPreview
            letterCircleSection
            foundWordsTicker
                .frame(height: 32)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .topTrailing) {
            MultiplierBadgeView(combo: vm.combo, color: .mint)
                .padding(.top, 8).padding(.trailing, 16)
        }
        .overlay(wordResultToast)
    }

    private var timerBar: some View {
        let fraction = vm.timeRemaining / 90.0
        let color: Color = fraction > 0.5 ? .mint : fraction > 0.25 ? .orange : .red
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(.systemFill))
                Rectangle().fill(color.gradient).frame(width: geo.size.width * CGFloat(fraction))
                    .animation(.linear(duration: 0.1), value: vm.timeRemaining)
            }
        }
        .frame(height: 6)
    }

    private var topStatsBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.score)").font(.title2.bold())
                Text("points").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vm.wordsFound)").font(.title2.bold())
                Text("words").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }

    private var wordSlotsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(vm.requiredByLength, id: \.self) { group in
                    wordLengthGroup(group)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 80)
    }

    private func wordLengthGroup(_ words: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(words[0].count) letters")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(words, id: \.self) { word in
                    wordSlot(word)
                }
            }
        }
    }

    private func wordSlot(_ word: String) -> some View {
        let found = vm.foundWords.contains(word)
        return Text(found ? word.uppercased() : String(repeating: "·", count: word.count))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(found ? .mint : .secondary)
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(found ? Color.mint.opacity(0.15) : Color(.systemFill))
            )
            .animation(.spring(response: 0.3), value: found)
    }

    private var currentWordPreview: some View {
        HStack(spacing: 4) {
            ForEach(Array(vm.currentWord.uppercased().enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.mint)
                    .transition(.scale.combined(with: .opacity))
            }
            if vm.currentWord.isEmpty {
                Text("Swipe to spell").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(height: 40)
        .animation(.spring(response: 0.2), value: vm.currentWord)
    }

    // MARK: Letter Circle

    private var letterCircleSection: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 44
            let letterSize: CGFloat = 56
            let positions = letterPositions(count: vm.letters.count, center: center, radius: radius)

            ZStack {
                // Connection lines
                Canvas { ctx, _ in
                    guard vm.selectedIndices.count >= 2 else { return }
                    var path = Path()
                    path.move(to: positions[vm.selectedIndices[0]])
                    for idx in vm.selectedIndices.dropFirst() {
                        path.addLine(to: positions[idx])
                    }
                    ctx.stroke(path, with: .color(.mint.opacity(0.7)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }

                // Letter buttons
                ForEach(Array(vm.letters.enumerated()), id: \.offset) { i, letter in
                    let pos = positions[i]
                    let isSelected = vm.selectedIndices.contains(i)
                    Text(letter)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(width: letterSize, height: letterSize)
                        .background(
                            Circle().fill(isSelected ? Color.mint.gradient : Color(.secondarySystemBackground).gradient)
                                .shadow(color: isSelected ? .mint.opacity(0.4) : .clear, radius: 8)
                        )
                        .position(pos)
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isSelected)
                }
            }
            // Drag gesture over the whole area
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let loc = value.location
                        for (i, pos) in positions.enumerated() {
                            let dist = hypot(loc.x - pos.x, loc.y - pos.y)
                            if dist < 30 { vm.addLetterToPath(index: i) }
                        }
                    }
                    .onEnded { _ in vm.submitCurrentWord() }
            )
        }
        .frame(height: 320)
        .padding(.horizontal, 16)
    }

    private func letterPositions(count: Int, center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<count).map { i in
            let angle = 2 * .pi / Double(count) * Double(i) - .pi / 2
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    // MARK: Found words ticker

    private var foundWordsTicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(vm.foundWords).sorted(), id: \.self) { word in
                    Text(word.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.mint)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.mint.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Word result toast

    @ViewBuilder
    private var wordResultToast: some View {
        if let result = vm.lastResult {
            VStack {
                HStack(spacing: 8) {
                    if result.isInvalid {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.orange)
                        Text(result.word).foregroundStyle(.orange)
                    } else if result.isBonus {
                        Image(systemName: "sparkles").foregroundStyle(.yellow)
                        Text("\(result.word) +BONUS!").foregroundStyle(.yellow)
                    } else {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint)
                        Text("\(result.word)  +\(result.points)").foregroundStyle(.mint)
                    }
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
                Spacer()
            }
            .padding(.top, 60)
            .animation(.spring(response: 0.3), value: vm.lastResult)
        }
    }

    // MARK: Game Over

    private var gameOverScreen: some View {
        GameOverView(
            result: GameResult(
                gameTitle: "Word Hunt",
                primaryScore: vm.finalScore,
                primaryLabel: "pts",
                brainScore: vm.finalBrainScore,
                previousBrainScore: stats.wordScrambleBrainScore,
                isNewBest: showNewBest,
                multiplierBreakdown: nil,
                percentileText: vm.wordsFound >= 12 ? "Excellent vocabulary!" :
                                vm.wordsFound >= 8  ? "Great word hunting!" :
                                vm.wordsFound >= 5  ? "Good effort!" : "Keep practicing!",
                accentColor: .mint,
                share: GameResult.ShareConfig(
                    gameName: "Word Hunt",
                    icon: "text.word.spacing",
                    color: .mint,
                    primaryValue: "\(vm.wordsFound)",
                    primaryLabel: "words",
                    secondaryLine: "\(vm.finalScore) pts"
                )
            ),
            onRetry: {
                showNewBest = false; leveledUpTo = nil; unlockedAchievement = nil
                vm.startGame(difficulty: difficulty)
            }
        )
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if showNewBest {
                    NewBestBanner().transition(.move(edge: .top).combined(with: .opacity))
                }
                if let lvl = leveledUpTo {
                    LevelUpBanner(level: lvl).transition(.move(edge: .top).combined(with: .opacity))
                }
                if let ach = unlockedAchievement {
                    AchievementUnlockedBanner(achievement: ach)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 8)
            .animation(.spring(response: 0.5), value: showNewBest)
        }
    }
}
