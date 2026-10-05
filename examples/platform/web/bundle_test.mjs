// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only
//
// Noninteractive validation for a C3 browser bundle. It checks that the
// standalone glue and WebGL assets are present, the template was substituted,
// the wasm module links against every declared namespace, and the ABI export
// agrees with the C3 source of truth.
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { GLUE_ABI_VERSION } from "./glue.js";

// The runner executes the source file, while direct bundle checks execute the
// copy under c3/build/examples/<name>/web. Resolve both layouts.
const bundleRoot = dirname(fileURLToPath(import.meta.url));
let root = resolve(bundleRoot, "../../../..");
if (!existsSync(join(root, "c3/src/rhi/rhi.c3"))) {
  root = resolve(bundleRoot, "../../../../..");
}
const [bundle, name] = process.argv.slice(2);
assert.ok(bundle && name, "usage: node bundle_test.mjs <bundle_dir> <name>");
const wasmFile = `${name}.wasm`;

const required = ["glue.js", "webgl_glue.js", "index.html", wasmFile];
const missing = required.filter((file) => !existsSync(join(bundle, file)));
assert.deepEqual(missing, [], `bundle ${bundle} is missing: ${missing.join(", ")}`);

const html = readFileSync(join(bundle, "index.html"), "utf8");
assert.ok(!html.includes("{{WASM_NAME}}"), "index.html still contains the {{WASM_NAME}} placeholder");
assert.ok(html.includes(`"./${wasmFile}"`), `index.html must boot ./${wasmFile}`);
assert.ok(html.includes('import { boot } from "./glue.js"'), "index.html must import ./glue.js");
assert.ok(!html.includes("odin.js"), "C3 bundle must not depend on the Odin runtime");

const c3Source = readFileSync(join(root, "c3/src/rhi/rhi.c3"), "utf8");
const match = c3Source.match(/^const\s+GLUE_ABI_VERSION\s*=\s*(\d+)/m);
assert.ok(match, "const GLUE_ABI_VERSION = N not found in c3/src/rhi/rhi.c3");
const c3Abi = Number(match[1]);
assert.equal(GLUE_ABI_VERSION, c3Abi, `glue.js ABI ${GLUE_ABI_VERSION} != c3/src/rhi/rhi.c3 ${c3Abi}`);

const module = new WebAssembly.Module(readFileSync(join(bundle, wasmFile)));
const namespaces = new Set(WebAssembly.Module.imports(module).map((item) => item.module));
assert.ok(namespaces.has("wgpu"), "wasm must import the wgpu namespace");
assert.ok(namespaces.has("webgl"), "wasm must import the webgl namespace");
const imports = {};
for (const imp of WebAssembly.Module.imports(module)) {
  const ns = (imports[imp.module] ??= {});
  switch (imp.kind) {
    case "function": ns[imp.name] = () => 0; break;
    case "memory": ns[imp.name] = new WebAssembly.Memory({ initial: 32 }); break;
    case "table": ns[imp.name] = new WebAssembly.Table({ initial: 0, element: "anyfunc" }); break;
    case "global": ns[imp.name] = new WebAssembly.Global({ value: "i32", mutable: true }, 0); break;
    default: throw new Error(`unexpected import kind ${imp.kind} for ${imp.module}.${imp.name}`);
  }
}
const instance = new WebAssembly.Instance(module, imports);
const wasmAbi = instance.exports.rhi_glue_abi_version();
assert.equal(wasmAbi, GLUE_ABI_VERSION, `${wasmFile} ABI ${wasmAbi} != glue.js ${GLUE_ABI_VERSION}`);

console.log(`${name} C3 bundle ok: ${required.length} files, glue ABI ${wasmAbi}`);
