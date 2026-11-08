/* Klain Lab shell: device grid, visual editor, live reload. */
(function () {
  'use strict';
  const TOKEN = window.__LAB_TOKEN__ || '';
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // Logical viewport sizes (points) for every distinct iPhone/iPad screen class.
  // feat: 'dynamic' | 'notch' | 'none'
  const DEVICES = [
    { id: 'se', group: 'iPhone SE / классика', name: 'iPhone SE (3rd)', w: 375, h: 667, scale: 2, feat: 'none', home: true },
    { id: '8', group: 'iPhone SE / классика', name: 'iPhone 8', w: 375, h: 667, scale: 2, feat: 'none', home: true },
    { id: '8p', group: 'iPhone SE / классика', name: 'iPhone 8 Plus', w: 414, h: 736, scale: 3, feat: 'none', home: true },
    { id: 'x', group: 'Notch (X–13)', name: 'iPhone X / XS / 11 Pro', w: 375, h: 812, scale: 3, feat: 'notch' },
    { id: 'xr', group: 'Notch (X–13)', name: 'iPhone XR / 11', w: 414, h: 896, scale: 2, feat: 'notch' },
    { id: '11', group: 'Notch (X–13)', name: 'iPhone 11 Pro Max / XS Max', w: 414, h: 896, scale: 3, feat: 'notch' },
    { id: '12mini', group: 'Notch (X–13)', name: 'iPhone 12 / 13 mini', w: 375, h: 812, scale: 3, feat: 'notch' },
    { id: '12', group: 'Notch (X–13)', name: 'iPhone 12 / 13 / 14', w: 390, h: 844, scale: 3, feat: 'notch' },
    { id: '12pm', group: 'Notch (X–13)', name: 'iPhone 12/13 Pro Max', w: 428, h: 926, scale: 3, feat: 'notch' },
    { id: '14pro', group: 'Dynamic Island (14–16)', name: 'iPhone 14 / 15 / 16 Pro', w: 393, h: 852, scale: 3, feat: 'dynamic' },
    { id: '14pm', group: 'Dynamic Island (14–16)', name: 'iPhone 14/15 Pro Max', w: 430, h: 932, scale: 3, feat: 'dynamic' },
    { id: '16', group: 'Dynamic Island (14–16)', name: 'iPhone 16 / 16e', w: 393, h: 852, scale: 3, feat: 'dynamic' },
    { id: '16plus', group: 'Dynamic Island (14–16)', name: 'iPhone 16 Plus', w: 430, h: 932, scale: 3, feat: 'dynamic' },
    { id: '16pm', group: 'Dynamic Island (14–16)', name: 'iPhone 16 Pro Max', w: 440, h: 956, scale: 3, feat: 'dynamic' },
    { id: 'ipadmini', group: 'iPad', name: 'iPad mini', w: 744, h: 1133, scale: 2, feat: 'none', home: true },
    { id: 'ipad', group: 'iPad', name: 'iPad 10.9" / Air', w: 820, h: 1180, scale: 2, feat: 'none', home: true },
    { id: 'ipad11', group: 'iPad', name: 'iPad Pro 11"', w: 834, h: 1194, scale: 2, feat: 'none', home: true },
    { id: 'ipad13', group: 'iPad', name: 'iPad Pro 12.9"', w: 1024, h: 1366, scale: 2, feat: 'none', home: true },
  ];
  const PRESET_THEMES = {
    default: { accent: '#FC995C', accent2: '#ED59A1', background: '#0B0B14', panel: '#242421', radius: 22, fontScale: 1, density: 1, glass: 1, dark: true },
    ocean: { accent: '#38bdf8', accent2: '#6366f1', background: '#071018', panel: '#0e202c', radius: 18, fontScale: 1, density: 1, glass: .8, dark: true },
    mono: { accent: '#d4d4d8', accent2: '#a1a1aa', background: '#090909', panel: '#1a1a1a', radius: 8, fontScale: .95, density: 1.1, glass: .35, dark: true },
    candy: { accent: '#fb7185', accent2: '#f0abfc', background: '#1a0c18', panel: '#2a1426', radius: 30, fontScale: 1.05, density: .95, glass: 1, dark: true },
  };

  let state = null;
  let mode = 'grid';
  let selected = new Set(DEVICES.map((d) => d.id));
  let focusDevice = '14pro';
  let zoom = 0.42;
  let rotate = false, showFrame = true, statusbar = true;
  let uiTheme = 'dark';
  let inspectOn = false;
  let inspectTarget = null; // { selector, frame }
  let overrides = {};       // selector -> css props
  let customCSS = '';
  let renderTimer = null;

  async function api(path, opts) {
    const res = await fetch(path + (path.includes('?') ? '&' : '?') + 'token=' + TOKEN, opts);
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json();
  }

  async function boot() {
    const info = await api('/api/info');
    $('#foot-state').textContent = info.stateFile;
    $('#foot-info').textContent = `Electron ${info.electron} · Node ${info.node} · Chromium ${info.chrome}`;
    state = await api('/api/state');
    overrides = state.inspectOverrides || {};
    customCSS = state.customCSS || '';
    $('#custom-css').value = customCSS;
    syncThemeControls();
    buildDeviceList();
    renderDevices();
    wireControls();
    connectEvents();
  }

  function saveState() {
    if (!state) return;
    clearTimeout(renderTimer);
    renderTimer = setTimeout(async () => {
      state.inspectOverrides = overrides;
      state.customCSS = customCSS;
      const patch = {
        theme: state.theme,
        inspectOverrides: overrides,
        customCSS: customCSS,
      };
      try {
        await api('/api/patch', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(patch) });
        setStatus(true);
        // Tell each device to re-read the shared fields from disk.
        $$('#devices iframe').forEach((f) => {
          try { f.contentWindow.Lab?.syncFromDisk?.('theme'); } catch { /* not ready */ }
        });
      } catch (e) { setStatus(false, e.message); }
    }, 300);
  }

  function setStatus(ok, msg) {
    const el = $('#live-status');
    el.textContent = ok ? '● подключено' : '● ' + (msg || 'нет связи');
    el.classList.toggle('off', !ok);
  }

  function log(file) {
    const el = $('#log'); if (!el) return;
    const d = document.createElement('div');
    d.className = 'entry';
    d.innerHTML = `<span>${new Date().toLocaleTimeString('ru-RU')}</span> · изменён <b>${esc(file)}</b> → все макеты обновлены`;
    el.prepend(d);
    while (el.children.length > 40) el.lastChild.remove();
  }

  function connectEvents() {
    const es = new EventSource(`/api/events?token=${TOKEN}`);
    es.addEventListener('reload', (ev) => {
      let file = 'файл', scope = 'app';
      try { const d = JSON.parse(ev.data); file = d.file; scope = d.scope || 'app'; } catch { /* ignore */ }
      log(file);
      if (scope === 'shell') {
        // main.js also reloads the whole BrowserWindow; this is the belt-and-
        // suspenders path for when the lab is opened in a plain browser tab.
        setTimeout(() => location.reload(), 260);
      } else {
        scheduleReload();
      }
    });
    es.onerror = () => setStatus(false, 'переподключение…');
    es.onopen = () => setStatus(true);
    if (window.labHost?.onFileChanged) window.labHost.onFileChanged((name) => log(name));
  }

  function scheduleReload() {
    clearTimeout(scheduleReload.t);
    scheduleReload.t = setTimeout(async () => {
      try { state = await api('/api/state'); } catch { /* ignore */ }
      renderDevices();
    }, 220);
  }

  function buildDeviceList() {
    const el = $('#device-list');
    let html = '';
    let group = '';
    for (const d of DEVICES) {
      if (d.group !== group) { group = d.group; html += `<div class="dev-group">${esc(group)}</div>`; }
      html += `<label class="dev-item"><input type="checkbox" data-dev="${d.id}" ${selected.has(d.id) ? 'checked' : ''}>
        <span class="nm">${esc(d.name)}</span>
        <span class="px">${d.w}×${d.h}</span>
        ${d.feat === 'dynamic' ? '<span class="feat" title="Dynamic Island">▬</span>' : ''}
      </label>`;
    }
    el.innerHTML = html;
    $('#dev-count').textContent = selected.size + ' / ' + DEVICES.length;
    $$('[data-dev]', el).forEach((cb) => cb.onchange = () => {
      if (cb.checked) selected.add(cb.dataset.dev); else selected.delete(cb.dataset.dev);
      $('#dev-count').textContent = selected.size + ' / ' + DEVICES.length;
      renderDevices();
    });
  }

  function visibleDevices() {
    const all = DEVICES.filter((d) => selected.has(d.id));
    return mode === 'single' ? all.filter((d) => d.id === focusDevice) : all;
  }

  function renderDevices() {
    const wrap = $('#devices');
    const list = visibleDevices();
    $('#stage-empty').classList.toggle('hidden', list.length > 0);
    wrap.classList.toggle('single', mode === 'single');
    wrap.innerHTML = list.map(deviceHTML).join('');
    $$('.device .label', wrap).forEach((el) => el.onclick = () => {
      focusDevice = el.closest('.device').dataset.id;
      if (mode === 'grid') { mode = 'single'; syncSeg(); renderDevices(); }
    });
    for (const d of list) attachFrame(d);
  }

  function statusIcons(dark) {
    const c = dark ? '#0a0a0c' : '#fff';
    return `<svg viewBox="0 0 18 14" fill="${c}" aria-hidden="true"><rect x="0" y="9" width="3" height="4" rx=".6"/><rect x="4.5" y="6.5" width="3" height="6.5" rx=".6"/><rect x="9" y="3.5" width="3" height="9.5" rx=".6"/><rect x="13.5" y="0" width="3" height="13" rx=".6"/></svg>
      <svg viewBox="0 0 18 14" fill="none" stroke="${c}" stroke-width="1.6" aria-hidden="true"><path d="M1 4.5a12 12 0 0 1 16 0M4 8a8 8 0 0 1 10 0M7 11.2a3.6 3.6 0 0 1 4 0" stroke-linecap="round"/><circle cx="9" cy="12.4" r="1" fill="${c}" stroke="none"/></svg>
      <svg viewBox="0 0 27 14" fill="none" aria-hidden="true"><rect x="0.6" y="1" width="22" height="12" rx="3.2" stroke="${c}" stroke-width="1.2" opacity=".55"/><rect x="2.3" y="2.7" width="18.6" height="8.6" rx="1.8" fill="${c}"/><path d="M24 5v4a2.4 2.4 0 0 0 0-4z" fill="${c}" opacity=".55"/></svg>`;
  }

  function deviceHTML(d) {
    const zw = rotate ? d.h : d.w, zh = rotate ? d.w : d.h;
    // Render the iframe at its NATURAL point size; CSS zoom on .scaler scales
    // the whole frame (transform:scale breaks iframe compositing in Chromium).
    const natW = zw, natH = zh;
    const pad = showFrame ? 22 : 0;
    const island = d.feat === 'dynamic' ? '<div class="island dynamic"></div>'
      : d.feat === 'notch' ? '<div class="island notch"></div>' : '';
    const home = showFrame ? '<div class="homebar"></div>' : '';
    const sideBtns = showFrame && !d.group.startsWith('iPad') ? `
      <div class="sidebtn mute"></div><div class="sidebtn volup"></div><div class="sidebtn voldn"></div><div class="sidebtn power"></div>` : '';
    const dark = uiTheme !== 'light';
    return `<div class="device" data-id="${d.id}">
      <div class="label"><b>${esc(d.name)}</b> · ${d.w}×${d.h} pt · <span style="cursor:pointer;color:var(--ui-accent)">увеличить ↗</span></div>
      <div class="scaler" style="zoom:${zoom};width:${natW + pad}px;height:${natH + pad}px">
        <div class="phone ${showFrame ? '' : 'no-frame'}" style="width:${natW + pad}px;height:${natH + pad}px">
          <div class="screen-clip" style="width:${natW}px;height:${natH}px">
            <iframe src="/app/device.html?token=${TOKEN}&dev=${d.id}" data-dev="${d.id}" loading="eager" title="${esc(d.name)}"></iframe>
          </div>
          ${sideBtns}${island}${home}
          ${statusbar ? `<div class="statusbar ${dark ? 'light-text' : 'dark-text'}"><span class="clock">9:41</span><span class="right">${statusIcons(dark)}</span></div>` : '<div class="statusbar hide"></div>'}
        </div>
      </div>
    </div>`;
  }

  function attachFrame(d) {
    const frame = $(`iframe[data-dev="${d.id}"]`);
    if (!frame) return;
    frame.addEventListener('load', () => {
      try {
        const doc = frame.contentDocument;
        if (!doc) return;
        doc.documentElement.style.setProperty('--lab-zoom', String(zoom));
        doc.documentElement.style.setProperty('--lab-status-height', statusbar ? '44px' : '0px');
        applyOverridesToDoc(doc);
        applyCustomCSSToDoc(doc);
        if (inspectOn) setupInspector(doc, frame);
      } catch (e) { console.warn('[frame]', e); }
    });
  }

  function broadcastToFrames(fn) {
    $$('#devices iframe').forEach((f) => { try { fn(f.contentDocument, f); } catch { /* not ready */ } });
  }

  function applyOverridesToDoc(doc) {
    let style = doc.getElementById('lab-inspect-style');
    if (!style) { style = doc.createElement('style'); style.id = 'lab-inspect-style'; doc.head.appendChild(style); }
    style.textContent = Object.entries(overrides).map(([sel, props]) =>
      `${sel} { ${Object.entries(props).map(([k, v]) => `${k}: ${v} !important`).join('; ')} }`).join('\n');
  }
  function applyCustomCSSToDoc(doc) {
    let style = doc.getElementById('lab-custom-style');
    if (!style) { style = doc.createElement('style'); style.id = 'lab-custom-style'; doc.head.appendChild(style); }
    style.textContent = customCSS;
  }

  function cssPath(el) {
    if (!el || el.nodeType !== 1) return '';
    const parts = [];
    let cur = el;
    for (let i = 0; cur && i < 5 && cur.nodeType === 1; i++) {
      let part = cur.tagName.toLowerCase();
      if (cur.id) { parts.unshift('#' + cur.id); break; }
      const cls = [...(cur.classList || [])].filter((c) => !c.startsWith('lab-')).slice(0, 2);
      if (cls.length) part += '.' + cls.join('.');
      const sib = cur.parentElement ? [...cur.parentElement.children].filter((x) => x.tagName === cur.tagName) : [];
      if (sib.length > 1) part += `:nth-of-type(${sib.indexOf(cur) + 1})`;
      parts.unshift(part);
      cur = cur.parentElement;
    }
    return parts.join(' > ');
  }

  function setupInspector(doc, frame) {
    if (doc.__labInspector) return;
    doc.__labInspector = true;
    doc.addEventListener('click', (e) => {
      if (!inspectOn) return;
      const el = e.target;
      if (!el || el.closest('#lab-hint')) return;
      e.preventDefault(); e.stopPropagation();
      $$('.inspect-outline', doc).forEach((x) => x.classList.remove('inspect-outline'));
      el.classList.add('inspect-outline');
      const sel = cssPath(el);
      inspectTarget = { selector: sel, el };
      showInspectorFields(sel, el, doc);
    }, true);
  }

  function showInspectorFields(sel, el, doc) {
    $('#inspect-empty').classList.add('hidden');
    $('#inspect-fields').classList.remove('hidden');
    $('#inspect-sel').textContent = sel;
    const cs = doc.defaultView.getComputedStyle(el);
    $('#i-text').value = (el.childNodes.length === 1 && el.firstChild.nodeType === 3) ? el.textContent.trim().slice(0, 120) : '';
    const rgb2hex = (v) => { const m = v.match(/\d+/g); return m ? '#' + m.slice(0, 3).map((n) => (+n).toString(16).padStart(2, '0')).join('') : '#ffffff'; };
    $('#i-color').value = rgb2hex(cs.color);
    $('#i-bg').value = rgb2hex(cs.backgroundColor === 'rgba(0, 0, 0, 0)' ? 'rgb(22,22,31)' : cs.backgroundColor);
    $('#i-size').value = parseInt(cs.fontSize, 10) || 14; $('#o-size').textContent = $('#i-size').value;
    $('#i-radius').value = parseInt(cs.borderRadius, 10) || 0; $('#o-iradius').textContent = $('#i-radius').value;
    $('#i-pad').value = parseInt(cs.paddingTop, 10) || 0; $('#o-pad').textContent = $('#i-pad').value;
    $('#i-opacity').value = cs.opacity; $('#o-opacity').textContent = cs.opacity;
  }

  function setOverride(prop, value) {
    if (!inspectTarget) return;
    const sel = inspectTarget.selector;
    overrides[sel] = overrides[sel] || {};
    overrides[sel][prop] = value;
    broadcastToFrames(applyOverridesToDoc);
    saveState();
  }

  function syncThemeControls() {
    const t = state.theme;
    $('#t-accent').value = t.accent; $('#t-accent2').value = t.accent2;
    $('#t-bg').value = t.background; $('#t-panel').value = t.panel;
    $('#t-radius').value = t.radius; $('#o-radius').textContent = t.radius;
    $('#t-font').value = t.fontScale; $('#o-font').textContent = (+t.fontScale).toFixed(2);
    $('#t-density').value = t.density; $('#o-density').textContent = (+t.density).toFixed(2);
    $('#t-glass').value = t.glass; $('#o-glass').textContent = (+t.glass).toFixed(2);
    $('#t-dark').checked = !t.dark;
  }

  function pushTheme() {
    state.theme = state.theme || {};
    saveState();
    broadcastToFrames((doc) => {
      try { doc.defaultView.dispatchEvent(new doc.defaultView.Event('lab:theme')); } catch { /* ignore */ }
    });
  }

  function applyPreset(name) {
    state.theme = { ...PRESET_THEMES[name] };
    syncThemeControls(); pushTheme();
    uiTheme = state.theme.dark ? 'dark' : 'light';
    $('#theme-select').value = uiTheme;
    renderDevices();
  }

  function syncSeg() { $$('#mode-seg button').forEach((b) => b.classList.toggle('on', b.dataset.mode === mode)); }

  function wireControls() {
    $$('#mode-seg button').forEach((b) => b.onclick = () => {
      mode = b.dataset.mode; syncSeg();
      if (mode === 'single' && zoom < 0.8) { zoom = 0.85; $('#zoom').value = '0.85'; $('#zoom-out').textContent = '0.85'; }
      if (mode === 'grid' && zoom > 0.6) { zoom = 0.42; $('#zoom').value = '0.42'; $('#zoom-out').textContent = '0.42'; }
      renderDevices();
    });
    $('#zoom').oninput = (e) => { zoom = +e.target.value; $('#zoom-out').textContent = zoom.toFixed(2); renderDevices(); };
    $('#rotate').onchange = (e) => { rotate = e.target.checked; renderDevices(); };
    $('#frame').onchange = (e) => { showFrame = e.target.checked; renderDevices(); };
    $('#statusbar').onchange = (e) => { statusbar = e.target.checked; renderDevices(); };
    $('#theme-select').onchange = (e) => {
      uiTheme = e.target.value;
      state.theme.dark = uiTheme !== 'light';
      $('#t-dark').checked = !state.theme.dark;
      pushTheme(); renderDevices();
    };
    $('#btn-reload').onclick = async () => { await api('/api/reload'); scheduleReload(); log('вручную'); };
    $('#btn-open-dir').onclick = () => api('/api/open-app-dir', { method: 'POST' }).catch(() => {});
    $('#btn-state').onclick = () => api('/api/reveal', { method: 'POST' }).catch(() => {});
    $('#btn-devtools').onclick = () => { if (window.labHost) window.labHost.openDevTools?.(); };

    $$('#tabs button').forEach((b) => b.onclick = () => {
      $$('#tabs button').forEach((x) => x.classList.toggle('on', x === b));
      ['theme', 'inspect', 'log'].forEach((t) => $('#tab-' + t).classList.toggle('hidden', t !== b.dataset.tab));
      if (b.dataset.tab === 'inspect' && inspectOn) broadcastToFrames((doc, f) => setupInspector(doc, f));
    });

    const tmap = {
      '#t-accent': 'accent', '#t-accent2': 'accent2', '#t-bg': 'background', '#t-panel': 'panel',
    };
    for (const [sel, key] of Object.entries(tmap)) {
      $(sel).oninput = (e) => { state.theme[key] = e.target.value; pushTheme(); };
    }
    $('#t-radius').oninput = (e) => { state.theme.radius = +e.target.value; $('#o-radius').textContent = e.target.value; pushTheme(); };
    $('#t-font').oninput = (e) => { state.theme.fontScale = +e.target.value; $('#o-font').textContent = (+e.target.value).toFixed(2); pushTheme(); };
    $('#t-density').oninput = (e) => { state.theme.density = +e.target.value; $('#o-density').textContent = (+e.target.value).toFixed(2); pushTheme(); };
    $('#t-glass').oninput = (e) => { state.theme.glass = +e.target.value; $('#o-glass').textContent = (+e.target.value).toFixed(2); pushTheme(); };
    $('#t-dark').onchange = (e) => { state.theme.dark = !e.target.checked; uiTheme = state.theme.dark ? 'dark' : 'light'; $('#theme-select').value = uiTheme; pushTheme(); renderDevices(); };
    $$('[data-preset]').forEach((b) => b.onclick = () => applyPreset(b.dataset.preset));

    $('#inspect-toggle').onclick = () => {
      inspectOn = !inspectOn;
      $('#inspect-toggle').textContent = inspectOn ? '🔍 Инспектор включён (выключить)' : '🔍 Включить инспектор';
      broadcastToFrames((doc, f) => {
        if (inspectOn) setupInspector(doc, f);
        else { $$('.inspect-outline', doc).forEach((x) => x.classList.remove('inspect-outline')); }
      });
      if (!inspectOn) { $('#inspect-fields').classList.add('hidden'); $('#inspect-empty').classList.remove('hidden'); inspectTarget = null; }
    };
    $('#i-text').oninput = (e) => {
      if (inspectTarget && inspectTarget.el.childNodes.length === 1 && inspectTarget.el.firstChild.nodeType === 3) inspectTarget.el.textContent = e.target.value;
      setOverride('font-size', $('#i-size').value + 'px');
    };
    $('#i-color').oninput = (e) => setOverride('color', e.target.value);
    $('#i-bg').oninput = (e) => setOverride('background-color', e.target.value);
    $('#i-size').oninput = (e) => { $('#o-size').textContent = e.target.value; setOverride('font-size', e.target.value + 'px'); };
    $('#i-radius').oninput = (e) => { $('#o-iradius').textContent = e.target.value; setOverride('border-radius', e.target.value + 'px'); };
    $('#i-pad').oninput = (e) => { $('#o-pad').textContent = e.target.value; setOverride('padding', e.target.value + 'px'); };
    $('#i-opacity').oninput = (e) => { $('#o-opacity').textContent = e.target.value; setOverride('opacity', e.target.value); };
    $('#i-reset').onclick = () => { if (!inspectTarget) return; delete overrides[inspectTarget.selector]; broadcastToFrames(applyOverridesToDoc); saveState(); };
    $('#i-reset-all').onclick = () => { overrides = {}; broadcastToFrames(applyOverridesToDoc); saveState(); };
    $('#custom-css').oninput = (e) => { customCSS = e.target.value; saveState(); };
    $('#apply-css').onclick = () => { customCSS = $('#custom-css').value; broadcastToFrames(applyCustomCSSToDoc); saveState(); log('custom CSS'); };
  }

  boot().catch((e) => { setStatus(false, e.message); $('#stage-empty').textContent = 'Ошибка запуска: ' + e.message; });
})();
