// Petit serveur pour essayer la version web du jeu sur un téléphone du même Wi-Fi.
// Lancer depuis la racine du dépôt :  node tools/serveur_web.js
// puis ouvrir sur le téléphone l'adresse affichée (http://192.168.x.x:8000).
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");

const ROOT = path.join(__dirname, "..", "build", "web");
const PORT = 8000;
const TYPES = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".json": "application/json",
};

http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  const file = path.join(ROOT, url === "/" ? "index.html" : url);
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404);
    return res.end("Introuvable");
  }
  res.writeHead(200, {
    "Content-Type": TYPES[path.extname(file)] || "application/octet-stream",
    "Cache-Control": "no-cache",
  });
  fs.createReadStream(file).pipe(res);
}).listen(PORT, "0.0.0.0", () => {
  const ips = Object.values(os.networkInterfaces()).flat()
    .filter((i) => i && i.family === "IPv4" && !i.internal).map((i) => i.address);
  console.log("Serveur prêt. Sur le téléphone (même Wi-Fi), ouvre :");
  for (const ip of ips) console.log("   http://" + ip + ":" + PORT);
});
