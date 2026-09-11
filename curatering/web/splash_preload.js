/* Early splash image preload (CSP-safe external script). */
(function () {
  var host = (location.hostname || '').toLowerCase().replace(/^www\./, '');
  var staff =
    host === 'staff.curatering.com' || host.split('.')[0] === 'staff';
  var path = (location.pathname || '/').replace(/\/+$/, '') || '/';
  if (staff || path === '/login') {
    document.documentElement.classList.add('staff-shell');
  }
  var href = staff || path === '/login' ? 'splash-staff.webp' : 'shell-hero.webp';
  var type = 'image/webp';
  var sizes = staff || path === '/login' ? '80vw' : '100vw';

  var link = document.createElement('link');
  link.rel = 'preload';
  link.as = 'image';
  link.href = href;
  link.type = type;
  link.fetchPriority = 'high';
  link.imageSizes = sizes;
  document.head.appendChild(link);
})();
