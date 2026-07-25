// Syntax-checks all Swift files using tree-sitter-swift.
// Reports files containing ERROR or MISSING nodes with line/col context.
const Parser = require('tree-sitter');
const Swift = require('tree-sitter-swift');
const fs = require('fs');
const path = require('path');

const dir = process.argv[2];
const parser = new Parser();
parser.setLanguage(Swift);

let bad = 0;
const files = fs.readdirSync(dir).filter(f => f.endsWith('.swift')).sort();
for (const f of files) {
  const src = fs.readFileSync(path.join(dir, f), 'utf8');
  const tree = parser.parse(src);
  const errors = [];
  const walk = (node) => {
    if (node.type === 'ERROR' || node.isMissing) {
      errors.push(`${node.isMissing ? 'MISSING ' + node.type : 'ERROR'} at ${node.startPosition.row + 1}:${node.startPosition.column + 1} "${src.slice(node.startIndex, Math.min(node.endIndex, node.startIndex + 60)).replace(/\n/g, '\\n')}"`);
      return; // don't descend into error subtrees
    }
    for (let i = 0; i < node.childCount; i++) walk(node.child(i));
  };
  walk(tree.rootNode);
  if (errors.length) {
    bad++;
    console.log(`FAIL ${f}`);
    errors.slice(0, 5).forEach(e => console.log('  ' + e));
  }
}
console.log(bad === 0 ? `OK: all ${files.length} files parse cleanly` : `${bad}/${files.length} files with syntax errors`);
process.exit(bad ? 1 : 0);
