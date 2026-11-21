// Core Round Step 1: verify the SAVED .rbxlx (not the open Studio session) against src/**/CoreRound/**.
//   node tools/studio/coreround/cr_40_verify_saved.js <place.rbxlx>
// For every CoreRound .luau file a script of the same class and name must exist in the file with an
// identical Source (line endings normalised). Also lists scripts in the place that are NOT from the
// CoreRound subtree (expected: none) and prints the place SHA-256. Exit code 1 on any mismatch.
const fs = require("fs"), path = require("path"), crypto = require("crypto");
const place = process.argv[2];
const SRC = path.resolve(__dirname, "..", "..", "..", "src");
const raw = fs.readFileSync(place);
const xml = raw.toString("utf8");
const dec = (s) => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&#13;/g, "\r").replace(/&#10;/g, "\n").replace(/&amp;/g, "&");
const scripts = [];
const re = /<Item class="(Script|LocalScript|ModuleScript)"[^>]*>([\s\S]*?)<\/Item>/g;
let m;
while ((m = re.exec(xml))) {
  const body = m[2];
  const name = (body.match(/<string name="Name">([\s\S]*?)<\/string>/) || [])[1];
  let src = (body.match(/<ProtectedString name="Source"><!\[CDATA\[([\s\S]*?)\]\]><\/ProtectedString>/) || [])[1];
  if (src === undefined) src = dec((body.match(/<ProtectedString name="Source">([\s\S]*?)<\/ProtectedString>/) || [, ""])[1]);
  scripts.push({ cls: m[1], name: dec(name || ""), src: src.replace(/\r\n/g, "\n"), used: false });
}
function walk(d, o) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); e.isDirectory() ? walk(p, o) : e.name.endsWith(".luau") && o.push(p); } return o; }
const out = { place: path.basename(place), bytes: raw.length, sha256: crypto.createHash("sha256").update(raw).digest("hex"), checked: 0, ok: 0, failed: [], extraScripts: [] };
for (const p of walk(SRC, [])) {
  const rel = path.relative(SRC, p).split(path.sep).join("/");
  if (!rel.split("/").includes("CoreRound")) continue;
  const cls = rel.endsWith(".server.luau") ? "Script" : rel.endsWith(".client.luau") ? "LocalScript" : "ModuleScript";
  const name = path.basename(rel).replace(/\.server\.luau$|\.client\.luau$|\.luau$/, "");
  const want = fs.readFileSync(p, "utf8").replace(/\r\n/g, "\n");
  out.checked++;
  const hit = scripts.find((s) => !s.used && s.cls === cls && s.name === name && s.src === want);
  if (hit) { hit.used = true; out.ok++; } else out.failed.push(rel);
}
out.extraScripts = scripts.filter((s) => !s.used).map((s) => s.cls + ":" + s.name);
console.log(JSON.stringify(out, null, 1));
process.exit(out.failed.length ? 1 : 0);
