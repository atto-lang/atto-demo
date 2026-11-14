import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,lstatSync} from 'node:fs';
import {resolve,dirname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const catalog=JSON.parse(readFileSync(resolve(root,'examples/manifest.json'),'utf8'));
function validate(data) {
  assert.equal(data.schema,'atto.demo.examples.v1');
  assert.ok(Array.isArray(data.examples) && data.examples.length>=2);
  const ids=new Set();
  for(const e of data.examples) {
    assert.match(e.id,/^[a-z][a-z0-9-]+$/);
    assert.ok(!ids.has(e.id));ids.add(e.id);
    assert.match(e.path,/^examples\/[a-z0-9-]+\.atto$/);
    assert.equal(e.status,'candidate');
    assert.equal(e.execution,'not_executed_here');
    assert.ok(Number.isSafeInteger(e.expected_return));
    assert.match(e.source_reference,/^https:\/\/github\.com\/atto-lang\//);
    const file=resolve(root,e.path);
    assert.ok(file.startsWith(root+sep));
    const st=lstatSync(file);
    assert.ok(st.isFile()&&!st.isSymbolicLink()&&st.size<65536);
    const source=readFileSync(file,'utf8');
    assert.match(source,/pub fnc main\(\): int \{/);
    assert.match(source,/return /);
    assert.doesNotMatch(source,/\.ores\b/);
  }
}
test('catalog is a safe, explicit not-executed inventory',()=>validate(catalog));
test('reject path traversal and false evidence claims',()=>{
  for(const mutation of [{path:'../secret.atto'},{path:'examples/legacy.ores'},{execution:'passed'},{status:'supported'}]){
    assert.throws(()=>validate({...catalog,examples:[{...catalog.examples[0],...mutation},catalog.examples[1]]}));
  }
  assert.throws(()=>validate({...catalog,examples:[catalog.examples[0],catalog.examples[0]]}));
});
test('both examples document the same expected scalar return without claiming it ran',()=>{
  assert.deepEqual(catalog.examples.map(x=>x.expected_return),[42,42]);
  for(const entry of catalog.examples) assert.match(readFileSync(resolve(root,entry.path),'utf8'),/return .*;/);
});
