import MosaicPlugin from "../vendor/mosaic-plugin.js";

const MAX_RENDER_PIXELS = 8_000_000;
const MOSAIC_SEED = 20_250_802;

let hasAnimated = false;
let activeAnimation = null;
let renderVersion = 0;
let resizeTimer = null;
let sourceImagePromise = null;
const loadSourceImage = (sourceUrl) => {
  if (sourceImagePromise) return sourceImagePromise;

  sourceImagePromise = new Promise((resolve, reject) => {
    const image = new Image();
    image.decoding = "async";
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`Could not load ${sourceUrl}`));
    image.src = sourceUrl;

    if (image.complete && image.naturalWidth > 0) resolve(image);
  });

  return sourceImagePromise;
};

const createCoverCanvas = (image, width, height) => {
  const deviceScale = Math.min(window.devicePixelRatio || 1, 2);
  const pixelScale = Math.min(
    deviceScale,
    Math.sqrt(MAX_RENDER_PIXELS / (width * height))
  );
  const canvas = document.createElement("canvas");
  const canvasWidth = Math.max(1, Math.round(width * pixelScale));
  const canvasHeight = Math.max(1, Math.round(height * pixelScale));
  const drawScale = Math.max(
    canvasWidth / image.naturalWidth,
    canvasHeight / image.naturalHeight
  );
  const drawWidth = image.naturalWidth * drawScale;
  const drawHeight = image.naturalHeight * drawScale;
  const context = canvas.getContext("2d", { alpha: false });

  canvas.width = canvasWidth;
  canvas.height = canvasHeight;
  context.drawImage(
    image,
    (canvasWidth - drawWidth) / 2,
    (canvasHeight - drawHeight) / 2,
    drawWidth,
    drawHeight
  );

  return { canvas, pixelScale };
};

const renderMosaic = async () => {
  if (hasAnimated) return;

  const container = document.getElementById("mosaic-animation");
  if (!container) return;

  const sourceUrl = container.dataset.backgroundSrc;
  if (!sourceUrl) return;

  const version = ++renderVersion;
  const { width, height } = container.getBoundingClientRect();
  if (width < 1 || height < 1) return;
  hasAnimated = true;


  activeAnimation?.cancel();
  activeAnimation = null;

  try {
    const image = await loadSourceImage(sourceUrl);
    if (version !== renderVersion) return;

    const { canvas: sourceCanvas, pixelScale } = createCoverCanvas(image, width, height);
    const areaScale = pixelScale * pixelScale;
    const mosaic = new MosaicPlugin({
      image: sourceCanvas,
      algorithm: "stained-glass",
      edgeStrength: 0.5,
      voronoiRelaxation: 4,
      maxColors: 256,
      minTileArea: 50 * areaScale,
      maxTileArea: 200 * areaScale,
      maxSides: 7,
      borderColor: "#2d241b",
      borderWidth: 1,
      seed: MOSAIC_SEED,
      yieldEveryMs: 10
    });
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const animation = await mosaic.animate({
      duration: 2_400,
      order: "radial",
      from: "transparent",
      easing: (progress) => 1 - Math.pow(1 - progress, 4),
      seed: MOSAIC_SEED
    });

    if (version !== renderVersion) {
      animation.cancel();
      return;
    }

    animation.canvas.className = "hero-mosaic-canvas";
    animation.canvas.setAttribute("aria-hidden", "true");
    container.replaceChildren(animation.canvas);
    activeAnimation = animation;

    if (reducedMotion) {
      animation.seek(1);
      return;
    }

    requestAnimationFrame(() => {
      if (version === renderVersion) animation.play().catch(console.warn);
    });
  } catch (error) {
    if (version === renderVersion) {
      container.replaceChildren();
      console.warn("Hero mosaic could not be rendered.", error);
    }
  }
};

const scheduleRender = () => {
  if (hasAnimated) return;

  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(renderMosaic, 250);
};

document.addEventListener("DOMContentLoaded", renderMosaic);
window.addEventListener("resize", scheduleRender);

export default { renderMosaic };
