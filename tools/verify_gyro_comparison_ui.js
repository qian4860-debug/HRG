// Exercise the standalone comparison table without a browser or network.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('HRG_WA_simulink/layered/docs/literature_method_matrix.html', 'utf8');
const script = source.match(/<script>([\s\S]*?)<\/script>/)[1];
function element() {
  return { value: '', textContent: '', children: [],
    append(child) { this.children.push(child); },
    replaceChildren() { this.children = []; } };
}
const elements = Object.fromEntries(['q', 'level', 'count', 'body'].map(key => [key, element()]));
const context = { document: {
  getElementById(key) { assert.ok(elements[key], key); return elements[key]; },
  createElement() { return element(); }
} };
vm.createContext(context);
vm.runInContext(script, context);
assert.equal(elements.body.children.length, 153);
elements.q.value = 'PIR';
context.render();
assert.ok(elements.body.children.some(row => row.children[0].textContent.startsWith('L054')));
assert.ok(elements.body.children.length < 153);
elements.q.value = '';
elements.level.value = 'pending_fulltext';
context.render();
assert.ok(elements.body.children.length > 0);
for (const row of elements.body.children) assert.ok(row.children[0].textContent.includes('pending_fulltext'));
elements.q.value = '__no_such_reference__';
context.render();
assert.equal(elements.body.children.length, 0);
assert.equal(elements.count.textContent, '显示 0 / 153 条');
console.log('PASS comparison UI: full list, keyword filter, evidence filter and empty result');
