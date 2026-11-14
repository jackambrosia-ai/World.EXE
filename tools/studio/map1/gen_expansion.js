// WORLD.EXE Map 1 "Stable Simulation" expansion generator (deterministic, offline).
//   node gen_expansion.js [notesDir]
// Writes:
//   ./1_build_expansion.luau        (build_expansion_template.luau + inlined spec)
//   <notesDir>/LAYOUT.json          (sectors, routes, bounds for Agent C)
//   <notesDir>/layout_plan.svg      (top-down plan generated from LAYOUT.json + spec footprints)
// Coordinates are Roblox studs, Y up. The reactor is at (0,0,0). Ground tier top = Y 0.
'use strict';
const fs = require('fs');
const path = require('path');
const HERE = __dirname;
const NOTES = process.argv[2] || 'C:/WORLD.EXE-Art/TwoMaps/Map1/notes';
const VERSION = 'map1-expansion v10 2026-11-14';

// ---------------------------------------------------------------- palette
const C = {
  floor: [58, 70, 112], floorBoss: [64, 78, 124], floorRoute: [52, 62, 100],
  plate: [44, 54, 92], plateDark: [32, 38, 62], charcoal: [30, 34, 46], trim: [120, 136, 176],
  rail: [96, 112, 158], cyan: [0, 225, 255], cyanSoft: [110, 220, 255], violet: [95, 85, 255], floorLight: [98, 114, 162], floorLightV: [150, 166, 206], wallLight: [92, 108, 152], columnLight: [78, 92, 136],
  glass: [120, 200, 255], white: [210, 225, 255], cover: [70, 84, 128], amber: [255, 190, 90],
};
const rows = [];
const containers = {}; // grp -> {sector, cls, streaming}
const layoutExtra = { landmarks: [] };

function grp(name, sector, cls = 'Folder', streaming = null, inName = null) {
  containers[name] = { sector, cls, streaming, name: inName };
  return name;
}
const R3 = (v) => Math.round(v * 1000) / 1000;
const IDENT = [1, 0, 0, 0, 1, 0, 0, 0, 1];
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const mul = (a, s) => [a[0] * s, a[1] * s, a[2] * s];
const len = (a) => Math.hypot(a[0], a[1], a[2]);
const unit = (a) => mul(a, 1 / len(a));
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
// Roblox CFrame.lookAt(at, target, up=Y). Returns {pos, rot(row-major 9), right, up, look}
function lookAt(at, target) {
  const look = unit(sub(target, at));
  let right = cross(look, [0, 1, 0]);
  if (len(right) < 1e-6) right = [1, 0, 0];
  right = unit(right);
  const up = cross(right, look);
  const back = mul(look, -1);
  return { right, up, look, rot: [right[0], up[0], back[0], right[1], up[1], back[1], right[2], up[2], back[2]] };
}
const ROT_CYL_UP = [0, -1, 0, 1, 0, 0, 0, 0, 1]; // Rz(90): part X axis -> world up

const COLL_ROLES = new Set(['Floor', 'Ramp', 'Rail', 'Cover', 'Wall']);
function push(r) {
  const coll = r.coll !== undefined ? r.coll : COLL_ROLES.has(r.role);
  for (const v of r.size) if (!(v > 0.04) || v > 2048) throw new Error('bad size ' + r.name + ' ' + r.size);
  rows.push({
    name: r.name, grp: r.grp, role: r.role, size: r.size.map(R3), pos: r.pos.map(R3), rot: (r.rot || IDENT).map((v) => Math.round(v * 1e6) / 1e6),
    mat: r.mat || 'SmoothPlastic', color: r.color || C.plate, tr: r.tr || 0, coll, shape: r.shape || 'B',
    boss: r.boss || null, light: r.light || null, sign: r.sign || null, shadow: r.shadow !== undefined ? r.shadow : (coll && r.role !== 'Rail'), attrs: r.attrs || null,
  });
}
// axis-aligned box from min/max
function box(g, name, role, mn, mx, mat, color, o = {}) {
  const size = [mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]];
  const pos = [(mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2];
  push(Object.assign({ name, grp: g, role, size, pos, mat, color }, o));
}
// vertical cylinder: centre x,z, y0..y1, diameter d
function cylY(g, name, role, x, z, y0, y1, d, mat, color, o = {}) {
  push(Object.assign({ name, grp: g, role, size: [y1 - y0, d, d], pos: [x, (y0 + y1) / 2, z], rot: ROT_CYL_UP, mat, color, shape: 'C' }, o));
}
// beam between two points (square section t)
function beam(g, name, role, p0, p1, t, mat, color, o = {}) {
  const L = len(sub(p1, p0));
  const mid = mul(add(p0, p1), 0.5);
  const f = lookAt(mid, p1);
  push(Object.assign({ name, grp: g, role, size: [t, t, L], pos: mid, rot: f.rot, mat, color }, o));
}
// ramp: p0 low end top-surface centre, p1 high end top-surface centre, width w. Adds side rails if asked.
function ramp(g, name, p0, p1, w, mat, color, o = {}) {
  const t = 2;
  const ext = 1.0; // overlap into the landings at both ends
  const d = unit(sub(p1, p0));
  const a = sub(p0, mul(d, ext)), b = add(p1, mul(d, ext));
  const L = len(sub(b, a));
  const mid = mul(add(a, b), 0.5);
  const f = lookAt(mid, b);
  const pos = sub(mid, mul(f.up, t / 2));
  push(Object.assign({ name, grp: g, role: 'Ramp', size: [w, t, L], pos, rot: f.rot, mat, color,
    attrs: { RampLow: p0.map(R3).join(','), RampHigh: p1.map(R3).join(',') } }, o.ramp || {}));
  // v10: o.railFoot = studs along the slope from the low end where the side rails start (open ramp foot;
  // only used where the floor beside the foot is within about 6 studs of the ramp surface)
  const foot = o.railFoot || 0;
  const rl = len(sub(p1, p0)) - foot;
  const rmid = mul(add(add(p0, mul(d, foot)), p1), 0.5);
  for (const side of o.rails || []) { // side: -1 left (-right), +1 right
    const rp = add(add(rmid, mul(f.right, side * (w / 2 - 0.5))), mul(f.up, 2));
    push({ name: name + (side < 0 ? '_RailL' : '_RailR'), grp: g, role: 'Rail', size: [1, 4, rl], pos: rp, rot: f.rot, mat: 'Metal', color: C.rail });
  }
}
// ring segment at angle th (rad) of ring r1..r2 around (cx,cz), y0..y1, N segments
function ringSeg(g, name, role, cx, cz, r1, r2, th, N, y0, y1, mat, color, o = {}) {
  const rc = (r1 + r2) / 2;
  const w = 2 * r2 * Math.tan(Math.PI / N) + 0.3;
  const pos = [cx + rc * Math.cos(th), (y0 + y1) / 2, cz + rc * Math.sin(th)];
  const f = lookAt(pos, [cx, pos[1], cz]);
  push(Object.assign({ name, grp: g, role, size: [w, y1 - y0, r2 - r1], pos, rot: f.rot, mat, color }, o));
}
// tangential thin strip along a ring at radius r, height y, from angle th, chord length
function ringStrip(g, name, role, cx, cz, r, th, N, y0, y1, depth, mat, color, o = {}) {
  const w = 2 * r * Math.tan(Math.PI / N) + 0.1;
  const pos = [cx + r * Math.cos(th), (y0 + y1) / 2, cz + r * Math.sin(th)];
  const f = lookAt(pos, [cx, pos[1], cz]);
  push(Object.assign({ name, grp: g, role, size: [w, y1 - y0, depth], pos, rot: f.rot, mat, color }, o));
}
// in-world sign: a thin decor panel with a SurfaceGui text label on face `face` (Front/Back/Left/Right).
function sign(g, name, mn, mx, face, text, o = {}) {
  const sg = { face, text, color: o.color || C.cyan, ppS: o.ppS || 20 };
  if (o.hi) { sg.bg = [225, 248, 255]; sg.color = [6, 12, 34]; sg.font = 'GothamBlack'; sg.bright = 1.0; } // v10 high-contrast
  box(g, name, 'Decor', mn, mx, 'SmoothPlastic', o.panel || C.plateDark, { shadow: false, sign: sg });
}
// v10 floor chevron (two flat neon arms, non-collidable) at floor top y, pointing along XZ direction (dx,dz)
function chevron(g, name, x, y, z, dx, dz, o = {}) {
  const L = o.len || 6, a = (o.deg || 38) * Math.PI / 180, w = o.w || 0.9;
  const n = Math.hypot(dx, dz); dx /= n; dz /= n;
  const tip = [x + dx * L * 0.4, y + 0.06, z + dz * L * 0.4];
  for (const [k, sgn] of [['A', 1], ['B', -1]]) {
    const bx = -dx * Math.cos(a) - sgn * dz * Math.sin(a), bz = -dz * Math.cos(a) + sgn * dx * Math.sin(a);
    const end = [tip[0] + bx * L, tip[1], tip[2] + bz * L];
    const mid = mul(add(tip, end), 0.5);
    const f = lookAt(mid, end);
    push({ name: name + k, grp: g, role: 'Decor', size: [w, 0.12, L], pos: mid, rot: f.rot, mat: 'Neon', color: o.color || C.cyan, shadow: false });
  }
}
// vertical ring (aperture) in the plane X = x0, centre (yc, zc), radius r (to the segment centre), N segments
function apertureX(g, name, x0, yc, zc, r, N, depth, thick, mat, color, o = {}) {
  for (let k = 0; k < N; k++) {
    const ph = (k + 0.5) * 2 * Math.PI / N, c = Math.cos(ph), sn = Math.sin(ph);
    const tl = 2 * (r + thick / 2) * Math.tan(Math.PI / N) + 0.2;
    push(Object.assign({ name: `${name}${k + 1}`, grp: g, role: 'Decor', size: [depth, thick, tl], pos: [x0, yc + r * c, zc + r * sn],
      rot: [1, 0, 0, 0, c, -sn, 0, sn, c], mat, color }, o));
  }
}
// wall in an axis plane with rectangular openings. axis 'x' => wall spans X (u) and Y (v), thickness along Z.
function wallWithOpenings(g, name, axis, u0, u1, v0, v1, t0, t1, openings, mat, color, o = {}) {
  const us = new Set([u0, u1]), vs = new Set([v0, v1]);
  for (const op of openings) { us.add(Math.max(u0, Math.min(u1, op[0]))); us.add(Math.max(u0, Math.min(u1, op[1]))); vs.add(Math.max(v0, Math.min(v1, op[2]))); vs.add(Math.max(v0, Math.min(v1, op[3]))); }
  const U = [...us].sort((a, b) => a - b), V = [...vs].sort((a, b) => a - b);
  const filled = (ua, ub, va, vb) => !openings.some((op) => ua >= op[0] - 1e-6 && ub <= op[1] + 1e-6 && va >= op[2] - 1e-6 && vb <= op[3] + 1e-6);
  // merge cells row by row (along u), then emit
  let k = 0;
  const spans = [];
  for (let j = 0; j < V.length - 1; j++) {
    let start = null;
    for (let i = 0; i < U.length - 1; i++) {
      const f = filled(U[i], U[i + 1], V[j], V[j + 1]);
      if (f && start === null) start = U[i];
      if ((!f || i === U.length - 2) && start !== null) {
        const end = f ? U[i + 1] : U[i];
        spans.push([start, end, V[j], V[j + 1]]);
        start = null;
      }
    }
  }
  // vertical merge of identical u-spans
  const merged = [];
  for (const s of spans) {
    const m = merged.find((q) => q[0] === s[0] && q[1] === s[1] && Math.abs(q[3] - s[2]) < 1e-6);
    if (m) m[3] = s[3]; else merged.push(s.slice());
  }
  for (const s of merged) {
    k++;
    if (axis === 'x') box(g, `${name}_${k}`, o.role || 'Wall', [s[0], s[2], t0], [s[1], s[3], t1], mat, color, o);
    else box(g, `${name}_${k}`, o.role || 'Wall', [t0, s[2], s[0]], [t1, s[3], s[1]], mat, color, o);
  }
}

// ---------------------------------------------------------------- shared route builder
// Straight corridor/bridge along 'x' or 'z'. c = centre of the other horizontal axis, w width,
// a..b along axis (a<b), y = floor top. railGaps: [[s0,s1,side]] side 'L' (low coord side) / 'R' / 'B'.
function corridor(g, name, axis, c, w, a, b, y, o = {}) {
  const thick = o.thick || 2;
  const lo = c - w / 2, hi = c + w / 2;
  const mk = (s0, s1, cc0, cc1, y0, y1) => axis === 'x' ? [[s0, y0, cc0], [s1, y1, cc1]] : [[cc0, y0, s0], [cc1, y1, s1]];
  // floor (split if > 2000)
  const segs = Math.ceil((b - a) / 2000);
  for (let i = 0; i < segs; i++) {
    const s0 = a + (b - a) * i / segs, s1 = a + (b - a) * (i + 1) / segs;
    const [mn, mx] = mk(s0, s1, lo, hi, y - thick, y);
    box(g, `${name}_Floor${segs > 1 ? i + 1 : ''}`, 'Floor', mn, mx, o.mat || 'DiamondPlate', o.color || C.floorRoute);
  }
  // edge neon strips (decor, inset 1.2)
  for (const [sd, cc] of [['L', lo + 1.2], ['R', hi - 1.2]]) {
    const [mn, mx] = mk(a + 1, b - 1, cc - 0.2, cc + 0.2, y, y + 0.15);
    box(g, `${name}_Strip${sd}`, 'Decor', mn, mx, 'Neon', C.cyan);
  }
  // rails
  const ra = o.railFrom !== undefined ? o.railFrom : a, rb = o.railTo !== undefined ? o.railTo : b;
  for (const sd of ['L', 'R']) {
    if (o.noRails && o.noRails.includes(sd)) continue;
    const gaps = (o.railGaps || []).filter((q) => q[2] === sd || q[2] === 'B').map((q) => [q[0], q[1]]).sort((p, q) => p[0] - q[0]);
    let cur = ra, k = 0;
    const cc0 = sd === 'L' ? lo : hi - 1, cc1 = sd === 'L' ? lo + 1 : hi;
    for (const gp of [...gaps, [rb, rb]]) {
      const e = Math.min(gp[0], rb);
      if (e - cur > 0.5) {
        k++;
        const [mn, mx] = mk(cur, e, cc0, cc1, y, y + 4);
        box(g, `${name}_Rail${sd}${k}`, 'Rail', mn, mx, 'Metal', C.rail);
        if (o.railGlow) {
          const [gm, gx] = mk(cur, e, cc0 + 0.3, cc1 - 0.3, y + 4, y + 4.15);
          box(g, `${name}_RailGlow${sd}${k}`, 'Decor', gm, gx, 'Neon', o.railGlow);
        }
      }
      cur = Math.max(cur, gp[1]);
    }
  }
  // arches (decor) every o.arch studs within [archFrom, archTo]
  if (o.arch) {
    const h = o.archH || 16;
    const f0 = o.archFrom !== undefined ? o.archFrom : a, f1 = o.archTo !== undefined ? o.archTo : b;
    let k = 0;
    for (let s = f0 + o.arch / 2; s < f1; s += o.arch) {
      k++;
      for (const [sd, cc] of [['L', lo - 1.5], ['R', hi + 1.5]]) {
        const [mn, mx] = mk(s - 1, s + 1, cc - 1, cc + 1, y - 2, y + h);
        box(g, `${name}_ArchPost${sd}${k}`, 'Decor', mn, mx, 'Metal', C.plateDark, { shadow: true });
      }
      const [mn, mx] = mk(s - 1.2, s + 1.2, lo - 2.5, hi + 2.5, y + h, y + h + 2.5);
      box(g, `${name}_ArchBeam${k}`, 'Decor', mn, mx, 'Metal', C.plateDark, { shadow: true });
      const [mn2, mx2] = mk(s - 0.3, s + 0.3, lo, hi, y + h - 0.3, y + h);
      box(g, `${name}_ArchGlow${k}`, 'Decor', mn2, mx2, 'Neon', C.cyanSoft);
    }
  }
  // support piers (decor) down to the abyss floor
  if (o.piers) {
    let k = 0;
    for (const s of o.piers) {
      k++;
      const [mn, mx] = mk(s - 2.5, s + 2.5, c - 3, c + 3, -92, y - thick);
      box(g, `${name}_Pier${k}`, 'Decor', mn, mx, 'Concrete', C.charcoal, { shadow: true });
    }
  }
}
// hub-side portal frame on the plinth face around a cut opening (decor). axis 'x': opening spans X (u),
// plane at Z = t; axis 'z': opening spans Z, plane at X = t. u0..u1 opening, y0..y1 opening.
function portal(g, name, axis, t, u0, u1, y0, y1, ht = 1, jamb = null) {
  const t0 = t - ht, t1 = t + ht;
  const bx = (nm, a0, a1, b0, b1, mat, col) => axis === 'x' ? box(g, nm, 'Decor', [a0, b0, t0], [a1, b1, t1], mat, col, { shadow: true }) : box(g, nm, 'Decor', [t0, b0, a0], [t1, b1, a1], mat, col, { shadow: true });
  bx(name + '_JambA', u0 - 3, u0, y0 - 2, y1 + 3, 'Metal', C.trim);
  bx(name + '_JambB', u1, u1 + 3, y0 - 2, y1 + 3, 'Metal', C.trim);
  bx(name + '_Lintel', u0 - 3, u1 + 3, y1, y1 + 3, 'Metal', C.trim);
  const g0 = axis === 'x' ? [u0, y1 - 0.5, t - ht - 0.3] : [t - ht - 0.3, y1 - 0.5, u0];
  const g1 = axis === 'x' ? [u1, y1, t + ht + 0.3] : [t + ht + 0.3, y1, u1];
  box(g, name + '_Glow', 'Decor', g0, g1, 'Neon', C.cyan);
  if (jamb) { // v8: lit jambs so the opening reads from inside the hub (violet = ground route, cyan = elevated)
    bx(name + '_JambGlowA', u0, u0 + 0.3, y0, y1, 'Neon', jamb);
    bx(name + '_JambGlowB', u1 - 0.3, u1, y0, y1, 'Neon', jamb);
  }
}
const routes = [];

// ---------------------------------------------------------------- hall openings (cuts) and isolations
// Each cut box is applied by the builder to every intersecting existing part (split into pieces).
const CUTS = [];
function cut(name, mn, mx) { CUTS.push({ name, min: mn, max: mx }); }
const ISOLATE = [
  // decorative far tower standing inside the TestingPit footprint (moved, not deleted)
  'Workspace.WORLD_EXE.Map.Megastructure.Detail.FarTower_8',
  'Workspace.WORLD_EXE.Map.Megastructure.Detail.FarTowerTop_8',
];

// =================================================================== NORTH: ContainmentVault
{
  const S = 'ContainmentVault';
  const g = grp('ContainmentVault', S), gl = grp('ContainmentVault_Landmark', S, 'Model', 'Persistent');
  const rN = grp('Route_N', 'Route_N');
  // --- Route N ground: Archive floor north edge (Z -260) -> forecourt (Z -420), X 55..75
  corridor(rN, 'RN_Ground', 'z', 65, 20, -420, -260, 0, {
    railFrom: -420, railTo: -262, railGaps: [[-396, -340, 'B']],
    piers: [-290, -410], railGlow: C.violet, arch: 48, archFrom: -314, archTo: -262, archH: 18,
  });
  // gatehouse plaza under the terrace
  box(rN, 'RN_Gate_Floor', 'Floor', [43, -2, -396], [87, 0, -340], 'DiamondPlate', C.floorRoute);
  for (const [nm, mn, mx] of [
    ['RN_Gate_RailW1', [43, 0, -396], [44, 4, -392]], ['RN_Gate_RailW2', [43, 0, -380], [44, 4, -340]], ['RN_Gate_RailE', [86, 0, -396], [87, 4, -340]],
    ['RN_Gate_RailS1', [44, 0, -341], [55, 4, -340]], ['RN_Gate_RailS2', [75, 0, -341], [86, 4, -340]],
    ['RN_Gate_RailN1', [44, 0, -396], [55, 4, -395]], ['RN_Gate_RailN2', [75, 0, -396], [86, 4, -395]],
  ]) box(rN, nm, 'Rail', mn, mx, 'Metal', C.rail);
  box(rN, 'RN_Gate_Cover1', 'Cover', [47, 0, -371], [53, 5, -365], 'Metal', C.cover);
  box(rN, 'RN_Gate_Cover2', 'Cover', [77, 0, -371], [83, 5, -365], 'Metal', C.cover);
  box(rN, 'RN_Gate_Lamp', 'Decor', [60, 50, -370], [70, 51, -366], 'Neon', C.cyanSoft, { light: { range: 40, brightness: 1.2, color: [170, 230, 255] } });
  box(rN, 'RN_Gate_JambW', 'Decor', [41, -2, -399], [44, 30, -396], 'Metal', C.plateDark, { shadow: true });
  box(rN, 'RN_Gate_JambE', 'Decor', [86, -2, -399], [89, 30, -396], 'Metal', C.plateDark, { shadow: true });
  box(rN, 'RN_Gate_Lintel', 'Decor', [41, 26, -399], [89, 30, -396], 'Metal', C.plateDark, { shadow: true });
  box(rN, 'RN_Gate_LintelGlow', 'Decor', [44, 25.6, -398], [86, 26, -397], 'Neon', C.cyan);
  cut('RN_Ground_Plinth', [53, -6, -337], [77, 30, -316]);
  portal(rN, 'RN_Ground_Portal', 'x', -318, 53, 77, 0, 30, 1, C.violet);
  // v8: full-height slot (VaultWall_N becomes 3 pieces instead of 6; reads clearly from the hub)
  cut('RN_Ground_VaultWallDoor', [55, -4, -261.6], [75, 70, -260]);
  portal(rN, 'RN_Ground_Door', 'x', -259.7, 55, 75, 0, 68, 0.3, C.violet);
  sign(rN, 'RN_HubSign_Ground', [55, 15, -259.6], [75, 20, -259.2], 'Back', 'N  CONTAINMENT VAULT', { hi: true });
  routes.push({ id: 'N_Ground', from: 'Hub.DataArchive', to: S, level: 0, width: 20,
    waypoints: [[65, 0, -255], [65, 0, -340], [65, 0, -396], [65, 0, -420], [0, 0, -470], [0, 0, -520], [0, 0, -598]],
    openings: ['VaultWall_N full-height slot X55..75 Y-4..70', 'north plinth X53..77 Y-6..30'] });

  // --- Route N elevated: Ring_N (Y24, Z -237) -> vault west balcony (Z -496), X -75..-55
  corridor(rN, 'RN_Bridge', 'z', -65, 20, -496, -237, 24, {
    railFrom: -496, railTo: -237, railGaps: [[-496, -482, 'R'], [-404, -368, 'R']], arch: 32, archFrom: -496, archTo: -414, archH: 14,
    piers: [-290, -350],
  });
  // v8 N-Line Junction station (Z -404..-368): widened deck east of the bridge + ramp down to a link
  // that joins the ground gatehouse plaza (split decision point between the two N routes)
  box(rN, 'RN_Jct_Deck', 'Floor', [-55, 22, -404], [-39, 24, -368], 'DiamondPlate', C.floor);
  box(rN, 'RN_Jct_RailN', 'Rail', [-55, 24, -404], [-39, 28, -403], 'Metal', C.rail);
  box(rN, 'RN_Jct_RailS', 'Rail', [-55, 24, -369], [-39, 28, -368], 'Metal', C.rail);
  box(rN, 'RN_Jct_RailE1', 'Rail', [-40, 24, -403], [-39, 28, -392], 'Metal', C.rail);
  box(rN, 'RN_Jct_RailE2', 'Rail', [-40, 24, -380], [-39, 28, -369], 'Metal', C.rail);
  box(rN, 'RN_Jct_Cover', 'Cover', [-51, 24, -401], [-44, 28.5, -397], 'Metal', C.cover);
  ramp(rN, 'RN_Jct_Ramp', [13, 0, -386], [-39, 24, -386], 12, 'DiamondPlate', C.floorRoute, { rails: [-1, 1] });
  box(rN, 'RN_Link_Floor', 'Floor', [13, -2, -392], [43, 0, -380], 'DiamondPlate', C.floorRoute);
  box(rN, 'RN_Link_RailN', 'Rail', [13, 0, -392], [43, 4, -391], 'Metal', C.rail);
  box(rN, 'RN_Link_RailS', 'Rail', [13, 0, -381], [43, 4, -380], 'Metal', C.rail);
  for (const [nm, x0, x1] of [['W', -78, -76], ['E', -38, -36]]) for (const [k, z] of [[1, -404], [2, -368]]) box(rN, `RN_Jct_Mast${nm}${k}`, 'Decor', [x0, -92, z - 1], [x1, 40, z + 1], 'Metal', C.plateDark, { shadow: true });
  box(rN, 'RN_Jct_Roof', 'Decor', [-78, 40, -406], [-36, 41.5, -366], 'Metal', C.plateDark, { shadow: true });
  box(rN, 'RN_Jct_RoofGlowW', 'Decor', [-74, 39.6, -404], [-73.4, 40, -368], 'Neon', C.cyan);
  box(rN, 'RN_Jct_RoofGlowE', 'Decor', [-41.4, 39.6, -404], [-40.8, 40, -368], 'Neon', C.violet);
  box(rN, 'RN_Jct_Lamp', 'Decor', [-60, 39.4, -390], [-50, 40, -382], 'Neon', C.cyanSoft, { light: { range: 36, brightness: 1.3, color: [170, 230, 255] } });
  sign(rN, 'RN_Jct_SignN', [-74, 32, -368.6], [-42, 37, -368.2], 'Back', 'N-LINE JUNCTION   VAULT ^   GATE >', { hi: true });
  sign(rN, 'RN_Jct_SignS', [-74, 32, -403.8], [-42, 37, -403.4], 'Front', 'N-LINE JUNCTION   HUB ^', { hi: true });
  chevron(rN, 'RN_Jct_ChevGate', -44, 24, -386, 1, 0);
  chevron(rN, 'RN_Jct_ChevVault', -65, 24, -398, 0, -1, { color: C.white });
  chevron(rN, 'RN_Link_ChevUp', 34, 0, -386, -1, 0);
  routes.push({ id: 'N_Junction', from: 'Route_N elevated', to: 'Route_N ground gatehouse', level: 24, width: 12,
    waypoints: [[-65, 24, -386], [-39, 24, -386], [13, 0, -386], [43, 0, -386], [65, 0, -386]], openings: [] });
  cut('RN_Bridge_Plinth', [-77, 20, -337], [-53, 52, -316]);
  portal(rN, 'RN_Bridge_Portal', 'x', -318, -77, -53, 24, 52, 1, C.cyan);
  // v8: full-height slot; a 4-high rail closes it at the Archive floor (Y0)
  cut('RN_Bridge_VaultWall', [-75, -4, -261.6], [-55, 70, -260]);
  portal(rN, 'RN_Bridge_Door', 'x', -259.7, -75, -55, 0, 68, 0.3, C.cyan);
  box(rN, 'RN_SlotRail', 'Rail', [-75, 0, -261.5], [-55, 4, -260.5], 'Metal', C.rail);
  sign(rN, 'RN_HubSign_Elevated', [-75, 36, -259.6], [-55, 41, -259.2], 'Back', 'N ELEVATED  VAULT', { hi: true });
  routes.push({ id: 'N_Elevated', from: 'Hub.OuterRing_N', to: S, level: 24, width: 20,
    waypoints: [[-65, 24, -232], [-65, 24, -300], [-65, 24, -386], [-65, 24, -494], [-72, 24, -506], [-57.5, 24, -506], [-57.5, 24, -512], [-57.5, 0, -564], [0, 0, -598]],
    openings: ['VaultWall_N full-height slot X-75..-55 Y-4..70 (rail at Y0)', 'north plinth X-77..-53 Y20..52'] });

  // --- Forecourt (objective: Vault Antechamber), Y0, X -90..90, Z -496..-420
  box(g, 'CV_Forecourt_Floor', 'Floor', [-90, -4, -496], [90, 0, -420], 'DiamondPlate', C.floor, { attrs: { Map1Space: 'Objective_VaultAntechamber' } });
  box(g, 'CV_Forecourt_Base', 'Decor', [-92, -60, -498], [92, -4, -420], 'Concrete', C.charcoal, { shadow: true });
  box(g, 'CV_Forecourt_RailW', 'Rail', [-90, 0, -496], [-89, 4, -420], 'Metal', C.rail);
  box(g, 'CV_Forecourt_RailE', 'Rail', [89, 0, -496], [90, 4, -420], 'Metal', C.rail);
  box(g, 'CV_Forecourt_RailS1', 'Rail', [-89, 0, -421], [55, 4, -420], 'Metal', C.rail);
  box(g, 'CV_Forecourt_RailS2', 'Rail', [75, 0, -421], [89, 4, -420], 'Metal', C.rail);
  box(g, 'CV_Forecourt_RailNW', 'Rail', [-89, 0, -496], [-84, 4, -495], 'Metal', C.rail);
  box(g, 'CV_Forecourt_RailNE', 'Rail', [84, 0, -496], [89, 4, -495], 'Metal', C.rail);
  // ramp forecourt -> bridge (Y0 -> Y24) and landing
  ramp(g, 'CV_Forecourt_Ramp', [-48.5, 0, -430], [-48.5, 24, -482], 11, 'DiamondPlate', C.floor, { rails: [-1, 1], railFoot: 14 });
  box(g, 'CV_Forecourt_Landing', 'Floor', [-55, 22, -496], [-43, 24, -482], 'DiamondPlate', C.floor);
  box(g, 'CV_Forecourt_LandingRailE', 'Rail', [-44, 24, -496], [-43, 28, -482], 'Metal', C.rail);
  // objective terminals + low cover
  for (const [i, x] of [[1, -20], [2, 20]]) {
    box(g, `CV_Terminal${i}`, 'Cover', [x - 3, 0, -462], [x + 3, 5, -456], 'Metal', C.cover);
    box(g, `CV_Terminal${i}_Screen`, 'Decor', [x - 2.4, 5, -459.2], [x + 2.4, 8, -458.8], 'Neon', C.cyanSoft);
  }
  box(g, 'CV_ForecourtWall1', 'Cover', [-80, 0, -440], [-64, 4, -437], 'Metal', C.cover);
  box(g, 'CV_ForecourtWall2', 'Cover', [64, 0, -470], [80, 4, -467], 'Metal', C.cover);
  box(g, 'CV_Forecourt_Lamp', 'Decor', [-4, 30, -462], [4, 31, -454], 'Neon', C.cyanSoft, { light: { range: 50, brightness: 1.2, color: [170, 230, 255] } });
  box(g, 'CV_Forecourt_LampMast', 'Decor', [-0.6, 0, -458.6], [0.6, 30, -457.4], 'Metal', C.plateDark);

  // --- Vault hall: interior X -80..80, Z -700..-496 (south wall Z -500..-496)
  box(g, 'CV_VaultFloor', 'Floor', [-80, -4, -700], [80, 0, -496], 'SmoothPlastic', C.floorLightV, { boss: S });
  box(g, 'CV_VaultBase', 'Decor', [-88, -70, -708], [88, -4, -496], 'Concrete', C.charcoal, { shadow: true });
  // floor telegraph grid (decor neon lines)
  for (const x of [-40, 0, 40]) box(g, `CV_FloorLineX${x}`, 'Decor', [x - 0.25, 0, -690], [x + 0.25, 0.12, -506], 'Neon', C.cyan, { tr: 0.35 });
  for (const z of [-548, -598, -648]) box(g, `CV_FloorLineZ${-z}`, 'Decor', [-70, 0, z - 0.25], [70, 0.12, z + 0.25], 'Neon', C.cyan, { tr: 0.35 });
  // walls
  wallWithOpenings(g, 'CV_WallS', 'x', -84, 84, 0, 96, -500, -496,
    [[-16, 16, 0, 30], [-80, -64, 22, 54], [48, 72, 0, 26]], 'Metal', C.plate);
  box(g, 'CV_BalconyW_RailS', 'Rail', [-80, 24, -497], [-75, 28, -496], 'Metal', C.rail);
  box(g, 'CV_WallW', 'Wall', [-84, -4, -704], [-80, 96, -500], 'Metal', C.wallLight);
  box(g, 'CV_WallE', 'Wall', [80, -4, -704], [84, 96, -500], 'Metal', C.wallLight);
  wallWithOpenings(g, 'CV_WallN', 'x', -84, 84, -4, 96, -704, -700, [[-36, 36, 8, 80]], 'Metal', C.plate);
  box(g, 'CV_WallN_Glass', 'Wall', [-36, 8, -703], [36, 80, -701], 'Glass', C.glass, { tr: 0.55, shadow: false });
  box(g, 'CV_GateGlow', 'Decor', [-16, 30, -501], [16, 31, -495], 'Neon', C.cyan);
  // balconies Y24 + ramps + rails + columns
  for (const [sd, x0, x1, rx0, rx1, side] of [['W', -80, -64, -65, -64, 1], ['E', 64, 80, 64, 65, -1]]) {
    const z0 = sd === 'W' ? -496 : -500;
    box(g, `CV_Balcony${sd}`, 'Floor', [x0, 22, -640], [x1, 24, z0], 'DiamondPlate', C.floor);
    box(g, `CV_Balcony${sd}_Rail`, 'Rail', [rx0, 24, -640], [rx1, 28, sd === 'W' ? -512 : z0], 'Metal', C.rail);
    box(g, `CV_Balcony${sd}_Edge`, 'Decor', [rx0, 21.6, -640], [rx1, 22, -500], 'Neon', C.cyan);
    const xm = (x0 + x1) / 2;
    ramp(g, `CV_Ramp${sd}`, [xm, 0, -692], [xm, 24, -640], 16, 'DiamondPlate', C.floor, { rails: [side > 0 ? -1 : 1], railFoot: 14 });
    for (const [i, z] of [[1, -520], [2, -560], [3, -600], [4, -636]]) {
      const cx = sd === 'W' ? -65.5 : 65.5;
      box(g, `CV_Column${sd}${i}`, 'Cover', [cx - 1.5, 0, z - 1.5], [cx + 1.5, 22, z + 1.5], 'Metal', C.columnLight);
    }
  }
  // v8 grand stair: west balcony (Y24) -> vault floor, right inside the south wall (the elevated
  // route now reaches the boss floor in ~5 s instead of walking the balcony to the north ramp)
  box(g, 'CV_Stair_Landing', 'Floor', [-64, 22, -512], [-51, 24, -500], 'DiamondPlate', C.floor);
  box(g, 'CV_Stair_LandingRailE', 'Rail', [-52, 24, -512], [-51, 28, -500], 'Metal', C.rail);
  ramp(g, 'CV_Stair', [-57.5, 0, -564], [-57.5, 24, -512], 12, 'DiamondPlate', C.floor, { rails: [-1, 1], railFoot: 14 });
  box(g, 'CV_Stair_Glow', 'Decor', [-63.5, 21.6, -512.4], [-51.5, 22, -512], 'Neon', C.violet);
  // v8 entry landmark: Containment Gate (two collidable pylons against the south wall + lintel and sign)
  for (const [nm, x0] of [['W', -26], ['E', 18]]) {
    box(g, `CV_GatePylon${nm}`, 'Wall', [x0, 0, -496], [x0 + 8, 88, -494], 'Metal', C.plateDark);
    box(g, `CV_GatePylon${nm}_Strip`, 'Decor', [x0 + 3, 2, -494], [x0 + 5, 86, -493.6], 'Neon', C.violet);
  }
  box(g, 'CV_GateLintel', 'Decor', [-26, 80, -496], [26, 90, -493], 'Metal', C.plateDark, { shadow: true });
  sign(g, 'CV_GateSign', [-18, 81.5, -493], [18, 88.5, -492.6], 'Back', 'CONTAINMENT VAULT  N-01');
  // human-scale service doors either side of the gate (scale cue)
  for (const [nm, x] of [['W', -46], ['E', 40]]) {
    box(g, `CV_ServiceDoor${nm}`, 'Decor', [x - 3, 0, -496], [x + 3, 9, -495.6], 'Metal', C.charcoal);
    box(g, `CV_ServiceDoor${nm}_Glow`, 'Decor', [x - 3, 9, -496], [x + 3, 9.4, -495.5], 'Neon', C.cyan);
  }
  // dais + steps at the north end
  box(g, 'CV_Dais', 'Floor', [-40, 0, -700], [40, 6, -666], 'SmoothPlastic', C.floorBoss);
  box(g, 'CV_DaisStep2', 'Floor', [-12, 0, -666], [12, 4, -662], 'SmoothPlastic', C.floorBoss);
  box(g, 'CV_DaisStep1', 'Floor', [-12, 0, -662], [12, 2, -658], 'SmoothPlastic', C.floorBoss);
  box(g, 'CV_DaisEdge', 'Decor', [-40, 5.9, -666.3], [40, 6.1, -665.9], 'Neon', C.cyan);
  // cover pods and barriers
  for (const [i, x, z] of [[1, -40, -560], [2, 40, -560], [3, -40, -625], [4, 40, -625]]) {
    box(g, `CV_Pod${i}`, 'Cover', [x - 5, 0, z - 5], [x + 5, 12, z + 5], 'Metal', C.columnLight);
    box(g, `CV_Pod${i}_Glow`, 'Decor', [x - 5.2, 9, z - 5.2], [x + 5.2, 9.6, z + 5.2], 'Neon', C.cyanSoft, { tr: 0.2 });
  }
  box(g, 'CV_Barrier1', 'Cover', [-9, 0, -546], [9, 3.5, -544], 'Metal', C.cover);
  box(g, 'CV_Barrier2', 'Cover', [-9, 0, -636], [9, 3.5, -634], 'Metal', C.cover);
  // roof (decor) with skylight X -20..20
  box(g, 'CV_RoofW', 'Decor', [-88, 96, -708], [-20, 100, -496], 'Metal', C.plateDark, { shadow: true });
  box(g, 'CV_RoofE', 'Decor', [20, 96, -708], [88, 100, -496], 'Metal', C.plateDark, { shadow: true });
  for (let k = 0; k < 5; k++) { const z = -520 - k * 40; box(g, `CV_RoofRib${k + 1}`, 'Decor', [-20, 96, z - 1.5], [20, 99, z + 1.5], 'Metal', C.plateDark, { shadow: true }); }
  box(g, 'CV_SkyEdgeW', 'Decor', [-20.4, 95.6, -704], [-19.6, 96, -500], 'Neon', C.cyan);
  box(g, 'CV_SkyEdgeE', 'Decor', [19.6, 95.6, -704], [20.4, 96, -500], 'Neon', C.cyan);
  // wall bands + exterior buttresses
  for (const x of [-79.8, 79.8]) for (const y of [44, 84]) box(g, `CV_Band${x < 0 ? 'W' : 'E'}${y}`, 'Decor', [x - 0.2, y, -700], [x + 0.2, y + 0.6, -500], 'Neon', C.cyan);
  let bk = 0;
  for (const z of [-510, -545, -580, -615, -650, -685]) for (const x of [-88, 84]) { bk++; box(g, `CV_Buttress${bk}`, 'Decor', [x, -90, z - 3], [x + 4, 126, z + 3], 'Concrete', C.charcoal, { shadow: true }); box(g, `CV_ButtressCap${bk}`, 'Decor', [x - 0.2, 126, z - 3.2], [x + 4.2, 127.2, z + 3.2], 'Neon', bk % 2 ? C.violet : C.cyan); }
  for (const x of [-84.2, 84.2]) box(g, `CV_ExtBand${x < 0 ? 'W' : 'E'}`, 'Decor', [x - 0.3, 70, -704], [x + 0.3, 71.2, -496], 'Neon', C.violet);
  // lights
  for (const [i, x, z] of [[1, -40, -540], [2, 40, -540], [3, -40, -640], [4, 40, -640]]) {
    // v10: lamps hang at Y36 (at Y90 the floor was outside PointLight range 60)
    box(g, `CV_Lamp${i}`, 'Decor', [x - 3, 36, z - 3], [x + 3, 37, z + 3], 'Neon', C.white, { shadow: false, light: { range: 60, brightness: 3, color: [215, 240, 255] } });
    box(g, `CV_LampRod${i}`, 'Decor', [x - 0.4, 37, z - 0.4], [x + 0.4, 96, z + 0.4], 'Metal', C.trim, { shadow: false });
  }
  for (const x of [-79.8, 79.8]) box(g, `CV_Band${x < 0 ? 'W' : 'E'}12`, 'Decor', [x - 0.2, 12, -638], [x + 0.2, 12.6, -500], 'Neon', C.cyanSoft, { shadow: false });
  box(g, 'CV_DaisLamp', 'Decor', [-20, 34, -700.2], [20, 35, -699.8], 'Neon', C.white, { shadow: false, light: { range: 50, brightness: 1.8, color: [215, 240, 255] } });
  // boss bounds (invisible reference)
  box(g, 'BossSector_ContainmentVault_Bounds', 'Bounds', [-80, 0, -700], [80, 96, -496], 'SmoothPlastic', C.white, { tr: 1, coll: false, attrs: { FloorY: 0, BossSector: S } });
  // landmarks: containment vessel behind the north glass, twin pylons at the forecourt
  box(gl, 'CV_VesselDeck', 'Decor', [-44, -12, -780], [44, 0, -704], 'Concrete', C.charcoal, { shadow: true });
  cylY(gl, 'CV_Vessel', 'Decor', 0, -742, 0, 150, 46, 'Glass', C.glass, { tr: 0.45, shadow: false });
  cylY(gl, 'CV_VesselCore', 'Decor', 0, -742, 0, 172, 10, 'Neon', C.cyan);
  for (const [i, y] of [[1, 2], [2, 40], [3, 80], [4, 120], [5, 150]]) cylY(gl, `CV_VesselRing${i}`, 'Decor', 0, -742, y, y + 4, 50, 'Metal', C.trim);
  cylY(gl, 'CV_VesselCap', 'Decor', 0, -742, 154, 160, 40, 'Metal', C.plateDark);
  for (const x of [-104, 104]) {
    const nm = x < 0 ? 'W' : 'E';
    box(gl, `CV_Pylon${nm}`, 'Decor', [x - 7, -90, -447], [x + 7, 190, -433], 'Metal', C.plateDark, { shadow: true });
    box(gl, `CV_Pylon${nm}_Strip`, 'Decor', [x - 1, 0, -433.4], [x + 1, 186, -432.6], 'Neon', C.cyan);
    box(gl, `CV_Pylon${nm}_Beacon`, 'Decor', [x - 4, 190, -444], [x + 4, 198, -436], 'Neon', C.cyan, { light: { range: 60, brightness: 2, color: [120, 230, 255] } });
  }
  layoutExtra.landmarks.push({ sector: S, name: 'Containment vessel (glass cylinder, Y0-172) + twin forecourt pylons (Y190)', pos: [0, 0, -742] });
}

// =================================================================== WEST: TestingPit
{
  const S = 'TestingPit';
  const g = grp('TestingPit', S), gl = grp('TestingPit_Landmark', S, 'Model', 'Persistent');
  const rW = grp('Route_W', 'Route_W');
  const cx = -620, cz = 32;
  // --- Route W ground: YardFloor_W edge (X -260) -> pit rim (X -470), Z 23..41
  corridor(rW, 'RW_Ground', 'x', 32, 18, -472, -260, 0, {
    railFrom: -469, railTo: -260, railGaps: [[-396, -340, 'B'], [-456, -432, 'L']], piers: [-290, -440], railGlow: C.violet,
  });
  // mid-corridor objective nook (Agent C review): side alcove with a console and lamp
  box(rW, 'RW_Nook_Floor', 'Floor', [-456, -2, 9], [-432, 0, 23], 'DiamondPlate', C.floor, { attrs: { Map1Space: 'Objective_RW_Nook' } });
  box(rW, 'RW_Nook_RailOuter', 'Rail', [-456, 0, 9], [-432, 4, 10], 'Metal', C.rail);
  box(rW, 'RW_Nook_RailA', 'Rail', [-456, 0, 9], [-455, 4, 23], 'Metal', C.rail);
  box(rW, 'RW_Nook_RailB', 'Rail', [-433, 0, 9], [-432, 4, 23], 'Metal', C.rail);
  box(rW, 'RW_Nook_Console', 'Cover', [-450, 0, 13], [-438, 4, 16], 'Metal', C.cover);
  box(rW, 'RW_Nook_Screen', 'Decor', [-449, 4, 14.3], [-439, 7, 14.7], 'Neon', C.cyanSoft);
  box(rW, 'RW_Nook_Mast', 'Decor', [-444.6, 0, 8.4], [-443.4, 18, 9.6], 'Metal', C.plateDark);
  box(rW, 'RW_Nook_Lamp', 'Decor', [-447, 18, 6], [-441, 19, 12], 'Neon', C.cyanSoft, { light: { range: 32, brightness: 1.2, color: [170, 230, 255] } });
  box(rW, 'RW_Gate_Floor', 'Floor', [-396, -2, 13], [-340, 0, 51], 'DiamondPlate', C.floorRoute);
  for (const [nm, mn, mx] of [
    ['RW_Gate_RailN', [-396, 0, 13], [-340, 4, 14]], ['RW_Gate_RailS', [-396, 0, 50], [-340, 4, 51]],
    ['RW_Gate_RailE1', [-341, 0, 14], [-340, 4, 23]], ['RW_Gate_RailE2', [-341, 0, 41], [-340, 4, 50]],
    ['RW_Gate_RailW1', [-396, 0, 14], [-395, 4, 23]], ['RW_Gate_RailW2', [-396, 0, 41], [-395, 4, 50]],
  ]) box(rW, nm, 'Rail', mn, mx, 'Metal', C.rail);
  box(rW, 'RW_Gate_Cover1', 'Cover', [-371, 0, 15], [-365, 5, 21], 'Metal', C.cover);
  box(rW, 'RW_Gate_Cover2', 'Cover', [-371, 0, 43], [-365, 5, 49], 'Metal', C.cover);
  box(rW, 'RW_Gate_Lamp', 'Decor', [-370, 20.5, 28], [-366, 21, 36], 'Neon', C.cyanSoft, { light: { range: 36, brightness: 1.2, color: [170, 230, 255] } });
  // --- Route W elevated: Ring_W (X -237, Y24) -> pit gantry, stacked over the ground route, Z 26..38
  corridor(rW, 'RW_Bridge', 'x', 32, 12, -470, -237, 24, { arch: 34, archFrom: -470, archTo: -430, archH: 14, railGaps: [[-428, -396, 'R']] });
  cut('RW_Plinth', [-337, -6, 21], [-315, 52, 43]);
  portal(rW, 'RW_Portal', 'z', -318, 21, 43, 0, 52, 1, C.violet);
  sign(rW, 'RW_HubSign_Ground', [-317, 4, 52], [-316.6, 17, 100], 'Right', 'TESTING PIT  W  >>', { hi: true });
  sign(rW, 'RW_HubSign_Elevated', [-317, 27, 52], [-316.6, 37, 92], 'Right', 'W  ELEVATED  >>', { hi: true });
  // v8 W-Line Junction station (X -428..-396): deck south of the bridge + ramp straight down to the
  // pit's east rim (split: descend into the pit now, or stay high on the gantry over the arena)
  box(rW, 'RW_Jct_Deck', 'Floor', [-428, 22, 38], [-396, 24, 56], 'DiamondPlate', C.floor);
  box(rW, 'RW_Jct_RailE', 'Rail', [-397, 24, 38], [-396, 28, 56], 'Metal', C.rail);
  box(rW, 'RW_Jct_RailS', 'Rail', [-428, 24, 55], [-397, 28, 56], 'Metal', C.rail);
  box(rW, 'RW_Jct_RailW', 'Rail', [-428, 24, 38], [-427, 28, 44], 'Metal', C.rail);
  box(rW, 'RW_Jct_Cover', 'Cover', [-412, 24, 47], [-405, 28.5, 52], 'Metal', C.cover);
  ramp(rW, 'RW_Jct_Ramp', [-480, 0, 50], [-428, 24, 50], 12, 'DiamondPlate', C.floorRoute, { rails: [-1, 1], railFoot: 10 });
  for (const [nm, x0] of [['W', -432], ['E', -394]]) for (const [k, z0] of [[1, 20], [2, 58]]) box(rW, `RW_Jct_Mast${nm}${k}`, 'Decor', [x0, -92, z0], [x0 + 2, 40, z0 + 2], 'Metal', C.plateDark, { shadow: true });
  box(rW, 'RW_Jct_Roof', 'Decor', [-432, 40, 20], [-392, 41.5, 60], 'Metal', C.plateDark, { shadow: true });
  box(rW, 'RW_Jct_RoofGlowN', 'Decor', [-430, 39.6, 24], [-394, 40, 24.6], 'Neon', C.cyan);
  box(rW, 'RW_Jct_RoofGlowS', 'Decor', [-430, 39.6, 55.4], [-394, 40, 56], 'Neon', C.violet);
  box(rW, 'RW_Jct_Lamp', 'Decor', [-418, 39.4, 40], [-408, 40, 48], 'Neon', C.cyanSoft, { light: { range: 36, brightness: 1.3, color: [170, 230, 255] } });
  sign(rW, 'RW_Jct_Sign', [-396.4, 31, 25], [-396, 36, 55], 'Right', 'W-LINE JUNCTION   RIM <   GANTRY ^', { hi: true });
  chevron(rW, 'RW_Jct_ChevRim', -424, 24, 50, -1, 0);
  chevron(rW, 'RW_Jct_ChevGantry', -412, 24, 34, -1, 0, { color: C.white });
  // v8 entry landmark: test aperture ring around both W routes where they reach the rim
  apertureX(rW, 'RW_Aperture', -462, 14, 32, 30, 16, 3, 4, 'Metal', C.trim, { shadow: true });
  apertureX(rW, 'RW_ApertureGlow', -460.2, 14, 32, 27.6, 16, 0.4, 0.6, 'Neon', C.violet);
  sign(rW, 'RW_ApertureSign', [-460.6, 46, 18], [-460.2, 52, 46], 'Right', 'TESTING PIT  W-02');
  routes.push({ id: 'W_Junction', from: 'Route_W elevated', to: 'TestingPit east rim', level: 24, width: 12,
    waypoints: [[-412, 24, 32], [-412, 24, 50], [-428, 24, 50], [-480, 0, 50]], openings: [] });
  // --- the pit (rings descend from the rim at Y0 to the floor at Y-24)
  // v8: the pit is a 12-sided bowl (was 24-34 segments per tier): 48 tier slabs instead of 116, with
  // faces centred on E/W so the corridor and the control deck meet flat faces
  cylY(g, 'TP_PitFloor', 'Floor', cx, cz, -28, -24, 150, 'SmoothPlastic', C.floorBoss, { boss: S });
  const rings = [
    { nm: 'TierC', r1: 72, r2: 94, top: -18, N: 12, boss: S },
    { nm: 'TierB', r1: 94, r2: 114, top: -12, N: 12 },
    { nm: 'TierA', r1: 114, r2: 136, top: -6, N: 12 },
    { nm: 'Rim', r1: 136, r2: 152, top: 0, N: 12 },
  ];
  for (const ring of rings) {
    for (let k = 0; k < ring.N; k++) {
      const th = k * 2 * Math.PI / ring.N;
      ringSeg(g, `TP_${ring.nm}_${k + 1}`, 'Floor', cx, cz, ring.r1, ring.r2, th, ring.N, -30, ring.top, 'Metal', ring.nm === 'Rim' ? C.floor : C.plate, { boss: ring.boss || null, shadow: true });
      if (ring.nm === 'TierC' || ring.nm === 'TierA') ringStrip(g, `TP_${ring.nm}_Edge${k + 1}`, 'Decor', cx, cz, ring.r1 + 0.4, th, ring.N, ring.top, ring.top + 0.15, 0.5, 'Neon', C.cyan);
    }
  }
  // aisle ramps at 45/135/225/315 deg
  const aisle = [30, 150, 210, 330]; // v8: on 12-gon face centres
  for (const deg of [30, 210]) { // v8: two aisle ramps (tiers are 6 studs: jumpable); masts stay on all four
    const th = deg * Math.PI / 180, ux = Math.cos(th), uz = Math.sin(th);
    const P = (r, y) => [cx + r * ux, y, cz + r * uz];
    ramp(g, `TP_Aisle${deg}_0`, P(57, -24), P(72, -18), 10, 'DiamondPlate', C.floor);
    ramp(g, `TP_Aisle${deg}_1`, P(79, -18), P(94, -12), 10, 'DiamondPlate', C.floor);
    ramp(g, `TP_Aisle${deg}_2`, P(99, -12), P(114, -6), 10, 'DiamondPlate', C.floor);
    ramp(g, `TP_Aisle${deg}_3`, P(121, -6), P(136, 0), 10, 'DiamondPlate', C.floor);
  }
  // v8 rim outer rail: one straight rail per 12-gon face (apothem 151.5), with openings on the E face
  // (ground corridor Z 23..41, junction ramp Z 44..56) and the W face (control deck Z 0..64)
  const HALF = 152 * Math.tan(Math.PI / 12) + 0.05;
  const faceGaps = { 0: [[-9, 9], [12, 24]], 6: [[-32, 32]] }; // tangential t (E face: t = Z - cz; W face: t = cz - Z)
  for (let k = 0; k < 12; k++) {
    const th = k * Math.PI / 6, n = [Math.cos(th), 0, Math.sin(th)], tv = [-Math.sin(th), 0, Math.cos(th)];
    const spans = [];
    let cur = -HALF;
    for (const gp of faceGaps[k] || []) { spans.push([cur, gp[0]]); cur = gp[1]; }
    spans.push([cur, HALF]);
    spans.forEach(([t0, t1], i) => {
      const tm = (t0 + t1) / 2;
      const pos = [cx + n[0] * 151.5 + tv[0] * tm, 2, cz + n[2] * 151.5 + tv[2] * tm];
      const f = lookAt(pos, [cx, 2, cz]);
      push({ name: `TP_RimRail${k + 1}${spans.length > 1 ? String.fromCharCode(97 + i) : ''}`, grp: g, role: 'Rail', size: [t1 - t0, 4, 1], pos, rot: f.rot, mat: 'Metal', color: C.rail });
    });
  }
  // pit cover (6 blocks) + central emitter (low, jumpable)
  for (let k = 0; k < 6; k++) {
    const th = (k * 60 + 30) * Math.PI / 180, x = cx + 46 * Math.cos(th), z = cz + 46 * Math.sin(th);
    box(g, `TP_Cover${k + 1}`, 'Cover', [x - 4, -24, z - 4], [x + 4, -18, z + 4], 'Metal', C.cover);
  }
  cylY(g, 'TP_EmitterBase', 'Cover', cx, cz, -24, -21, 16, 'Metal', C.trim);
  cylY(g, 'TP_EmitterGlow', 'Decor', cx, cz, -21, -20.6, 12, 'Neon', C.cyan);
  for (const [i, x, z] of [[1, cx + 60, cz + 60], [2, cx - 60, cz - 60], [3, cx + 60, cz - 60], [4, cx - 60, cz + 60]]) box(g, `TP_Lamp${i}`, 'Decor', [x - 2, 16, z - 2], [x + 2, 17, z + 2], 'Neon', C.cyanSoft, { light: { range: 60, brightness: 1.6, color: [185, 235, 255] } });
  box(g, 'TP_Base', 'Decor', [cx - 150, -70, cz - 150], [cx + 150, -30, cz + 150], 'Concrete', C.charcoal, { shadow: true });
  // gantry across the pit at Y24 (continuation of the elevated route) + west ramp down to the objective deck
  corridor(rW, 'RW_Gantry', 'x', 32, 12, -760, -470, 24, { thick: 2 });
  ramp(rW, 'RW_GantryRampW', [-812, 0, 32], [-760, 24, 32], 12, 'DiamondPlate', C.floorRoute, { rails: [-1, 1], railFoot: 14 });
  // objective: Test Control deck (Y0) beyond the west rim
  box(g, 'TP_Control_Floor', 'Floor', [-834, -4, 0], [-766, 0, 64], 'DiamondPlate', C.floor, { attrs: { Map1Space: 'Objective_TestControl' } });
  box(g, 'TP_Control_Base', 'Decor', [-836, -60, -2], [-766, -4, 66], 'Concrete', C.charcoal, { shadow: true });
  for (const [nm, mn, mx] of [
    ['TP_Control_RailW', [-834, 0, 0], [-833, 4, 64]], ['TP_Control_RailN', [-834, 0, 0], [-766, 4, 1]], ['TP_Control_RailS', [-834, 0, 63], [-766, 4, 64]],
  ]) box(g, nm, 'Rail', mn, mx, 'Metal', C.rail);
  box(g, 'TP_Control_Booth', 'Cover', [-830, 0, 4], [-816, 9, 18], 'Metal', C.cover);
  box(g, 'TP_Control_BoothGlass', 'Decor', [-816.2, 4, 6], [-815.8, 8, 16], 'Neon', C.cyanSoft, { tr: 0.3 });
  box(g, 'TP_Control_Console1', 'Cover', [-826, 0, 46], [-820, 4, 58], 'Metal', C.cover);
  box(g, 'TP_Control_Console1_Screen', 'Decor', [-820.2, 4, 47], [-819.8, 7, 57], 'Neon', C.cyanSoft);
  box(g, 'BossSector_TestingPit_Bounds', 'Bounds', [cx - 94, -24, cz - 94], [cx + 94, 40, cz + 94], 'SmoothPlastic', C.white, { tr: 1, coll: false, attrs: { FloorY: -24, BossSector: S } });
  // landmark: test halo ring at Y70, 4 masts, central beam, cables
  const HN = 24;
  for (let k = 0; k < HN; k++) {
    const th = (k + 0.5) * 2 * Math.PI / HN;
    ringSeg(gl, `TP_Halo${k + 1}`, 'Decor', cx, cz, 62, 72, th, HN, 68, 74, 'Metal', C.trim, { shadow: true });
    ringStrip(gl, `TP_HaloGlow${k + 1}`, 'Decor', cx, cz, 62.2, th, HN, 69, 71, 0.4, 'Neon', C.cyan);
  }
  for (const deg of aisle) {
    const th = deg * Math.PI / 180, x = cx + 168 * Math.cos(th), z = cz + 168 * Math.sin(th);
    box(gl, `TP_Mast${deg}`, 'Decor', [x - 5, -90, z - 5], [x + 5, 140, z + 5], 'Metal', C.plateDark, { shadow: true });
    box(gl, `TP_Mast${deg}_Beacon`, 'Decor', [x - 3, 140, z - 3], [x + 3, 146, z + 3], 'Neon', C.violet);
    beam(gl, `TP_Cable${deg}`, 'Decor', [x, 136, z], [cx + 70 * Math.cos(th), 74, cz + 70 * Math.sin(th)], 1.2, 'Metal', C.trim);
  }
  box(gl, 'TP_Beam', 'Decor', [cx - 1, 30, cz - 1], [cx + 1, 68, cz + 1], 'Neon', C.cyan, { tr: 0.25 });
  layoutExtra.landmarks.push({ sector: S, name: 'Test halo (r62-72, Y68-74) on four violet-capped masts (Y146) + cyan beam', pos: [cx, 70, cz] });
  routes.push({ id: 'W_Ground', from: 'Hub.ResearchYard', to: S, level: 0, width: 18,
    waypoints: [[-255, 0, 32], [-340, 0, 32], [-396, 0, 32], [-466, 0, 32], [-500, 0, 32], [cx + 102, -12, cz + 0], [cx + 60, -24, cz]], openings: ['west plinth X-337..-315 Z21..43 Y-6..52 (shared with elevated)'] });
  routes.push({ id: 'W_Elevated', from: 'Hub.OuterRing_W', to: S, level: 24, width: 12,
    waypoints: [[-232, 24, 32], [-412, 24, 32], [-412, 24, 50], [-428, 24, 50], [-480, 0, 50], [cx + 102, -12, cz + 10], [cx + 40, -24, cz]], openings: ['shared west plinth opening'] });
  routes.push({ id: 'W_Gantry', from: 'Route_W elevated', to: 'Test Control deck', level: 24, width: 12,
    waypoints: [[-470, 24, 32], [-620, 24, 32], [-760, 24, 32], [-812, 0, 32], [-772, 0, 32], [cx - 140, 0, cz], [cx - 60, -24, cz]], openings: [] });
}

// =================================================================== EAST: Foundry
{
  const S = 'Foundry';
  const g = grp('Foundry', S), gl = grp('Foundry_Landmark', S, 'Model', 'Persistent');
  const rE = grp('Route_E', 'Route_E');
  const X0 = 510, X1 = 690, Z0 = -110, Z1 = 70, cx = 600, cz = -20;
  // --- Route E ground: SkyBase edge (X 200) -> foundry west door (X 510), Z -30..-10
  corridor(rE, 'RE_Ground', 'x', -20, 20, 200, 510, 0, {
    railFrom: 200, railTo: 506, railGaps: [[340, 396, 'B'], [406, 428, 'R'], [432, 456, 'R']], railGlow: C.violet, arch: 30, archFrom: 414, archTo: 506, archH: 16, piers: [290, 430, 480],
  });
  // mid-corridor objective nook (Agent C review): side alcove with a console and lamp
  box(rE, 'RE_Nook_Floor', 'Floor', [432, -2, -10], [456, 0, 6], 'DiamondPlate', C.floor, { attrs: { Map1Space: 'Objective_RE_Nook' } });
  box(rE, 'RE_Nook_RailOuter', 'Rail', [432, 0, 5], [456, 4, 6], 'Metal', C.rail);
  box(rE, 'RE_Nook_RailA', 'Rail', [432, 0, -10], [433, 4, 6], 'Metal', C.rail);
  box(rE, 'RE_Nook_RailB', 'Rail', [455, 0, -10], [456, 4, 6], 'Metal', C.rail);
  box(rE, 'RE_Nook_Console', 'Cover', [438, 0, 0], [450, 4, 3], 'Metal', C.cover);
  box(rE, 'RE_Nook_Screen', 'Decor', [439, 4, 1.3], [449, 7, 1.7], 'Neon', C.cyanSoft);
  box(rE, 'RE_Nook_Mast', 'Decor', [443.4, 0, 4.4], [444.6, 18, 5.6], 'Metal', C.plateDark);
  box(rE, 'RE_Nook_Lamp', 'Decor', [441, 18, 2], [447, 19, 8], 'Neon', C.cyanSoft, { light: { range: 32, brightness: 1.2, color: [170, 230, 255] } });
  box(rE, 'RE_Gate_Floor', 'Floor', [340, -2, -42], [396, 0, 2], 'DiamondPlate', C.floorRoute);
  for (const [nm, mn, mx] of [
    ['RE_Gate_RailN', [340, 0, -42], [396, 4, -41]], ['RE_Gate_RailS', [340, 0, 1], [396, 4, 2]],
    ['RE_Gate_RailW1', [340, 0, -41], [341, 4, -30]], ['RE_Gate_RailW2', [340, 0, -10], [341, 4, 1]],
    ['RE_Gate_RailE1', [395, 0, -41], [396, 4, -30]], ['RE_Gate_RailE2', [395, 0, -10], [396, 4, 1]],
  ]) box(rE, nm, 'Rail', mn, mx, 'Metal', C.rail);
  box(rE, 'RE_Gate_Cover1', 'Cover', [365, 0, -38], [371, 5, -32], 'Metal', C.cover);
  box(rE, 'RE_Gate_Cover2', 'Cover', [365, 0, -8], [371, 5, -2], 'Metal', C.cover);
  box(rE, 'RE_Gate_Lamp', 'Decor', [366, 50, -24], [370, 51, -16], 'Neon', C.cyanSoft, { light: { range: 40, brightness: 1.2, color: [170, 230, 255] } });
  cut('RE_Ground_Plinth', [315, -6, -32], [337, 30, -8]);
  portal(rE, 'RE_Ground_Portal', 'z', 318, -32, -8, 0, 30, 1, C.violet);
  // --- Route E elevated: Ring_E (X 237, Y24) -> control gallery (X 540), Z 83..97
  corridor(rE, 'RE_Bridge', 'x', 90, 14, 237, 540, 24, { arch: 34, archFrom: 440, archTo: 540, archH: 14, piers: [290, 380, 470], railGaps: [[399, 435, 'L']] });
  sign(rE, 'RE_HubSign_Ground', [316.6, 4, -84], [317, 17, -36], 'Left', 'FOUNDRY  E  >>', { hi: true });
  sign(rE, 'RE_HubSign_Elevated', [316.6, 27, 38], [317, 37, 77], 'Left', 'E  ELEVATED  >>', { hi: true });
  // v8 E-Line Junction station (X 399..435): deck south of the bridge + ramp down to a platform on the
  // ground corridor (split decision point; links the two E routes halfway)
  box(rE, 'RE_Jct_Deck', 'Floor', [399, 22, 67], [435, 24, 83], 'DiamondPlate', C.floor);
  box(rE, 'RE_Jct_RailW', 'Rail', [399, 24, 67], [400, 28, 83], 'Metal', C.rail);
  box(rE, 'RE_Jct_RailE', 'Rail', [434, 24, 67], [435, 28, 83], 'Metal', C.rail);
  box(rE, 'RE_Jct_RailS1', 'Rail', [400, 24, 67], [411, 28, 68], 'Metal', C.rail);
  box(rE, 'RE_Jct_RailS2', 'Rail', [423, 24, 67], [434, 28, 68], 'Metal', C.rail);
  box(rE, 'RE_Jct_Cover', 'Cover', [403, 24, 73], [408, 28.5, 79], 'Metal', C.cover);
  ramp(rE, 'RE_Jct_Ramp', [417, 0, 15], [417, 24, 67], 12, 'DiamondPlate', C.floorRoute, { rails: [-1, 1] });
  box(rE, 'RE_Jct_Platform', 'Floor', [406, -2, -10], [428, 0, 17], 'DiamondPlate', C.floorRoute);
  box(rE, 'RE_Jct_PlatRailW', 'Rail', [406, 0, -10], [407, 4, 17], 'Metal', C.rail);
  box(rE, 'RE_Jct_PlatRailE', 'Rail', [427, 0, -10], [428, 4, 17], 'Metal', C.rail);
  box(rE, 'RE_Jct_PlatRailN1', 'Rail', [407, 0, 16], [411, 4, 17], 'Metal', C.rail);
  box(rE, 'RE_Jct_PlatRailN2', 'Rail', [423, 0, 16], [427, 4, 17], 'Metal', C.rail);
  for (const [nm, x0] of [['W', 395], ['E', 437]]) for (const [k, z0] of [[1, 61], [2, 101]]) box(rE, `RE_Jct_Mast${nm}${k}`, 'Decor', [x0, -92, z0], [x0 + 2, 40, z0 + 2], 'Metal', C.plateDark, { shadow: true });
  box(rE, 'RE_Jct_Roof', 'Decor', [395, 40, 61], [439, 41.5, 103], 'Metal', C.plateDark, { shadow: true });
  box(rE, 'RE_Jct_RoofGlowN', 'Decor', [397, 39.6, 64], [437, 40, 64.6], 'Neon', C.violet);
  box(rE, 'RE_Jct_RoofGlowS', 'Decor', [397, 39.6, 99.4], [437, 40, 100], 'Neon', C.cyan);
  box(rE, 'RE_Jct_Lamp', 'Decor', [412, 39.4, 72], [422, 40, 80], 'Neon', C.cyanSoft, { light: { range: 36, brightness: 1.3, color: [170, 230, 255] } });
  sign(rE, 'RE_Jct_Sign', [399, 31, 69], [399.4, 36, 99], 'Left', 'E-LINE JUNCTION   GROUND v   GALLERY ^', { hi: true });
  chevron(rE, 'RE_Jct_ChevGround', 417, 24, 72, 0, -1);
  chevron(rE, 'RE_Jct_ChevGallery', 430, 24, 90, 1, 0, { color: C.white });
  chevron(rE, 'RE_Ground_ChevUp', 417, 0, -20, 0, 1);
  // v8 Ring_E drop-down (C13 correction): open both 1.2-high TransitRing edge rails where the E ground
  // corridor runs 24 studs below, so the drop onto the corridor is an intended route, not a blocked edge
  cut('RE_RingDrop_Inner', [222.9, 24.02, -29.6], [223.5, 25.5, -10.4]);
  cut('RE_RingDrop_Outer', [236.5, 24.02, -29.6], [237.2, 25.5, -10.4]);
  box(rE, 'RE_RingDrop_GlowW', 'Decor', [223.4, 24, -29.4], [224.2, 24.12, -10.6], 'Neon', C.violet);
  box(rE, 'RE_RingDrop_GlowE', 'Decor', [235.8, 24, -29.4], [236.6, 24.12, -10.6], 'Neon', C.violet);
  // v10 landing marker on the corridor floor below the drop (two flat cyan bars across the corridor)
  box(rE, 'RE_RingDrop_LandN', 'Decor', [216, 0, -28.6], [244, 0.12, -28], 'Neon', C.cyan, { shadow: false });
  box(rE, 'RE_RingDrop_LandS', 'Decor', [216, 0, -12], [244, 0.12, -11.4], 'Neon', C.cyan, { shadow: false });
  // v10 step-off bollards at both ends of both ring edges: the drop-off stays 2 studs inside the corridor rails
  // (Z -27.6..-12.4), so a player cannot land on a corridor rail top and step out into the void beside it.
  // Not EdgeRails: the TransitRing EdgeRail cut (legacy C13) is unchanged at Z -29.6..-10.4.
  for (const [k, x0, x1] of [['W', 223.5, 224.7], ['E', 235.3, 236.5]]) for (const [j, z0, z1] of [['N', -29.6, -27.6], ['S', -12.4, -10.4]])
    box(rE, `RE_RingDrop_Bollard${k}${j}`, 'Rail', [x0, 24, z0], [x1, 28, z1], 'Metal', C.violet);
  routes.push({ id: 'E_Junction', from: 'Route_E elevated', to: 'Route_E ground', level: 24, width: 12,
    waypoints: [[417, 24, 90], [417, 24, 67], [417, 0, 15], [417, 0, -20]], openings: [] });
  routes.push({ id: 'E_RingDrop', from: 'Hub.OuterRing_E', to: 'Route_E ground (drop 24)', level: 24, width: 20,
    waypoints: [[230, 24, -20], [246, 0, -20]], openings: ['TransitRing EdgeRail gaps Z-29.6..-10.4 (inner + outer), inside the corridor rails'] });
  cut('RE_Bridge_Plinth', [315, 20, 81], [337, 52, 99]);
  portal(rE, 'RE_Bridge_Portal', 'z', 318, 81, 99, 24, 52, 1, C.cyan);
  cut('RE_Bridge_RingEdgeRail', [236.5, 24.02, 83], [237.2, 25.5, 97]);
  routes.push({ id: 'E_Ground', from: 'Hub.Skybridge', to: S, level: 0, width: 20,
    waypoints: [[195, 0, -20], [340, 0, -20], [396, 0, -20], [505, 0, -20], [560, 0, -20], [cx, 0, cz + 40]], openings: ['east plinth X315..337 Z-32..-8 Y-6..30'] });
  routes.push({ id: 'E_Elevated', from: 'Hub.OuterRing_E', to: S, level: 24, width: 14,
    waypoints: [[232, 24, 90], [420, 24, 90], [538, 24, 90], [600, 24, 80], [600, 24, 63], [620, 24, 60], [620, 0, 4], [cx - 30, 0, cz + 20]],
    openings: ['east plinth X315..337 Z81..99 Y20..52', 'TransitRing EdgeRail gap Z83..97'] });

  // --- shaft floor + walls
  box(g, 'FD_Floor', 'Floor', [X0, -4, Z0], [X1, 0, Z1], 'DiamondPlate', C.floorLight, { boss: S });
  box(g, 'FD_Base', 'Decor', [X0 - 6, -70, Z0 - 6], [X1 + 6, -4, Z1 + 6], 'Concrete', C.charcoal, { shadow: true });
  wallWithOpenings(g, 'FD_WallW', 'z', Z0 - 4, Z1 + 4, -4, 120, X0 - 4, X0, [[-30, -10, -4, 28]], 'Metal', C.plate);
  box(g, 'FD_WallE', 'Wall', [X1, -4, Z0 - 4], [X1 + 4, 120, Z1 + 4], 'Metal', C.wallLight);
  wallWithOpenings(g, 'FD_WallN', 'x', X0, X1, -4, 120, Z0 - 4, Z0, [[560, 640, 84, 104]], 'Metal', C.plate);
  box(g, 'FD_WallN_Slit', 'Wall', [560, 84, Z0 - 3], [640, 104, Z0 - 1], 'Glass', C.glass, { tr: 0.55, shadow: false });
  wallWithOpenings(g, 'FD_WallS', 'x', X0, X1, -4, 120, Z1, Z1 + 4, [[580, 620, 22, 46]], 'Metal', C.plate);
  // catwalk rings Y24, Y48 (14 wide) with inner rails
  for (const y of [24, 48]) {
    const t = `L${y}`;
    box(g, `FD_${t}_N`, 'Floor', [X0, y - 2, Z0], [X1, y, Z0 + 14], 'DiamondPlate', C.floor);
    box(g, `FD_${t}_S`, 'Floor', [X0, y - 2, Z1 - 14], [X1, y, Z1], 'DiamondPlate', C.floor);
    box(g, `FD_${t}_W`, 'Floor', [X0, y - 2, Z0 + 14], [X0 + 14, y, Z1 - 14], 'DiamondPlate', C.floor);
    box(g, `FD_${t}_E`, 'Floor', [X1 - 14, y - 2, Z0 + 14], [X1, y, Z1 - 14], 'DiamondPlate', C.floor);
    box(g, `FD_${t}_EdgeGlow`, 'Decor', [X0 + 14, y - 2.2, Z0 + 13.6], [X1 - 14, y - 1.6, Z0 + 14], 'Neon', C.cyan);
    box(g, `FD_${t}_EdgeGlowS`, 'Decor', [X0 + 14, y - 2.2, Z1 - 14], [X1 - 14, y - 1.6, Z1 - 13.6], 'Neon', C.cyan);
  }
  // rails (inner edges) with gaps for ramp landings
  // L24: N inner edge Z -96 gap X548..560 (R1 low landing); W inner edge X 524 gap Z -24..-12 (R0a landing);
  //      E inner edge X 676 gap Z -28..-16 (R0b landing); S inner edge Z 56 full.
  // L48: N inner edge gap X612..624 (R1 high landing); S inner edge Z 56 gap X640..652 (R2 low landing).
  function railRun(name, axis, fixed0, fixed1, a, b, y, gaps) {
    let cur = a, k = 0;
    for (const gp of [...gaps.sort((p, q) => p[0] - q[0]), [b, b]]) {
      if (Math.min(gp[0], b) - cur > 0.5) {
        k++;
        if (axis === 'x') box(g, `${name}${k}`, 'Rail', [cur, y, fixed0], [Math.min(gp[0], b), y + 4, fixed1], 'Metal', C.rail);
        else box(g, `${name}${k}`, 'Rail', [fixed0, y, cur], [fixed1, y + 4, Math.min(gp[0], b)], 'Metal', C.rail);
      }
      cur = Math.max(cur, gp[1]);
    }
  }
  railRun('FD_L24_RailN', 'x', Z0 + 13, Z0 + 14, X0 + 14, X1 - 14, 24, [[548, 560]]);
  railRun('FD_L24_RailS', 'x', Z1 - 14, Z1 - 13, X0 + 14, X1 - 14, 24, [[614, 626]]);
  railRun('FD_L24_RailW', 'z', X0 + 14, X0 + 15, Z0 + 13, Z1 - 13, 24, [[-24, -12]]);
  railRun('FD_L24_RailE', 'z', X1 - 15, X1 - 14, Z0 + 13, Z1 - 13, 24, [[-28, -16]]);
  railRun('FD_L48_RailN', 'x', Z0 + 13, Z0 + 14, X0 + 14, X1 - 14, 48, [[612, 624]]);
  railRun('FD_L48_RailS', 'x', Z1 - 14, Z1 - 13, X0 + 14, X1 - 14, 48, [[640, 652]]);
  railRun('FD_L48_RailW', 'z', X0 + 14, X0 + 15, Z0 + 13, Z1 - 13, 48, []);
  railRun('FD_L48_RailE', 'z', X1 - 15, X1 - 14, Z0 + 13, Z1 - 13, 48, []);
  // Y72 ledges + gantries
  box(g, 'FD_L72_W', 'Floor', [X0, 70, Z0], [X0 + 14, 72, Z1], 'DiamondPlate', C.floor);
  box(g, 'FD_L72_E', 'Floor', [X1 - 14, 70, Z0], [X1, 72, Z1], 'DiamondPlate', C.floor);
  box(g, 'FD_L72_S', 'Floor', [X0 + 14, 70, Z1 - 14], [X1 - 14, 72, Z1], 'DiamondPlate', C.floor);
  railRun('FD_L72_RailW', 'z', X0 + 14, X0 + 15, Z0, Z1 - 14, 72, [[-75, -63], [23, 35]]);
  railRun('FD_L72_RailE', 'z', X1 - 15, X1 - 14, Z0, Z1 - 14, 72, [[-75, -63], [23, 35]]);
  railRun('FD_L72_RailS', 'x', Z1 - 15, Z1 - 14, X0 + 15, X1 - 15, 72, [[576, 588]]);
  for (const [nm, z0] of [['G1', -75], ['G2', 23]]) {
    box(g, `FD_Gantry${nm}`, 'Floor', [X0 + 14, 70, z0], [X1 - 14, 72, z0 + 12], 'DiamondPlate', C.floor);
    box(g, `FD_Gantry${nm}_RailN`, 'Rail', [X0 + 15, 72, z0], [X1 - 15, 76, z0 + 1], 'Metal', C.rail);
    box(g, `FD_Gantry${nm}_RailS`, 'Rail', [X0 + 15, 72, z0 + 11], [X1 - 15, 76, z0 + 12], 'Metal', C.rail);
    box(g, `FD_Gantry${nm}_Glow`, 'Decor', [X0 + 14, 69.4, z0 + 5.8], [X1 - 14, 70, z0 + 6.2], 'Neon', C.cyan);
  }
  // ramps
  ramp(g, 'FD_R0a', [530, 0, 40], [530, 24, -12], 12, 'DiamondPlate', C.floor, { rails: [-1, 1], railFoot: 14 });
  box(g, 'FD_R0a_Landing', 'Floor', [524, 22, -24], [536, 24, -12], 'DiamondPlate', C.floor);
  box(g, 'FD_R0a_LandingRail', 'Rail', [535, 24, -24], [536, 28, -12], 'Metal', C.rail);
  box(g, 'FD_R0a_LandingRailN', 'Rail', [524, 24, -24], [536, 28, -23], 'Metal', C.rail);
  ramp(g, 'FD_R0b', [670, 0, -80], [670, 24, -28], 12, 'DiamondPlate', C.floor, { rails: [-1, 1], railFoot: 14 });
  box(g, 'FD_R0b_Landing', 'Floor', [664, 22, -28], [676, 24, -16], 'DiamondPlate', C.floor);
  box(g, 'FD_R0b_LandingRail', 'Rail', [664, 24, -28], [665, 28, -16], 'Metal', C.rail);
  box(g, 'FD_R0b_LandingRailS', 'Rail', [664, 24, -17], [676, 28, -16], 'Metal', C.rail);
  ramp(g, 'FD_R1', [560, 24, -90], [612, 48, -90], 12, 'DiamondPlate', C.floor, { rails: [-1, 1] });
  box(g, 'FD_R1_LandingLow', 'Floor', [548, 22, -96], [560, 24, -84], 'DiamondPlate', C.floor);
  box(g, 'FD_R1_LandingLowRail', 'Rail', [548, 24, -85], [560, 28, -84], 'Metal', C.rail);
  box(g, 'FD_R1_LandingLowRailW', 'Rail', [548, 24, -96], [549, 28, -85], 'Metal', C.rail);
  box(g, 'FD_R1_LandingHigh', 'Floor', [612, 46, -96], [624, 48, -84], 'DiamondPlate', C.floor);
  box(g, 'FD_R1_LandingHighRail', 'Rail', [612, 48, -85], [624, 52, -84], 'Metal', C.rail);
  box(g, 'FD_R1_LandingHighRailE', 'Rail', [623, 48, -96], [624, 52, -85], 'Metal', C.rail);
  ramp(g, 'FD_R2', [640, 48, 50], [588, 72, 50], 12, 'DiamondPlate', C.floor, { rails: [-1, 1] });
  box(g, 'FD_R2_LandingLow', 'Floor', [640, 46, 44], [652, 48, 56], 'DiamondPlate', C.floor);
  box(g, 'FD_R2_LandingLowRail', 'Rail', [640, 48, 44], [652, 52, 45], 'Metal', C.rail);
  box(g, 'FD_R2_LandingLowRailE', 'Rail', [651, 48, 45], [652, 52, 56], 'Metal', C.rail);
  box(g, 'FD_R2_LandingHigh', 'Floor', [576, 70, 44], [588, 72, 56], 'DiamondPlate', C.floor);
  box(g, 'FD_R2_LandingHighRail', 'Rail', [576, 72, 44], [588, 76, 45], 'Metal', C.rail);
  box(g, 'FD_R2_LandingHighRailW', 'Rail', [576, 72, 45], [577, 76, 56], 'Metal', C.rail);
  // v8 gallery stair: the south door threshold drops straight to the floor (elevated route ~15 s shorter)
  ramp(g, 'FD_R3', [620, 0, 4], [620, 24, 56], 12, 'DiamondPlate', C.floor, { rails: [-1, 1], railFoot: 14 });
  box(g, 'FD_R3_Glow', 'Decor', [614, 21.6, 55.6], [626, 22, 56], 'Neon', C.violet);
  // v8 entry landmark: crane gate over the west door + twin cooling stacks on the north side
  for (const [nm, z0] of [['N', -42], ['S', -4]]) {
    box(gl, `FD_CranePost${nm}`, 'Decor', [494, -60, z0], [500, 62, z0 + 6], 'Metal', C.plateDark, { shadow: true });
    box(gl, `FD_CranePost${nm}_Strip`, 'Decor', [493.6, 2, z0 + 2], [494, 58, z0 + 4], 'Neon', C.violet);
  }
  box(gl, 'FD_CraneBeam', 'Decor', [490, 62, -46], [504, 70, 6], 'Metal', C.trim, { shadow: true });
  sign(gl, 'FD_CraneSign', [489.6, 63, -40], [490, 69, 0], 'Left', 'FOUNDRY  E-03');
  box(gl, 'FD_CraneHook', 'Decor', [495, 46, -23], [499, 54, -17], 'Metal', C.plateDark, { shadow: true });
  box(gl, 'FD_CraneCable', 'Decor', [496.6, 54, -20.4], [497.4, 62, -19.6], 'Metal', C.rail);
  for (const [i, x] of [[1, 555], [2, 645]]) {
    cylY(gl, `FD_Stack${i}`, 'Decor', x, -150, -90, 200, 22, 'Metal', C.plateDark, { shadow: true });
    cylY(gl, `FD_StackBand${i}`, 'Decor', x, -150, 150, 153, 23.2, 'Neon', i === 1 ? C.cyan : C.violet);
    cylY(gl, `FD_StackCap${i}`, 'Decor', x, -150, 200, 203, 25, 'Metal', C.trim);
  }
  // furnace (collidable base) + chimney landmark
  cylY(g, 'FD_FurnaceBase', 'Cover', cx, cz, 0, 22, 36, 'Metal', C.plateDark);
  cylY(g, 'FD_FurnaceVent', 'Decor', cx, cz, 10, 13, 36.6, 'Neon', C.cyan, { tr: 0.15, light: { range: 50, brightness: 1.5, color: [190, 240, 255] } });
  cylY(gl, 'FD_Chimney', 'Decor', cx, cz, 22, 262, 28, 'Metal', C.plateDark, { shadow: true });
  for (const [i, y] of [[1, 60], [2, 120], [3, 180], [4, 240]]) cylY(gl, `FD_ChimneyBand${i}`, 'Decor', cx, cz, y, y + 2, 29.6, 'Neon', i % 2 ? C.violet : C.cyan);
  cylY(gl, 'FD_ChimneyCap', 'Decor', cx, cz, 262, 266, 34, 'Metal', C.trim, { light: { range: 60, brightness: 2, color: [160, 120, 255] } });
  // floor cover crates
  for (const [i, x, z] of [[1, 555, -55], [2, 645, -55], [3, 555, 15], [4, 645, 15], [5, 600, 45]]) {
    box(g, `FD_Crate${i}`, 'Cover', [x - 4, 0, z - 4], [x + 4, 6, z + 4], 'Metal', C.cover);
  }
  // roof girders (decor) + exterior buttresses + lights
  for (const [i, z] of [[1, -80], [3, 40]]) box(g, `FD_RoofGirder${i}`, 'Decor', [X0 - 4, 118, z - 2], [X1 + 4, 124, z + 2], 'Metal', C.plateDark, { shadow: true });
  box(g, 'FD_RoofRimN', 'Decor', [X0 - 4, 120, Z0 - 4], [X1 + 4, 124, Z0], 'Metal', C.trim);
  box(g, 'FD_RoofRimS', 'Decor', [X0 - 4, 120, Z1], [X1 + 4, 124, Z1 + 4], 'Metal', C.trim);
  box(g, 'FD_RimGlowN', 'Decor', [X0, 119.4, Z0 - 0.4], [X1, 120, Z0], 'Neon', C.cyan);
  box(g, 'FD_RimGlowS', 'Decor', [X0, 119.4, Z1], [X1, 120, Z1 + 0.4], 'Neon', C.cyan);
  let bk = 0;
  for (const z of [-90, -45, 0, 45]) { bk++; box(g, `FD_ButtressE${bk}`, 'Decor', [X1 + 4, -90, z - 3], [X1 + 9, 126, z + 3], 'Concrete', C.charcoal, { shadow: true }); }
  for (const x of [530, 600, 670]) { bk++; box(g, `FD_ButtressN${bk}`, 'Decor', [x - 3, -90, Z0 - 9], [x + 3, 126, Z0 - 4], 'Concrete', C.charcoal, { shadow: true }); }
  for (const [i, x, z] of [[1, 545, -69], [2, 655, -69], [3, 545, 29], [4, 655, 29]]) {
    // v10: lamps hang from the Y70 gantries at Y40 (at Y100 the floor was outside PointLight range 60)
    box(g, `FD_Lamp${i}`, 'Decor', [x - 2.5, 40, z - 2.5], [x + 2.5, 41, z + 2.5], 'Neon', C.white, { shadow: false, light: { range: 60, brightness: 2.2, color: [215, 240, 255] } });
    box(g, `FD_LampRod${i}`, 'Decor', [x - 0.4, 41, z - 0.4], [x + 0.4, 70, z + 0.4], 'Metal', C.trim, { shadow: false });
  }
  box(g, 'FD_BandW1', 'Decor', [509.8, 12, -110], [510.2, 12.6, -31], 'Neon', C.cyanSoft, { shadow: false });
  box(g, 'FD_BandW2', 'Decor', [509.8, 12, -9], [510.2, 12.6, 70], 'Neon', C.cyanSoft, { shadow: false });
  box(g, 'FD_BandE', 'Decor', [689.8, 12, -110], [690.2, 12.6, 70], 'Neon', C.cyanSoft, { shadow: false });
  box(g, 'FD_BandN', 'Decor', [512, 12, -110.2], [688, 12.6, -109.8], 'Neon', C.cyanSoft, { shadow: false });
  // objective: Control Gallery deck (Y24) south of the shaft, threshold through the south door
  box(g, 'FD_Threshold', 'Floor', [580, 22, Z1], [620, 24, Z1 + 4], 'DiamondPlate', C.floor);
  box(g, 'FD_Gallery_Floor', 'Floor', [540, 22, Z1 + 4], [660, 24, 124], 'DiamondPlate', C.floor, { attrs: { Map1Space: 'Objective_ControlGallery' } });
  box(g, 'FD_Gallery_Base', 'Decor', [538, -60, Z1 + 4], [662, 22, 126], 'Concrete', C.charcoal, { shadow: true });
  box(g, 'FD_Gallery_RailS', 'Rail', [540, 24, 123], [660, 28, 124], 'Metal', C.rail);
  box(g, 'FD_Gallery_RailE', 'Rail', [659, 24, Z1 + 4], [660, 28, 123], 'Metal', C.rail);
  box(g, 'FD_Gallery_RailW1', 'Rail', [540, 24, Z1 + 4], [541, 28, 83], 'Metal', C.rail);
  box(g, 'FD_Gallery_RailW2', 'Rail', [540, 24, 97], [541, 28, 123], 'Metal', C.rail);
  for (const [i, x] of [[1, 570], [2, 630]]) {
    box(g, `FD_Console${i}`, 'Cover', [x - 6, 24, 104], [x + 6, 28, 110], 'Metal', C.cover);
    box(g, `FD_Console${i}_Screen`, 'Decor', [x - 5, 28, 106.8], [x + 5, 31, 107.2], 'Neon', C.cyanSoft);
  }
  box(g, 'FD_Gallery_Canopy', 'Decor', [540, 44, 96], [660, 46, 124], 'Metal', C.plateDark, { shadow: true });
  box(g, 'FD_Gallery_CanopyGlow', 'Decor', [540, 43.6, 110], [660, 44, 110.6], 'Neon', C.cyan, { light: { range: 40, brightness: 1.2, color: [170, 230, 255] } });
  box(g, 'BossSector_Foundry_Bounds', 'Bounds', [X0, 0, Z0], [X1, 120, Z1], 'SmoothPlastic', C.white, { tr: 1, coll: false, attrs: { FloorY: 0, BossSector: S } });
  layoutExtra.landmarks.push({ sector: S, name: 'Furnace chimney (dia 28, to Y266) with violet/cyan bands', pos: [cx, 0, cz] });
}

// =================================================================== v9 proposed marker placeholders
// NOT gameplay markers: no CollectionService tags (real tags would change ArenaService's exact marker
// counts and boot the game Degraded). Invisible, non-collidable, CanQuery off; attribute ProposedMarkerTag
// names the tag each would become once the map-contract prerequisite (Agent C's checklist) is approved.
const PROPOSED = [];
{
  const M = {
    ContainmentVault: [
      ['SupplyLandingPoint', 40, 0, -445, 4], ['FragmentSpawn', -60, 0, -460, 2], ['FragmentSpawn', -72, 24, -600, 2], ['FragmentSpawn', 72, 24, -600, 2],
      ['CorruptionNode', -50, 0, -600, 3], ['CorruptionNode', 50, 0, -655, 3], ['DroneWaypoint', 0, 30, -462, 2], ['DroneWaypoint', 0, 40, -560, 2],
      ['DecayTile', 24, 0, -432, 6], ['DecayTile', 34, 0, -432, 6], ['DecayTile', 44, 0, -432, 6], ['DecayTile', 24, 0, -442, 6],
    ],
    TestingPit: [
      ['SupplyLandingPoint', -800, 0, 44, 4], ['FragmentSpawn', -620, 0, -112, 2], ['FragmentSpawn', -620, 0, 176, 2], ['FragmentSpawn', -724, -12, 32, 2],
      ['CorruptionNode', -580, -24, 80, 3], ['CorruptionNode', -660, -24, -16, 3], ['DroneWaypoint', -620, 45, -60, 2], ['DroneWaypoint', -620, 45, 124, 2],
      ['DecayTile', -640, 0, 176, 6], ['DecayTile', -630, 0, 176, 6], ['DecayTile', -610, 0, 176, 6], ['DecayTile', -600, 0, 176, 6],
    ],
    Foundry: [
      ['SupplyLandingPoint', 620, 24, 84, 4], ['FragmentSpawn', 600, 48, -103, 2], ['FragmentSpawn', 517, 72, -20, 2], ['FragmentSpawn', 650, 0, -80, 2],
      ['CorruptionNode', 565, 0, 45, 3], ['CorruptionNode', 650, 0, -30, 3], ['DroneWaypoint', 600, 60, -60, 2], ['DroneWaypoint', 560, 90, 30, 2],
      ['DecayTile', 683, 24, -70, 6], ['DecayTile', 683, 24, -60, 6], ['DecayTile', 683, 24, -50, 6], ['DecayTile', 683, 24, -40, 6],
    ],
  };
  for (const S of Object.keys(M)) {
    const g = grp(S + '_ProposedMarkers', S, 'Folder', null, 'ProposedMarkers');
    const n = {};
    for (const [tag, x, y, z, w] of M[S]) {
      n[tag] = (n[tag] || 0) + 1;
      const nm = `PM_${S}_${tag}${n[tag]}`;
      box(g, nm, 'ProposedMarker', [x - w / 2, y, z - w / 2], [x + w / 2, y + 0.4, z + w / 2], 'SmoothPlastic', C.white,
        { tr: 1, coll: false, shadow: false, attrs: { ProposedMarkerTag: tag, ProposedStatus: 'proposed, not active (needs the map-contract prerequisite)' } });
      PROPOSED.push({ sector: S, tag, pos: [x, y, z] });
    }
  }
}

// =================================================================== Backdrop (calm exterior)
{
  const g = grp('Backdrop', 'Backdrop', 'Model', 'Persistent');
  // outer foundation plane around the existing abyss floor (|x|,|z| <= 550)
  for (const [nm, a, b] of [
    ['N1', [-1700, -1700], [0, -550]], ['N2', [0, -1700], [1700, -550]], ['S1', [-1700, 550], [0, 1700]], ['S2', [0, 550], [1700, 1700]],
    ['W', [-1700, -550], [-550, 550]], ['E', [550, -550], [1700, 550]],
  ]) box(g, `BD_Foundation${nm}`, 'Decor', [a[0], -94, a[1]], [b[0], -92, b[1]], 'Concrete', C.plateDark);
  // grid lines on the foundation (sparse; split at the origin to stay under the 2048 size limit)
  for (const v of [-1200, -900, 900, 1200]) for (const [h, a, b] of [['a', -1700, 0], ['b', 0, 1700]]) {
    box(g, `BD_GridX${v}${h}`, 'Decor', [a, -92, v - 1], [b, -91.8, v + 1], 'Neon', C.cyan, { tr: 0.75 });
    box(g, `BD_GridZ${v}${h}`, 'Decor', [v - 1, -92, a], [v + 1, -91.8, b], 'Neon', C.cyan, { tr: 0.75 });
  }
  // distant facility towers (deterministic pseudo-random)
  let seed = 7;
  const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  for (let k = 0; k < 22; k++) {
    const deg = k * (360 / 22) + rnd() * 8;
    const th = deg * Math.PI / 180;
    const r = 1150 + rnd() * 350;
    const w = 60 + Math.floor(rnd() * 70), d = 50 + Math.floor(rnd() * 50), h = 260 + Math.floor(rnd() * 360);
    const x = Math.round(r * Math.cos(th)), z = Math.round(r * Math.sin(th));
    box(g, `BD_Tower${k + 1}`, 'Decor', [x - w / 2, -92, z - d / 2], [x + w / 2, h, z + d / 2], 'Metal', k % 3 === 0 ? C.plate : C.plateDark, { shadow: false });
    box(g, `BD_Tower${k + 1}_Strip`, 'Decor', [x - 2, -40, z - d / 2 - 0.6], [x + 2, h - 10, z + d / 2 + 0.6], 'Neon', k % 5 === 2 ? C.violet : C.cyan, { tr: 0.15 });
    box(g, `BD_Tower${k + 1}_Cap`, 'Decor', [x - w / 2 - 4, h, z - d / 2 - 4], [x + w / 2 + 4, h + 8, z + d / 2 + 4], 'Metal', C.trim);
  }
  // horizon wall ring (low skyline band)
  const HN = 16, HR = 1900;
  for (let k = 0; k < HN; k++) {
    const th = (k + 0.5) * 2 * Math.PI / HN;
    ringSeg(g, `BD_Horizon${k + 1}`, 'Decor', 0, 0, HR - 40, HR, th, HN, -92, 60 + (k % 3) * 25, 'Concrete', C.plateDark, { shadow: false });
    ringStrip(g, `BD_HorizonGlow${k + 1}`, 'Decor', 0, 0, HR - 40.5, th, HN, 40 + (k % 3) * 25, 42 + (k % 3) * 25, 0.6, 'Neon', C.cyan, { tr: 0.3 });
  }
}

// ---------------------------------------------------------------- uniqueness + stats
const names = new Set();
for (const r of rows) { if (names.has(r.name)) throw new Error('dup name ' + r.name); names.add(r.name); }
const stats = {};
for (const r of rows) {
  const s = containers[r.grp].sector;
  stats[s] = stats[s] || { parts: 0, collidable: 0, lights: 0 };
  stats[s].parts++; if (r.coll) stats[s].collidable++; if (r.light) stats[s].lights++;
}
const total = { parts: rows.length, collidable: rows.filter((r) => r.coll).length, lights: rows.filter((r) => r.light).length };

// ---------------------------------------------------------------- bounds (playable extents + margin)
let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
for (const r of rows) if (r.coll) {
  // conservative AABB of the OBB
  const h = [r.size[0] / 2, r.size[1] / 2, r.size[2] / 2], R = r.rot;
  const e = [0, 1, 2].map((i) => Math.abs(R[i * 3]) * h[0] + Math.abs(R[i * 3 + 1]) * h[1] + Math.abs(R[i * 3 + 2]) * h[2]);
  for (let i = 0; i < 3; i++) { mn[i] = Math.min(mn[i], r.pos[i] - e[i]); mx[i] = Math.max(mx[i], r.pos[i] + e[i]); }
}
const BOUNDS_BEFORE = { min: [-275, -40, -275], max: [275, 160, 275] };
const BOUNDS_AFTER = {
  min: [Math.floor((Math.min(mn[0], -275) - 10) / 5) * 5, -40, Math.floor((Math.min(mn[2], -275) - 10) / 5) * 5],
  max: [Math.ceil((Math.max(mx[0], 275) + 10) / 5) * 5, 160, 275],
};

// ---------------------------------------------------------------- Luau emit
const q = (s) => JSON.stringify(s);
const num = (v) => (Number.isInteger(v) ? String(v) : String(v));
function luaVal(v) {
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'number') return num(v);
  if (typeof v === 'string') return q(v);
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (Array.isArray(v)) return '{' + v.map(luaVal).join(',') + '}';
  return '{' + Object.keys(v).sort().map((k) => `${k}=${luaVal(v[k])}`).join(',') + '}';
}
const rowLines = rows.map((r) => '\t' + luaVal([r.name, r.grp, r.role, r.size, r.pos, r.rot, r.mat, r.color, r.tr, r.coll, r.shape, r.shadow,
  { boss: r.boss, light: r.light, attrs: r.attrs, sign: r.sign }]) + ',');
const contLines = Object.keys(containers).sort().map((k) => `\t[${q(k)}] = ${luaVal(containers[k])},`);
const spec = [
  `local VERSION = ${q(VERSION)}`,
  `local ROWS = {\n${rowLines.join('\n')}\n}`,
  `local CONTAINERS = {\n${contLines.join('\n')}\n}`,
  `local CUTS = ${luaVal(CUTS.map((c) => ({ name: c.name, min: c.min, max: c.max })))}`,
  `local ISOLATE = ${luaVal(ISOLATE)}`,
  `local EXPECT = ${luaVal(total)}`,
].join('\n');
const tpl = fs.readFileSync(path.join(HERE, 'build_expansion_template.luau'), 'utf8');
if (!tpl.includes('--@@SPEC@@')) throw new Error('template marker missing');
fs.writeFileSync(path.join(HERE, '1_build_expansion.luau'), tpl.replace('--@@SPEC@@', () => spec));

// ---------------------------------------------------------------- LAYOUT.json
function sectorBox(sector) {
  let a = [1e9, 1e9, 1e9], b = [-1e9, -1e9, -1e9];
  for (const r of rows) if (containers[r.grp].sector === sector && (r.coll)) {
    const h = [r.size[0] / 2, r.size[1] / 2, r.size[2] / 2], R = r.rot;
    const e = [0, 1, 2].map((i) => Math.abs(R[i * 3]) * h[0] + Math.abs(R[i * 3 + 1]) * h[1] + Math.abs(R[i * 3 + 2]) * h[2]);
    for (let i = 0; i < 3; i++) { a[i] = Math.min(a[i], r.pos[i] - e[i]); b[i] = Math.max(b[i], r.pos[i] + e[i]); }
  }
  return { min: a.map(Math.round), max: b.map(Math.round) };
}
const bossRow = (s) => rows.find((r) => r.name === `BossSector_${s}_Bounds`);
const sectors = [
  { name: 'Hub', role: 'hub', centre: [0, 0, 0], bounds: { min: [-260, -14, -260], max: [260, 72, 260] }, floorY: [0, 24, 48, 72],
    note: 'Existing hall (CentralCore/Reactor, ResearchYard W, Skybridge E, DataArchive N, CoolantReservoir S, OuterRing Y24). Unchanged except openings listed in CHANGED_OBJECTS.md.' },
];
const desc = {
  ContainmentVault: { dir: 'N', shape: 'long containment vault hall 160x204 with Y24 balconies (16 wide), north dais (Y6), 4 pods + 2 barriers, skylight roof Y96', objective: 'Vault Antechamber forecourt X-90..90 Z-496..-420 (Y0) with terminals; ramp to the Y24 bridge' },
  TestingPit: { dir: 'W', shape: 'circular testing pit: floor r72 at Y-24, tiers C/B/A at Y-18/-12/-6, rim r136-152 at Y0, aisle ramps at 45/135/225/315 deg, Y24 gantry across', objective: 'Test Control deck X-834..-766 Z0..64 (Y0) beyond the west rim' },
  Foundry: { dir: 'E', shape: 'vertical foundry shaft 180x180, furnace base dia 36 (Y0-22), catwalk rings Y24/Y48 (14 wide), Y72 ledges + 2 gantries, 4 ramps', objective: 'Control Gallery deck X540..660 Z74..124 (Y24) through the south wall door' },
};
for (const s of ['ContainmentVault', 'TestingPit', 'Foundry']) {
  const b = bossRow(s);
  const half = b.size.map((v) => v / 2);
  sectors.push({
    name: s, role: 'boss', direction: desc[s].dir,
    centre: [b.pos[0], b.attrs.FloorY, b.pos[2]],
    distanceFromReactor: Math.round(Math.hypot(b.pos[0], b.pos[2])),
    encounterBounds: { min: b.pos.map((v, i) => Math.round(v - half[i])), max: b.pos.map((v, i) => Math.round(v + half[i])) },
    encounterSize: [b.size[0], b.size[2]],
    floorY: b.attrs.FloorY,
    sectorBounds: sectorBox(s),
    shape: desc[s].shape,
    objective: desc[s].objective,
    boundsPart: `Workspace.WORLD_EXE.Map.Map1Expansion.${s}.BossSector_${s}_Bounds`,
  });
}
const layout = {
  map: 'Map1 Stable Simulation', version: VERSION, units: 'Roblox studs, Y up, reactor at origin',
  agent: 'A', generatedBy: 'tools/studio/map1/gen_expansion.js', generated: new Date().toISOString(),
  movement: { walkSpeed: 16, jumpHeight: 7.2, jumpRule: 'rise <= 6.5, gap <= 6' },
  sectors, routes,
  landmarks: layoutExtra.landmarks,
  proposedMarkers: { status: 'proposed, not active: untagged placeholders under Map1Expansion.<Wing>.ProposedMarkers (attribute ProposedMarkerTag); needs the map-contract prerequisite from Agent C', list: PROPOSED },
  bounds: { before: BOUNDS_BEFORE, after: BOUNDS_AFTER, outOfBoundsY: -60, note: 'Working copy only: Config ModuleScript edited in Studio; src/ unchanged.' },
  parts: { total, bySector: stats },
  measured: fs.existsSync(path.join(NOTES, 'measured.json')) ? JSON.parse(fs.readFileSync(path.join(NOTES, 'measured.json'), 'utf8')) : null,
};
fs.mkdirSync(NOTES, { recursive: true });
fs.writeFileSync(path.join(NOTES, 'LAYOUT.json'), JSON.stringify(layout, null, 2));

// ---------------------------------------------------------------- SVG plan (top-down, X right, -Z up = north up)
{
  const W0 = -900, W1 = 760, H0 = -820, H1 = 330; // world X range, world Z range
  const sc = 0.62, pad = 40;
  const Wd = (W1 - W0) * sc + 2 * pad, Hd = (H1 - H0) * sc + 2 * pad + 60;
  const X = (x) => pad + (x - W0) * sc, Y = (z) => pad + (z - H0) * sc;
  const out = [];
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${Math.round(Wd)}" height="${Math.round(Hd)}" viewBox="0 0 ${Math.round(Wd)} ${Math.round(Hd)}" font-family="Segoe UI, Arial" font-size="11">`);
  out.push(`<rect width="100%" height="100%" fill="#0d1226"/>`);
  // grid
  for (let v = -800; v <= 800; v += 100) {
    if (v >= W0 && v <= W1) out.push(`<line x1="${X(v)}" y1="${Y(H0)}" x2="${X(v)}" y2="${Y(H1)}" stroke="#1b2446" stroke-width="1"/><text x="${X(v) + 2}" y="${Y(H1) + 12}" fill="#4a5a8a">${v}</text>`);
    if (v >= H0 && v <= H1) out.push(`<line x1="${X(W0)}" y1="${Y(v)}" x2="${X(W1)}" y2="${Y(v)}" stroke="#1b2446" stroke-width="1"/><text x="${X(W0) + 2}" y="${Y(v) - 2}" fill="#4a5a8a">${v}</text>`);
  }
  // bounds
  const rect = (a, b, st, fill, dash, sw = 1.5) => `<rect x="${X(Math.min(a[0], b[0]))}" y="${Y(Math.min(a[2], b[2]))}" width="${Math.abs(b[0] - a[0]) * sc}" height="${Math.abs(b[2] - a[2]) * sc}" fill="${fill}" stroke="${st}" stroke-width="${sw}" ${dash ? 'stroke-dasharray="6 4"' : ''}/>`;
  out.push(rect(BOUNDS_AFTER.min, BOUNDS_AFTER.max, '#ffb35a', 'none', true));
  out.push(rect(BOUNDS_BEFORE.min, BOUNDS_BEFORE.max, '#ff6b6b', 'none', true));
  out.push(rect([-414, 0, -414], [414, 0, 414], '#3a4a80', 'none', false, 3)); // hall wall
  out.push(rect([-260, 0, -260], [260, 0, 260], '#5a6ab0', '#18204a', false));
  // footprints of collidable floors (flat projection)
  const roleCol = { Floor: '#4f63a8', Ramp: '#7b8fd8', Cover: '#8a96c0', Wall: '#2a3566', Rail: '#a8b6e8' };
  for (const r of rows) if (r.coll && roleCol[r.role]) {
    const h = [r.size[0] / 2, r.size[1] / 2, r.size[2] / 2], R = r.rot;
    // projected corners of the OBB on XZ (use the 4 corners of the face spanned by the two most horizontal axes)
    const ax = [[R[0], R[3], R[6]], [R[1], R[4], R[7]], [R[2], R[5], R[8]]];
    const idx = [0, 1, 2].sort((a, b) => Math.abs(ax[a][1]) - Math.abs(ax[b][1])).slice(0, 2);
    const u = mul(ax[idx[0]], h[idx[0]]), v = mul(ax[idx[1]], h[idx[1]]);
    const pts = [[1, 1], [1, -1], [-1, -1], [-1, 1]].map(([a, b]) => { const p = add(add(r.pos, mul(u, a)), mul(v, b)); return `${X(p[0]).toFixed(1)},${Y(p[2]).toFixed(1)}`; });
    out.push(`<polygon points="${pts.join(' ')}" fill="${roleCol[r.role]}" fill-opacity="${r.role === 'Floor' ? 0.55 : 0.8}" stroke="none"/>`);
  }
  // boss encounter bounds + labels
  for (const s of sectors.filter((s) => s.role === 'boss')) {
    out.push(rect(s.encounterBounds.min, s.encounterBounds.max, '#00e1ff', 'none', false, 2));
    out.push(`<text x="${X(s.encounterBounds.min[0])}" y="${Y(s.encounterBounds.min[2]) - 6}" fill="#00e1ff" font-size="13" font-weight="bold">${s.name} (boss) ${s.encounterSize[0]}x${s.encounterSize[1]}, floor Y${s.floorY}</text>`);
  }
  // routes
  const rc = { 0: '#7dffb0', 24: '#ff9df5' };
  for (const r of routes) {
    const pts = r.waypoints.map((p) => `${X(p[0]).toFixed(1)},${Y(p[2]).toFixed(1)}`).join(' ');
    out.push(`<polyline points="${pts}" fill="none" stroke="${rc[r.level]}" stroke-width="2" stroke-dasharray="${r.level ? '5 3' : ''}"/>`);
  }
  out.push(`<text x="${X(0) - 16}" y="${Y(0) + 4}" fill="#ffffff" font-size="13" font-weight="bold">HUB</text>`);
  out.push(`<circle cx="${X(0)}" cy="${Y(0)}" r="4" fill="#00e1ff"/>`);
  // legend
  const ly = Y(H1) + 30;
  const leg = [['#7dffb0', 'ground route (Y0)'], ['#ff9df5', 'elevated route (Y24)'], ['#00e1ff', 'boss encounter bounds'], ['#ffb35a', 'new ArenaBounds (working copy)'], ['#ff6b6b', 'old ArenaBounds'], ['#3a4a80', 'hall wall (±414)']];
  leg.forEach(([c, t], i) => { out.push(`<rect x="${pad + i * 180}" y="${ly - 9}" width="14" height="10" fill="${c}"/><text x="${pad + i * 180 + 18}" y="${ly}" fill="#c8d2f0">${t}</text>`); });
  out.push(`<text x="${pad}" y="${ly + 20}" fill="#c8d2f0">WORLD.EXE Map 1 Stable Simulation expansion plan (${VERSION}). North (-Z) up, X right. Grid 100 studs. Generated from LAYOUT.json/spec.</text>`);
  out.push('</svg>');
  fs.writeFileSync(path.join(NOTES, 'layout_plan.svg'), out.join('\n'));
}

console.log(JSON.stringify({ total, stats, bounds: BOUNDS_AFTER, playableExtents: { min: mn.map(Math.round), max: mx.map(Math.round) }, cuts: CUTS.length }, null, 1));
