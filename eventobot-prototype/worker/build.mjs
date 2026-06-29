// Embeds ../index.html into worker.js at build time
import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dir = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(__dir, '..', 'index.html'), 'utf8');
const escaped = JSON.stringify(html);

const src = `
const HTML = ${escaped};

const REALM = "EventoBot Demo";
// Password is set via environment variable DEMO_PASS (wrangler secret)
function basicAuthResponse() {
  return new Response("Требуется авторизация", {
    status: 401,
    headers: { "WWW-Authenticate": \`Basic realm="\${REALM}"\` },
  });
}

export default {
  async fetch(request, env) {
    const password = env.DEMO_PASS;
    if (!password) return new Response("DEMO_PASS secret not configured", { status: 500 });

    const authHeader = request.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Basic ")) return basicAuthResponse();

    const [user, pass] = atob(authHeader.slice(6)).split(":");
    if (pass !== password) return basicAuthResponse();

    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "/index.html" || url.pathname === "") {
      return new Response(HTML, {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }
    return new Response("Not found", { status: 404 });
  },
};
`.trimStart();

writeFileSync(join(__dir, 'worker.js'), src, 'utf8');
console.log('worker.js written, HTML size:', html.length, 'bytes');
