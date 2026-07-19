document.documentElement.classList.add('js');

const header = document.querySelector('.site-header');
const navToggle = document.querySelector('.nav-toggle');
const primaryNav = document.querySelector('.primary-nav');

function updateHeader() {
  if (header) {
    header.classList.toggle('is-scrolled', window.scrollY > 16);
  }
}

function closeMenu() {
  if (!header || !navToggle) return;
  header.classList.remove('menu-open');
  navToggle.setAttribute('aria-expanded', 'false');
}

updateHeader();
window.addEventListener('scroll', updateHeader, { passive: true });

if (header && navToggle && primaryNav) {
  navToggle.addEventListener('click', () => {
    const isOpen = header.classList.toggle('menu-open');
    navToggle.setAttribute('aria-expanded', String(isOpen));
  });

  primaryNav.addEventListener('click', (event) => {
    if (event.target.closest('a')) closeMenu();
  });

  document.addEventListener('click', (event) => {
    if (!header.contains(event.target)) closeMenu();
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      closeMenu();
      navToggle.focus();
    }
  });
}

const revealItems = document.querySelectorAll('[data-reveal]');
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (reduceMotion || !('IntersectionObserver' in window)) {
  revealItems.forEach((item) => item.classList.add('is-visible'));
} else {
  const observer = new IntersectionObserver((entries, revealObserver) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      revealObserver.unobserve(entry.target);
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px' });

  revealItems.forEach((item) => observer.observe(item));
}

document.querySelectorAll('[data-current-year]').forEach((item) => {
  item.textContent = String(new Date().getFullYear());
});
