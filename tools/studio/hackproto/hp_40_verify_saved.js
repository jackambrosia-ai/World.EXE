// Wrist-hacking prototype: verify the SAVED .rbxlx (not the open Studio session) against src/.
//   node tools/studio/hackproto/hp_40_verify_saved.js <place.rbxlx>
// For every src/**/*.luau, a script of the same class and name must exist in the file with an
// identical Source (line endings normalised). Prints a JSON summary; exit code 1 on any mismatch.
const fs = require("fs"), path = require("path"), crypto = require("crypto");
const place = process.argv[2];
const SRC = path.resolve(__dirname, "..", "..", "..", "src");
const xml = fs.readFileSync(place, "utf8");
const dec = (s) => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&#13;/g, "\r").replace(/&#10;/g, "\n").replace(/&amp;/g, "&");
const scripts = [];
const re = /<Item class="(Script|LocalScript|ModuleScript)"[^>]*>([\s\S]*?)<\/Item>/g;
let m;
while ((m = re.exec(xml))) {
  const body = m[2];
  const name = (body.match(/<string name="Name">([\s\S]*?)<\/string>/) || [])[1];
  let src = (body.match(/<ProtectedString name="Source"><!\[CDATA\[([\s\S]*?)\]\]><\/ProtectedString>/) || [])[1];
  if (src === undefined) src = dec((body.match(/<ProtectedString name="Source">([\s\S]*?)<\/ProtectedString>/) || [, ""])[1]);
  scripts.push({ cls: m[1], name: dec(name || ""), src: src.replace(/\r\n/g, "\n") });
}
function walk(d, o) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); e.isDirectory() ? walk(p, o) : e.name.endsWith(".luau") && o.push(p); } return o; }
const out = { place: path.basename(place), sha256: crypto.createHash("sha256").update(fs.readFileSync(place)).digest("hex"), checked: 0, ok: 0, failed: [] };
for (const p of walk(SRC, [])) {
  const rel = path.relative(SRC, p).split(path.sep).join("/");
  const cls = rel.endsWith(".server.luau") ? "Script" : rel.endsWith(".client.luau") ? "LocalScript" : "ModuleScript";
  const name = path.basename(rel).replace(/\.server\.luau$|\.client\.luau$|\.luau$/, "");
  const want = fs.readFileSync(p, "utf8").replace(/\r\n/g, "\n");
  out.checked++;
  if (scripts.some((s) => s.cls === cls && s.name === name && s.src === want)) out.ok++; else out.failed.push(rel);
}
console.log(JSON.stringify(out, null, 1));
process.exit(out.failed.length ? 1 : 0);
