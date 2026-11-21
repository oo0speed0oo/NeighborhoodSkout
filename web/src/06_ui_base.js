// ===== Shared UI pieces: modals, sheets, dialogs, toast =====
const modalStack = [];
let modalLock = 0;

function updateBodyLock() { document.body.classList.toggle('modal-open', modalStack.length > 0); }

// openModal({title, render(body, m), right(m) -> node, live, back, onClose})
function openModal(opts) {
  hideToast();
  const overlay = h('div', { class: 'overlay', onmousedown: (e) => { if (e.target === overlay) m.close(); } });
  const titleEl = h('div', { class: 'mtitle' });
  const rightEl = h('div', { class: 'mright' });
  const closeBtn = h('button', { class: 'mbtn', type: 'button', onclick: () => m.close() }, opts.back ? '‹ ' + opts.back : t('Close'));
  const body = h('div', { class: 'mbody' });
  const sheet = h('div', { class: 'msheet', role: 'dialog', 'aria-modal': 'true' }, h('div', { class: 'mhead' }, closeBtn, titleEl, rightEl), body);
  overlay.appendChild(sheet);
  const m = {
    el: overlay, body, opts, live: opts.live !== false,
    update() {
      const sc = body.scrollTop;
      titleEl.textContent = typeof opts.title === 'function' ? opts.title() : opts.title || '';
      rightEl.replaceChildren();
      if (opts.right) { const r = opts.right(m); if (r) rightEl.appendChild(r); }
      body.replaceChildren();
      opts.render(body, m);
      body.scrollTop = sc;
    },
    close() {
      const i = modalStack.indexOf(m);
      if (i < 0) return;
      modalStack.splice(i, 1);
      overlay.classList.add('closing');
      setTimeout(() => overlay.remove(), 120);
      updateBodyLock();
      if (opts.onClose) opts.onClose();
    },
  };
  modalStack.push(m);
  $('#modalRoot').appendChild(overlay);
  updateBodyLock();
  m.update();
  return m;
}
function refreshModals() { for (const m of [...modalStack]) if (m.live && m.el.isConnected) m.update(); }
function closeTopModal() { const m = modalStack[modalStack.length - 1]; if (m) { m.close(); return true; } return false; }

// action sheet: items = [{label, onClick, danger, hidden}]
function openSheet(title, subtitle, items) {
  const close = () => { overlay.classList.add('closing'); setTimeout(() => overlay.remove(), 120); sheetOpen = null; };
  const overlay = h('div', { class: 'overlay sheetwrap', onmousedown: (e) => { if (e.target === overlay) close(); } },
    h('div', { class: 'asheet' },
      h('div', { class: 'agroup' },
        h('div', { class: 'ahead' }, h('div', { class: 'at' }, title), subtitle ? h('div', { class: 'as' }, subtitle) : null),
        items.filter((i) => !i.hidden).map((i) => h('button', { class: 'aitem' + (i.danger ? ' danger' : ''), type: 'button', onclick: () => { close(); setTimeout(i.onClick, 0); } }, i.label))),
      h('div', { class: 'agroup' }, h('button', { class: 'aitem bold', type: 'button', onclick: close }, t('Cancel')))));
  $('#modalRoot').appendChild(overlay);
  sheetOpen = { close };
  return { close };
}
let sheetOpen = null;

function confirmDialog({ title, message, ok, danger }) {
  return new Promise((resolve) => {
    const done = (v) => { overlay.remove(); resolve(v); };
    const overlay = h('div', { class: 'overlay dialogwrap' },
      h('div', { class: 'dialog', role: 'alertdialog' },
        h('div', { class: 'dt' }, title),
        message ? h('div', { class: 'dm' }, message) : null,
        h('div', { class: 'dbtns' },
          h('button', { class: 'dbtn', type: 'button', onclick: () => done(false) }, t('Cancel')),
          h('button', { class: 'dbtn bold' + (danger ? ' danger' : ''), type: 'button', onclick: () => done(true) }, ok || t('OK')))));
    $('#modalRoot').appendChild(overlay);
  });
}

// toast with an optional action button (for Undo)
let toastTimer = null;
function toast(msg, opts = {}) {
  const el = $('#toast');
  el.replaceChildren(h('span', null, msg));
  if (opts.action) el.appendChild(h('button', { type: 'button', class: 'tact', onclick: () => { hideToast(); opts.action.fn(); } }, opts.action.label));
  el.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(hideToast, opts.ms || 3200);
}
function hideToast() { $('#toast').classList.remove('show'); }

// reusable bits ------------------------------------------------------------
function swatchRow(selected, onPick, names = COLORS) {
  return h('div', { class: 'swatches' }, names.map((n) => h('button', {
    type: 'button', class: `swatch hc-${n}` + (n === selected ? ' sel' : ''), 'aria-label': n,
    onclick: (e) => { onPick(n); [...e.currentTarget.parentNode.children].forEach((x) => x.classList.toggle('sel', x === e.currentTarget)); },
  })));
}
function field(label, input, hint) {
  return h('label', { class: 'field' }, h('span', { class: 'flabel' }, label), input, hint ? h('span', { class: 'fhint' }, hint) : null);
}
function segmented(options, value, onPick) {
  const wrap = h('div', { class: 'seg' });
  options.forEach(([val, label]) => wrap.appendChild(h('button', {
    type: 'button', class: val === value ? 'on' : '',
    onclick: () => { onPick(val); [...wrap.children].forEach((b, i) => b.classList.toggle('on', options[i][0] === val)); },
  }, label)));
  return wrap;
}
function avatar(person, size = 44) {
  const url = photoOf(person.id);
  const g = person.gender;
  const el = h('div', { class: `avatar g-${g}`, style: { width: size + 'px', height: size + 'px', fontSize: Math.round(size * 0.52) + 'px' } },
    url ? h('img', { src: url, alt: '' }) : GENDER_ICON[g] || '🧑');
  return el;
}
