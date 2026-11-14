#!/usr/bin/env node
// WORLD.EXE ENV_SPRINT2 assembler. Produces 1_build.luau from build_template.luau and the two spec
// chunks (traversal_spec.luau by Agent A, exterior_spec.luau by Agent B). Deterministic: same inputs ->
// byte-identical output (LF line endings, no timestamps; input hashes recorded in the header).
//
//   node assemble.js                       # specs and output next to this file
//   node assemble.js --traversal a.luau --exterior b.luau --out 1_build.luau [--geometry parts.tsv]
//   node assemble.js --no-preflight        # skip the offline spec preflight (Studio still validates)
//   node assemble.js --check f1.luau ...   # structural Luau check only (blocks, brackets, strings)
//
// Steps: (1) read and normalise inputs; fail clearly if a spec is missing or empty; (2) offline
// preflight: evaluate each spec with a small Lua-table evaluator and apply the builder's rules and
// budgets (map-after uses the geometry export when found); (3) splice each spec into the template as
// `(function() <chunk> end)()`; (4) structural Luau check of the result; (5) write.
// The builder in Studio repeats every rule authoritatively; this preflight only fails earlier.
"use strict";
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const HERE = __dirname;
const MARK_T = "--@@TRAVERSAL_SPEC@@";
const MARK_E = "--@@EXTERIOR_SPEC@@";

function die(msg) {
  console.error("assemble: " + msg);
  process.exit(1);
}
function readText(p, what) {
  if (!fs.existsSync(p)) die(`${what} not found: ${p}`);
  let s = fs.readFileSync(p, "utf8");
  if (s.charCodeAt(0) === 0xfeff) s = s.slice(1);
  s = s.replace(/\r\n?/g, "\n");
  if (!s.endsWith("\n")) s += "\n";
  return s;
}
const sha = (s) => crypto.createHash("sha256").update(s, "utf8").digest("hex");

// ------------------------------------------------------------------------------------------------
// Lexer shared by the structural checker and the spec evaluator.
function lex(src, file) {
  const toks = [];
  let i = 0, line = 1;
  const n = src.length;
  const fail = (m) => { throw new Error(`${file}:${line}: ${m}`); };
  const longBracket = (at) => { // returns level or -1 for "[" "="* "["
    if (src[at] !== "[") return -1;
    let j = at + 1, lvl = 0;
    while (src[j] === "=") { lvl++; j++; }
    return src[j] === "[" ? lvl : -1;
  };
  const skipLong = (at, lvl) => {
    const close = "]" + "=".repeat(lvl) + "]";
    const end = src.indexOf(close, at);
    if (end < 0) fail("unterminated long string/comment");
    for (let k = at; k < end; k++) if (src[k] === "\n") line++;
    return end + close.length;
  };
  while (i < n) {
    const c = src[i];
    if (c === "\n") { line++; i++; continue; }
    if (c === " " || c === "\t" || c === "\r") { i++; continue; }
    if (c === "-" && src[i + 1] === "-") {
      const lvl = longBracket(i + 2);
      if (lvl >= 0) { i = skipLong(i + 2 + lvl + 2, lvl); continue; }
      while (i < n && src[i] !== "\n") i++;
      continue;
    }
    const startLine = line;
    if (c === '"' || c === "'") {
      let j = i + 1, val = "";
      while (true) {
        if (j >= n || src[j] === "\n") fail("unterminated string");
        if (src[j] === "\\") {
          const e = src[j + 1];
          const map = { n: "\n", t: "\t", r: "\r", "\\": "\\", '"': '"', "'": "'", "0": "\0" };
          if (e === "\n") { line++; val += "\n"; } else val += map[e] !== undefined ? map[e] : e;
          j += 2; continue;
        }
        if (src[j] === c) break;
        val += src[j++];
      }
      toks.push({ t: "str", v: val, line: startLine });
      i = j + 1; continue;
    }
    if (c === "`") { // Luau interpolated string: skip, balancing {} and nested quotes
      let j = i + 1, depth = 0;
      while (true) {
        if (j >= n) fail("unterminated interpolated string");
        const d = src[j];
        if (d === "\\") { j += 2; continue; }
        if (d === "\n") line++;
        if (depth === 0 && d === "`") break;
        if (d === "{") depth++;
        else if (d === "}") depth--;
        else if (depth > 0 && (d === '"' || d === "'")) { const q = d; j++; while (j < n && src[j] !== q) { if (src[j] === "\\") j++; j++; } }
        j++;
      }
      toks.push({ t: "str", v: "", interp: true, line: startLine });
      i = j + 1; continue;
    }
    if (c === "[") {
      const lvl = longBracket(i);
      if (lvl >= 0) {
        const s0 = i + lvl + 2;
        const close = "]" + "=".repeat(lvl) + "]";
        const end = src.indexOf(close, s0);
        if (end < 0) fail("unterminated long string");
        let v = src.slice(s0, end);
        if (v.startsWith("\n")) v = v.slice(1);
        i = skipLong(s0, lvl);
        toks.push({ t: "str", v, line: startLine });
        continue;
      }
    }
    if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(src[i + 1] || ""))) {
      const m = /^(0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:[0-9][0-9_]*)?\.?[0-9_]*(?:[eE][+-]?[0-9]+)?)/.exec(src.slice(i));
      const raw = m[0];
      const clean = raw.replace(/_/g, "");
      const v = /^0[bB]/.test(clean) ? parseInt(clean.slice(2), 2) : Number(clean);
      if (!Number.isFinite(v)) fail("bad number " + raw);
      toks.push({ t: "num", v, line: startLine });
      i += raw.length; continue;
    }
    if (/[A-Za-z_]/.test(c)) {
      const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(i));
      toks.push({ t: "name", v: m[0], line: startLine });
      i += m[0].length; continue;
    }
    const three = src.substr(i, 3), two = src.substr(i, 2);
    if (three === "..." || three === "..=" || three === "//=") { toks.push({ t: "op", v: three, line }); i += 3; continue; }
    if (["==", "~=", "<=", ">=", "..", "::", "->", "+=", "-=", "*=", "/=", "%=", "^=", "//"].includes(two)) { toks.push({ t: "op", v: two, line }); i += 2; continue; }
    if ("{}()[],;=.:+-*/%^#<>?&|".includes(c)) { toks.push({ t: "op", v: c, line }); i++; continue; }
    fail("unexpected character " + JSON.stringify(c));
  }
  toks.push({ t: "eof", line });
  return toks;
}

// ------------------------------------------------------------------------------------------------
// Structural Luau check: balanced blocks (function/do/repeat/statement-if vs end/until, with Luau
// if-expressions recognised), balanced brackets, terminated strings and comments. Not a full parser.
const EXPR_PREV = new Set(["=", "(", ",", "{", "[", "return", "and", "or", "not", "==", "~=", "<", ">", "<=", ">=", "..", "+", "-", "*", "/", "%", "^", "#", "+=", "-=", "*=", "/=", "..=", "//", "in", "then", "else", "elseif", "::", "->"]);
function checkStructure(src, file) {
  const toks = lex(src, file);
  const blocks = [], brackets = [];
  const pairs = { ")": "(", "]": "[", "}": "{" };
  let prev = null, elseExpr = false;
  for (const k of toks) {
    if (k.t === "eof") break;
    const v = k.v;
    const isKw = k.t === "name";
    if (k.t === "op" && "([{".includes(v)) brackets.push({ v, line: k.line });
    else if (k.t === "op" && ")]}".includes(v)) {
      const top = brackets.pop();
      if (!top || top.v !== pairs[v]) throw new Error(`${file}:${k.line}: unbalanced '${v}'`);
    } else if (isKw) {
      const top = blocks[blocks.length - 1];
      if (v === "function" || v === "do" || v === "repeat") blocks.push({ v, line: k.line });
      else if (v === "if") {
        // Expression-if: after an operator/opening token, or at the start of an if-expression's
        // else branch. "then" / "else" before a statement-if mean a nested statement.
        const pv = prev ? prev.v : null;
        const exprPos = elseExpr || (prev && ((prev.t === "op" && EXPR_PREV.has(pv)) || (prev.t === "name" && ["return", "and", "or", "not", "in"].includes(pv))));
        blocks.push({ v: exprPos ? "eif" : "if", line: k.line });
      } else if (v === "else") {
        if (top && top.v === "eif") { blocks.pop(); elseExpr = true; prev = k; continue; }
        if (!top || top.v !== "if") throw new Error(`${file}:${k.line}: 'else' outside if`);
      } else if (v === "elseif") {
        if (!top || (top.v !== "if" && top.v !== "eif")) throw new Error(`${file}:${k.line}: 'elseif' outside if`);
      } else if (v === "end") {
        const b = blocks.pop();
        if (!b || !["function", "do", "if"].includes(b.v)) throw new Error(`${file}:${k.line}: unexpected 'end'` + (b ? ` (open ${b.v} from line ${b.line})` : ""));
      } else if (v === "until") {
        const b = blocks.pop();
        if (!b || b.v !== "repeat") throw new Error(`${file}:${k.line}: unexpected 'until'`);
      }
    }
    elseExpr = false;
    prev = k;
  }
  if (brackets.length) throw new Error(`${file}: unclosed '${brackets[brackets.length - 1].v}' from line ${brackets[brackets.length - 1].line}`);
  const open = blocks.filter((b) => b.v !== "eif");
  if (open.length) throw new Error(`${file}: unclosed '${open[open.length - 1].v}' from line ${open[open.length - 1].line}`);
  return toks.length - 1;
}

// ------------------------------------------------------------------------------------------------
// Minimal evaluator for spec chunks: local/global assignments of expressions and one final return.
// Supports tables, numbers, strings, booleans, nil, arithmetic, Vector3.new / Color3.fromRGB, math.*.
class Unsupported extends Error {}
function evalSpec(src, file) {
  const toks = lex(src, file);
  let p = 0;
  const peek = () => toks[p];
  const next = () => toks[p++];
  const isOp = (v) => peek().t === "op" && peek().v === v;
  const isKw = (v) => peek().t === "name" && peek().v === v;
  const expectOp = (v) => { if (!isOp(v)) throw new Unsupported(`${file}:${peek().line}: expected '${v}'`); next(); };
  const V3 = (x, y, z) => ({ __v3: true, X: x, Y: y, Z: z, Magnitude: Math.hypot(x, y, z) });
  const env = new Map(Object.entries({
    Vector3: { new: (x = 0, y = 0, z = 0) => V3(x, y, z), zero: V3(0, 0, 0), one: V3(1, 1, 1) },
    Color3: { fromRGB: (r, g, b) => ({ __c3: true, r, g, b }) },
    math: { rad: (d) => (d * Math.PI) / 180, floor: Math.floor, ceil: Math.ceil, abs: Math.abs, min: Math.min, max: Math.max, sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, pi: Math.PI, huge: Infinity },
  }));
  const arith = (op, a, b) => {
    const num = (x) => typeof x === "number";
    if (num(a) && num(b)) return { "+": a + b, "-": a - b, "*": a * b, "/": a / b, "%": a - Math.floor(a / b) * b, "^": a ** b, "//": Math.floor(a / b) }[op];
    if (a && a.__v3 && b && b.__v3 && (op === "+" || op === "-")) return op === "+" ? V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) : V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z);
    if (a && a.__v3 && num(b) && (op === "*" || op === "/")) return op === "*" ? V3(a.X * b, a.Y * b, a.Z * b) : V3(a.X / b, a.Y / b, a.Z / b);
    if (num(a) && b && b.__v3 && op === "*") return V3(a * b.X, a * b.Y, a * b.Z);
    throw new Unsupported(`${file}: unsupported arithmetic ${op}`);
  };
  const PREC = { or: 1, and: 2, "<": 3, ">": 3, "<=": 3, ">=": 3, "~=": 3, "==": 3, "..": 5, "+": 6, "-": 6, "*": 7, "/": 7, "//": 7, "%": 7, "^": 10 };
  function primary() {
    const k = next();
    if (k.t === "num" || k.t === "str") { if (k.interp) throw new Unsupported(`${file}:${k.line}: interpolated string`); return k.v; }
    if (k.t === "name") {
      if (k.v === "nil") return undefined;
      if (k.v === "true") return true;
      if (k.v === "false") return false;
      if (["function", "if", "for", "while", "local", "return"].includes(k.v)) throw new Unsupported(`${file}:${k.line}: unsupported '${k.v}' in expression`);
      if (!env.has(k.v)) throw new Unsupported(`${file}:${k.line}: unknown name ${k.v}`);
      let val = env.get(k.v);
      for (;;) {
        if (isOp(".")) { next(); const nm = next(); val = val == null ? undefined : val[nm.v]; }
        else if (isOp("(")) {
          next();
          const args = [];
          if (!isOp(")")) { args.push(expr(0)); while (isOp(",")) { next(); args.push(expr(0)); } }
          expectOp(")");
          if (typeof val !== "function") throw new Unsupported(`${file}:${k.line}: call of a non-function`);
          val = val(...args);
        } else if (isOp("[")) { next(); const key = expr(0); expectOp("]"); val = val == null ? undefined : val[key]; }
        else break;
      }
      return val;
    }
    if (k.t === "op" && k.v === "(") { const v = expr(0); expectOp(")"); return v; }
    if (k.t === "op" && k.v === "{") return table();
    if (k.t === "op" && k.v === "-") { const v = expr(8); return typeof v === "number" ? -v : arith("*", v, -1); }
    if (k.t === "name" && k.v === "not") return !expr(8);
    throw new Unsupported(`${file}:${k.line}: unexpected token ${k.v}`);
  }
  function expr(minPrec) {
    let left;
    if (isKw("not")) { next(); left = !truthy(expr(8)); } else left = primary();
    for (;;) {
      const k = peek();
      const op = k.v;
      const prec = (k.t === "op" || (k.t === "name" && (op === "and" || op === "or"))) ? PREC[op] : undefined;
      if (prec === undefined || prec <= minPrec) break;
      next();
      const right = expr(op === "^" || op === ".." ? prec - 1 : prec);
      if (op === "..") left = String(left) + String(right);
      else if (op === "and") left = truthy(left) ? right : left;
      else if (op === "or") left = truthy(left) ? left : right;
      else if (["<", ">", "<=", ">=", "==", "~="].includes(op)) left = { "<": left < right, ">": left > right, "<=": left <= right, ">=": left >= right, "==": left === right, "~=": left !== right }[op];
      else left = arith(op, left, right);
    }
    return left;
  }
  const truthy = (v) => v !== undefined && v !== false;
  function table() { // returns a JS object; positional entries at keys 1..n, `__n` = positional count
    const t = { __tbl: true, __n: 0 };
    while (!isOp("}")) {
      if (isOp("[")) { next(); const key = expr(0); expectOp("]"); expectOp("="); t[key] = expr(0); }
      else if (peek().t === "name" && toks[p + 1].t === "op" && toks[p + 1].v === "=") { const key = next().v; next(); t[key] = expr(0); }
      else { t.__n += 1; const v = expr(0); if (v !== undefined) t[t.__n] = v; }
      if (isOp(",") || isOp(";")) next(); else break;
    }
    expectOp("}");
    return t;
  }
  // statements
  for (;;) {
    if (peek().t === "eof") throw new Unsupported(`${file}: no return statement`);
    if (isOp(";")) { next(); continue; }
    if (isKw("return")) { next(); const v = expr(0); if (isOp(";")) next(); if (peek().t !== "eof") throw new Unsupported(`${file}:${peek().line}: code after return`); return v; }
    const isLocal = isKw("local");
    if (isLocal) next();
    if (peek().t !== "name") throw new Unsupported(`${file}:${peek().line}: unsupported statement`);
    const names = [next().v];
    while (isOp(",")) { next(); names.push(next().v); }
    if (isOp(":")) throw new Unsupported(`${file}:${peek().line}: type annotations`);
    expectOp("=");
    const vals = [expr(0)];
    while (isOp(",")) { next(); vals.push(expr(0)); }
    names.forEach((nm, idx) => env.set(nm, vals[idx]));
  }
}

// ------------------------------------------------------------------------------------------------
// Preflight: the builder's spec rules and budgets, offline.
const MATERIALS = new Set("Plastic SmoothPlastic Neon Wood WoodPlanks Marble Basalt Slate CrackedLava Concrete Limestone Granite Pavement Brick Pebble Cobblestone Rock Sandstone CorrodedMetal DiamondPlate Foil Metal Grass LeafyGrass Sand Fabric Snow Mud Ground Asphalt Salt Ice Glacier Glass Cardboard Carpet CeramicTiles ClayRoofTiles RoofShingles Leather Plaster Rubber".split(" "));
const RESERVED = new Set(["EnergyCore", "HubEmitter", "CrownEmitter", "Catwalk_N", "Catwalk_S", "RackDeck_NW", "RackDeck_NE", "ArchiveWalk_S", "SkyDeck", "SkyLanding_N", "SkyLanding_S", "Island_N", "Island_S", "Bridge_W", "Bridge_E", "BridgeLink_W", "BridgeLink_E", "Ring_N", "Ring_S", "Ring_W", "Ring_E", "CorePlaza", "Mezz_N", "Mezz_S", "Mezz_E", "Mezz_W", "Gantry_N_Bridge", "Gantry_E_Bridge"]);
const RESERVED_RX = [/^Step_\d/, /^Rack_/, /^Column_/, /^ButtressPlinth_/, /^EnvSlice1/, /^EnvSprint2/, /^SupplyCrate_/, /^Spawn_/];
const CAP = { SprintTraversal: [95, 42, 0], SprintExterior: [105, 0, 2] };
const PREFIX = { Traversal: "SprintTraversal", Exterior: "SprintExterior" };

function preflight(spec, expectCat, label, problems, modelNames) {
  const out = { parts: 0, collide: 0, lights: 0, rows: [] };
  const P = (m) => problems.push(`${label}: ${m}`);
  const isV = (v) => v && v.__v3 && [v.X, v.Y, v.Z].every(Number.isFinite);
  if (!spec || !spec.__tbl || spec.__n === 0) { P("must return a non-empty list of model groups"); return out; }
  for (let gi = 1; gi <= spec.__n; gi++) {
    const g = spec[gi];
    if (!g || !g.__tbl) { P(`group ${gi}: not a table`); continue; }
    for (const k of Object.keys(g)) if (!["__tbl", "__n", "model", "category", "parts", "anchors"].includes(k)) P(`group ${gi}: unknown key ${k}`);
    const m = /^([A-Za-z]+)_[A-Za-z0-9_]+$/.exec(g.model || "");
    if (!m || PREFIX[m[1]] !== g.category || g.category !== expectCat || g.model.length > 60) P(`${g.model}: model must be ${expectCat === "SprintTraversal" ? "Traversal_" : "Exterior_"}<Name> with category ${expectCat} (got ${g.category})`);
    if (modelNames.has(g.model)) P(`${g.model}: duplicate model name`);
    modelNames.add(g.model);
    const parts = g.parts;
    if (!parts || !parts.__tbl || parts.__n === 0) { P(`${g.model}: parts must be a non-empty list`); continue; }
    const names = new Set();
    for (let ri = 1; ri <= parts.__n; ri++) {
      const r = parts[ri];
      if (!r || !r.__tbl) { P(`${g.model} row ${ri}: not a table`); continue; }
      for (const k of Object.keys(r)) if (!["__tbl", "__n"].includes(k) && !(/^[1-8]$/.test(k))) P(`${g.model} row ${ri}: unexpected key ${k}`);
      const [name, size, pos, col, mat, role, orient, extraRaw] = [1, 2, 3, 4, 5, 6, 7, 8].map((i) => r[i]);
      if (typeof name !== "string" || !/^[A-Za-z][A-Za-z0-9_]*$/.test(name) || name.length > 60) { P(`${g.model} row ${ri}: bad part name`); continue; }
      const w = `${g.model}.${name}`;
      if (names.has(name)) P(`${w}: duplicate part name in model`);
      names.add(name);
      if (RESERVED.has(name) || RESERVED_RX.some((rx) => rx.test(name))) P(`${w}: reserved name`);
      if (!isV(size) || [size.X, size.Y, size.Z].some((x) => x < 0.05 || x > 2048)) { P(`${w}: size must be Vector3 with components 0.05..2048`); continue; }
      if (!isV(pos)) { P(`${w}: bad position`); continue; }
      if (orient !== undefined && !isV(orient)) { P(`${w}: bad orientation`); continue; }
      if (!col || !col.__tbl || col.__n !== 3 || [1, 2, 3].some((i) => !Number.isInteger(col[i]) || col[i] < 0 || col[i] > 255)) P(`${w}: colour must be {r,g,b} integers 0..255`);
      if (!MATERIALS.has(mat)) P(`${w}: invalid material ${mat}`);
      if (role !== undefined && !["WalkSurface", "EdgeRail", "JumpStep"].includes(role)) P(`${w}: bad role ${role}`);
      const extra = extraRaw && extraRaw.__tbl ? extraRaw : {};
      if (extraRaw !== undefined && !extraRaw.__tbl) P(`${w}: extra must be a table`);
      for (const k of Object.keys(extra)) if (!["__tbl", "__n", "light", "shape", "class", "transparency", "reservedUse"].includes(k)) P(`${w}: unknown extra key ${k}`);
      const cls = extra.class || "Part";
      if (!["Part", "WedgePart", "CornerWedgePart"].includes(cls)) P(`${w}: bad class ${cls}`);
      const shape = cls === "Part" ? extra.shape || "Block" : null;
      if (cls === "Part" && !["Block", "Wedge", "Cylinder", "Ball"].includes(shape)) P(`${w}: bad shape ${shape}`);
      if (cls !== "Part" && extra.shape !== undefined) P(`${w}: shape only valid for class Part`);
      if (shape === "Ball" && !(size.X === size.Y && size.X === size.Z)) P(`${w}: Ball must be uniform`);
      const tr = extra.transparency === undefined ? 0 : extra.transparency;
      if (typeof tr !== "number" || tr < 0 || tr >= 1) P(`${w}: transparency must be in [0,1)`);
      if (extra.reservedUse !== undefined && (typeof extra.reservedUse !== "string" || !extra.reservedUse)) P(`${w}: reservedUse must be a non-empty string`);
      const dims = [size.X, size.Y, size.Z].sort((a, b) => a - b);
      if (mat === "Neon" && dims[1] > 4) P(`${w}: Neon with two dimensions > 4 (C11)`);
      if (role) {
        if (expectCat !== "SprintTraversal") P(`${w}: roles only in SprintTraversal`);
        if (cls !== "Part" || shape !== "Block") P(`${w}: ${role} must be a Block Part`);
        if (orient && orient.Magnitude > 1e-9) P(`${w}: ${role} must be unrotated`);
        if (tr !== 0) P(`${w}: ${role} must be opaque`);
        if ((role === "WalkSurface" || role === "JumpStep") && (size.X < 4 || size.Z < 4)) P(`${w}: ${role} must be >= 4 x 4`);
        if (role === "EdgeRail" && size.Y < 4) P(`${w}: EdgeRail must be >= 4 high`);
        const lo = [pos.X - size.X / 2, pos.Y - size.Y / 2, pos.Z - size.Z / 2], hi = [pos.X + size.X / 2, pos.Y + size.Y / 2, pos.Z + size.Z / 2];
        const head = role === "EdgeRail" ? 0 : 6;
        if (lo[0] < -275 || lo[1] < -40 || lo[2] < -275 || hi[0] > 275 || hi[1] + head > 160 || hi[2] > 275) P(`${w}: collidable outside Config.ArenaBounds`);
      }
      let light = null;
      if (extra.light !== undefined) {
        const L = extra.light;
        if (expectCat !== "SprintExterior") P(`${w}: lights only in SprintExterior`);
        if (!L || !L.__tbl) P(`${w}: light must be a table`);
        else {
          for (const k of Object.keys(L)) if (!["__tbl", "__n", "class", "range", "brightness", "color", "angle", "face"].includes(k)) P(`${w}: unknown light key ${k}`);
          if (!["PointLight", "SpotLight"].includes(L.class)) P(`${w}: light class must be PointLight or SpotLight`);
          if (!(L.range > 0 && L.range <= 60)) P(`${w}: light range must be in (0,60]`);
          if (!(L.brightness > 0 && L.brightness <= 10)) P(`${w}: light brightness must be in (0,10]`);
          if (!L.color || !L.color.__tbl || L.color.__n !== 3) P(`${w}: light colour must be {r,g,b}`);
          if (L.class !== "SpotLight" && (L.angle !== undefined || L.face !== undefined)) P(`${w}: angle/face only for SpotLight`);
          if (L.class === "SpotLight" && L.face !== undefined && !["Front", "Back", "Top", "Bottom", "Left", "Right"].includes(L.face)) P(`${w}: bad spot face`);
          if (L.class === "SpotLight" && L.angle !== undefined && !(L.angle >= 0 && L.angle <= 180)) P(`${w}: bad spot angle`);
          light = L.class;
        }
      }
      out.parts++;
      if (role) out.collide++;
      if (light) out.lights++;
      out.rows.push({ model: g.model, name, size, pos, orient, mat, role, shape, cls, transparency: tr, light });
    }
  }
  const cap = CAP[expectCat];
  if (out.parts > cap[0] || out.collide > cap[1] || out.lights > cap[2]) P(`budget ${expectCat} ${out.parts}/${out.collide}/${out.lights} exceeds ${cap.join("/")}`);
  return out;
}

function mapCountsFromExport(tsv) {
  const lines = fs.readFileSync(tsv, "utf8").split(/\r?\n/).filter(Boolean);
  const head = lines[0].split("\t");
  const iPath = head.indexOf("path"), iCol = head.indexOf("collide"), iLights = head.indexOf("lights");
  let parts = 0, collide = 0, lights = 0;
  for (const l of lines.slice(1)) {
    const c = l.split("\t");
    if (!c[iPath].startsWith("WORLD_EXE.Map.")) continue;
    if (c[iPath].startsWith("WORLD_EXE.Map.EnvSprint2.")) continue;
    parts++;
    if (c[iCol] === "1") collide++;
    if (iLights >= 0 && c[iLights]) lights += c[iLights].split(/[;,|]/).filter((s) => s.trim()).length;
  }
  return { parts, collide, lights };
}

// ------------------------------------------------------------------------------------------------
function main() {
  const args = process.argv.slice(2);
  const opt = (name, def) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : def; };
  if (args[0] === "--check") {
    let bad = 0;
    for (const f of args.slice(1)) {
      try { const n = checkStructure(readText(f, "file"), f); console.log(`ok   ${f} (${n} tokens)`); }
      catch (e) { bad++; console.log(`FAIL ${e.message}`); }
    }
    process.exit(bad ? 1 : 0);
  }
  const templatePath = opt("--template", path.join(HERE, "build_template.luau"));
  const tPath = opt("--traversal", path.join(HERE, "traversal_spec.luau"));
  const ePath = opt("--exterior", path.join(HERE, "exterior_spec.luau"));
  const outPath = opt("--out", path.join(HERE, "1_build.luau"));
  const geoPath = opt("--geometry", "C:\\WORLD.EXE-Art\\EnvSprint2\\geometry\\parts.tsv");

  const template = readText(templatePath, "template");
  const tSpec = readText(tPath, "traversal spec (Agent A: traversal_spec.luau)");
  const eSpec = readText(ePath, "exterior spec (Agent B: exterior_spec.luau)");
  for (const [s, p] of [[tSpec, tPath], [eSpec, ePath]]) {
    if (!s.trim()) die(`spec is empty: ${p}`);
    if (!/(^|\n)\s*return\b/.test(s)) die(`spec has no top-level 'return': ${p}`);
    if (s.includes("--@@")) die(`spec contains an assembler marker: ${p}`);
  }
  for (const mark of [MARK_T, MARK_E]) {
    const count = template.split("\n").filter((l) => l.trim() === mark).length;
    if (count !== 1) die(`template must contain the line ${mark} exactly once (found ${count})`);
  }

  // Preflight.
  if (!args.includes("--no-preflight")) {
    const problems = [], modelNames = new Set();
    let tot = null;
    try {
      const t = preflight(evalSpec(tSpec, path.basename(tPath)), "SprintTraversal", "traversal_spec", problems, modelNames);
      const e = preflight(evalSpec(eSpec, path.basename(ePath)), "SprintExterior", "exterior_spec", problems, modelNames);
      tot = { parts: t.parts + e.parts, collide: t.collide + e.collide, lights: t.lights + e.lights };
      if (tot.parts > 200 || tot.collide > 42 || tot.lights > 2) problems.push(`sprint total ${tot.parts}/${tot.collide}/${tot.lights} exceeds 200/42/2`);
      let mapLine = "map-after not checked (no geometry export)";
      if (fs.existsSync(geoPath)) {
        const m = mapCountsFromExport(geoPath);
        const after = [m.parts + tot.parts, m.collide + tot.collide, m.lights + tot.lights];
        mapLine = `map ${m.parts}/${m.collide}/${m.lights} -> ${after.join("/")} (cap 2102/421/53)`;
        if (after[0] > 2102 || after[1] > 421 || after[2] > 53) problems.push(`map after ${after.join("/")} exceeds 2102/421/53`);
      }
      console.log(`preflight: SprintTraversal ${t.parts}/${t.collide}/${t.lights} (cap 95/42/0), SprintExterior ${e.parts}/${e.collide}/${e.lights} (cap 105/0/2), total ${tot.parts}/${tot.collide}/${tot.lights}; ${mapLine}`);
    } catch (err) {
      if (err instanceof Unsupported) console.log(`preflight skipped (spec uses syntax the offline evaluator does not support: ${err.message}); the Studio builder still validates everything`);
      else throw err;
    }
    if (problems.length) die(`preflight refused (${problems.length} problem(s)):\n  - ` + problems.join("\n  - "));
  }

  const wrap = (s) => s.replace(/\n+$/, ""); // chunk text, inserted verbatim between the template's wrapper lines
  const header = [
    "-- GENERATED by tools/studio/envsprint2/assemble.js. Do not edit; edit the template or the specs and re-run.",
    `-- build_template.luau sha256 ${sha(template)}`,
    `-- traversal_spec.luau sha256 ${sha(tSpec)}`,
    `-- exterior_spec.luau  sha256 ${sha(eSpec)}`,
  ].join("\n");
  const out = header + "\n" + template
    .split("\n")
    .map((l) => (l.trim() === MARK_T ? wrap(tSpec) : l.trim() === MARK_E ? wrap(eSpec) : l))
    .join("\n");
  try { checkStructure(out, path.basename(outPath)); } catch (e) { die("structural check of the assembled builder failed: " + e.message); }
  fs.writeFileSync(outPath, out, "utf8");
  console.log(`wrote ${outPath} (${out.length} bytes, sha256 ${sha(out)})`);
}

if (require.main === module) main();
module.exports = { lex, checkStructure, evalSpec, preflight };
