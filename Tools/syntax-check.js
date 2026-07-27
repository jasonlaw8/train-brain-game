// Structural check over every Swift source file. No dependencies — it must run
// anywhere, including CI images with no compiler toolchain.
//
// It is a lexer, not a parser: it tokenizes Swift's comment and string forms
// (nested block comments, multiline strings, raw strings with # delimiters, and
// recursive \( ) interpolation) and then verifies that every delimiter is
// balanced and correctly nested.
//
// That catches the failure mode of editing Swift without a compiler — a brace
// dropped or doubled by a bad edit. It does NOT type-check, resolve symbols, or
// validate syntax beyond delimiters. Build in Xcode before shipping.

const fs = require('fs');
const path = require('path');

const OPEN = { '(': ')', '[': ']', '{': '}' };
const CLOSE = { ')': '(', ']': '[', '}': '{' };

function checkSource(src) {
  const errors = [];
  const stack = [];          // open delimiters awaiting a match
  let line = 1, col = 1;
  let i = 0;
  const n = src.length;

  let blockDepth = 0;        // Swift block comments nest
  const strings = [];        // active string contexts: {multiline, hashes}

  const at = k => (k >= 0 && k < n ? src[k] : '');
  const startsWith = (k, s) => src.startsWith(s, k);

  const advance = (count = 1) => {
    for (let k = 0; k < count && i < n; k++) {
      if (src[i] === '\n') { line++; col = 1; } else { col++; }
      i++;
    }
  };

  while (i < n) {
    // ---- inside a block comment ----
    if (blockDepth > 0) {
      if (startsWith(i, '/*')) { blockDepth++; advance(2); continue; }
      if (startsWith(i, '*/')) { blockDepth--; advance(2); continue; }
      advance();
      continue;
    }

    // ---- inside a string literal ----
    if (strings.length > 0 && !strings[strings.length - 1].suspended) {
      const ctx = strings[strings.length - 1];
      const hashes = '#'.repeat(ctx.hashes);
      const terminator = (ctx.multiline ? '"""' : '"') + hashes;

      // A backslash only escapes when followed by the matching hash count.
      if (at(i) === '\\' && startsWith(i + 1, hashes)) {
        const after = i + 1 + ctx.hashes;
        if (at(after) === '(') {
          // Interpolation: parentheses resume normal delimiter tracking.
          stack.push({ ch: '(', line, col, interpolation: true });
          advance(1 + ctx.hashes + 1);
          strings.push({ suspended: true });
          continue;
        }
        advance(2 + ctx.hashes);   // ordinary escape — skip the escaped char
        continue;
      }
      if (startsWith(i, terminator)) {
        strings.pop();
        advance(terminator.length);
        continue;
      }
      if (at(i) === '\n' && !ctx.multiline) {
        errors.push({ line, col, msg: 'unterminated string literal' });
        strings.pop();
      }
      advance();
      continue;
    }

    // ---- normal code ----
    if (startsWith(i, '//')) {
      while (i < n && src[i] !== '\n') advance();
      continue;
    }
    if (startsWith(i, '/*')) { blockDepth++; advance(2); continue; }

    // String openers, optionally prefixed with # for raw strings.
    let hashCount = 0;
    while (at(i + hashCount) === '#') hashCount++;
    if (at(i + hashCount) === '"') {
      const q = i + hashCount;
      const multiline = startsWith(q, '"""');
      strings.push({ multiline, hashes: hashCount });
      advance(hashCount + (multiline ? 3 : 1));
      continue;
    }

    const ch = at(i);
    if (OPEN[ch]) {
      stack.push({ ch, line, col });
      advance();
      continue;
    }
    if (CLOSE[ch]) {
      const top = stack.pop();
      if (!top) {
        errors.push({ line, col, msg: `unmatched closing '${ch}'` });
      } else if (top.ch !== CLOSE[ch]) {
        errors.push({
          line, col,
          msg: `closing '${ch}' does not match '${top.ch}' opened at ${top.line}:${top.col}`,
        });
      } else if (top.interpolation) {
        // Interpolation closed — resume the enclosing string literal.
        if (strings.length && strings[strings.length - 1].suspended) strings.pop();
      }
      advance();
      continue;
    }
    advance();
  }

  if (blockDepth > 0) errors.push({ line, col, msg: 'unterminated block comment' });
  for (const open of stack.reverse()) {
    errors.push({ line: open.line, col: open.col, msg: `unclosed '${open.ch}'` });
  }
  return errors;
}

function main() {
  const dir = process.argv[2];
  if (!dir) {
    console.error('usage: node syntax-check.js <dir-of-swift-files>');
    process.exit(2);
  }
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.swift')).sort();
  if (files.length === 0) {
    console.error(`no .swift files found in ${dir}`);
    process.exit(2);
  }

  let bad = 0;
  for (const f of files) {
    const errors = checkSource(fs.readFileSync(path.join(dir, f), 'utf8'));
    if (errors.length) {
      bad++;
      console.log(`FAIL ${f}`);
      for (const e of errors.slice(0, 5)) console.log(`  ${e.line}:${e.col}  ${e.msg}`);
      if (errors.length > 5) console.log(`  ...and ${errors.length - 5} more`);
    }
  }
  console.log(bad === 0
    ? `OK: ${files.length} files structurally balanced`
    : `${bad}/${files.length} files with structural errors`);
  process.exit(bad ? 1 : 0);
}

if (require.main === module) main();
module.exports = { checkSource };
