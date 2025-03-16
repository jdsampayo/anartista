const initMosaicAnimation = () => {
    const mosaicContainer = document.getElementById('mosaic-animation');
    if (!mosaicContainer) return;
    
    const colors = [
      '#e63946', '#457b9d', '#a8dadc', '#1d3557', '#f1faee',
      '#fca311', '#14213d', '#e5e5e5', '#9c89b8', '#2a9d8f',
      '#f15bb5', '#fee440', '#00bbf9', '#00f5d4', '#9b5de5'
    ];

    const rows = 10;
    const cols = 15;
    const totalTiles = rows * cols;
    
    mosaicContainer.innerHTML = '';
    
    for (let i = 0; i < totalTiles; i++) {
      const tile = document.createElement('div');
      tile.className = 'mosaic-tile';
      
      const randomColor = colors[Math.floor(Math.random() * colors.length)];
      tile.style.backgroundColor = randomColor;
      
      const delay = Math.random() * 3;
      tile.style.animation = `appearTile 0.5s forwards`;
      tile.style.animationDelay = `${delay}s`;
      
      mosaicContainer.appendChild(tile);
    }
  };
  
  document.addEventListener('DOMContentLoaded', () => {
    initMosaicAnimation();
  });
  
  export default { initMosaicAnimation };