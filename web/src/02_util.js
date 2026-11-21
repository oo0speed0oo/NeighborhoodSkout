// ===== Utilities =====
const $ = (sel, el = document) => el.querySelector(sel);

function h(tag, props, ...kids) {
  const el = document.createElement(tag);
  if (props) {
    for (const [k, v] of Object.entries(props)) {
      if (v === null || v === undefined || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
      else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
      else if (k === 'value' || k === 'checked' || k === 'disabled' || k === 'selected' || k === 'textContent') el[k] = v;
      else el.setAttribute(k, v === true ? '' : v);
    }
  }
  const add = (kid) => {
    if (kid === null || kid === undefined || kid === false) return;
    if (Array.isArray(kid)) kid.forEach(add);
    else if (kid instanceof Node) el.appendChild(kid);
    else el.appendChild(document.createTextNode(String(kid)));
  };
  kids.forEach(add);
  return el;
}

function uid() {
  if (window.crypto && crypto.randomUUID) return crypto.randomUUID().toUpperCase();
  const b = (n) => Math.floor(Math.random() * 16 ** n).toString(16).padStart(n, '0');
  return `${b(8)}-${b(4)}-4${b(3)}-a${b(3)}-${b(12)}`.toUpperCase();
}
const normId = (s) => String(s || '').trim().toUpperCase();
const nowISO = () => new Date().toISOString();
const pad2 = (n) => String(n).padStart(2, '0');
const clone = (o) => JSON.parse(JSON.stringify(o));
const lc = (s) => String(s || '').trim().toLowerCase();

// ----- dates (birthdays are stored as plain 'YYYY-MM-DD' strings) -----
function ymdFromDate(d) { return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`; }
function validYMD(y, m, d) {
  if (!(y >= 1900 && y <= new Date().getFullYear() + 1)) return false;
  if (!(m >= 1 && m <= 12)) return false;
  const dt = new Date(y, m - 1, d);
  return dt.getFullYear() === y && dt.getMonth() === m - 1 && dt.getDate() === d;
}
// Accepts 2024-05-03, 2024/5/3, 2024.5.3, 2024年5月3日, 5/3/2024 (month first), 25/12/2000 (day first when >12),
// and ISO timestamps like 1980-01-14T15:00:00Z (converted to the local date). Returns 'YYYY-MM-DD' or null.
function parseDateLoose(input) {
  const s = String(input || '').trim();
  if (!s) return '';
  let m;
  if ((m = s.match(/^(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})$/)) || (m = s.match(/^(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日?$/))) {
    const y = +m[1], mo = +m[2], d = +m[3];
    return validYMD(y, mo, d) ? `${y}-${pad2(mo)}-${pad2(d)}` : null;
  }
  if ((m = s.match(/^(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{4})$/))) {
    let a = +m[1], b = +m[2]; const y = +m[3];
    let mo = a, d = b;
    if (a > 12 && b <= 12) { mo = b; d = a; }
    return validYMD(y, mo, d) ? `${y}-${pad2(mo)}-${pad2(d)}` : null;
  }
  if (/^\d{4}-\d{2}-\d{2}T/.test(s)) {
    const dt = new Date(s);
    if (isNaN(dt)) return null;
    const out = ymdFromDate(dt);
    const [y, mo, d] = out.split('-').map(Number);
    return validYMD(y, mo, d) ? out : null;
  }
  return null;
}
function splitYMD(s) { const [y, m, d] = s.split('-').map(Number); return { y, m, d }; }

function download(filename, content, mime) {
  const blob = content instanceof Blob ? content : new Blob([content], { type: mime || 'application/octet-stream' });
  const url = URL.createObjectURL(blob);
  const a = h('a', { href: url, download: filename });
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { a.remove(); URL.revokeObjectURL(url); }, 4000);
}

async function copyText(text) {
  try { await navigator.clipboard.writeText(text); return true; } catch (e) { /* fall through */ }
  try {
    const ta = h('textarea', { value: text, style: { position: 'fixed', opacity: 0 } });
    document.body.appendChild(ta); ta.select();
    const ok = document.execCommand('copy'); ta.remove(); return ok;
  } catch (e) { return false; }
}

function pickFile(accept, multiple) {
  return new Promise((resolve) => {
    const inp = h('input', { type: 'file', accept: accept || '', style: { display: 'none' } });
    if (multiple) inp.multiple = true;
    inp.addEventListener('change', () => { resolve(inp.files && inp.files[0] ? inp.files[0] : null); inp.remove(); });
    inp.addEventListener('cancel', () => { resolve(null); inp.remove(); });
    document.body.appendChild(inp);
    inp.click();
  });
}

// Is this text a single emoji (or an emoji sequence like a flag or a family)?
function firstEmoji(text) {
  const s = String(text || '').trim();
  if (!s) return null;
  const seg = (typeof Intl !== 'undefined' && Intl.Segmenter)
    ? [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(s)].map((x) => x.segment)
    : Array.from(s);
  const re = /\p{Extended_Pictographic}|\p{Regional_Indicator}|⃣/u;
  for (const g of seg) { if (re.test(g)) return g; }
  return null;
}
