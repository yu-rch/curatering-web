/* Early splash image preload (CSP-safe external script). */
(function () {
  var host = (location.hostname || '').toLowerCase().replace(/^www\./, '');
  var staff =
    host === 'staff.curatering.com' || host.split('.')[0] === 'staff';
  var webp = staff ? 'splash-staff.webp' : 'splash-customer.webp';

  var link = document.createElement('link');
  link.rel = 'preload';
  link.as = 'image';
  link.href = webp;
  link.type = 'image/webp';
  link.fetchPriority = 'high';
  link.imageSizes = '320px';
  document.head.appendChild(link);
})();
