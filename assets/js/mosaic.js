import MosaicPlugin from "../vendor/mosaic-plugin.js";

const MAX_RENDER_PIXELS = 8_000_000;
const MOSAIC_SEED = 20_250_802;

const sourceImagePromises = new Map();

const loadSourceImage = (sourceUrl, signal) => {
  signal.throwIfAborted();

  if (!sourceImagePromises.has(sourceUrl)) {
    sourceImagePromises.set(sourceUrl, new Promise((resolve, reject) => {
      const image = new Image();
      image.decoding = "async";
      image.onload = () => resolve(image);
      image.onerror = () => reject(new Error(`Could not load ${sourceUrl}`));
      image.src = sourceUrl;

      if (image.complete && image.naturalWidth > 0) resolve(image);
    }));
  }

  // Cancel this element's wait without discarding the reusable decoded image.
  return new Promise((resolve, reject) => {
    const abort = () => reject(signal.reason);
    signal.addEventListener("abort", abort, { once: true });
    sourceImagePromises.get(sourceUrl).then(
      (image) => {
        signal.removeEventListener("abort", abort);
        resolve(image);
      },
      (error) => {
        signal.removeEventListener("abort", abort);
        reject(error);
      }
    );
  });
};

// The vendored render/animate API has no AbortSignal; its cooperative _yield
// boundary lets a destroyed hook stop generation without changing the algorithm.
class LifecycleMosaicPlugin extends MosaicPlugin {
  constructor(options, signal) {
    super(options);
    this.signal = signal;
  }

  _yield() {
    const signal = this.signal;
    signal.throwIfAborted();

    return new Promise((resolve, reject) => {
      const abort = () => {
        clearTimeout(timer);
        reject(signal.reason);
      };
      const timer = setTimeout(() => {
        signal.removeEventListener("abort", abort);
        resolve();
      }, 0);
      signal.addEventListener("abort", abort, { once: true });
    });
  }
}

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

const renderMosaic = async (hook) => {
  const container = hook.el;
  const signal = hook.abortController.signal;
  if (signal.aborted || hook.hasAnimated) return;

  const sourceUrl = container.dataset.backgroundSrc;
  if (!sourceUrl) return;

  const version = ++hook.renderVersion;
  const { width, height } = container.getBoundingClientRect();
  if (width < 1 || height < 1) return;
  hook.hasAnimated = true;

  try {
    const image = await loadSourceImage(sourceUrl, signal);
    if (signal.aborted || version !== hook.renderVersion || !container.isConnected) return;

    const { canvas: sourceCanvas, pixelScale } = createCoverCanvas(image, width, height);
    const areaScale = pixelScale * pixelScale;
    const mosaic = new LifecycleMosaicPlugin({
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
    }, signal);
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const animation = await mosaic.animate({
      duration: 2_400,
      order: "radial",
      from: "transparent",
      easing: (progress) => 1 - Math.pow(1 - progress, 4),
      seed: MOSAIC_SEED
    });

    if (signal.aborted || version !== hook.renderVersion || !container.isConnected) {
      animation.cancel();
      return;
    }

    animation.canvas.className = "hero-mosaic-canvas";
    animation.canvas.setAttribute("aria-hidden", "true");
    container.replaceChildren(animation.canvas);
    hook.activeAnimation = animation;

    if (reducedMotion) {
      animation.seek(1);
      return;
    }

    hook.animationFrame = requestAnimationFrame(() => {
      hook.animationFrame = null;
      if (!signal.aborted && version === hook.renderVersion) {
        animation.play().catch((error) => {
          if (!signal.aborted && version === hook.renderVersion) console.warn(error);
        });
      }
    });
  } catch (error) {
    if (!signal.aborted && version === hook.renderVersion && container.isConnected) {
      container.replaceChildren();
      console.warn("Hero mosaic could not be rendered.", error);
    }
  }
};

export const Mosaic = {
  mounted() {
    this.abortController = new AbortController();
    this.hasAnimated = false;
    this.activeAnimation = null;
    this.renderVersion = 0;
    this.resizeTimer = null;
    this.animationFrame = null;
    this.scheduleRender = () => {
      if (this.hasAnimated) return;

      clearTimeout(this.resizeTimer);
      this.resizeTimer = setTimeout(() => {
        this.resizeTimer = null;
        renderMosaic(this);
      }, 250);
    };

    window.addEventListener("resize", this.scheduleRender);
    renderMosaic(this);
  },

  destroyed() {
    this.abortController.abort();
    this.renderVersion++;
    clearTimeout(this.resizeTimer);
    if (this.animationFrame !== null) cancelAnimationFrame(this.animationFrame);
    this.activeAnimation?.cancel();
    this.activeAnimation = null;
    window.removeEventListener("resize", this.scheduleRender);
  }
};
