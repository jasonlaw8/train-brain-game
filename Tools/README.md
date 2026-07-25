# Testing TrainBrain

Two layers: checks that run anywhere, and real UI testing on a Mac.

## 1. Checks that run without Xcode

These exist because CI and cloud dev environments have no Swift toolchain and
no simulator. They are not a substitute for building — they catch the classes
of mistake that are cheap to catch early.

```bash
cd Tools
npm install
npm test
```

**`syntax-check.js`** parses every `.swift` file with tree-sitter-swift and
fails on any `ERROR` or `MISSING` node. This catches unbalanced braces and
malformed declarations — the failure mode when editing Swift without a
compiler. It does not type-check.

**`logic-tests.js`** holds JS ports of the pure logic in the app and exercises
it: Bounce Cast's ball physics (deflection table, reversibility, termination),
every brain-score curve (range, monotonicity, population anchors), the
`overallBrainScore` threshold, streak expiry, the Today's Workout rotation, the
n-back staircase, and the accuracy guards. **When you change one of those
algorithms in Swift, mirror it here** — the port is the test.

This suite is how the Reflex scoring bug was found: the curve's own comment
claimed 280 ms mapped to 100, but the formula returned 70, so every player
scored the floor of the scale.

## 2. UI testing on a Mac — XcodeBuildMCP

There is no MCP server that can drive an iOS app from Linux; a simulator needs
macOS. On a Mac, **[XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP)**
gives an agent the same kind of control Playwright gives over a web app: build
the scheme, boot a simulator, install and launch, tap/swipe/type by coordinate
or accessibility identifier, read the view hierarchy, and capture screenshots
and logs.

Add it to Claude Code on your Mac:

```bash
claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest
```

Then a request like *"build TrainBrain for the iPhone 16 simulator, play a
round of Switchboard, and screenshot the results screen"* becomes a single
agent task. Useful loops:

- **Smoke test each game.** Launch, open every game from Train, start a round,
  leave mid-game, and confirm no session was recorded (this is what the
  `abandon()` cleanup added — the regression is silent without a UI check).
- **Layout at accessibility text sizes.** Boot with the largest Dynamic Type
  setting and screenshot every game-over screen.
- **VoiceOver labels.** Dump the accessibility hierarchy and check no control
  reads as "button" with no label.

Alternatives if you prefer: [mobile-mcp](https://github.com/mobile-next/mobile-mcp)
(works across iOS and Android, more device-automation flavored) or Xcode's own
XCUITest if you'd rather write tests than drive an agent. There is no XCUITest
target in this project yet; adding one is the natural next step for anything
you want enforced in CI.

## 3. What still needs a human

Neither layer above judges feel. Before shipping, play through on a device and
check pacing (are countdowns too slow on replay?), haptic intensity, and
whether the difficulty staircase lands anywhere near the intended ~79%
accuracy for a real player rather than in theory.
