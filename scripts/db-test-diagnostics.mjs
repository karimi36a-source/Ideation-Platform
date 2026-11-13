// Test-runner observability only. Never log SQL, arguments, payloads or environment.
import childProcess from "node:child_process";
import { syncBuiltinESMExports } from "node:module";
import { readFileSync } from "node:fs";
import { basename, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const begun = performance.now();
const sources = new Map();
let sequence = 0;
let currentSuite;
const elapsed = start => `${Math.round(performance.now() - start)}ms`;
const cumulative = () => `cumulative=${elapsed(begun)}`;
function origin() {
  for (const frame of new Error().stack.split("\n")) {
    const match = frame.match(/(file:\/\/\/[^)]+):(\d+):(\d+)\)?$/);
    if (!match || match[1] === import.meta.url || /at run \(/.test(frame)) continue;
    const path = fileURLToPath(match[1]);
    const source = relative(root, path).replaceAll("\\", "/");
    if (!source.startsWith("scripts/")) continue;
    if (!sources.has(path)) sources.set(path, readFileSync(path, "utf8").split(/\r?\n/));
    const line = Number(match[2]);
    const text = sources.get(path)[line - 1] ?? "";
    // Literal source filenames only; never the SQL text on that line.
    const files = [...text.matchAll(/["']((?:tests\/integration|scripts|supabase)\/[\w./-]+\.(?:sql|mjs))["']/g)].map(x => x[1]);
    return { source: `${source}:${line}`, files };
  }
  return { source: "scripts/test-db.mjs", files: [] };
}
function begin(name, source, kind) {
  const step = { id: ++sequence, name, source, kind, start: performance.now() };
  console.error(`[DB-TEST START] ${step.id} ${name} source=${source} command=${kind} ${cumulative()}`);
  return step;
}
function finish(step, ok, details = "") {
  console.error(`[DB-TEST ${ok ? "PASS" : "FAIL"}] ${step.id} ${step.name} ${elapsed(step.start)} source=${step.source} command=${step.kind} ${details} ${cumulative()}`);
}
export function suite(name, source, operation) {
  const previous = currentSuite;
  const step = begin(name, source, "helper");
  currentSuite = step;
  const done = (ok, value) => {
    finish(step, ok, ok ? "" : `error=${value?.code ?? value?.name ?? "Error"}`);
    currentSuite = previous;
    if (!ok) throw value;
    return value;
  };
  try {
    const result = operation();
    if (result?.then) return result.then(value => done(true, value), error => done(false, error));
    return done(true, result);
  } catch (error) { return done(false, error); }
}
export function command(name, args, operation) {
  const location = origin();
  const fileIndex = args.indexOf("-f");
  const file = fileIndex >= 0 ? args[fileIndex + 1] : null;
  const source = file && file !== "-" ? file : location.files.join("+") || location.source;
  const mode = file === "-" ? "stdin" : file ? "file" : args.includes("-c") ? "inline-SQL" : "control";
  const label = currentSuite ? `${currentSuite.name}/${name}@${location.source}` : source;
  const step = begin(label, source, `spawnSync:${name}:${mode}`);
  try {
    const result = operation();
    finish(step, !result.error && result.status === 0,
      `pid=${result.pid ?? "unknown"} exit=${result.status} signal=${result.signal ?? "none"} error=${result.error?.code ?? "none"}`);
    return result;
  } catch (error) {
    finish(step, false, `error=${error.code ?? error.name}`);
    throw error;
  }
}

// Observe the existing asynchronous children in every imported helper without
// changing their arguments, streams, timers, lifetime or cleanup behavior.
const originalSpawn = childProcess.spawn;
childProcess.spawn = function diagnosticSpawn(executable, args, options) {
  const location = origin();
  const name = basename(executable);
  const step = begin(`${currentSuite?.name ?? "runner"}/${name}@${location.source}`, location.source, `spawn:${name}`);
  let child;
  try { child = originalSpawn(executable, args, options); }
  catch (error) { finish(step, false, `error=${error.code ?? error.name}`); throw error; }
  console.error(`[DB-PROCESS START] step=${step.id} pid=${child.pid ?? "pending"} source=${location.source} ${cumulative()}`);
  child.once("error", error => console.error(`[DB-PROCESS ERROR] step=${step.id} pid=${child.pid ?? "none"} code=${error.code ?? error.name}`));
  child.once("close", (code, signal) => finish(step, code === 0, `pid=${child.pid ?? "none"} exit=${code} signal=${signal ?? "none"}`));
  return child;
};
syncBuiltinESMExports();
console.error(`[DB-RUN START] timestamp=${new Date().toISOString()} pid=${process.pid}`);
