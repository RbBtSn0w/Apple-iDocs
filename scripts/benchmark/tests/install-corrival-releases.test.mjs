import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, mkdir, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repoRoot = path.resolve(import.meta.dirname, "../../..");
const installer = path.join(repoRoot, "scripts/benchmark/install-corrival-releases.mjs");

test("dry-run installer records exact package metadata without network mutation", async () => {
  const outputDir = await mkdtemp(path.join(os.tmpdir(), "idocs-install-"));
  try {
    const output = path.join(outputDir, "versions.json");
    const result = spawnSync(process.execPath, [
      installer,
      "--dry-run",
      "--package-spec", "@kimsungwhee/apple-docs-mcp@1.0.26,apple-doc-mcp-server@1.9.1,@nshipster/sosumi@1.0.0",
      "--output", output
    ], { cwd: repoRoot, encoding: "utf8" });

    assert.equal(result.status, 0, result.stderr);
    const versions = JSON.parse(await readFile(output, "utf8"));
    assert.deepEqual(Object.keys(versions.packages), [
      "@kimsungwhee/apple-docs-mcp",
      "apple-doc-mcp-server",
      "@nshipster/sosumi"
    ]);
    assert.equal(versions.packages["@kimsungwhee/apple-docs-mcp"].resolvedVersion, "1.0.26");
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
});


test("installer records actual installed versions for ranges and tags", async () => {
  const root=await mkdtemp(path.join(os.tmpdir(),"idocs-installed-version-"));
  try {
    const bin=path.join(root,"bin");await mkdir(bin);
    await writeFile(path.join(bin,"npm"),`#!${process.execPath}
const fs=require('node:fs'),p=require('node:path'),a=process.argv.slice(2);
fs.appendFileSync(p.join(process.env.FIXTURE,'calls'),a[0]+'\\n');
if(a[0]==='view'){console.log(JSON.stringify(['1.0.0','1.9.2']));process.exit(0);}
if(a[0]!=='install')process.exit(42);
const prefix=a[a.indexOf('--prefix')+1];
for(const [name,version]of [['@scope/fixture','1.9.2'],['unscoped-fixture','2.0.1']]){const dir=p.join(prefix,'node_modules',name);fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(p.join(dir,'package.json'),JSON.stringify({name,version}));}
`,{mode:0o755});
    const output=path.join(root,'versions.json');
    const result=spawnSync(process.execPath,[installer,'--package-spec','@scope/fixture@^1.0.0,unscoped-fixture@latest','--output',output,'--install-dir',path.join(root,'install')],{cwd:repoRoot,env:{...process.env,PATH:bin+':'+process.env.PATH,FIXTURE:root},encoding:'utf8'});
    assert.equal(result.status,0,result.stderr);
    const metadata=JSON.parse(await readFile(output,'utf8'));
    assert.equal(metadata.packages['@scope/fixture'].resolvedVersion,'1.9.2');
    assert.equal(metadata.packages['unscoped-fixture'].resolvedVersion,'2.0.1');
    assert.equal((await readFile(path.join(root,'calls'),'utf8')).trim(),'install');
    const invalid=spawnSync(process.execPath,[installer,'--package-spec','../local','--output',path.join(root,'invalid.json'),'--install-dir',path.join(root,'unsafe')],{cwd:repoRoot,env:{...process.env,PATH:bin+':'+process.env.PATH,FIXTURE:root},encoding:'utf8'});
    assert.equal(invalid.status,2);assert.match(invalid.stderr,/registry package name/);
    assert.equal((await readFile(path.join(root,'calls'),'utf8')).trim(),'install');

  } finally {await rm(root,{recursive:true,force:true});}
});
