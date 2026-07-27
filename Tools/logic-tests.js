// Faithful JS ports of the pure logic in the Swift sources, so the algorithms
// can be exercised without an Xcode toolchain. Any change to the Swift must be
// mirrored here. Run: node logic-tests.js

let pass = 0, fail = 0;
function eq(actual, expected, name) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a === e) { pass++; } else { fail++; console.log(`FAIL ${name}\n  expected ${e}\n  actual   ${a}`); }
}
function ok(cond, name) { if (cond) pass++; else { fail++; console.log(`FAIL ${name}`); } }

// ---------- BounceCastGameView.swift physics ----------
const DIR = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] }; // [dx, dy]
function reflect(dir, bumper) {
  if (bumper === '/') return { right: 'up', up: 'right', left: 'down', down: 'left' }[dir];
  return { right: 'down', down: 'right', left: 'up', up: 'left' }[dir];
}
const entryDirection = { top: 'down', bottom: 'up', left: 'right', right: 'left' };
function entryCell(edge, i) {
  return { top: [0, i], bottom: [4, i], left: [i, 0], right: [i, 4] }[edge]; // [row, col]
}
function exitSlot(cell, dir) {
  const [row, col] = cell;
  return { up: ['top', col], down: ['bottom', col], left: ['left', row], right: ['right', row] }[dir];
}
const inside = ([r, c]) => r >= 0 && r < 5 && c >= 0 && c < 5;

function simulate(edge, index, bumpers) {
  let dir = entryDirection[edge];
  let cell = entryCell(edge, index);
  const path = [];
  let crossed = 0, steps = 0;
  while (steps < 100) {
    steps++;
    path.push([...cell]);
    const key = `${cell[0]},${cell[1]}`;
    if (bumpers[key]) { crossed++; dir = reflect(dir, bumpers[key]); }
    const [dx, dy] = DIR[dir];
    const next = [cell[0] + dy, cell[1] + dx];
    if (!inside(next)) return { exit: exitSlot(cell, dir), path, crossed };
    cell = next;
  }
  return { exit: exitSlot(cell, dir), path, crossed };
}

// Straight through, no bumpers
eq(simulate('left', 2, {}).exit, ['right', 2], 'bounce: empty board left->right');
eq(simulate('top', 0, {}).exit, ['bottom', 0], 'bounce: empty board top->bottom');
eq(simulate('right', 4, {}).exit, ['left', 4], 'bounce: empty board right->left');

// Single "/" deflection: enter left row 2 heading right, bumper at (2,2) -> turns up -> exits top col 2
eq(simulate('left', 2, { '2,2': '/' }).exit, ['top', 2], 'bounce: single slash deflects up');
eq(simulate('left', 2, { '2,2': '/' }).crossed, 1, 'bounce: crossed count = 1');

// Single "\" deflection: enter left row 2 heading right, bumper at (2,2) -> turns down -> exits bottom col 2
eq(simulate('left', 2, { '2,2': '\\' }).exit, ['bottom', 2], 'bounce: single backslash deflects down');

// Two deflections routing back out the left edge
// enter left row 0 heading right; "\" at (0,3) -> down; "/" at (3,3) -> left; exits left row 3
eq(simulate('left', 0, { '0,3': '\\', '3,3': '/' }).exit, ['left', 3], 'bounce: double deflection');
eq(simulate('left', 0, { '0,3': '\\', '3,3': '/' }).crossed, 2, 'bounce: crossed count = 2');

// Reversibility: light entering the exit backwards retraces the path (mirror-maze invariant)
for (const [edge, idx] of [['left', 1], ['top', 3], ['bottom', 2], ['right', 0]]) {
  const bumpers = { '1,1': '/', '3,3': '\\', '2,4': '/', '0,2': '\\' };
  const fwd = simulate(edge, idx, bumpers);
  const back = simulate(fwd.exit[0], fwd.exit[1], bumpers);
  eq(back.exit, [edge, idx], `bounce: reversible from ${edge}${idx}`);
}

// Termination: no configuration should hit the 100-step cap
let maxSteps = 0;
for (let trial = 0; trial < 3000; trial++) {
  const bumpers = {};
  const n = 2 + Math.floor(Math.random() * 4);
  while (Object.keys(bumpers).length < n) {
    bumpers[`${Math.floor(Math.random() * 5)},${Math.floor(Math.random() * 5)}`] =
      Math.random() < 0.5 ? '/' : '\\';
  }
  const edges = ['top', 'bottom', 'left', 'right'];
  const r = simulate(edges[Math.floor(Math.random() * 4)], Math.floor(Math.random() * 5), bumpers);
  maxSteps = Math.max(maxSteps, r.path.length);
}
ok(maxSteps < 100, `bounce: always terminates (worst path ${maxSteps} steps)`);

// ---------- AppStorage.swift brain-score curves ----------
const clamp = v => Math.max(70, Math.min(145, Math.trunc(v)));
const memoryBrainScore = l => clamp(60 + l * 6);
const reflexBrainScore = ms => clamp(100 + (280 - ms) / 3);
const speedBrainScore = c => clamp(10 + c * 3);
const switchBrainScore = c => clamp(40 + c * 2);
const nbackBrainScore = (n, acc) => clamp(45 + n * 20 + Math.trunc(acc / 10));
const bounceBrainScore = c => clamp(40 + c * 13);

// Every curve must stay inside the documented 70-145 band at its extremes
for (const [name, fn, lo, hi] of [
  ['memory', memoryBrainScore, 0, 100],
  ['speed', speedBrainScore, 0, 500],
  ['switch', switchBrainScore, 0, 500],
  ['bounce', bounceBrainScore, 0, 8],
]) {
  let bad = false;
  for (let v = lo; v <= hi; v++) { const s = fn(v); if (s < 70 || s > 145) bad = true; }
  ok(!bad, `score curve ${name} stays in 70-145`);
}
ok(reflexBrainScore(50) <= 145 && reflexBrainScore(5000) >= 70, 'score curve reflex stays in 70-145');
let nbBad = false;
for (let n = 0; n <= 6; n++) for (let a = 0; a <= 100; a++) { const s = nbackBrainScore(n, a); if (s < 70 || s > 145) nbBad = true; }
ok(!nbBad, 'score curve nback stays in 70-145');

// Anchors: the comments claim these map to ~100 (population average)
ok(Math.abs(memoryBrainScore(7) - 100) <= 5, 'memory level 7 ~= 100');
ok(Math.abs(speedBrainScore(30) - 100) <= 5, 'speed 30 correct ~= 100');
ok(Math.abs(reflexBrainScore(280) - 100) <= 5, 'reflex 280ms ~= 100');
ok(Math.abs(switchBrainScore(30) - 100) <= 5, 'switch 30 correct ~= 100');
ok(Math.abs(nbackBrainScore(2, 75) - 100) <= 8, 'nback 2-back @75% ~= 100');
ok(Math.abs(bounceBrainScore(5) - 100) <= 8, 'bounce 5/8 ~= 100');

// Monotonicity — a better raw score must never lower the brain score
for (const [name, fn, hi] of [['memory', memoryBrainScore, 30], ['speed', speedBrainScore, 60],
                              ['switch', switchBrainScore, 60], ['bounce', bounceBrainScore, 8]]) {
  let mono = true;
  for (let v = 1; v <= hi; v++) if (fn(v) < fn(v - 1)) mono = false;
  ok(mono, `score curve ${name} is monotonic`);
}

// ---------- overallBrainScore ----------
function overallBrainScore(scores) {
  const s = scores.filter(v => v > 0);
  if (s.length < 3) return 0;
  return Math.trunc(s.reduce((a, b) => a + b, 0) / s.length);
}
eq(overallBrainScore([0, 0, 0, 0]), 0, 'overall: nothing played = 0');
eq(overallBrainScore([100, 110, 0]), 0, 'overall: 2 games is not enough');
eq(overallBrainScore([100, 110, 120]), 110, 'overall: 3 games averages');
eq(overallBrainScore([100, 110, 120, 0, 0, 0, 0]), 110, 'overall: zeros excluded');

// ---------- currentStreak (lapsed streaks must read 0) ----------
function currentStreak(dailyStreakCount, daysSinceLastPlay) {
  if (daysSinceLastPlay === null) return 0;
  return daysSinceLastPlay <= 1 ? dailyStreakCount : 0;
}
eq(currentStreak(12, 0), 12, 'streak: played today');
eq(currentStreak(12, 1), 12, 'streak: played yesterday still alive');
eq(currentStreak(12, 2), 0, 'streak: 2-day gap is broken');
eq(currentStreak(12, 30), 0, 'streak: month gap is broken');
eq(currentStreak(0, null), 0, 'streak: never played');

// ---------- TodayWorkout rotation ----------
const buckets = [
  ['memory', 'spatial', 'nback', 'bounce'],
  ['flanker', 'color'],
  ['speed', 'visual', 'reflex'],
  ['switch', 'pattern'],
];
function workout(day) {
  const skipped = day % buckets.length;
  const plan = [];
  buckets.forEach((b, i) => { if (i !== skipped) plan.push(b[Math.floor(day / buckets.length) % b.length]); });
  return plan;
}
let allThree = true, allUnique = true, dupDays = 0;
const seenPlans = new Set();
for (let d = 0; d < 400; d++) {
  const p = workout(d);
  if (p.length !== 3) allThree = false;
  if (new Set(p).size !== 3) allUnique = false;
  seenPlans.add(p.join(','));
  if (d > 0 && workout(d - 1).join(',') === p.join(',')) dupDays++;
}
ok(allThree, 'workout: always exactly 3 games');
ok(allUnique, 'workout: no repeated game within a day');
ok(dupDays === 0, 'workout: plan changes every day');
ok(seenPlans.size >= 8, `workout: rotation covers ${seenPlans.size} distinct plans`);
// every game must appear in the rotation at some point
const covered = new Set();
for (let d = 0; d < 400; d++) workout(d).forEach(g => covered.add(g));
eq(covered.size, 11, 'workout: every one of the 11 games gets scheduled');

// ---------- N-back staircase ----------
function staircase(n, accuracy) {
  if (accuracy >= 80) return Math.min(4, n + 1);
  if (accuracy <= 50) return Math.max(1, n - 1);
  return n;
}
eq(staircase(1, 90), 2, 'staircase: high accuracy levels up');
eq(staircase(2, 65), 2, 'staircase: mid accuracy holds');
eq(staircase(2, 40), 1, 'staircase: low accuracy levels down');
eq(staircase(1, 10), 1, 'staircase: floors at 1');
eq(staircase(4, 100), 4, 'staircase: caps at 4');

// ---------- accuracy guards (the Flanker exploit) ----------
function accuracy(correct, total) { return total > 0 ? Math.round((correct / total) * 100) : 0; }
eq(accuracy(0, 0), 0, 'accuracy: no answers scores 0, not 100');
eq(accuracy(8, 10), 80, 'accuracy: normal case');

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
