// ===== Startup =====
function makeTouchIcon() {
  try {
    const c = h('canvas', { width: 180, height: 180 });
    const x = c.getContext('2d');
    x.fillStyle = '#eaf4e4'; x.fillRect(0, 0, 180, 180);
    x.fillStyle = '#38383d'; x.fillRect(0, 100, 180, 34);
    x.fillStyle = '#ecd028'; for (let i = 0; i < 4; i++) x.fillRect(12 + i * 46, 114, 26, 6);
    x.font = '84px serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText('🏡', 90, 62);
    const link = h('link', { rel: 'apple-touch-icon', href: c.toDataURL('image/png') });
    document.head.appendChild(link);
    const fav = h('link', { rel: 'icon', href: c.toDataURL('image/png') });
    document.head.appendChild(fav);
  } catch (e) { /* icon is optional */ }
}

async function main() {
  makeTouchIcon();
  await initStorage();
  LANG = detectLang(settings.lang);
  document.title = 'NeighborhoodSkout';
  onChange = renderAll;
  onSaveStatus = () => { renderBanners(); refreshModals(); };

  // static controls
  $('#btnSettings').addEventListener('click', openSettings);
  $('#btnMenu').addEventListener('click', openMenu);
  $('#btnEdit').addEventListener('click', () => {
    ui.edit = !ui.edit; ui.moving = null; ui.moveSrc = null;
    if (!ui.edit) ui.tool = null;
    renderAll();
  });
  $('#btnZoomOut').addEventListener('click', () => setZoom(settings.zoom - 1));
  $('#btnZoomIn').addEventListener('click', () => setZoom(settings.zoom + 1));
  $('#map').addEventListener('click', onMapClick);
  setupStrokes();

  // keyboard: Esc closes, Ctrl/Cmd+Z undoes
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { if (sheetOpen) { sheetOpen.close(); return; } closeTopModal(); }
    const tag = (e.target && e.target.tagName) || '';
    if ((e.metaKey || e.ctrlKey) && !e.shiftKey && e.key.toLowerCase() === 'z' && !/INPUT|TEXTAREA|SELECT/.test(tag)) { e.preventDefault(); doUndo(); }
  });
  // ctrl/cmd + wheel zooms the map
  $('#mapScroll').addEventListener('wheel', (e) => {
    if (!(e.ctrlKey || e.metaKey)) return;
    e.preventDefault();
    setZoom(settings.zoom + (e.deltaY < 0 ? 1 : -1));
  }, { passive: false });

  let rz = null;
  window.addEventListener('resize', () => { clearTimeout(rz); rz = setTimeout(renderMap, 80); });
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') flushSave(); else renderBanners(); });
  window.addEventListener('pagehide', flushSave);

  renderAll();
  $('#loading').remove();
}

window.__nsk = {
  get S() { return S; }, get settings() { return settings; }, ui, kv, t,
  importBuffer, buildCSV, csvParse, planCSVImport, convertLegacyStore, buildBirthdayICS, upcomingBirthdays,
  parseDateLoose, firstEmoji, renderAll, doSave, getBackups, nextBirthday,
  setLang(l) { settings.lang = l; LANG = detectLang(l); renderAll(); },
};
main().catch((e) => {
  const l = document.getElementById('loading');
  if (l) l.textContent = 'Could not start: ' + (e && e.message || e);
  console.error(e);
});
