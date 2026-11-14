// Optional native compiler + executable WebAssembly guest conformance test.
// This is not part of host-only catalog tests: set ATTOC and ATTO_COMPILER_HEAD.
// Private carrier integration. Run real guest Wasm, never label host-only checks as guest execution.
import assert from 'node:assert/strict';
import {readFileSync, mkdtempSync, rmSync, existsSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const root=resolve(new URL('../',import.meta.url).pathname);
const attoc=resolve(process.env.ATTOC||'missing-attoc');
const hex=/^[a-f0-9]{40}$/;
assert.ok(hex.test(process.env.ATTO_COMPILER_HEAD||''),'ATTO_COMPILER_HEAD must pin a 40-digit source commit');
assert.ok(existsSync(attoc), 'compiled native attoc unavailable');
const manifest=JSON.parse(readFileSync(join(root,'examples/manifest.json','utf8'));
assert.equal(manifest.schema,'atto.demo.examples.v1');
assert.equal(manifest.examples.length,2);
const decoder=new TextDecoder('utf-8',{fatal:true});
const expectedOutputs={'scalar-42':'','functions-and-stdio':'Hello from WebAssembly!\n42\n'};
const tmp=mkdtempSync(join(tmpdir(),'atto-guest-'));
let passed=0;
try {
  for(const fixture of manifest.examples){
    assert.equal(fixture.execution,'not_executed_here', 'do not rewrite original repository evidence without a reviewed receipt');
    assert.match(fixture.path,/^examples\/[a-z0-9-]+\.atto$/);
    assert.equal(fixture.expected_return,42);
    const sourcePath=join(root,fixture.path);
    const out=join(tmp,fixture.id+'.wasm');
    const compile=spawnSync(attoc,[sourcePath,'-o',out],{encoding:'utf8',timeout:60000,maxBuffer:1<<20});
    assert.equal(compile.status,0,fixture.id+': real native Atto compiler failed: '+compile.stderr);
    const guest=readFileSync(out);
    assert.ok(WebAssembly.validate(guest),fixture.id+': generated guest invalid');
    const mod=new WebAssembly.Module(guest);
    const allowed=new Set(['print_i64','print_bool','print_str','print_newline','print_f64']);
    for(const imp of WebAssembly.Module.imports(mod)){
      assert.equal(imp.module,'atto');
      assert.ok(allowed.has(imp.name), 'unknown guest import '+imp.name);
    }
    let instance;
    let stdout='';
    const atto={
      print_i64(v){stdout+=String(v);},
      print_bool(v){stdout+=v?'true':'false';},
      print_str(ptr,len){stdout+=decoder.decode(new Uint8Array(instance.exports.memory.buffer,ptr,len));},
      print_newline(){stdout+='\n';},
      print_f64(v){stdout+=String(v);}
    };
    instance=new WebAssembly.Instance(mod,{atto});
    assert.equal(typeof instance.exports.main,'function');
    const actual=instance.exports.main();
    assert.equal(actual,42n,'incorrect executed main() value for '+fixture.id);
    assert.equal(Number(instance.exports.panic_code?.value??0),0,'guest panic');
    assert.equal(stdout,expectedOutputs[fixture.id],'stdout mismatch '+fixture.id);
    console.log(JSON.stringify({kind:'GUEST_EXECUTION',fixture:fixture.id,compiler_head:process.env.ATTO_COMPILER_HEAD,guest_sha256:createHash('sha256').update(guest).digest('hex'),return_value:String(actual),stdout,status:'passed'}));
    passed++;
  }
  // Negative source must fail without writing a guest artifact.
  const neg=join(tmp,'negative.atto'); const negWasm=join(tmp,'negative.wasm');
  const {writeFileSync}=await import('node:fs');
  writeFileSync(neg,'pub fnc main(): int { return not_defined; }\n');
  const reject=spawnSync(attoc,[neg,'-o',negWasm],{encoding:'utf8',timeout:60000});
  assert.equal(reject.status,1,'invalid Atto source incorrectly accepted');
  assert.ok(!existsSync(negWasm),'rejected compiler output emitted an artifact');
  assert.match(reject.stderr,/E_[A-Z_]+/,'invalid source missing compiler-owned code');
  console.log(JSON.stringify({kind:'NEGATIVE_NO_ARTIFACT',status:'passed'}));
  assert.equal(passed,2);
  console.log('PASS: two compiled Atto guest Wasm programs execute 42 and invalid source produces no artifact');
} finally {rmSync(tmp,{recursive:true,force:true});}
