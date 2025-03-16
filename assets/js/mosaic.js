const initMosaicAnimation = () => {
  const mosaicContainer = document.getElementById('mosaic-animation');
  if (!mosaicContainer) return;

  const colors = [
    '#9ea531', // Verde Lima
    '#121212', // Negro
    '#B5DDD1', // Menta/Agua
    '#ded9ca'  // Gris Cemento
  ];

  let rows, cols;

  if (window.innerWidth < 640) {
    // Mobile
    rows = 8;
    cols = 6;
  } else if (window.innerWidth < 1024) {
    // Tablet
    rows = 8;
    cols = 10;
  } else {
    // Desktop
    rows = 10;
    cols = 15;
  }

  const totalTiles = rows * cols;

  mosaicContainer.innerHTML = '';

  for (let i = 0; i < totalTiles; i++) {
    const tile = document.createElement('div');
    tile.className = 'mosaic-tile';

    const randomColor = colors[Math.floor(Math.random() * colors.length)];
    tile.style.backgroundColor = randomColor;

    const delay = Math.random() * 3;
    tile.style.animationDelay = `${delay}s`;

    mosaicContainer.appendChild(tile);
  }
};

// Mobile adds scrollbars when you scroll which changes size, useful to ignore those changes
let lastWidth = window.innerWidth;

document.addEventListener('DOMContentLoaded', () => {
  initMosaicAnimation();
  lastWidth = window.innerWidth;
});


window.addEventListener('resize', () => {
  if (window.innerWidth !== lastWidth) {
    // Debounce to avoid executing too many times
    clearTimeout(window.resizeTimer);
    window.resizeTimer = setTimeout(() => {
      initMosaicAnimation();
      lastWidth = window.innerWidth;
    }, 250);
  }
});

export default { initMosaicAnimation };