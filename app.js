function showPage(id) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('nav a').forEach(a => a.classList.remove('active'));
  document.getElementById(id).classList.add('active');
  document.getElementById('nav-' + id).classList.add('active');
  const titles = {
    dashboard: 'V75 • M5 • LIVE',
    signals: 'Signal Center',
    trades: 'Open Trade • LIVE',
    history: 'Trade History',
    settings: 'App Settings'
  };
  document.getElementById('subTitle').textContent = titles[id] || 'V75 • M5 • LIVE';
  window.scrollTo({ top: 0, behavior: 'smooth' });
}
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => navigator.serviceWorker.register("./service-worker.js"));
}
