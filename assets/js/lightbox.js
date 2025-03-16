const initLightbox = () => {
  const createLightboxOverlay = () => {
    if (document.getElementById('lightbox-overlay')) return;

    // Create lightbox overlay
    const overlay = document.createElement('div');
    overlay.id = 'lightbox-overlay';
    overlay.className = 'lightbox-overlay';
    overlay.innerHTML = `
        <div class="lightbox-content">
          <img src="" alt="" class="lightbox-img" id="lightbox-img">
          <div class="lightbox-close">&times;</div>
          <div class="lightbox-caption" id="lightbox-caption"></div>
        </div>
      `;

    document.body.appendChild(overlay);

    // Close lightbox
    const closeBtn = overlay.querySelector('.lightbox-close');
    closeBtn.addEventListener('click', closeLightbox);
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) {
        closeLightbox();
      }
    });

    // Close with ESC key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        closeLightbox();
      }
    });
  };

  // Open
  const openLightbox = (src, alt) => {
    const overlay = document.getElementById('lightbox-overlay');
    const img = document.getElementById('lightbox-img');
    const caption = document.getElementById('lightbox-caption');

    img.src = src;
    caption.textContent = alt;
    overlay.classList.add('active');

    // Block body scroll
    document.body.style.overflow = 'hidden';
  };

  // Close
  const closeLightbox = () => {
    const overlay = document.getElementById('lightbox-overlay');
    overlay.classList.remove('active');

    // Restore body scroll
    document.body.style.overflow = '';
  };

  // Initialize lightbox
  createLightboxOverlay();

  // Add listeners to all images with the lightbox-trigger class
  const images = document.querySelectorAll('.lightbox-trigger');
  images.forEach(img => {
    img.addEventListener('click', () => {
      openLightbox(img.src, img.alt);
    });
  });
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initLightbox);

export default { initLightbox };