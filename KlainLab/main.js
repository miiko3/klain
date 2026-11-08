'use strict';

// Klain Lab — Electron main process.
// Raises a loopback-only HTTP server so the lab shell and every device iframe
// share one origin (no CORS, shared localStorage, working BroadcastChannel).
// API keys never leave this machine except to the provider the user picked.

const { app, BrowserWindow, ipcMain, shell, dialog } = require('electron');
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { Readable } = require('stream');

const ROOT = __dirname;
const APP_DIR = path.join(ROOT, 'app');
const PUBLIC_DIR = ROOT;
const STATE_DIR = app.getPath('userData');
const STATE_FILE = path.join(STATE_DIR, 'state.json');
const TOKEN = crypto.randomBytes(16).toString('hex');

let win = null;
let server = null;
let port = 0;
const reloadClients = new Set();

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
};

const DEFAULT_STATE = {
  version: 1,
  providers: [],
  drafts: [],
  chats: [],
  records: [],
  generatedImages: [],
  selectedChatID: null,
  defaultModel: '',
  imageModel: '',
  imageSize: '1024x1024',
  settings: { reasoning: 'default', webSearch: false },
  theme: {
    accent: '#FC995C',
    accent2: '#ED59A1',
    background: '#0B0B14',
    panel: '#242421',
    radius: 22,
    fontScale: 1,
    density: 1,
    glass: 1,
    dark: true,
  },
  devicePrefs: { zoom: 0.85, rotate: false, showFrame: true, theme: 'dark' },
};

function readState() {
  try {
    if (!fs.existsSync(STATE_FILE)) return { ...DEFAULT_STATE };
    const parsed = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
    return {
      ...DEFAULT_STATE,
      ...parsed,
      theme: { ...DEFAULT_STATE.theme, ...(parsed.theme || {}) },
      settings: { ...DEFAULT_STATE.settings, ...(parsed.settings || {}) },
      devicePrefs: { ...DEFAULT_STATE.devicePrefs, ...(parsed.devicePrefs || {}) },
    };
  } catch (err) {
    console.error('[state] read failed, starting fresh:', err.message);
    return { ...DEFAULT_STATE };
  }
}

function writeState(next) {
  const tmp = STATE_FILE + '.tmp';
  fs.mkdirSync(STATE_DIR, { recursive: true });
  fs.writeFileSync(tmp, JSON.stringify(next), 'utf8');
  fs.renameSync(tmp, STATE_FILE);
}

function sendJSON(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > 40 * 1024 * 1024) {
        reject(new Error('Слишком большой запрос (лимит 40 МБ)'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function authorized(req) {
  const u = new URL(req.url, 'http://127.0.0.1');
  return u.searchParams.get('token') === TOKEN || req.headers['x-lab-token'] === TOKEN;
}

function isSafeUpstream(raw) {
  let u;
  try { u = new URL(raw); } catch { return false; }
  if (u.protocol === 'https:') return true;
  // Allow local OpenAI-compatible servers (Ollama / LM Studio) — an explicit
  // improvement over the iOS client, which required HTTPS everywhere.
  if (u.protocol === 'http:') {
    return ['localhost', '127.0.0.1', '::1', '[::1]'].includes(u.hostname);
  }
  return false;
}

async function handleProxy(req, res) {
  let payload;
  try {
    payload = JSON.parse((await readBody(req)).toString('utf8'));
  } catch (err) {
    return sendJSON(res, 400, { error: 'Некорректный JSON: ' + err.message });
  }

  const { url, method = 'GET', headers = {}, body = null, stream = false } = payload;
  if (typeof url !== 'string' || !isSafeUpstream(url)) {
    return sendJSON(res, 400, { error: 'Разрешены только HTTPS-адреса и локальные http://localhost.' });
  }

  const controller = new AbortController();
  req.on('close', () => controller.abort());

  // Strip hop-by-hop and browser-only headers before forwarding.
  const outHeaders = {};
  for (const [k, v] of Object.entries(headers)) {
    const lower = k.toLowerCase();
    if (['host', 'connection', 'content-length', 'origin', 'referer', 'accept-encoding', 'cookie'].includes(lower)) continue;
    if (typeof v === 'string' && !/[\r\n]/.test(v)) outHeaders[k] = v;
  }

  let upstream;
  try {
    upstream = await fetch(url, {
      method,
      headers: outHeaders,
      body: body == null ? undefined : JSON.stringify(body),
      signal: controller.signal,
      redirect: 'follow',
    });
  } catch (err) {
    if (controller.signal.aborted) return;
    return sendJSON(res, 502, { error: 'Не удалось связаться с провайдером: ' + err.message });
  }

  const contentType = upstream.headers.get('content-type') || 'application/octet-stream';

  // Non-2xx: always hand back a JSON error so the UI can show the API message.
  if (!upstream.ok) {
    let text = '';
    try { text = await upstream.text(); } catch { /* ignore */ }
    let message = text.slice(0, 1200);
    try {
      const j = JSON.parse(text);
      message = (j.error && (j.error.message || j.error)) || j.message || message;
    } catch { /* plain text */ }
    return sendJSON(res, upstream.status, {
      error: message.replace(/sk-[A-Za-z0-9_-]{4,}/g, 'sk-***'),
      status: upstream.status,
    });
  }

  if (stream) {
    res.writeHead(200, {
      'Content-Type': contentType.includes('event-stream') ? 'text/event-stream; charset=utf-8' : contentType,
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    try {
      Readable.fromWeb(upstream.body).pipe(res);
    } catch (err) {
      if (!res.headersSent) sendJSON(res, 502, { error: err.message });
      else res.end();
    }
  } else {
    const buf = Buffer.from(await upstream.arrayBuffer());
    res.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': 'no-store', 'Content-Length': buf.length });
    res.end(buf);
  }
}

function serveStatic(req, res, pathname) {
  let rel = pathname === '/' ? '/index.html' : pathname;
  rel = decodeURIComponent(rel).replace(/\.\./g, '');
  const full = path.join(PUBLIC_DIR, rel);
  if (!full.startsWith(PUBLIC_DIR)) { res.writeHead(403); return res.end(); }
  fs.readFile(full, (err, data) => {
    if (err) { res.writeHead(404); return res.end('Not found: ' + rel); }
    let out = data;
    const ext = path.extname(full).toLowerCase();
    if (ext === '.html') {
      // Replace only the quoted placeholder, NOT the window.__LAB_TOKEN__ name.
      out = Buffer.from(data.toString('utf8').replace(/'__LAB_TOKEN__'/g, "'" + TOKEN + "'"));
    }
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(out);
  });
}

function handleEvents(req, res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.write(': connected\n\n');
  reloadClients.add(res);
  const keep = setInterval(() => { try { res.write(': ping\n\n'); } catch { /* dead */ } }, 20000);
  req.on('close', () => { clearInterval(keep); reloadClients.delete(res); });
}

function broadcastReload(file, scope = 'app') {
  const name = path.basename(file);
  const msg = `event: reload\ndata: ${JSON.stringify({ file: name, scope, at: Date.now() })}\n\n`;
  for (const client of reloadClients) {
    try { client.write(msg); } catch { reloadClients.delete(client); }
  }
}

async function handleRequest(req, res) {
  let pathname;
  try { pathname = new URL(req.url, 'http://127.0.0.1').pathname; }
  catch { res.writeHead(400); return res.end(); }

  // Static assets carry no secrets (the token is injected into HTML by the
  // server itself), so loopback GETs are free. Every /api/* route is gated.
  const pathname0 = pathname;
  const remote = req.socket.remoteAddress;
  if (remote && !['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(remote)) {
    res.writeHead(403); return res.end('Loopback only');
  }
  if (pathname0 === '/api/events') return handleEvents(req, res);
  if (!pathname0.startsWith('/api/')) return serveStatic(req, res, pathname0);
  if (!authorized(req)) { res.writeHead(403); return res.end('Forbidden'); }

  try {
    if (pathname === '/api/state' && req.method === 'GET') return sendJSON(res, 200, readState());

    if (pathname === '/api/state' && req.method === 'PUT') {
      const incoming = JSON.parse((await readBody(req)).toString('utf8'));
      writeState(incoming);
      return sendJSON(res, 200, { ok: true });
    }

    // Partial update. The shell owns theme/inspect/CSS, the app owns chats and
    // providers — merging here prevents either side from clobbering the other.
    if (pathname === '/api/patch' && req.method === 'POST') {
      const patch = JSON.parse((await readBody(req)).toString('utf8'));
      if (!patch || typeof patch !== 'object' || Array.isArray(patch)) {
        return sendJSON(res, 400, { error: 'Ожидается объект' });
      }
      const current = readState();
      const merged = { ...current, ...patch };
      merged.theme = { ...current.theme, ...(patch.theme || {}) };
      writeState(merged);
      return sendJSON(res, 200, { ok: true });
    }

    if (pathname === '/api/proxy' && req.method === 'POST') return await handleProxy(req, res);

    if (pathname === '/api/info' && req.method === 'GET') {
      return sendJSON(res, 200, {
        stateFile: STATE_FILE,
        appDir: APP_DIR,
        electron: process.versions.electron,
        node: process.versions.node,
        chrome: process.versions.chrome,
      });
    }

    if (pathname === '/api/reveal' && req.method === 'POST') {
      shell.showItemInFolder(STATE_FILE);
      return sendJSON(res, 200, { ok: true });
    }

    if (pathname === '/api/open-app-dir' && req.method === 'POST') {
      shell.openPath(APP_DIR);
      return sendJSON(res, 200, { ok: true });
    }

    return serveStatic(req, res, pathname);
  } catch (err) {
    console.error('[http]', err);
    if (!res.headersSent) sendJSON(res, 500, { error: err.message });
    else res.end();
  }
}

function createServer() {
  return new Promise((resolve, reject) => {
    server = http.createServer((req, res) => { handleRequest(req, res).catch((e) => {
      console.error(e);
      if (!res.headersSent) sendJSON(res, 500, { error: e.message });
    }); });
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      port = server.address().port;
      resolve();
    });
  });
}

function startWatching() {
  // app/ files render inside every device iframe — a fast iframe refresh is enough.
  try {
    fs.watch(APP_DIR, { recursive: true }, (_event, filename) => {
      if (!filename) return;
      broadcastReload(filename, 'app');
      if (win && !win.isDestroyed()) win.webContents.send('lab:file-changed', String(filename));
    });
  } catch (err) {
    console.error('[watch] fs.watch(app) failed:', err.message);
  }

  // Root shell files (index.html / shell.js / shell.css / preload) define the
  // window chrome itself, so they need a full window reload, not just iframes.
  const SHELL_FILES = ['index.html', 'shell.js', 'shell.css'];
  try {
    fs.watch(ROOT, (_event, filename) => {
      if (!filename || !SHELL_FILES.includes(String(filename))) return;
      broadcastReload(String(filename), 'shell');
      if (win && !win.isDestroyed()) {
        win.webContents.send('lab:file-changed', String(filename));
        // Give the SSE client a moment, then force a full chrome reload.
        setTimeout(() => { if (win && !win.isDestroyed()) win.webContents.reload(); }, 250);
      }
    });
  } catch (err) {
    console.error('[watch] fs.watch(root) failed:', err.message);
  }
}

async function createWindow() {
  win = new BrowserWindow({
    width: 1680,
    height: 1020,
    minWidth: 1100,
    minHeight: 700,
    title: 'Klain Lab — живые макеты iPhone',
    backgroundColor: '#0a0a0f',
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      preload: path.join(ROOT, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      webSecurity: true,
    },
  });

  win.once('ready-to-show', () => win.show());
  await win.loadURL(`http://127.0.0.1:${port}/?token=${TOKEN}`);
  if (process.env.KLAIN_LAB_DEVTOOLS === '1') win.webContents.openDevTools({ mode: 'detach' });
}

app.whenReady().then(async () => {
  await createServer();
  startWatching();
  await createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
}).catch((err) => {
  console.error(err);
  dialog.showErrorBox('Klain Lab не запустился', String(err && err.stack || err));
  app.quit();
});

app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('before-quit', () => { if (server) server.close(); });

ipcMain.handle('lab:info', () => ({ port, token: TOKEN, stateFile: STATE_FILE, appDir: APP_DIR }));
ipcMain.handle('lab:reload', () => { broadcastReload('manual'); return true; });
ipcMain.on('lab:devtools', () => { if (win && !win.isDestroyed()) win.webContents.openDevTools({ mode: 'detach' }); });
