/* Early splash image preload (CSP-safe external script). */
(function () {
  var host = (location.hostname || '').toLowerCase().replace(/^www\./, '');
  var staff =
    host === 'staff.curatering.com' || host.split('.')[0] === 'staff';
  var href = staff ? 'splash-staff.webp' : 'shell-hero.webp';
  var type = 'image/webp';
  var sizes = staff ? '320px' : '100vw';

  var link = document.createElement('link');
  link.rel = 'preload';
  link.as = 'image';
  link.href = href;
  link.type = type;
  link.fetchPriority = 'high';
  link.imageSizes = sizes;
  document.head.appendChild(link);
})();
