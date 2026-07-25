// Tests for the structure checker: it must accept real Swift constructs and
// reject genuine breakage. A checker that never fails is worse than none.
const { checkSource } = require('./syntax-check');

let pass = 0, fail = 0;
const ok = (cond, name) => cond ? pass++ : (fail++, console.log('FAIL ' + name));
const clean = (src, name) => {
  const e = checkSource(src);
  ok(e.length === 0, `${name} — expected clean, got: ${e.map(x => x.msg).join('; ')}`);
};
const broken = (src, name) => ok(checkSource(src).length > 0, `${name} — expected an error, got none`);

// --- valid Swift that must not trip the checker ---
clean('func f() { let x = [1, 2, 3] }', 'basic delimiters');
clean('let s = "a string with { an unbalanced brace"', 'braces inside strings ignored');
clean('let s = "closing paren ) alone"', 'closing delim inside string ignored');
clean('// a comment with { unbalanced\nfunc f() {}', 'line comment ignored');
clean('/* block { comment */ func f() {}', 'block comment ignored');
clean('/* outer /* inner { */ still comment */ func f() {}', 'nested block comments');
clean('let s = "escaped quote \\" still inside"', 'escaped quote');
clean('let s = "trailing backslash pair \\\\"', 'escaped backslash ends string');
clean('let s = "value: \\(x + (y * 2))"', 'interpolation with nested parens');
clean('let s = "\\(a) and \\(b)"', 'multiple interpolations');
clean('let s = "\\("nested \\(deep)")"', 'nested interpolation containing a string');
clean('let s = """\nmultiline with " quotes and { braces\n"""', 'multiline string');
clean('let s = #"raw \\(not interpolation) here"#', 'raw string ignores interpolation');
clean('let s = #"raw with "quotes" inside"#', 'raw string ignores bare quotes');
clean('let s = ##"double hash "# inside"##', 'double-hash raw string');
clean('let s = #"real \\#(x) interpolation"#', 'raw string with matching hash interpolation');
clean('let c: Character = "}"', 'lone closing brace as a string');
clean('let url = "https://example.com//not-a-comment"', 'slashes inside a string');

// --- breakage the checker must catch ---
broken('func f() { let x = 1', 'missing closing brace');
broken('func f() { } }', 'extra closing brace');
broken('func f( { }', 'mismatched paren/brace nesting');
broken('let a = [1, 2)', 'bracket closed by paren');
broken('/* unterminated comment func f() {}', 'unterminated block comment');
broken('let s = "unterminated\nfunc f() {}', 'unterminated single-line string');
broken('let s = "\\(x + 1"', 'unclosed interpolation');
broken('func f() {\n  if true {\n    print("hi")\n}', 'missing brace in nested block');

// --- the specific regression this tool exists to catch ---
broken(`
struct A: View {
    var body: some View {
        VStack {
            Text("hello")
    }
}
`, 'dropped brace in a SwiftUI view');

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
