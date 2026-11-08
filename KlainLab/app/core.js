/* Klain Lab — shared application core (loaded inside every device iframe).
 * Real API calls, real streaming, real persistence. No mocked responses.
 * STATE is shared across frames via BroadcastChannel + localStorage so all
 * device mockups stay in sync like a single app on multiple screens.
 */
(function () {
  'use strict';

  const TOKEN = window.__LAB_TOKEN__ || new URLSearchParams(location.search).get('token') || '';
  const API = '/api';
  const CHANNEL = 'klain-lab-state';

  const DEFAULT = {
    version: 1,
    providers: [], drafts: [], chats: [], records: [], generatedImages: [],
    selectedChatID: null, defaultModel: '', imageModel: '', imageSize: '1024x1024',
    settings: { reasoning: 'default', webSearch: false },
    theme: {
      accent: '#FC995C', accent2: '#ED59A1', background: '#0B0B14', panel: '#242421',
      radius: 22, fontScale: 1, density: 1, glass: 1, dark: true,
    },
    devicePrefs: { zoom: 0.85, rotate: false, showFrame: true, theme: 'dark' },
  };

  let STATE = null;
  let bc = null;
  const listeners = new Set();
  let saveTimer = null;
  let applyingRemote = false;

  function normalize(s) {
    const out = {
      ...DEFAULT, ...(s || {}),
      theme: { ...DEFAULT.theme, ...((s || {}).theme || {}) },
      settings: { ...DEFAULT.settings, ...((s || {}).settings || {}) },
      devicePrefs: { ...DEFAULT.devicePrefs, ...((s || {}).devicePrefs || {}) },
    };
    // Guard against malformed/legacy persisted state so no screen can crash on
    // a missing array (e.g. a chat saved without messages, or imported JSON).
    for (const k of ['providers', 'drafts', 'chats', 'records', 'generatedImages']) {
      if (!Array.isArray(out[k])) out[k] = [];
    }
    out.chats = out.chats.map((c) => ({
      ...c,
      messages: Array.isArray(c.messages) ? c.messages : [],
    }));
    for (const p of out.providers) {
      if (!Array.isArray(p.models)) p.models = [];
      if (!Array.isArray(p.headers)) p.headers = [];
    }
    return out;
  }

  async function boot() {
    try {
      const res = await fetch(`${API}/state?token=${TOKEN}`);
      const data = await res.json();
      STATE = normalize(data);
    } catch (err) {
      console.error('[core] state load failed', err);
      STATE = normalize(null);
    }
    if (!STATE.chats.length) {
      const c = newChatObject(STATE);
      STATE.chats.push(c);
      STATE.selectedChatID = c.id;
      persist();
    }
    try {
      bc = new BroadcastChannel(CHANNEL);
      bc.onmessage = (ev) => {
        if (ev.data && ev.data.type === 'state') {
          applyingRemote = true;
          STATE = normalize(ev.data.state);
          emit('remote');
          applyingRemote = false;
        }
      };
    } catch (err) { console.warn('[core] BroadcastChannel unavailable', err); }
    emit('boot');
  }

  function emit(reason) { for (const fn of listeners) { try { fn(STATE, reason); } catch (e) { console.error(e); } } }

  function onChange(fn) { listeners.add(fn); return () => listeners.delete(fn); }

  function mutate(fn, reason = 'local') {
    fn(STATE);
    emit(reason);
    persist(reason === 'stream');
    // Streaming tokens don't need a cross-frame broadcast every chunk; the
    // final render (reason 'local') syncs all devices. Cuts 18x traffic/token.
    if (bc && !applyingRemote && reason !== 'stream') {
      try { bc.postMessage({ type: 'state', state: STATE }); } catch (e) { console.warn(e); }
    }
  }

  function persist(streaming = false) {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(async () => {
      // Send only the app-owned slice. A full PUT would overwrite theme,
      // inspector overrides and custom CSS written by the lab shell.
      const s = STATE;
      const patch = {
        providers: s.providers, drafts: s.drafts, chats: s.chats, records: s.records,
        generatedImages: s.generatedImages, selectedChatID: s.selectedChatID,
        defaultModel: s.defaultModel, imageModel: s.imageModel, imageSize: s.imageSize,
        settings: s.settings, devicePrefs: s.devicePrefs,
      };
      try {
        await fetch(`${API}/patch?token=${TOKEN}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(patch),
        });
      } catch (err) { console.error('[core] save failed', err); }
    }, streaming ? 900 : 250);
  }

  // The shell may change theme/inspect/CSS while we're running. Pull those
  // fields from disk without touching app-owned data.
  async function syncFromDisk(reason = 'external') {
    try {
      const res = await fetch(`${API}/state?token=${TOKEN}`);
      const disk = await res.json();
      STATE.theme = { ...STATE.theme, ...(disk.theme || {}) };
      STATE.inspectOverrides = disk.inspectOverrides || {};
      STATE.customCSS = disk.customCSS || '';
      emit(reason);
    } catch (err) { console.warn('[core] sync failed', err); }
  }

  function get() { return STATE; }

  function uid() {
    return (crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    }));
  }

  const EMOJI = ['🌿', '🪐', '🦊', '✨', '🌊', '🍀', '🚀', '🐈', '🌻', '🦋'];

  function newChatObject(s) {
    const p = activeProvider(s);
    const model = (p && (p.models || []).find((m) => m.id === s.defaultModel)?.id)
      || selectedChat(s)?.model || (p && (p.models || [])[0]?.id) || '';
    return {
      id: uid(), title: 'Новый чат', model, messages: [], providerID: p?.id || null,
      reasoning: s.settings?.reasoning || 'default', webSearch: !!s.settings?.webSearch,
      archived: false, emoji: EMOJI[Math.floor(Math.random() * EMOJI.length)],
    };
  }

  function activeProvider(s = STATE) {
    const sel = selectedChat(s);
    return s.providers.find((p) => p.id === sel?.providerID) || s.providers[0] || null;
  }
  function selectedChat(s = STATE) { return s.chats.find((c) => c.id === s.selectedChatID) || null; }
  function selectedModelEntry(s = STATE) {
    const c = selectedChat(s), p = activeProvider(s);
    if (!c || !p) return null;
    return (p.models || []).find((m) => m.id === c.model) || null;
  }

  function proxy(payload) {
    return fetch(`${API}/proxy?token=${TOKEN}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  }

  function headersFor(p) {
    const h = { 'Content-Type': 'application/json' };
    if (p.apiKey) h[p.kind === 'anthropic' ? 'x-api-key' : 'Authorization'] = p.kind === 'anthropic' ? p.apiKey : `Bearer ${p.apiKey}`;
    if (p.kind === 'anthropic') h['anthropic-version'] = '2023-06-01';
    for (const item of (p.headers || [])) if (item.name) h[item.name] = item.value;
    return h;
  }

  function trimBase(u) { return (u || '').trim().replace(/\/+$/, ''); }

  async function proxyError(res) {
    let msg = `HTTP ${res.status}`;
    try {
      const j = await res.clone().json();
      msg = j.error || msg;
    } catch { /* ignore */ }
    return new Error(String(msg).slice(0, 1200));
  }

  const PRESETS = [
    { id: 'anthropic', name: 'Anthropic', url: 'https://api.anthropic.com/v1', symbol: 'aSquare' },
    { id: 'openai', name: 'OpenAI', url: 'https://api.openai.com/v1', symbol: 'sparkle' },
    { id: 'google', name: 'Google', url: 'https://generativelanguage.googleapis.com/v1beta/openai', symbol: 'sparkles' },
    { id: 'openrouter', name: 'OpenRouter', url: 'https://openrouter.ai/api/v1', symbol: 'branch' },
    { id: 'vercel', name: 'Vercel AI Gateway', url: 'https://ai-gateway.vercel.sh/v1', symbol: 'triangle' },
    { id: 'custom', name: 'Пользовательский провайдер', url: '', symbol: 'sliders' },
  ];

  async function fetchModels(p) {
    const base = trimBase(p.baseURL);
    if (!base) throw new Error('Укажи Base URL');
    const res = await proxy({ url: base + '/models', method: 'GET', headers: headersFor(p) });
    if (!res.ok) throw await proxyError(res);
    const j = await res.json();
    const items = j.data || j.models || [];
    if (!Array.isArray(items) || !items.length) throw new Error('Провайдер не вернул список моделей. Добавь ID вручную.');
    return items.map((it) => {
      const a = it.architecture || {};
      let input = a.input_modalities;
      if (!input && a.modality) {
        const left = String(a.modality).split('->')[0];
        input = left.split('+').map((x) => x.trim());
      }
      return {
        id: it.id,
        name: it.display_name || it.name || it.id,
        inputModalities: Array.isArray(input) ? input : null,
        outputModalities: Array.isArray(a.output_modalities) ? a.output_modalities : null,
      };
    }).filter((m) => m.id).sort((a, b) => a.id.localeCompare(b.id));
  }

  async function fetchBalance(p) {
    const base = trimBase(p.baseURL);
    if (base.includes('openrouter.ai')) {
      const res = await proxy({ url: base + '/key', headers: headersFor(p) });
      if (!res.ok) throw await proxyError(res);
      const j = await res.json();
      const v = j.data?.limit_remaining;
      return typeof v === 'number' ? `Остаток лимита ключа: $${v.toFixed(4)}` : 'Лимит ключа не задан';
    }
    return 'Баланс: нет данных API';
  }

  const IMAGE_HINTS = ['image', 'imagine', 'banana', 'dall-e', 'flux', 'stable-diffusion', 'sdxl', 'ideogram', 'midjourney', 'imagen'];
  const IMAGE_PRESETS = ['gpt-image-2.5-sunburst', 'gpt-image-2.5-flare', 'gpt-image-2', 'nano-banana-2', 'grok-imagine-image'];
  const IMAGE_SIZES = ['1024x1024', '1024x1536', '1536x1024', '512x512'];

  function imageModels(p) {
    const out = (p?.models || []).filter((m) =>
      (m.outputModalities || []).includes('image') || IMAGE_HINTS.some((h) => m.id.toLowerCase().includes(h)));
    const seen = new Set(out.map((m) => m.id));
    for (const id of IMAGE_PRESETS) if (!seen.has(id)) out.push({ id, name: id, outputModalities: ['image'], inputModalities: null });
    return out;
  }

  function toDataURL(a) { return `data:${a.mime};base64,${a.data}`; }

  function buildMessage(m, p, supportsImages) {
    const parts = [];
    if (m.text) parts.push({ type: 'text', text: m.text });
    for (const a of (m.attachments || [])) {
      if (!supportsImages && a.mime.startsWith('image/')) continue;
      const mime = a.mime;
      if (mime.startsWith('image/')) {
        if (p.kind === 'anthropic') parts.push({ type: 'image', source: { type: 'base64', media_type: mime, data: a.data } });
        else parts.push({ type: 'image_url', image_url: { url: toDataURL(a) } });
      } else if (mime === 'application/pdf' && p.kind === 'anthropic') {
        parts.push({ type: 'document', source: { type: 'base64', media_type: mime, data: a.data } });
      } else if (mime === 'application/pdf' && trimBase(p.baseURL).includes('openrouter.ai')) {
        parts.push({ type: 'file', file: { filename: a.name, file_data: toDataURL(a) } });
      } else if (mime.startsWith('video/') && (p.kind === 'google' || trimBase(p.baseURL).includes('openrouter.ai'))) {
        parts.push({ type: 'video_url', video_url: { url: toDataURL(a) } });
      } else if (mime.startsWith('text/') || /\.(txt|md|json|csv|log|js|ts|py|swift|html|css|xml|yaml|yml)$/i.test(a.name)) {
        try { parts.push({ type: 'text', text: `Файл: ${a.name}\n${atob(a.data)}` }); }
        catch { parts.push({ type: 'text', text: `Файл: ${a.name} (бинарный, не передан)` }); }
      } else {
        throw new Error(`${a.name}: формат не поддержан этим подключением.`);
      }
    }
    return { role: m.role, content: (m.attachments || []).length ? parts : (m.text || '') };
  }

  function imageSupportError(attachments) {
    if (!(attachments || []).some((a) => a.mime.startsWith('image/'))) return null;
    const e = selectedModelEntry();
    if (!e || !e.inputModalities) return null;
    if (e.inputModalities.includes('image')) return null;
    return `Модель ${e.name || e.id} не поддерживает изображения. Выбери vision-модель или убери фото.`;
  }

  function imageSupportWarning(attachments) {
    if (!(attachments || []).some((a) => a.mime.startsWith('image/'))) return null;
    const e = selectedModelEntry();
    if (!e) return null;
    if (e.inputModalities) return e.inputModalities.includes('image') ? null : imageSupportError(attachments);
    return 'Поддержка изображений не подтверждена. Обнови список моделей в «Провайдерах».';
  }

  async function* streamChat(chat, p, attachmentsForLast, signal) {
    const anthropic = p.kind === 'anthropic';
    const entry = (p.models || []).find((m) => m.id === chat.model);
    const supportsImages = entry?.inputModalities ? entry.inputModalities.includes('image') : true;
    const cleaned = chat.messages.filter((m) => !m.failed && (m.text || (m.attachments || []).length));
    const messages = cleaned.map((m, i) =>
      buildMessage(i === cleaned.length - 1 && attachmentsForLast
        ? { ...m, attachments: [...(m.attachments || []), ...attachmentsForLast] } : m,
      p, supportsImages));

    const body = { model: chat.model, stream: true, messages };
    if (anthropic) body.max_tokens = 8192;
    else body.stream_options = { include_usage: true };
    if (trimBase(p.baseURL).includes('openrouter.ai') && (entry?.outputModalities || []).includes('image')) body.modalities = entry.outputModalities;
    if (chat.reasoning && chat.reasoning !== 'default') {
      const effort = chat.reasoning === 'max' ? 'xhigh' : chat.reasoning;
      if (anthropic) { body.thinking = { type: 'adaptive' }; body.output_config = { effort: chat.reasoning === 'xhigh' ? 'max' : effort }; }
      else if (trimBase(p.baseURL).includes('openrouter.ai')) body.reasoning = { effort };
      else body.reasoning_effort = effort;
    }
    if (chat.webSearch) body.tools = anthropic ? [{ type: 'web_search_20250305', name: 'web_search' }] : [{ type: 'web_search' }];

    const url = trimBase(p.baseURL) + (anthropic ? '/messages' : '/chat/completions');
    const tryOpen = (includeUsage) => proxy({ url, method: 'POST', headers: headersFor(p), body: includeUsage ? body : (() => { const b = { ...body }; delete b.stream_options; return b; })(), stream: true });

    let res = await tryOpen(!anthropic);
    if (!res.ok && !anthropic) {
      const txt = await res.clone().text().catch(() => '');
      if (/stream_options/i.test(txt)) res = await tryOpen(false);
    }
    if (!res.ok) throw await proxyError(res);
    if (!res.body) throw new Error('У провайдера нет потокового ответа');

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buf = '';
    let usage = null;
    const emitYield = { };

    while (true) {
      if (signal?.aborted) { reader.cancel().catch(() => {}); throw new DOMException('Остановлено', 'AbortError'); }
      const { done, value } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });
      let idx;
      while ((idx = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, idx).replace(/\r$/, '');
        buf = buf.slice(idx + 1);
        if (!line.startsWith('data:')) continue;
        const payload = line.slice(5).trim();
        if (payload === '[DONE]') { reader.cancel().catch(() => {}); if (usage) yield { type: 'usage', usage }; return; }
        let j;
        try { j = JSON.parse(payload); } catch { continue; }
        if (j.error) throw new Error(String(j.error.message || j.error).slice(0, 800));
        if (anthropic) {
          const d = j.delta || {};
          if (typeof d.thinking === 'string') yield { type: 'thinking', text: d.thinking };
          if (typeof d.text === 'string') yield { type: 'text', text: d.text };
          const u = (j.message && j.message.usage) || j.usage;
          if (u) {
            usage = {
              input: u.input_tokens != null ? u.input_tokens + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0) : null,
              output: u.output_tokens ?? null, cached: u.cache_read_input_tokens ?? null, cost: null,
            };
            yield { type: 'usage', usage };
          }
        } else {
          const d = j.choices?.[0]?.delta || {};
          if (typeof d.reasoning_content === 'string' || typeof d.reasoning === 'string') yield { type: 'thinking', text: d.reasoning_content || d.reasoning };
          if (typeof d.content === 'string') yield { type: 'text', text: d.content };
          const arr = [...(Array.isArray(d.images) ? d.images : []), ...(Array.isArray(d.content) ? d.content : [])];
          for (const part of arr) {
            if (typeof part === 'object' && typeof part.text === 'string') yield { type: 'text', text: part.text };
            if (typeof part === 'object' && part.image_url?.url) yield { type: 'media', media: { url: part.image_url.url, kind: 'image' } };
            if (typeof part === 'object' && part.video_url?.url) yield { type: 'media', media: { url: part.video_url.url, kind: 'video' } };
          }
          if (j.usage) {
            usage = {
              input: j.usage.prompt_tokens ?? usage?.input ?? null,
              output: j.usage.completion_tokens ?? usage?.output ?? null,
              cached: j.usage.prompt_tokens_details?.cached_tokens ?? usage?.cached ?? null,
              cost: j.usage.cost ?? usage?.cost ?? null,
            };
            yield { type: 'usage', usage };
          }
        }
      }
    }
    if (usage) yield { type: 'usage', usage };
  }

  async function generateImage(p, model, prompt, size) {
    const res = await proxy({
      url: trimBase(p.baseURL) + '/images/generations', method: 'POST', headers: headersFor(p),
      body: { model, prompt, n: 1, size },
    });
    if (!res.ok) throw await proxyError(res);
    const j = await res.json();
    if (j.error) throw new Error(String(j.error.message || j.error).slice(0, 800));
    const first = (j.data || [])[0];
    if (!first) throw new Error('Провайдер не вернул изображение.');
    if (first.b64_json) return `data:image/png;base64,${first.b64_json}`;
    if (typeof first.url === 'string') {
      if (first.url.startsWith('data:')) return first.url;
      const r = await proxy({ url: first.url, method: 'GET' });
      if (!r.ok) throw new Error('Не удалось скачать изображение по URL');
      const blob = await r.blob();
      return await new Promise((resolve, reject) => {
        const fr = new FileReader();
        fr.onload = () => resolve(fr.result);
        fr.onerror = reject;
        fr.readAsDataURL(blob);
      });
    }
    throw new Error('Провайдер не вернул изображение.');
  }

  window.Lab = {
    boot, get, onChange, mutate, uid, persist, syncFromDisk,
    activeProvider, selectedChat, selectedModelEntry, newChatObject,
    PRESETS, IMAGE_SIZES, IMAGE_PRESETS, imageModels,
    fetchModels, fetchBalance, streamChat, generateImage,
    imageSupportError, imageSupportWarning,
    headersFor, trimBase, proxy,
    get token() { return TOKEN; },
  };
})();
