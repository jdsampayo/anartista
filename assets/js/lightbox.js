const createLightboxOverlay = () => {
  const host = document.fullscreenElement || document.body;
  let overlay = document.getElementById('lightbox-overlay');
  if (overlay) {
    if (overlay.parentElement !== host) host.appendChild(overlay);
    return overlay;
  }

  overlay = document.createElement('div');
  overlay.id = 'lightbox-overlay';
  overlay.className = 'lightbox-overlay';
  overlay.innerHTML = `
      <div class="lightbox-content">
        <img src="" alt="" class="lightbox-img" id="lightbox-img">
        <div class="lightbox-close">&times;</div>
        <div class="lightbox-caption" id="lightbox-caption"></div>
      </div>
    `;
  host.appendChild(overlay);

  return overlay;
};

const openLightbox = (src, caption) => {
  const overlay = createLightboxOverlay();
  overlay.querySelector('#lightbox-img').src = src;
  overlay.querySelector('#lightbox-caption').textContent = caption;
  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';
};

const closeLightbox = () => {
  const overlay = document.getElementById('lightbox-overlay');
  if (!overlay?.classList.contains('active')) return;

  overlay.classList.remove('active');
  document.body.style.overflow = '';
};

// Delegation keeps galleries interactive after LiveView replaces their images.
document.addEventListener('click', (event) => {
  const target = event.target instanceof Element ? event.target : event.target.parentElement;
  if (!target) return;

  const overlay = document.getElementById('lightbox-overlay');
  if (overlay && (target === overlay || target.closest('#lightbox-overlay .lightbox-close'))) {
    closeLightbox();
    return;
  }

  const trigger = target.closest('.lightbox-trigger');
  if (!trigger) return;

  const image = trigger.matches('img') ? trigger : trigger.querySelector('img');
  const imageSource = trigger.getAttribute('data-hires') ||
    image?.getAttribute('data-hires') || image?.src || trigger.getAttribute('href');
  const caption = trigger.getAttribute('data-caption') ||
    image?.getAttribute('data-caption') || image?.alt || trigger.getAttribute('alt') || '';
  if (!imageSource) return;

  event.preventDefault();
  openLightbox(imageSource, caption);
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeLightbox();
});

window.addEventListener('phx:page-loading-start', (event) => {
  if (event.detail.kind === 'patch' || event.detail.kind === 'redirect') closeLightbox();
});
window.addEventListener('phx:navigate', closeLightbox);