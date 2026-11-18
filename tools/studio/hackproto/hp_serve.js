// Wrist-hacking prototype: local-only (127.0.0.1:8790) file server for the Studio code sync.
//   node tools/studio/hackproto/hp_serve.js            (run from the repo root or anywhere)
// GET /manifest.json      -> [{ path, kind, bytes }] for every src/**/*.luau file
// GET /src/<path>         -> raw file text
// GET /tools/<file>       -> raw text of a file in tools/studio/hackproto
// Nothing is written; nothing listens beyond the loopback interface.
const http = require("http"), fs = require("fs"), path = require("path");
const REPO = path.resolve(__dirname, "..", "..", "..");
const SRC = path.join(REPO, "src"), TOOLS = __dirname;
function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith(".luau")) out.push(p);
  }
  return out;
}
function manifest() {
  return walk(SRC, []).map((p) => {
    const rel = path.relative(SRC, p).split(path.sep).join("/");
    const kind = rel.endsWith(".server.luau") ? "Script" : rel.endsWith(".client.luau") ? "LocalScript" : "ModuleScript";
    return { path: rel, kind, bytes: fs.statSync(p).size };
  });
}
http.createServer((q, r) => {
  const url = decodeURIComponent(q.url.split("?")[0]);
  const send = (code, body, type) => { r.writeHead(code, { "Content-Type": type || "text/plain; charset=utf-8" }); r.end(body); };
  if (url === "/manifest.json") return send(200, JSON.stringify(manifest()), "application/json");
  const m = url.match(/^\/(src|tools)\/(.+)$/);
  if (m) {
    const base = m[1] === "src" ? SRC : TOOLS;
    const p = path.resolve(base, m[2]);
    if (!p.startsWith(base) || !fs.existsSync(p)) return send(404, "not found");
    return send(200, fs.readFileSync(p));
  }
  send(404, "not found");
}).listen(8790, "127.0.0.1", () => console.log("hackproto serve ready 8790 " + SRC));
