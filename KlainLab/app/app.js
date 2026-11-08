/* klain — 1:1 web port of the SwiftUI sources in Klain/*.swift.
 * Exact strings, section headers, colors, radii and view order come from the
 * Swift sources (ContentView / HomeBanner / ProvidersView / ImageStudioView /
 * StatisticsView / GlassTheme / ChatStore). SF Symbols are approximated with
 * inline SVG geometry (the proprietary glyphs are not redistributable).
 * All actions still hit the real API through Lab.proxy. */
(function () {
  'use strict';
  const L = window.Lab;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  /* ── SF Symbols (approximated as inline SVG paths) ─────────────────── */
  const P = {
    chats: '<path d="M3 5.5h13a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H8l-4 3v-3H3a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2z"/><path d="M7 9h8M7 12h5" stroke="currentColor" stroke-width="1.4" fill="none" stroke-linecap="round"/>',
    sparkles: '<path d="M12 2l1.7 5.3L19 9l-5.3 1.7L12 16l-1.7-5.3L5 9l5.3-1.7z"/><path d="M18.5 14l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8zM5 14l.6 1.6L7.2 16l-1.6.6L5 18.2l-.6-1.6L2.8 16l1.6-.4z"/>',
    sliders: '<path d="M3 6h5m4 0h9M3 12h11m4 0h3M3 18h2m4 0h12" stroke="currentColor" stroke-width="1.6" fill="none" stroke-linecap="round"/><circle cx="10" cy="6" r="2" fill="currentColor"/><circle cx="16" cy="12" r="2" fill="currentColor"/><circle cx="7" cy="18" r="2" fill="currentColor"/>',
    chart: '<rect x="3" y="11" width="4" height="9" rx="1"/><rect x="10" y="6" width="4" height="14" rx="1"/><rect x="17" y="3" width="4" height="17" rx="1"/>',
    chevR: '<path d="M9 5l7 7-7 7" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    chevD: '<path d="M5 9l7 7 7-7" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    chevL: '<path d="M15 5l-7 7 7 7" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    pencil: '<path d="M4 20h4l10-10-4-4L4 16v4z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M13 7l4 4" stroke="currentColor" stroke-width="1.7"/>',
    arrowUR: '<path d="M7 17L17 7M8 7h9v9" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    clock: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M12 7v5l3 2" stroke="currentColor" stroke-width="1.7" fill="none" stroke-linecap="round"/>',
    brain: '<path d="M9 4a3 3 0 0 0-3 3 3 3 0 0 0-1 5.8A3 3 0 0 0 8 18a3 3 0 0 0 4 0V4.5A2.5 2.5 0 0 0 9 4zM15 4a3 3 0 0 1 3 3 3 3 0 0 1 1 5.8A3 3 0 0 1 16 18a3 3 0 0 1-4 0V4.5A2.5 2.5 0 0 1 15 4z" fill="none" stroke="currentColor" stroke-width="1.4"/>',
    globe: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M3 12h18M12 3c2.5 2.6 2.5 15.4 0 18M12 3c-2.5 2.6-2.5 15.4 0 18" fill="none" stroke="currentColor" stroke-width="1.3"/>',
    camera: '<path d="M3 8V5a2 2 0 0 1 2-2h3M16 3h3a2 2 0 0 1 2 2v3M21 16v3a2 2 0 0 1-2 2h-3M8 21H5a2 2 0 0 1-2-2v-3" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="12" r="3.2" fill="none" stroke="currentColor" stroke-width="1.6"/>',
    person: '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/>',
    sparkle: '<path d="M12 2l2.1 6.4L20.5 11l-6.4 2.1L12 20l-2.1-6.9L3.5 11l6.4-2.6z"/>',
    paperclip: '<path d="M16 7l-6.5 6.5a3 3 0 0 0 4.2 4.2L20 11a5 5 0 0 0-7-7L6.5 10.5a7 7 0 0 0 9.9 9.9" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
    arrowUp: '<path d="M12 19V5M6 11l6-6 6 6" stroke="currentColor" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    stop: '<rect x="6" y="6" width="12" height="12" rx="2"/>',
    warn: '<path d="M12 3l9.5 17H2.5z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M12 9v5M12 17h.01" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    doc: '<path d="M6 3h8l4 4v14H6z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M14 3v4h4" fill="none" stroke="currentColor" stroke-width="1.6"/>',
    xmark: '<path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/>',
    plus: '<path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    photo: '<rect x="3" y="4" width="18" height="16" rx="3" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="8.5" cy="9" r="1.6"/><path d="M4 18l5-5 3.5 3.5L16 13l4 4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>',
    server: '<rect x="3" y="4" width="18" height="6" rx="2" fill="none" stroke="currentColor" stroke-width="1.5"/><rect x="3" y="14" width="18" height="6" rx="2" fill="none" stroke="currentColor" stroke-width="1.5"/><circle cx="7" cy="7" r="1"/><circle cx="7" cy="17" r="1"/>',
    aspect: '<rect x="3" y="5" width="18" height="14" rx="2" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M7 9h6M7 9v6M17 15h-6M17 15V9" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    wand: '<path d="M4 20L16 8M14 4l.8 2.2L17 7l-2.2.8L14 10l-.8-2.2L11 7l2.2-.8zM20 12l.6 1.6L22 14l-1.4.6L20 16l-.6-1.4L18 14l1.4-.4z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',
    refresh: '<path d="M20 11a8 8 0 1 0-2 6M20 5v6h-6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
    trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>',
    aSquare: '<rect x="3" y="3" width="18" height="18" rx="4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M8 16l3.2-8L14.5 16M9.2 13h4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
    branch: '<circle cx="6" cy="5" r="2"/><circle cx="18" cy="7" r="2"/><circle cx="12" cy="19" r="2"/><path d="M6 7v3a4 4 0 0 0 4 4h2M18 9v3a4 4 0 0 1-4 4h-2" fill="none" stroke="currentColor" stroke-width="1.6"/>',
    triangle: '<path d="M12 4l9 16H3z"/>',
    at: '<circle cx="12" cy="12" r="4.2" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M16 8v5a2.5 2.5 0 0 0 5 0v-1a9 9 0 1 0-3.5 7" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
    paperplane: '<path d="M21 3L3 10l7 3 3 7z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M10 13L21 3" stroke="currentColor" stroke-width="1.6"/>',
    heart: '<path d="M12 20s-8-4.9-8-10.5A4.5 4.5 0 0 1 12 7a4.5 4.5 0 0 1 8 2.5C20 15.1 12 20 12 20z" fill="none" stroke="currentColor" stroke-width="1.6"/>',
    code: '<path d="M8 8l-4 4 4 4M16 8l4 4-4 4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
    folder: '<path d="M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" fill="none" stroke="currentColor" stroke-width="1.6"/>',
    copy: '<rect x="8" y="8" width="12" height="12" rx="2" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3" fill="none" stroke="currentColor" stroke-width="1.6"/>',
    gear: '<circle cx="12" cy="12" r="3.2" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9L17 7M7 17l-2.1 2.1" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
  };
  const sf = (name, cls = '') => `<svg class="sf ${cls}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">${P[name] || P.sparkle}</svg>`;

  /* ── exact strings from the Swift sources ─────────────────────────── */
  const TXT = {
    adLabel: 'Реклама', adName: 'CheapVibeCode', adSub: 'Дешёвые токены для 30+ ИИ-моделей',
    adURL: 'https://cheapvibecode.ru/ref/FJEU3K8DC9',
    reminderText: 'Напоминание для 7-дневной подписи SideStore/Sideloadly. Отсчёт от первого запуска или ручного сброса, не фактический срок сертификата. Можно обновить подпись без удаления приложения.',
    reminderReset: 'Я обновил приложение',
    welcomeTitle: 'Давай начнём.',
    welcomeSub: 'Твои модели. Твои идеи.\nОдин спокойный уголок для диалогов.',
    connectProvider: 'Подключить провайдера',
    emptyChats: 'Чатов пока нет,\nно творить волшебство можно начать в любой момент',
    newChat: 'Новый чат',
    promptChat: 'Напиши что-нибудь…', promptImage: 'Опиши изображение…',
    heroTitle: 'Image Studio', heroSub: 'Опиши идею — модель нарисует её.',
    emptyGallery: 'Здесь появятся сгенерированные изображения.',
    mediaNotice: 'Добавление API-ключа не гарантирует генерацию изображений, видео и аудио. В klain раздел «Картинки» работает, если выбранный провайдер и модель поддерживают отдельный API генерации изображений.',
    gatewayHint: 'Для своего шлюза можно оставить ключ пустым и задать авторизацию через заголовки.',
    visionHint: 'Бейдж «видит фото» отмечает модели, которым можно отправлять изображения.',
    providersFoot: 'Ключи и пользовательские заголовки хранятся в Keychain. Список моделей приходит от провайдера: доступ зависит от тарифа и прав ключа.',
    settingsFoot: 'klain — песочница для запросов к ИИ по твоим API-ключам. Генерация изображений доступна, если её поддерживает провайдер и выбранная модель.',
    statsFoot: 'Только usage, полученный от API. Пропущенные и старые ответы не оцениваются. Стоимость может быть известна лишь для части запросов. Кэшированные токены входят во входящие.',
    limitsFoot: 'Rate limit — временный лимит запросов, а не купленные токены. Баланс доступен не для всех провайдеров; остальные значения показываются только при наличии в заголовках API.',
    deleteTitle: 'Удалить чат?',
    deleteMsg: 'Все локальные данные чата, вложения и его статистика будут стёрты. Восстановить их нельзя. Данные у API-провайдера это не удаляет.',
  };
  const AUTHOR_LINKS = [
    ['GitHub · miiko3', 'code', 'https://github.com/miiko3'],
    ['Threads · @klain_app', 'at', 'https://www.threads.com/@klain_app'],
    ['Telegram · @yetilov', 'paperplane', 'https://t.me/yetilov'],
    ['Boosty · поддержать', 'heart', 'https://boosty.to/miilo3'],
  ];

  let view = 'home', params = {};
  let toastTimer = null, sending = false, generationAbort = null, imageBusy = false;
  let inputText = '', attachments = [], editDraft = null;
  let imagePrompt = '', imageActivePrompt = '', imageModel = '', imageSize = '1024x1024', imageProviderID = null;
  let imageQuery = '';
  let balances = {}, remaining = {};
  let modelsLoading = false, providerError = '', editorQuery = '', popKind = null;
  let reminderStart = 0;
  // Auto-scroll follows the stream ONLY while the user is (or was) pinned to
  // the bottom. Scrolling up by hand disables it until they return.
  let followTail = true;
  let savedScrollTop = null;

  const app = () => $('#app');
  const S = () => L.get();
  const chat = () => L.selectedChat();
  const provider = () => L.activeProvider();

  function toast(msg) {
    let el = $('.toast');
    if (!el) { el = document.createElement('div'); el.className = 'toast'; document.body.appendChild(el); }
    el.textContent = msg; el.classList.remove('hidden');
    clearTimeout(toastTimer); toastTimer = setTimeout(() => el.classList.add('hidden'), 3800);
  }

  function applyTheme() {
    const t = S().theme, r = document.documentElement.style;
    r.setProperty('--accent', t.accent); r.setProperty('--accent2', t.accent2);
    r.setProperty('--bg', t.background); r.setProperty('--panel', t.panel);
    r.setProperty('--radius', t.radius + 'px');
    r.setProperty('--font-scale', t.fontScale); r.setProperty('--density', t.density);
    r.setProperty('--glass', t.glass);
    document.body.classList.toggle('light', !t.dark);
  }

  /* ── chrome ───────────────────────────────────────────────────────── */
  function nav(title, left = '', right = '') {
    return `<div class="navbar">
      <div class="side">${left}</div>
      <div class="title">${title}</div>
      <div class="side right">${right || '<span style="width:8px"></span>'}</div>
    </div>`;
  }
  const backBtn = (to = 'home') => `<button class="navbtn backbtn" data-go="${to}" title="Назад">${sf('chevL')} Назад</button>`;
  const iconBtn = (icon, act, title) => `<button class="navbtn icon" data-act="${act}" title="${title}">${sf(icon)}</button>`;

  function render() {
    applyTheme();
    // Preserve the exact scroll offset across a full DOM rebuild so no token,
    // popover or remote sync can yank the chat back to the bottom.
    const old = $('#messages');
    if (view === 'chat' && old) savedScrollTop = old.scrollTop;
    let html = '<div class="liquid"><i></i><i></i><i></i></div>';
    switch (view) {
      case 'home': html += screenHome(); break;
      case 'chats': html += screenChats(); break;
      case 'chat': html += screenChat(); break;
      case 'images': html += screenImages(); break;
      case 'settings': html += screenSettings(); break;
      case 'providers': html += screenProviders(); break;
      case 'editor': html += screenEditor(); break;
      case 'stats': html += screenStats(); break;
    }
    app().innerHTML = html;
    wire();
    if (view === 'chat') {
      const el = $('#messages');
      if (el) {
        el.scrollTop = savedScrollTop != null ? savedScrollTop : el.scrollHeight;
        attachScrollFollow(el);
      }
      savedScrollTop = null;
    }
    followTail = view !== 'chat' ? true : followTail;
  }

  /* ── Home (ContentView.home + HomeBanner + SigningReminder) ───────── */
  function screenHome() {
    if (!reminderStart) reminderStart = Date.now() / 1000;
    const days = Math.max(0, Math.ceil((reminderStart + 7 * 86400 - Date.now() / 1000) / 86400));
    const rlabel = days === 0 ? 'Обновите подпись приложения' : `Переустановите приложение через ${days} дн.`;
    return nav('klain', '', '') + `<div class="large-title-row">
      <img class="brand-logo" src="/app/assets/logo.png" alt="klain">
      <span>klain</span>
    </div>
    <div class="screen">
      <a class="ad glass" href="${TXT.adURL}" target="_blank" rel="noopener">
        <img src="/app/assets/ad_logo.png" alt="">
        <span class="txt"><small>${TXT.adLabel}</small><b>${TXT.adName}</b><em>${TXT.adSub}</em></span>
        <span class="arr">${sf('arrowUR')}</span>
      </a>
      <div class="reminder glass">
        <div class="rl">${sf('clock')}<span>${esc(rlabel)}</span></div>
        <p>${TXT.reminderText}</p>
        <button data-act="reset-reminder">${TXT.reminderReset}</button>
      </div>
    </div>
    <div class="home-menu-wrap">
      <div class="home-menu glass">
        <button data-go="chats">${sf('chats')}<span>Чаты</span></button>
        <button data-go="images">${sf('sparkles')}<span>Картинки</span></button>
        <button data-go="settings">${sf('sliders')}<span>Настройки</span></button>
      </div>
    </div>`;
  }

  /* ── Chats list ───────────────────────────────────────────────────── */
  function screenChats() {
    const active = S().chats.filter((c) => !c.archived);
    const arch = S().chats.filter((c) => c.archived);
    const rows = (list, archived) => list.map((c) => `
      <div class="row glass" data-open-chat="${c.id}">
        <span class="emoji">${esc(c.emoji || '💬')}</span>
        <span class="grow"><b>${esc(c.title)}</b><small>${esc(c.model || '')}</small></span>
        <button class="del" data-archive="${c.id}" title="${archived ? 'Вернуть' : 'В архив'}">${archived ? '↩' : '📦'}</button>
        <button class="del" data-del-chat="${c.id}" title="Удалить">${sf('xmark')}</button>
        <span class="chev">${sf('chevR')}</span>
      </div>`).join('');
    const right = active.length ? `<button class="navbtn icon" data-act="new-chat" title="${TXT.newChat}">${sf('pencil')}</button>` : '';
    return nav('Чаты', backBtn(), right) + `<div class="screen">
      ${!active.length && !arch.length ? `<div class="empty-card glass">
        <span class="big">🪄</span><p>${TXT.emptyChats}</p>
        <button class="btn primary" data-act="new-chat">${sf('pencil')} ${TXT.newChat}</button>
      </div>` : ''}
      ${active.length ? `<div class="section-head">Диалоги</div>${rows(active, false)}` : ''}
      ${arch.length ? `<div class="section-head">Архивы</div>${rows(arch, true)}` : ''}
    </div>`;
  }

  /* ── Chat detail ──────────────────────────────────────────────────── */
  function screenChat() {
    const c = chat(), p = provider();
    if (!c) return nav('Новый чат', backBtn('chats'), '') + '<div class="screen"><div class="empty-note">Чат не найден</div></div>';
    const entry = (p?.models || []).find((m) => m.id === c.model);
    const vision = entry?.inputModalities?.includes('image');
    const reasoningLabel = c.reasoning === 'xhigh' ? 'xHigh' : (c.reasoning || 'default').replace(/^./, (x) => x.toUpperCase());
    const msgs = c.messages.map((m) => {
      const imgs = (m.attachments || []).filter((a) => a.mime.startsWith('image/'));
      const files = (m.attachments || []).filter((a) => !a.mime.startsWith('image/'));
      const isUser = m.role === 'user';
      const waiting = sending && m.id === c.messages[c.messages.length - 1]?.id && !m.text && !m.failed;
      return `<div class="msg glass ${isUser ? 'user user-tint' : ''} ${m.failed ? 'failed' : ''}">
        <div class="who">${sf(isUser ? 'person' : 'sparkle')} ${isUser ? 'ТЫ' : esc(m.modelName || 'Модель')}</div>
        ${!isUser && (waiting || m.thinking) ? `<details class="thinking" ${waiting ? 'open' : ''}><summary>${waiting && !m.text ? 'Думает…' : 'Мышление'} ${waiting ? '<span class="typing"><i></i><i></i><i></i></span>' : ''}</summary>${esc(m.thinking || 'Провайдер не передаёт текст рассуждений.')}</details>` : ''}
        ${imgs.length ? `<div class="attach-row">${imgs.map((a) => `<img src="data:${esc(a.mime)};base64,${a.data}">`).join('')}</div>` : ''}
        ${files.map((a) => `<div class="fileline">${sf('doc')} ${esc(a.name)}</div>`).join('')}
        ${m.text ? `<div class="body md-body">${vm(m.text)}</div>` : (waiting ? `<div class="body md-body"><span class="typing"><i></i><i></i><i></i></span></div>` : '')}
        ${(m.media || []).map((g) => `<img class="genimg" src="${esc(g.url)}" onerror="this.style.display='none'">`).join('')}
        ${m.usage ? `<div class="usage">↑ ${m.usage.input ?? '—'}   ↓ ${m.usage.output ?? '—'} токенов</div>` : ''}
      </div>`;
    }).join('');
    const warn = L.imageSupportWarning(attachments), hard = L.imageSupportError(attachments);
    return nav(esc(c.title), backBtn('chats'),
      iconBtn('chart', 'open-stats', 'Статистика') + iconBtn('sliders', 'open-providers', 'Провайдеры')) + `
    <div class="controls">
      <div class="menu-wrap">
        <button class="chip capsule" data-pop="model">${vision ? sf('camera') : ''}<span class="ct">${esc(c.model || 'Выбрать модель')}</span>${sf('chevD')}</button>
        <span id="pop-anchor"></span>
      </div>
      <div class="menu-wrap">
        <button class="chip capsule web" data-pop="reasoning">${sf('brain')}<span>${esc(reasoningLabel)}</span>${sf('chevD')}</button>
      </div>
      <button class="chip capsule web ${c.webSearch ? 'on' : ''}" data-act="toggle-web" title="Веб-поиск выполняет провайдер">${sf('globe')} Сеть</button>
    </div>
    <div class="messages" id="messages">
      ${c.messages.length ? msgs : `<div class="welcome glass">
        <div class="wcircle">${esc(c.emoji || '✨')}</div>
        <h2>${TXT.welcomeTitle}</h2>
        <p>${TXT.welcomeSub}</p>
        ${!S().providers.length ? `<button class="btn" data-go="settings">${sf('plus')} ${TXT.connectProvider}</button>` : ''}
      </div>`}
    </div>
    <button class="jump-bottom capsule hidden" data-act="jump-bottom" title="К последнему сообщению">${sf('chevD')}</button>
    <div class="composer-outer">
      <div class="composer glass">
        ${attachments.length ? `<div class="thumbs">${attachments.map((a, i) => `<div class="thumb">${a.mime.startsWith('image/') ? `<img src="data:${esc(a.mime)};base64,${a.data}">` : `<div class="file">${sf('doc')}</div>`}<button data-rm-attach="${i}">${sf('xmark')}</button></div>`).join('')}</div>` : ''}
        <textarea id="input" placeholder="${TXT.promptChat}" rows="1">${esc(inputText)}</textarea>
        ${warn ? `<div class="notice ${hard ? 'err' : 'warn'}">${sf('warn')}<span>${esc(warn)}</span></div>` : ''}
        ${sending ? '<div class="progress"><i></i></div>' : ''}
        <div class="tools">
          <div class="menu-wrap">
            <button class="iconbtn capsule" data-pop="attach" title="Прикрепить">${sf('paperclip')}</button>
          </div>
          <span class="grow"></span>
          <button class="send ${sending ? 'stop' : ''}" data-act="${sending ? 'stop' : 'send'}"
            ${!sending && (hard || !p || !c.model || (!inputText.trim() && !attachments.length)) ? 'disabled' : ''}>
            ${sf(sending ? 'stop' : 'arrowUp')}
          </button>
        </div>
        <input type="file" id="file-input" class="hidden" multiple>
      </div>
    </div>`;
  }

  /* ── Settings ─────────────────────────────────────────────────────── */
  function screenSettings() {
    return nav('Настройки', backBtn(), '') + `<div class="screen">
      <div class="section-head">Настройки</div>
      <button class="row glass" data-go="providers"><span class="ico">${sf('sliders')}</span><span class="grow"><b>Провайдеры</b></span><span class="chev">${sf('chevR')}</span></button>
      <button class="row glass" data-go="stats"><span class="ico">${sf('chart')}</span><span class="grow"><b>Статистика</b></span><span class="chev">${sf('chevR')}</span></button>
      <button class="row glass" data-go="images"><span class="ico">${sf('sparkles')}</span><span class="grow"><b>Картинки</b></span><span class="chev">${sf('chevR')}</span></button>
      <div class="section-head">Автор</div>
      ${AUTHOR_LINKS.map(([t, i, u]) => `<a class="row glass" href="${u}" target="_blank" rel="noopener" style="text-decoration:none;color:inherit"><span class="ico">${sf(i)}</span><span class="grow"><b>${t}</b></span><span class="arr" style="color:var(--tertiary)">${sf('arrowUR')}</span></a>`).join('')}
      <div class="section-foot">${TXT.settingsFoot}</div>
      <div class="section-foot" style="padding-top:16px">
        <button class="btn" data-act="reveal-state">${sf('folder')} Показать файл состояния</button>
      </div>
    </div>`;
  }

  /* ── Providers ────────────────────────────────────────────────────── */
  function screenProviders() {
    const list = S().providers;
    return nav('Провайдеры', '<button class="navbtn" data-go="settings">Назад</button>', '<button class="navbtn" data-go="settings">Готово</button>') + `<div class="screen">
      <div class="section-head">Черновики</div>
      ${S().drafts.length ? S().drafts.map((d) => `<div class="row glass" data-edit-provider="${esc(d.id)}"><span class="ico">${sf('pencil')}</span><span class="grow"><b>${esc(d.name || 'Новый провайдер')}</b></span><span class="chev">${sf('chevR')}</span></div>`).join('') : '<div class="section-foot" style="padding-left:20px">Нет черновиков</div>'}
      <div class="section-head">Подключено</div>
      ${list.length ? list.map((x) => `<div class="row glass" data-edit-provider="${esc(x.id)}">
          <span class="ico">${sf('branch')}</span><span class="grow"><b>${esc(x.name)}</b><small>${esc(x.baseURL || '')}</small></span>
          <span class="badge-count">${(x.models || []).length} моделей</span>
          <button class="del" data-del-provider="${esc(x.id)}">${sf('trash')}</button><span class="chev">${sf('chevR')}</span>
        </div>`).join('') : '<div class="section-foot" style="padding-left:20px">Добавь свой первый API-ключ</div>'}
      <div class="section-head">Добавить провайдера</div>
      ${L.PRESETS.map((x) => `<button class="row glass preset" data-preset="${esc(x.id)}"><span class="ico">${sf(x.symbol || 'sliders')}</span><span class="grow"><b>${esc(x.name)}</b><span class="url">${esc(x.url || '')}</span></span><span class="chev">${sf('plus')}</span></button>`).join('')}
      <div class="section-foot">${TXT.providersFoot}</div>
    </div>`;
  }

  /* ── Provider editor ──────────────────────────────────────────────── */
  function screenEditor() {
    const p = editDraft || { id: L.uid(), name: '', baseURL: '', apiKey: '', kind: 'custom', slug: 'custom', models: [], headers: [] };
    const models = p.models || [];
    const q = editorQuery.toLowerCase();
    const shown = models.map((m, i) => ({ m, i })).filter(({ m }) => !q || (m.id + ' ' + m.name).toLowerCase().includes(q));
    return nav(esc(p.name || 'Новый провайдер'),
      '<button class="navbtn" data-go="providers">Назад</button>',
      '<button class="navbtn" data-act="save-provider">Сохранить</button>') + `<div class="screen">
      ${providerError ? `<div class="err-card glass">${esc(providerError)}</div>` : ''}
      <div class="form-card glass">
        <h3>Подключение</h3>
        <label class="field"><span>ID провайдера</span><input id="e-slug" value="${esc(p.slug || 'custom')}" placeholder="ID провайдера"></label>
        <label class="field"><span>Протокол</span><select id="e-kind">
          <option value="custom" ${p.kind === 'custom' ? 'selected' : ''}>OpenAI-совместимый</option>
          <option value="anthropic" ${p.kind === 'anthropic' ? 'selected' : ''}>Anthropic (/messages)</option>
          <option value="google" ${p.kind === 'google' ? 'selected' : ''}>Google</option>
          <option value="openrouter" ${p.kind === 'openrouter' ? 'selected' : ''}>OpenRouter</option>
        </select></label>
        <label class="field"><span>Имя</span><input id="e-name" value="${esc(p.name)}" placeholder="Отображаемое имя"></label>
        <label class="field"><span>Base URL</span><input id="e-url" value="${esc(p.baseURL)}" placeholder="Базовый URL"></label>
        <label class="field"><span>Ключ API</span><input id="e-key" type="password" value="${esc(p.apiKey)}" placeholder="Ключ API (необязательно)"></label>
        <div class="section-foot" style="padding:4px 0 0">${TXT.mediaNotice}</div>
        <div class="section-foot" style="padding:4px 0 0">${TXT.gatewayHint}</div>
      </div>
      <div class="form-card glass">
        <h3>Модели</h3>
        <button class="btn full" data-act="load-models" ${modelsLoading ? 'disabled' : ''}>${sf('refresh')} ${modelsLoading ? 'Загрузка…' : 'Загрузить модели из API'}</button>
        <label class="field" style="margin-top:10px"><span>Фильтр</span><input id="e-filter" value="${esc(editorQuery)}" placeholder="Фильтр моделей"></label>
        ${models.some((m) => m.inputModalities?.includes('image')) ? `<div class="section-foot" style="padding:2px 0 8px">${TXT.visionHint}</div>` : ''}
        <div id="model-list">${shown.map(({ m, i }) => `
          <div class="model-row">
            <input data-model-id="${i}" value="${esc(m.id)}" placeholder="model-id">
            <input data-model-name="${i}" value="${esc(m.name || '')}" placeholder="Отображаемое имя">
            ${m.inputModalities?.includes('image') ? `<span class="vision-badge">${sf('camera')} видит фото</span>` : '<span class="text-badge">текст</span>'}
            <button class="rm-btn" data-rm-model="${i}">${sf('trash')}</button>
          </div>`).join('')}</div>
        <button class="btn" data-act="add-model">${sf('plus')} Добавить модель</button>
      </div>
      <div class="form-card glass">
        <h3>Заголовки</h3>
        <div id="header-list">${(p.headers || []).map((h, i) => `
          <div class="model-row">
            <input data-header-name="${i}" value="${esc(h.name)}" placeholder="Header-Name">
            <input data-header-value="${i}" value="${esc(h.value)}" placeholder="Значение" type="password">
            <button class="rm-btn" data-rm-header="${i}">${sf('trash')}</button>
          </div>`).join('')}</div>
        <button class="btn" data-act="add-header">${sf('plus')} Добавить заголовок</button>
      </div>
      <div style="padding:0 16px 10px"><button class="btn primary full" data-act="save-provider">Сохранить</button></div>
    </div>`;
  }

  /* ── Image Studio ─────────────────────────────────────────────────── */
  function screenImages() {
    const p = S().providers.find((x) => x.id === imageProviderID) || provider();
    const models = L.imageModels(p);
    if (!imageModel || !models.some((m) => m.id === imageModel)) imageModel = models[0]?.id || '';
    const imgs = S().generatedImages;
    const displayName = models.find((m) => m.id === imageModel)?.name || (imageModel ? imageModel : 'Модель не выбрана');
    const dot = S().providers.length ? 'var(--mint)' : 'orange';
    return nav('Картинки', backBtn(), iconBtn('sliders', 'open-providers', 'Провайдеры')) + `
    <div class="screen" style="padding-bottom:0">
      <div class="hero">
        <div class="status-line"><span class="dot" style="background:${dot}"></span>${S().providers.length ? 'API подключён' : 'API не настроен'}</div>
        <h2>${TXT.heroTitle}</h2><p>${TXT.heroSub}</p>
      </div>
      ${!imgs.length && !imageBusy ? `<div class="empty-note">${sf('photo')}<span class="big"></span>${TXT.emptyGallery}</div>` : ''}
      <div class="form-card glass">
        <div class="gallery-head"><b>История</b><span>${imgs.length}</span></div>
        ${imgs.length ? `<div class="grid">${imgs.map((g) => `<div class="cell"><img src="${esc(g.url)}" data-open-image="${esc(g.id)}"><small>${esc(g.model)}</small><button data-del-image="${esc(g.id)}">${sf('xmark')}</button></div>`).join('')}</div>` : '<div class="section-foot" style="padding:0">Пока пусто</div>'}
      </div>
    </div>
    <div class="composer-outer">
      <div class="composer glass">
        ${imageBusy ? `<div class="gen-row"><div class="grow"><b>Генерирую…</b><small>Обычно 10–60 секунд</small>${imageActivePrompt ? `<div class="gen-prompt">${esc(imageActivePrompt)}</div>` : ''}</div><div class="progress" style="width:70px"><i></i></div></div>` : ''}
        ${imageBusy ? '' : `<textarea id="image-input" placeholder="${TXT.promptImage}" rows="2">${esc(imagePrompt)}</textarea>`}
        ${S().providers.length ? `<div class="controls" style="padding:0;border:0;flex-wrap:wrap">
          <div class="menu-wrap"><button class="chip small capsule" data-pop="image-provider">${sf('server')}<span>${esc(p?.name || 'Провайдер')}</span>${sf('chevD')}</button></div>
          <div class="menu-wrap"><button class="chip small capsule" data-pop="image-model">${sf('sparkles')}<span>${esc(displayName)}</span>${sf('chevD')}</button></div>
          <div class="menu-wrap"><button class="chip small capsule" data-pop="image-size">${sf('aspect')}<span>${esc(imageSize)}</span>${sf('chevD')}</button></div>
        </div>` : ''}
        <div class="tools">
          ${imagePrompt && !imageBusy ? `<button class="btn plain" data-act="clear-image">Очистить</button>` : ''}
          <span class="grow"></span>
          ${!S().providers.length ? `<button class="btn primary" data-go="settings">Подключить API</button>`
            : imageBusy ? `<button class="btn" data-act="cancel-image">${sf('stop')} Отменить</button>`
            : `<button class="btn primary" data-act="generate-image" ${!imagePrompt.trim() || !imageModel ? 'disabled' : ''}>${sf('wand')} Сгенерировать</button>`}
        </div>
      </div>
    </div>`;
  }

  /* ── Statistics ───────────────────────────────────────────────────── */
  function screenStats() {
    const rec = S().records;
    const inSum = rec.reduce((a, r) => a + (r.usage.input || 0), 0);
    const outSum = rec.reduce((a, r) => a + (r.usage.output || 0), 0);
    const cost = rec.reduce((a, r) => a + (r.usage.cost || 0), 0);
    const groups = {};
    for (const r of rec) { const k = `${r.providerName} / ${r.model}`; (groups[k] = groups[k] || []).push(r); }
    const byChat = {};
    for (const r of rec) { const k = r.chatTitle || 'Чат'; (byChat[k] = byChat[k] || []).push(r); }
    const usageRow = (title, list) => `<div class="stat"><span class="grow">${esc(title)}<span class="sub">↑ ${list.reduce((a, r) => a + (r.usage.input || 0), 0)}  ↓ ${list.reduce((a, r) => a + (r.usage.output || 0), 0)} • ${list.length} ответов</span></span></div>`;
    return nav('Статистика', '<button class="navbtn" data-go="settings">Назад</button>', '<button class="navbtn" data-go="settings">Готово</button>') + `<div class="screen">
      <div class="section-head">Токены • это устройство</div>
      <div class="form-card glass" style="padding:0">
        <div class="stat"><span>Входящие</span><span class="v">${rec.some((r) => r.usage.input != null) ? inSum.toLocaleString() : 'Нет данных'}</span></div>
        <div class="stat"><span>Исходящие</span><span class="v">${rec.some((r) => r.usage.output != null) ? outSum.toLocaleString() : 'Нет данных'}</span></div>
        <div class="stat"><span>Учтено ответов</span><span class="v">${rec.length.toLocaleString()}</span></div>
        ${cost ? `<div class="stat"><span>Стоимость, сообщённая API</span><span class="v">$${cost.toFixed(5)}</span></div>` : ''}
      </div>
      <div class="section-foot">${TXT.statsFoot}</div>
      <div class="section-head">По моделям</div>
      <div class="form-card glass" style="padding:0">${Object.keys(groups).length ? Object.keys(groups).sort().map((k) => usageRow(k, groups[k])).join('') : '<div class="section-foot" style="padding:10px 14px">Нет данных</div>'}</div>
      <div class="section-head">По чатам</div>
      <div class="form-card glass" style="padding:0">${Object.keys(byChat).length ? Object.keys(byChat).sort().map((k) => usageRow(k, byChat[k])).join('') : '<div class="section-foot" style="padding:10px 14px">Нет данных</div>'}</div>
      <div class="section-head">Остаток и лимиты</div>
      <div class="form-card glass" style="padding:0">
        ${S().providers.map((x) => `<div class="stat"><span class="grow">${esc(x.name)}<span class="sub">${esc(remaining[x.id] || 'Остаток токенов: нет данных')}</span><span class="sub">${esc(balances[x.id] || 'Баланс: не запрошен')}</span></span></div>`).join('') || '<div class="section-foot" style="padding:10px 14px">Нет провайдеров</div>'}
        <div style="padding:10px 14px"><button class="btn full" data-act="refresh-balance">${sf('refresh')} Обновить баланс</button></div>
      </div>
      <div class="section-foot">${TXT.limitsFoot}</div>
    </div>`;
  }

  /* ── Markdown (GFM-like) ────────────────────────────────────────────
   * Replaces the tiny MarkdownMessage.swift subset. Renders headings, fenced
   * code (with language label), tables, ordered/unordered/task/nested lists,
   * blockquotes, horizontal rules, paragraphs + full inline formatting.
   * All user/model text is HTML-escaped before inline parsing. */
  function safeURL(u) {
    return /^(https?:\/\/|mailto:|#|\/)/i.test(u) && !/[\u0000-\u001f"']/.test(u) && !/^javascript:/i.test(u);
  }
  function inlineMd(escaped) {
    const stash = [];
    const hold = (html) => { stash.push(html); return `\u0001${stash.length - 1}\u0001`; };
    let t = escaped;
    // Protect inline code first so its contents are never re-parsed.
    t = t.replace(/`([^`\n]+)`/g, (_m, c) => hold(`<code class="mdcode">${c}</code>`));
    t = t.replace(/!\[([^\]]*)\]\(([^)\s]+)\)/g, (_m, alt, url) =>
      safeURL(url) ? hold(`<img class="mdimg" src="${url}" alt="${alt}" loading="lazy" onerror="this.style.display='none'">`) : alt);
    t = t.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_m, txt, url) =>
      safeURL(url) ? hold(`<a class="mdlink" href="${url}" target="_blank" rel="noopener noreferrer">${txt}</a>`) : txt);
    t = t.replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>');
    t = t.replace(/__([^_\n]+)__/g, '<strong>$1</strong>');
    t = t.replace(/~~([^~\n]+)~~/g, '<del>$1</del>');
    t = t.replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, '$1<em>$2</em>');
    t = t.replace(/(^|[^_\w])_([^_\n]+)_(?!_)/g, '$1<em>$2</em>');
    return t.replace(/\u0001(\d+)\u0001/g, (_m, n) => stash[+n]);
  }
  const mdInline = (raw) => inlineMd(esc(raw));
  const mdItem = (l) => l.match(/^(\s*)([-*+]|\d+[.)])\s+(.*)$/);
  function mdList(lines, i, indent) {
    const first = mdItem(lines[i]);
    const ordered = /^\d/.test(first[2]);
    let html = ordered ? '<ol class="mdlist">' : '<ul class="mdlist">';
    while (i < lines.length) {
      const m = mdItem(lines[i]);
      if (!m || m[1].length < indent) break;
      if (m[1].length > indent) break; // consumed by the parent's nested step
      let content = m[3];
      const task = content.match(/^\[([ xX])\]\s*(.*)$/);
      let cls = '', prefix = '';
      if (task) {
        const done = /[xX]/.test(task[1]);
        cls = ` class="mdtask${done ? ' done' : ''}"`;
        prefix = `<span class="mdcheck">${done ? '✓' : ''}</span>`;
        content = task[2];
      }
      i++;
      // lazy continuation lines
      while (i < lines.length) {
        if (mdItem(lines[i]) || lines[i].trim() === '') break;
        content += ' ' + lines[i].trim(); i++;
      }
      let inner = '';
      if (i < lines.length) {
        const nm = mdItem(lines[i]);
        if (nm && nm[1].length > indent) { const r = mdList(lines, i, nm[1].length); inner = r.html; i = r.next; }
      }
      html += `<li${cls}>${prefix}<span>${mdInline(content)}</span>${inner}</li>`;
      if (i < lines.length && lines[i].trim() === '') {
        let j = i; while (j < lines.length && lines[j].trim() === '') j++;
        const nn = mdItem(lines[j]);
        if (nn && nn[1].length === indent) i = j; else break;
      }
    }
    html += ordered ? '</ol>' : '</ul>';
    return { html, next: i };
  }
  function vm(s) {
    if (!s) return '';
    const lines = String(s).replace(/\r\n?/g, '\n').split('\n');
    const out = [];
    let i = 0;
    while (i < lines.length) {
      const line = lines[i], trimmed = line.trim();
      if (trimmed === '') { i++; continue; }

      // fenced code block
      const fence = trimmed.match(/^```+\s*([\w+.#-]*)\s*$/);
      if (fence) {
        const lang = fence[1] || '', code = [];
        i++;
        while (i < lines.length && !/^\s*```+\s*$/.test(lines[i])) { code.push(lines[i]); i++; }
        i++; // closing fence (or EOF)
        out.push(`<div class="codeblock"><div class="cbhead">${lang ? `<span class="cblang">${esc(lang)}</span>` : '<span></span>'}<button class="cbtn" data-act="copy-code">${sf('copy')} Копировать код</button></div><pre><code>${esc(code.join('\n'))}</code></pre></div>`);
        continue;
      }
      // heading (requires a space — avoids misreading "#include")
      const h = trimmed.match(/^(#{1,6})\s+(.*)$/);
      if (h) { const lv = h[1].length; out.push(`<h${lv} class="mdh">${mdInline(h[2])}</h${lv}>`); i++; continue; }
      // horizontal rule
      if (/^(\*\s*){3,}$/.test(trimmed) || /^(-\s*){3,}$/.test(trimmed) || /^(_\s*){3,}$/.test(trimmed)) { out.push('<hr class="mdhr">'); i++; continue; }
      // GFM table: header row followed by a delimiter row
      if (trimmed.includes('|') && i + 1 < lines.length && /^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)+\|?\s*$/.test(lines[i + 1])) {
        const cells = (r) => r.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());
        const heads = cells(line);
        const aligns = cells(lines[i + 1]).map((a) => a.startsWith(':') && a.endsWith(':') ? 'center' : a.endsWith(':') ? 'right' : 'left');
        i += 2;
        const rows = [];
        while (i < lines.length && lines[i].trim() && lines[i].includes('|')) { rows.push(cells(lines[i])); i++; }
        let t = '<div class="mdtable-wrap"><table class="mdtable"><thead><tr>';
        heads.forEach((c, j) => { t += `<th style="text-align:${aligns[j] || 'left'}">${mdInline(c)}</th>`; });
        t += '</tr></thead><tbody>';
        for (const r of rows) { t += '<tr>'; heads.forEach((_, j) => { t += `<td style="text-align:${aligns[j] || 'left'}">${mdInline(r[j] || '')}</td>`; }); t += '</tr>'; }
        out.push(t + '</tbody></table></div>'); continue;
      }
      // blockquote
      if (/^>\s?/.test(trimmed)) {
        const q = [];
        while (i < lines.length && /^\s*>/.test(lines[i])) { q.push(lines[i].replace(/^\s*>\s?/, '')); i++; }
        out.push(`<blockquote class="mdquote">${vm(q.join('\n'))}</blockquote>`); continue;
      }
      // lists
      const li = mdItem(line);
      if (li) { const r = mdList(lines, i, li[1].length); out.push(r.html); i = r.next; continue; }
      // paragraph: consecutive ordinary lines, soft breaks preserved
      const para = [];
      while (i < lines.length) {
        const t = lines[i].trim();
        if (t === '' || /^```/.test(t) || /^#{1,6}\s/.test(t) || mdItem(lines[i]) ||
            /^\s*>/.test(lines[i]) || /^(\*\s*){3,}$|^(-\s*){3,}$|^(_\s*){3,}$/.test(t) ||
            (lines[i].includes('|') && i + 1 < lines.length && /^\s*\|?\s*:?-{1,}:?\s*\|/.test(lines[i + 1]))) break;
        const hard = /\s{2,}$/.test(lines[i]);
        para.push(mdInline(t) + (hard ? '<br>' : ''));
        i++;
        if (i < lines.length && lines[i].trim() !== '' && !/^[#>`*-]|\d+[.)]/.test(lines[i].trim())) para.push('<br>');
      }
      if (para.length) out.push(`<p class="mdp">${para.join('')}</p>`);
      else i++; // safety
    }
    return out.join('');
  }

  /* ── popover menus (iOS Menu) ─────────────────────────────────────── */
  function closePop() { $$('.menu-pop').forEach((x) => x.remove()); popKind = null; }
  function popHTML(kind) {
    if (kind === 'model') {
      const c = chat();
      let h = '';
      for (const pr of S().providers) {
        h += `<div class="mhead">${esc(pr.name)}</div>`;
        for (const m of (pr.models || [])) {
          const vis = m.inputModalities?.includes('image') ? sf('camera') : '';
          const sel = pr.id === c?.providerID && m.id === c?.model ? sf('check') : '';
          h += `<button data-val="${esc(pr.id)}|${esc(m.id)}">${vis || sel}<span>${esc(m.name || m.id)}</span></button>`;
        }
      }
      h += `<button data-val="__settings__">${sf('sliders')}<span>Настроить модели…</span></button>`;
      return h;
    }
    if (kind === 'reasoning') {
      const cur = chat()?.reasoning || 'default';
      return ['default', 'low', 'medium', 'high', 'xhigh', 'max'].map((lv) => {
        const label = lv === 'xhigh' ? 'xHigh' : lv.replace(/^./, (x) => x.toUpperCase());
        return `<button data-val="${lv}">${sf(cur === lv ? 'check' : 'brain')}<span>${label}</span></button>`;
      }).join('');
    }
    if (kind === 'attach') {
      return `<button data-val="attach-file">${sf('folder')}<span>Файлы</span></button>
              <button data-val="attach-photo">${sf('photo')}<span>Галерея</span></button>
              <button data-val="attach-camera">${sf('camera')}<span>Камера</span></button>`;
    }
    if (kind === 'image-provider') {
      return S().providers.map((x) => `<button data-val="${esc(x.id)}">${sf(imageProviderID === x.id ? 'check' : 'server')}<span>${esc(x.name)}</span></button>`).join('');
    }
    if (kind === 'image-model') {
      const p = S().providers.find((x) => x.id === imageProviderID) || provider();
      return L.imageModels(p).map((m) => `<button data-val="${esc(m.id)}">${sf(imageModel === m.id ? 'check' : 'sparkles')}<span>${esc(m.name || m.id)}</span></button>`).join('');
    }
    if (kind === 'image-size') {
      return L.IMAGE_SIZES.map((s) => `<button data-val="${s}">${sf(imageSize === s ? 'check' : 'aspect')}<span>${s}</span></button>`).join('');
    }
    return '';
  }
  function showPop(kind, btn) {
    if (popKind === kind) { closePop(); return; }
    closePop(); popKind = kind;
    const pop = document.createElement('div');
    pop.className = 'menu-pop' + (kind.startsWith('image-') || kind === 'reasoning' ? ' right' : '');
    pop.innerHTML = popHTML(kind);
    const wrap = btn.closest('.menu-wrap') || btn.parentElement;
    wrap.appendChild(pop);
    pop.querySelectorAll('button[data-val]').forEach((b) => b.onclick = (e) => {
      e.stopPropagation(); const v = b.dataset.val; closePop(); applyPop(kind, v);
    });
  }
  function applyPop(kind, v) {
    if (kind === 'model') {
      if (v === '__settings__') return go('providers');
      const [pid, mid] = v.split('|');
      L.mutate((s) => { const c = L.selectedChat(s); if (c) { c.providerID = pid; c.model = mid; } s.defaultModel = mid; });
      render();
    } else if (kind === 'reasoning') {
      L.mutate((s) => { const c = L.selectedChat(s); if (c) c.reasoning = v; s.settings.reasoning = v; }); render();
    } else if (kind === 'attach') {
      if (v === 'attach-camera') return toast('Камера недоступна');
      const f = $('#file-input'); if (f) { f.accept = v === 'attach-photo' ? 'image/*' : ''; f.click(); }
    } else if (kind === 'image-provider') {
      imageProviderID = v; imageModel = ''; render();
    } else if (kind === 'image-model') {
      imageModel = v; L.mutate((s) => { s.imageModel = v; }); render();
    } else if (kind === 'image-size') {
      imageSize = v; L.mutate((s) => { s.imageSize = v; }); render();
    }
  }

  /* ── wiring ───────────────────────────────────────────────────────── */
  function wire() {
    app().querySelectorAll('[data-go]').forEach((el) => el.onclick = (e) => { e.preventDefault(); go(el.dataset.go); });
    app().querySelectorAll('[data-open-chat]').forEach((el) => el.onclick = (e) => {
      if (e.target.closest('button')) return;
      L.mutate((s) => { s.selectedChatID = el.dataset.openChat; }); go('chat');
    });
    app().querySelectorAll('[data-del-chat]').forEach((el) => el.onclick = (e) => {
      e.stopPropagation(); const id = el.dataset.delChat;
      if (!confirm(TXT.deleteTitle + '\n\n' + TXT.deleteMsg)) return;
      L.mutate((s) => { s.chats = s.chats.filter((c) => c.id !== id); s.records = s.records.filter((r) => r.chatID !== id); if (s.selectedChatID === id) s.selectedChatID = s.chats.find((c) => !c.archived)?.id || null; });
      render();
    });
    app().querySelectorAll('[data-archive]').forEach((el) => el.onclick = (e) => {
      e.stopPropagation(); L.mutate((s) => { const c = s.chats.find((x) => x.id === el.dataset.archive); if (c) c.archived = !c.archived; }); render();
    });
    app().querySelectorAll('[data-edit-provider]').forEach((el) => el.onclick = (e) => {
      if (e.target.closest('[data-del-provider]')) return;
      const id = el.dataset.editProvider;
      editDraft = JSON.parse(JSON.stringify(S().drafts.find((d) => d.id === id) || S().providers.find((x) => x.id === id) || {}));
      providerError = ''; editorQuery = ''; go('editor');
    });
    app().querySelectorAll('[data-del-provider]').forEach((el) => el.onclick = (e) => {
      e.stopPropagation(); if (!confirm('Удалить провайдера и его ключ?')) return;
      L.mutate((s) => { s.providers = s.providers.filter((x) => x.id !== el.dataset.delProvider); }); render();
    });
    app().querySelectorAll('[data-preset]').forEach((el) => el.onclick = () => {
      const pre = L.PRESETS.find((x) => x.id === el.dataset.preset);
      editDraft = { id: L.uid(), name: pre.name, baseURL: pre.url, apiKey: '', kind: pre.id, slug: pre.id, models: [], headers: [] };
      providerError = ''; editorQuery = ''; go('editor');
    });
    app().querySelectorAll('[data-act]').forEach((el) => el.onclick = (e) => onAction(el.dataset.act, el, e));
    app().querySelectorAll('[data-pop]').forEach((el) => el.onclick = (e) => { e.stopPropagation(); showPop(el.dataset.pop, el); });
    app().querySelectorAll('[data-rm-attach]').forEach((el) => el.onclick = () => { attachments.splice(+el.dataset.rmAttach, 1); render(); });
    app().querySelectorAll('[data-del-image]').forEach((el) => el.onclick = (e) => {
      e.stopPropagation(); L.mutate((s) => { s.generatedImages = s.generatedImages.filter((g) => g.id !== el.dataset.delImage); }); render();
    });
    app().querySelectorAll('[data-open-image]').forEach((el) => el.onclick = () => {
      const g = S().generatedImages.find((x) => x.id === el.dataset.openImage); if (g) window.open(g.url, '_blank');
    });
    document.addEventListener('click', (e) => { if (!e.target.closest('.menu-wrap')) closePop(); }, { once: true });

    const input = $('#input');
    if (input) {
      input.oninput = () => { inputText = input.value; input.style.height = 'auto'; input.style.height = Math.min(150, input.scrollHeight) + 'px'; updateSendState(); };
      input.onkeydown = (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } };
    }
    const iinput = $('#image-input');
    if (iinput) iinput.oninput = () => { imagePrompt = iinput.value; const b = $('[data-act="generate-image"]'); if (b) b.disabled = !imagePrompt.trim() || !imageModel; };

    const bind = (id, key) => { const el = $(id); if (el) el.oninput = () => { collectEditor(); editDraft[key] = el.value; }; };
    bind('#e-kind', 'kind'); bind('#e-name', 'name'); bind('#e-url', 'baseURL'); bind('#e-key', 'apiKey'); bind('#e-slug', 'slug');
    const flt = $('#e-filter');
    if (flt) flt.oninput = () => { collectEditor(); editorQuery = flt.value; render(); const f = $('#e-filter'); if (f) { f.focus(); f.setSelectionRange(f.value.length, f.value.length); } };
    app().querySelectorAll('[data-model-id]').forEach((el) => el.oninput = () => { collectEditor(); editDraft.models[+el.dataset.modelId].id = el.value; });
    app().querySelectorAll('[data-model-name]').forEach((el) => el.oninput = () => { collectEditor(); editDraft.models[+el.dataset.modelName].name = el.value; });
    app().querySelectorAll('[data-rm-model]').forEach((el) => el.onclick = () => { collectEditor(); editDraft.models.splice(+el.dataset.rmModel, 1); render(); });
    app().querySelectorAll('[data-header-name]').forEach((el) => el.oninput = () => { collectEditor(); editDraft.headers[+el.dataset.headerName].name = el.value; });
    app().querySelectorAll('[data-header-value]').forEach((el) => el.oninput = () => { collectEditor(); editDraft.headers[+el.dataset.headerValue].value = el.value; });
    app().querySelectorAll('[data-rm-header]').forEach((el) => el.onclick = () => { collectEditor(); editDraft.headers.splice(+el.dataset.rmHeader, 1); render(); });

    const fi = $('#file-input'); if (fi) fi.onchange = () => handleFiles(fi.files);
  }

  function collectEditor() {
    if (!editDraft) return;
    const g = (id) => $(id)?.value;
    if ($('#e-slug')) editDraft.slug = g('#e-slug');
    if ($('#e-kind')) editDraft.kind = g('#e-kind');
    if ($('#e-name')) editDraft.name = g('#e-name');
    if ($('#e-url')) editDraft.baseURL = g('#e-url');
    if ($('#e-key')) editDraft.apiKey = g('#e-key');
    app().querySelectorAll('[data-model-id]').forEach((el) => { editDraft.models[+el.dataset.modelId].id = el.value; });
    app().querySelectorAll('[data-model-name]').forEach((el) => { editDraft.models[+el.dataset.modelName].name = el.value; });
    app().querySelectorAll('[data-header-name]').forEach((el) => { editDraft.headers[+el.dataset.headerName].name = el.value; });
    app().querySelectorAll('[data-header-value]').forEach((el) => { editDraft.headers[+el.dataset.headerValue].value = el.value; });
  }

  function go(v, p = {}) {
    closePop();
    if (v === 'chat' && view !== 'chat') { followTail = true; savedScrollTop = null; }
    view = v; params = p; render();
  }
  function updateSendState() {
    const b = $('[data-act="send"]'); if (!b) return; const c = chat();
    b.disabled = !c || !c.model || !provider() || (!inputText.trim() && !attachments.length) || !!L.imageSupportError(attachments);
  }

  async function onAction(act, el, ev) {
    if (ev) ev.preventDefault();
    try {
      switch (act) {
        case 'reset-reminder': reminderStart = Date.now() / 1000; toast('Таймер обновлён'); render(); break;
        case 'new-chat': {
          if (sending) return;
          const c = L.newChatObject(S());
          L.mutate((s) => { s.chats.unshift(c); s.selectedChatID = c.id; });
          inputText = ''; attachments = []; followTail = true; savedScrollTop = null; go('chat'); break;
        }
        case 'open-stats': go('stats'); break;
        case 'open-providers': go('providers'); break;
        case 'toggle-web': L.mutate((s) => { const c = L.selectedChat(s); if (c) { c.webSearch = !c.webSearch; s.settings.webSearch = c.webSearch; } }); render(); break;
        case 'send': await send(); break;
        case 'stop': generationAbort?.abort(); break;
        case 'jump-bottom': jumpToBottom(); break;
        case 'copy-code': {
          const code = el.closest('.codeblock')?.querySelector('pre code');
          if (code) { try { await navigator.clipboard.writeText(code.textContent); toast('Код скопирован'); } catch { toast('Не удалось скопировать'); } }
          break;
        }
        case 'save-provider': await saveProvider(); break;
        case 'load-models': await loadModels(); break;
        case 'add-model': collectEditor(); editDraft.models = editDraft.models || []; editDraft.models.push({ id: '', name: '', inputModalities: null, outputModalities: null }); render(); break;
        case 'add-header': collectEditor(); editDraft.headers = editDraft.headers || []; editDraft.headers.push({ name: '', value: '' }); render(); break;
        case 'add-provider': editDraft = { id: L.uid(), name: 'Пользовательский провайдер', baseURL: '', apiKey: '', kind: 'custom', slug: 'custom', models: [], headers: [] }; providerError = ''; editorQuery = ''; go('editor'); break;
        case 'generate-image': await doGenerateImage(); break;
        case 'cancel-image': generationAbort?.abort(); imageBusy = false; imageActivePrompt = ''; render(); break;
        case 'clear-image': imagePrompt = ''; render(); break;
        case 'refresh-balance': await refreshBalance(); break;
        case 'reveal-state': await fetch('/api/reveal?token=' + L.token, { method: 'POST' }); break;
      }
    } catch (err) { toast('Ошибка: ' + err.message); }
  }

  async function handleFiles(fileList) {
    const files = [...(fileList || [])];
    for (const f of files) {
      if (f.size > 20 * 1024 * 1024) { toast('Лимит: 20 МБ на файл, 30 МБ на сообщение.'); continue; }
      const total = attachments.reduce((a, x) => a + (x.data.length * 3 / 4), 0) + f.size;
      if (total > 30 * 1024 * 1024) { toast('Лимит вложений: 30 МБ'); break; }
      const buf = await f.arrayBuffer();
      let mime = f.type || 'application/octet-stream';
      let b64 = btoa(String.fromCharCode(...new Uint8Array(buf)));
      if (mime.startsWith('image/') && mime !== 'image/jpeg' && mime !== 'image/png') {
        try { const j = await normalizeImage(b64, mime); b64 = j.data; mime = 'image/jpeg'; }
        catch { /* keep original */ }
      }
      attachments.push({ name: f.name, mime, data: b64 });
    }
    const fi = $('#file-input'); if (fi) { fi.value = ''; fi.accept = ''; }
    render();
  }

  function normalizeImage(b64, mime) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        const scale = Math.min(1, 1600 / Math.max(img.width, img.height));
        const c = document.createElement('canvas');
        c.width = Math.max(1, Math.round(img.width * scale)); c.height = Math.max(1, Math.round(img.height * scale));
        c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
        resolve({ data: c.toDataURL('image/jpeg', 0.82).split(',')[1], mime: 'image/jpeg' });
      };
      img.onerror = reject; img.src = `data:${mime};base64,${b64}`;
    });
  }

  async function send() {
    if (sending) return;
    const hard = L.imageSupportError(attachments);
    if (hard) { toast(hard); return; }
    const c = chat(), p = provider(), text = inputText.trim();
    if (!p || !c?.model || (!text && !attachments.length)) { toast('Выбери провайдера и модель'); return; }
    const files = attachments;
    inputText = ''; attachments = []; sending = true;
    followTail = true; savedScrollTop = null;
    const userMsg = { id: L.uid(), role: 'user', text, attachments: files };
    const assistantID = L.uid();
    L.mutate((s) => {
      const cc = L.selectedChat(s);
      cc.messages.push(userMsg);
      if (cc.messages.length === 1) cc.title = (text || files[0]?.name || 'Вложение').slice(0, 40);
      cc.messages.push({ id: assistantID, role: 'assistant', text: '', modelName: (p.models || []).find((m) => m.id === c.model)?.name || c.model });
    });
    go('chat');
    const snapshot = JSON.parse(JSON.stringify(c));
    generationAbort = new AbortController();
    let usage = null;
    try {
      for await (const ev of L.streamChat(snapshot, p, files, generationAbort.signal)) {
        L.mutate((s) => {
          const cc = s.chats.find((x) => x.id === snapshot.id);
          const m = cc?.messages.find((x) => x.id === assistantID); if (!m) return;
          if (ev.type === 'text') m.text += ev.text;
          else if (ev.type === 'thinking') m.thinking = (m.thinking || '') + ev.text;
          else if (ev.type === 'media') { m.media = m.media || []; if (!m.media.some((x) => x.url === ev.media.url)) m.media.push(ev.media); }
          else if (ev.type === 'usage') { usage = ev.usage; m.usage = ev.usage; }
        }, 'stream');
        scheduleMessagesLive();
      }
    } catch (err) {
      const stopped = err.name === 'AbortError';
      L.mutate((s) => {
        const m = s.chats.find((x) => x.id === snapshot.id)?.messages.find((x) => x.id === assistantID);
        if (m) { m.failed = true; m.text += stopped ? '\n[Остановлено]' : `\nОшибка: ${friendly(err.message)}`; }
      });
    } finally {
      if (liveRaf) { cancelAnimationFrame(liveRaf); liveRaf = 0; }
      sending = false; generationAbort = null;
      if (usage) L.mutate((s) => {
        s.records.push({ id: L.uid(), date: Date.now(), chatID: snapshot.id, chatTitle: snapshot.title, providerID: p.id, providerName: p.name, model: snapshot.model, usage });
      });
      L.persist(); // flush the final state immediately (not debounced)
      render();
    }
  }

  function friendly(msg) {
    if (/network|connection|fetch|timeout|timed/i.test(msg)) return 'Соединение с провайдером оборвалось. Возможно, модель не поддерживает изображение или файл слишком большой. Попробуй JPG/PNG меньшего размера.';
    if (/401|403|unauthor|invalid.*key/i.test(msg)) return msg;
    if (/429|rate/i.test(msg)) return 'Провайдер не ответил вовремя. Попробуй ещё раз.';
    return msg;
  }

  const FOLLOW_THRESHOLD = 48;
  let liveRaf = 0;
  function isAtBottom(el) {
    return el.scrollHeight - el.scrollTop - el.clientHeight <= FOLLOW_THRESHOLD;
  }
  function attachScrollFollow(el) {
    if (el.__labFollowWired) return;
    el.__labFollowWired = true;
    // Update the follow flag synchronously (works even when rAF is throttled in
    // a background tab); rAF only debounces the button's visibility.
    el.addEventListener('scroll', () => {
      followTail = isAtBottom(el);
      const jump = $('.jump-bottom');
      if (jump) jump.classList.toggle('hidden', followTail);
    }, { passive: true });
  }
  // Coalesce stream events to at most one DOM re-parse per animation frame.
  function scheduleMessagesLive() {
    if (liveRaf) return;
    liveRaf = requestAnimationFrame(() => { liveRaf = 0; updateMessagesLive(); });
  }
  function updateMessagesLive() {
    const c = chat(); if (!c) return;
    const last = c.messages[c.messages.length - 1], container = $('#messages'); if (!container) return;
    const wasAtBottom = isAtBottom(container);
    const nodes = container.querySelectorAll('.msg'), node = nodes[nodes.length - 1];
    if (node && last) {
      const body = node.querySelector('.body');
      if (body) { body.innerHTML = vm(last.text) || '<span class="typing"><i></i><i></i><i></i></span>'; }
      const think = node.querySelector('.thinking');
      if (last.thinking && !think) { const d = document.createElement('details'); d.className = 'thinking'; d.innerHTML = `<summary>Мышление</summary>${esc(last.thinking)}`; node.insertBefore(d, body); }
      else if (think) { const pre = think.querySelector('pre'); if (!pre) think.innerHTML = `<summary>Мышление</summary>${esc(last.thinking)}`; }
      const usage = node.querySelector('.usage');
      if (last.usage && !usage) { const d = document.createElement('div'); d.className = 'usage'; d.textContent = `↑ ${last.usage.input ?? '—'}   ↓ ${last.usage.output ?? '—'} токенов`; node.appendChild(d); }
    }
    // Only chase the tail if the user was pinned to the bottom. No forced jump.
    if (followTail && wasAtBottom) container.scrollTop = container.scrollHeight;
    const jump = $('.jump-bottom'); if (jump) jump.classList.toggle('hidden', followTail && wasAtBottom);
  }
  function scrollMessages(force = false) {
    const el = $('#messages'); if (!el) return;
    if (force || followTail) el.scrollTop = el.scrollHeight;
  }
  function jumpToBottom() { followTail = true; scrollMessages(true); const j = $('.jump-bottom'); if (j) j.classList.add('hidden'); }

  async function saveProvider() {
    collectEditor();
    const p = editDraft;
    p.slug = (p.slug || 'custom').trim();
    p.name = (p.name || '').trim();
    p.baseURL = (p.baseURL || '').trim().replace(/\/+$/, '');
    p.models = (p.models || []).filter((m) => m.id.trim());
    p.headers = (p.headers || []).filter((h) => h.name.trim());
    providerError = '';
    if (!/^[a-z0-9_-]+$/.test(p.slug)) { providerError = 'ID: строчные латинские буквы, цифры, дефис и подчёркивание'; render(); return; }
    const others = S().providers.filter((x) => x.id !== p.id);
    if (others.some((x) => (x.slug || 'custom') === p.slug)) { providerError = 'Этот ID уже используется'; render(); return; }
    if (!p.name || !/^https?:\/\//i.test(p.baseURL)) { providerError = 'Укажи имя и корректный HTTPS URL'; render(); return; }
    if (!p.models.length || new Set(p.models.map((m) => m.id)).size !== p.models.length) { providerError = 'Добавь хотя бы одну модель с уникальным ID'; render(); return; }
    for (const h of p.headers) {
      if (!/^[!#$%&'*+.^_`|~0-9A-Za-z-]+$/.test(h.name) || /[\r\n]/.test(h.value)) { providerError = 'Некорректный HTTP-заголовок'; render(); return; }
    }
    L.mutate((s) => {
      const i = s.providers.findIndex((x) => x.id === p.id);
      if (i >= 0) s.providers[i] = p; else s.providers.push(p);
      s.drafts = s.drafts.filter((d) => d.id !== p.id);
      if (!s.defaultModel) s.defaultModel = p.models[0].id;
      const c = L.selectedChat(s); if (c && !c.model) c.model = p.models[0].id;
    });
    editDraft = null; toast(TXT.mediaNotice); go('providers');
  }

  async function loadModels() {
    collectEditor(); const p = editDraft;
    if (!p.baseURL.trim()) { providerError = 'Укажи имя и корректный HTTPS URL'; render(); return; }
    modelsLoading = true; providerError = ''; render();
    try {
      const loaded = await L.fetchModels(p); collectEditor();
      const byId = new Map((p.models || []).map((m) => [m.id, m]));
      for (const m of loaded) byId.set(m.id, { ...(byId.get(m.id) || {}), ...m });
      p.models = [...byId.values()]; toast(`Загружено моделей: ${loaded.length}`);
    } catch (err) { providerError = err.message; }
    modelsLoading = false; render();
  }

  async function doGenerateImage() {
    if (imageBusy || !imagePrompt.trim() || !imageModel) return;
    const p = S().providers.find((x) => x.id === imageProviderID) || provider();
    if (!p) { toast('Нет провайдера'); return; }
    const prompt = imagePrompt.trim(), model = imageModel, size = imageSize;
    imageBusy = true; imagePrompt = ''; imageActivePrompt = prompt;
    L.mutate((s) => { s.imageModel = model; s.imageSize = size; }); render();
    generationAbort = new AbortController();
    try {
      const url = await L.generateImage(p, model, prompt, size);
      if (generationAbort.signal.aborted) return;
      L.mutate((s) => { s.generatedImages.unshift({ id: L.uid(), url, prompt, model, size, createdAt: Date.now() }); if (s.generatedImages.length > 20) s.generatedImages.length = 20; });
      toast('Изображение сохранено в Фото.');
    } catch (err) {
      if (generationAbort.signal.aborted) return;
      toast('Ошибка генерации: ' + err.message);
    } finally { imageBusy = false; imageActivePrompt = ''; generationAbort = null; render(); }
  }

  async function refreshBalance() {
    toast('Запрашиваю баланс…');
    for (const p of S().providers) {
      try { balances[p.id] = await L.fetchBalance(p); } catch (err) { balances[p.id] = err.message; }
    }
    render();
  }

  L.onChange((_s, reason) => {
    if (reason === 'theme' || reason === 'reload' || reason === 'external') applyTheme();
    if (reason === 'remote') render();
  });
  window.addEventListener('lab:theme', () => { L.syncFromDisk('theme'); });
  window.addEventListener('lab:reload', () => { L.syncFromDisk('reload'); });

  L.boot().then(() => { imageSize = S().imageSize || '1024x1024'; imageModel = S().imageModel || ''; render(); });
})();
