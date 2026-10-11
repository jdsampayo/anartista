const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const CONTROL_DAMPING = 65;
const GESTURE_DAMPING = 24;
const WHEEL_DAMPING = 50;

export const Exhibit = {
  mounted() {
    this.room = 0;
    this.yaw = 0;
    this.pitch = -5;
    this.zoom = 1;
    this.target = { yaw: this.yaw, pitch: this.pitch, zoom: this.zoom };
    this.cameraFrame = null;
    this.lastFrameTime = null;
    this.damping = CONTROL_DAMPING;
    this.disposed = false;
    this.animateCameraFrame = (timestamp) => this.animateCamera(timestamp);
    this.pointers = new Map();
    this.gesture = null;
    this.suppressClick = false;
    this.controller = new AbortController();
    const options = { signal: this.controller.signal };
    this.cacheElements();
    this.page.querySelector('.exhibit-filter-menu').open = false;
    this.motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
    this.reducedMotion = this.motionPreference.matches;
    this.motionPreference.addEventListener('change', (event) => {
      this.reducedMotion = event.matches;
      if (this.reducedMotion) this.requestCamera({ immediate: true });
    }, options);

    this.el.addEventListener('click', (event) => {
      if (this.suppressClick) {
        this.suppressClick = false;
        if (event.detail !== 0 && event.target.closest('.exhibit-viewport')) {
          event.preventDefault();
          return;
        }
      }
      const roomButton = event.target.closest('[data-room-step]');
      const cameraButton = event.target.closest('[data-camera]');
      const artwork = event.target.closest('.exhibit-viewport a[href^="#exhibit-record-"]');
      if (roomButton) this.showRoom(this.room + Number(roomButton.dataset.roomStep));
      if (cameraButton) this.moveCamera(cameraButton.dataset.camera);
      if (event.target.closest('[data-fullscreen]')) {
        const operation = document.fullscreenElement === this.page
          ? document.exitFullscreen()
          : this.page.requestFullscreen();
        operation.catch(() => {
          this.el.querySelector('#exhibit-room-status').textContent = 'El navegador no permitió activar la pantalla completa.';
        });
      }
      if (artwork) {
        event.preventDefault();
        const record = this.el.querySelector(artwork.getAttribute('href'));
        this.recordsPanel.open = true;
        record.open = true;
        const summary = record.querySelector('summary');
        summary.scrollIntoView({ block: 'start' });
        summary.focus({ preventScroll: true });
      }
    }, options);

    this.el.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && this.recordsPanel.open &&
          !document.getElementById('lightbox-overlay')?.classList.contains('active')) {
        this.recordsPanel.open = false;
        this.recordsPanel.querySelector('summary').focus({ preventScroll: true });
      }
    }, options);
    document.addEventListener('fullscreenchange', () => this.syncFullscreen(), options);
    this.syncFullscreen();

    this.el.addEventListener('keydown', (event) => {
      // Artwork links retain their native Enter/Space behavior.
      if (event.target !== this.viewport) return;
      const action = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down', '+': 'in', '=': 'in', '-': 'out', Home: 'reset' }[event.key];
      if (!action) return;
      event.preventDefault();
      this.moveCamera(action);
    }, options);

    // Delegation keeps the gestures attached when LiveView patches the viewport.
    this.el.addEventListener('pointerdown', (event) => {
      if (event.target.closest('.exhibit-viewport') === this.viewport) this.startPointer(event);
    }, options);
    window.addEventListener('pointermove', (event) => this.movePointer(event), options);
    window.addEventListener('pointerup', (event) => this.endPointer(event), options);
    window.addEventListener('pointercancel', (event) => {
      if (this.pointers.has(event.pointerId)) this.cancelGesture();
    }, options);
    this.el.addEventListener('lostpointercapture', (event) => {
      // Ignore implicit capture leaving an artwork when capture transfers to the viewport.
      if (event.target === this.viewport && this.pointers.has(event.pointerId)) this.cancelGesture();
    }, options);
    window.addEventListener('blur', () => {
      if (this.pointers.size) this.cancelGesture();
    }, options);
    this.el.addEventListener('wheel', (event) => {
      if (event.target.closest('.exhibit-viewport') === this.viewport) this.zoomWheel(event);
    }, { ...options, passive: false });

    this.resizeObserver = new ResizeObserver(() => {
      if (this.disposed) return;
      this.updateFit();
      this.paintCamera();
    });
    this.resizeObserver.observe(this.viewport);
    this.showRoom(0);
  },

  updated() {
    this.cancelGesture();
    this.resizeObserver.disconnect();
    this.cacheElements();
    this.resizeObserver.observe(this.viewport);
    this.showRoom(0);
    this.page.querySelector('.exhibit-filter-menu').open = false;
    this.recordsPanel.open = false;
    this.syncFullscreen();
  },

  cacheElements() {
    this.viewport = this.el.querySelector('.exhibit-viewport');
    this.camera = this.el.querySelector('.exhibit-camera');
    this.page = this.el.closest('.exhibit-page');
    this.recordsPanel = this.el.querySelector('#exhibit-records-panel');
    this.rooms = [...this.el.querySelectorAll('[data-room]')];
    this.zoomInButton = this.el.querySelector('[data-camera="in"]');
    this.zoomOutButton = this.el.querySelector('[data-camera="out"]');
  },

  showRoom(index) {
    this.room = clamp(index, 0, this.rooms.length - 1);
    this.rooms.forEach((room, i) => { room.hidden = i !== this.room; });
    const room = this.rooms[this.room];
    this.el.querySelector('#exhibit-room-status').textContent = `${room.dataset.roomName} · Sala ${this.room + 1} de ${this.rooms.length}`;
    this.viewport.setAttribute('aria-label', `Sala de exposición: ${room.dataset.roomName}`);
    this.roomWidth = Number(room.dataset.roomWidth);
    this.roomDepth = Number(room.dataset.roomDepth);
    this.roomHeight = Number(room.dataset.roomHeight);
    this.camera.style.width = `${this.roomWidth}px`;
    this.camera.style.height = `${this.roomHeight}px`;
    this.el.querySelector('[data-room-step="-1"]').disabled = this.room === 0;
    this.el.querySelector('[data-room-step="1"]').disabled = this.room === this.rooms.length - 1;
    this.updateFit();
    this.moveCamera('reset', true);
  },

  moveCamera(action, immediate = false) {
    if (action === 'reset' || this.pointers.size) this.cancelGesture();
    if (action === 'reset') {
      this.target.yaw = 0;
      this.target.pitch = -5;
      this.target.zoom = 1;
    }
    if (action === 'left') this.target.yaw += 8;
    if (action === 'right') this.target.yaw -= 8;
    if (action === 'up') this.target.pitch += 3;
    if (action === 'down') this.target.pitch -= 3;
    if (action === 'in') this.target.zoom += 0.15;
    if (action === 'out') this.target.zoom -= 0.15;
    this.requestCamera({ immediate });
  },

  requestCamera({ immediate = false, damping = CONTROL_DAMPING } = {}) {
    if (this.disposed) return;
    this.target.yaw = clamp(this.target.yaw, -28, 28);
    this.target.pitch = clamp(this.target.pitch, -12, 8);
    this.target.zoom = clamp(this.target.zoom, 0.75, 1.65);
    this.updateZoomButtons();
    this.damping = damping;
    if (immediate || this.reducedMotion || this.cameraIsSettled()) {
      this.stopCameraMotion();
      this.yaw = this.target.yaw;
      this.pitch = this.target.pitch;
      this.zoom = this.target.zoom;
      this.paintCamera();
    } else if (this.cameraFrame === null) {
      this.lastFrameTime = performance.now();
      this.cameraFrame = requestAnimationFrame(this.animateCameraFrame);
    }
  },

  cameraIsSettled() {
    return Math.abs(this.target.yaw - this.yaw) < 0.03 &&
      Math.abs(this.target.pitch - this.pitch) < 0.03 &&
      Math.abs(this.target.zoom - this.zoom) < 0.001;
  },

  animateCamera(timestamp) {
    this.cameraFrame = null;
    if (this.disposed) return;
    const elapsed = Math.max(0, timestamp - this.lastFrameTime);
    this.lastFrameTime = timestamp;
    const amount = 1 - Math.exp(-elapsed / this.damping);
    this.yaw += (this.target.yaw - this.yaw) * amount;
    this.pitch += (this.target.pitch - this.pitch) * amount;
    this.zoom += (this.target.zoom - this.zoom) * amount;
    if (this.cameraIsSettled()) {
      this.yaw = this.target.yaw;
      this.pitch = this.target.pitch;
      this.zoom = this.target.zoom;
      this.lastFrameTime = null;
      this.paintCamera();
      return;
    }
    this.paintCamera();
    this.cameraFrame = requestAnimationFrame(this.animateCameraFrame);
  },

  stopCameraMotion() {
    if (this.cameraFrame !== null) cancelAnimationFrame(this.cameraFrame);
    this.cameraFrame = null;
    this.lastFrameTime = null;
  },

  interruptCamera() {
    this.stopCameraMotion();
    this.target.yaw = this.yaw;
    this.target.pitch = this.pitch;
    this.target.zoom = this.zoom;
    this.updateZoomButtons();
  },

  updateZoomButtons() {
    this.zoomInButton.disabled = this.target.zoom >= 1.65;
    this.zoomOutButton.disabled = this.target.zoom <= 0.75;
  },

  startPointer(event) {
    if (event.button !== 0 || (!event.isPrimary && event.pointerType !== 'touch')) return;
    const activePointer = this.pointers.values().next().value;
    if (activePointer && (activePointer.type !== 'touch' || event.pointerType !== 'touch')) return;
    if (!this.pointers.size) this.suppressClick = false;
    this.interruptCamera();
    this.pointers.set(event.pointerId, {
      id: event.pointerId,
      type: event.pointerType,
      x: event.clientX,
      y: event.clientY,
      captureTarget: event.target
    });
    if (this.pointers.size === 1) {
      this.gesture = {
        type: 'drag',
        x: event.clientX,
        y: event.clientY,
        yaw: this.yaw,
        pitch: this.pitch,
        moved: false
      };
    } else {
      this.startPinch();
      this.capturePointers();
      this.viewport.classList.add('is-dragging');
      event.preventDefault();
    }
  },

  startPinch() {
    const [first, second] = this.pointers.values();
    this.gesture = {
      type: 'pinch',
      distance: Math.max(1, Math.hypot(first.x - second.x, first.y - second.y)),
      zoom: this.target.zoom,
      moved: true
    };
  },

  capturePointers() {
    for (const pointer of this.pointers.values()) {
      if (this.viewport.hasPointerCapture(pointer.id)) continue;
      try {
        this.viewport.setPointerCapture(pointer.id);
        pointer.captureTarget = this.viewport;
      } catch (error) {
        if (error.name !== 'NotFoundError') throw error;
      }
    }
  },

  releasePointer(pointer) {
    const target = pointer.captureTarget;
    if (!target?.hasPointerCapture(pointer.id)) return;
    try {
      target.releasePointerCapture(pointer.id);
    } catch (error) {
      if (error.name !== 'NotFoundError') throw error;
    }
  },

  movePointer(event) {
    const pointer = this.pointers.get(event.pointerId);
    if (!pointer || !this.gesture) return;
    pointer.x = event.clientX;
    pointer.y = event.clientY;
    if (this.gesture.type === 'pinch') {
      const [first, second] = this.pointers.values();
      const distance = Math.hypot(first.x - second.x, first.y - second.y);
      this.target.zoom = this.gesture.zoom * distance / this.gesture.distance;
    } else {
      const dx = pointer.x - this.gesture.x;
      const dy = pointer.y - this.gesture.y;
      if (!this.gesture.moved) {
        if (Math.hypot(dx, dy) < 8) return;
        this.gesture.moved = true;
        this.capturePointers();
        this.viewport.classList.add('is-dragging');
      }
      this.target.yaw = this.gesture.yaw + dx * 0.07;
      this.target.pitch = this.gesture.pitch - dy * 0.04;
    }
    event.preventDefault();
    this.requestCamera({ damping: GESTURE_DAMPING });
  },

  endPointer(event) {
    const pointer = this.pointers.get(event.pointerId);
    if (!pointer) return;
    this.suppressClick = this.suppressClick || this.gesture.moved;
    this.pointers.delete(event.pointerId);
    this.releasePointer(pointer);
    if (this.pointers.size >= 2) {
      this.startPinch();
    } else if (this.pointers.size === 1) {
      const remaining = this.pointers.values().next().value;
      this.gesture = {
        type: 'drag',
        x: remaining.x,
        y: remaining.y,
        yaw: this.target.yaw,
        pitch: this.target.pitch,
        moved: true
      };
    } else {
      this.gesture = null;
      this.viewport.classList.remove('is-dragging');
    }
  },

  cancelGesture() {
    this.suppressClick = this.suppressClick || Boolean(this.gesture?.moved);
    this.gesture = null;
    const pointers = [...this.pointers.values()];
    this.pointers.clear();
    for (const pointer of pointers) this.releasePointer(pointer);
    this.viewport.classList.remove('is-dragging');
    this.interruptCamera();
  },

  zoomWheel(event) {
    event.preventDefault();
    if (this.pointers.size || event.deltaY === 0) return;
    const unit = event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? this.viewportHeight : 1;
    const delta = event.deltaY * unit;
    this.target.zoom *= Math.exp(-delta * (event.ctrlKey ? 0.008 : 0.0015));
    this.requestCamera({ damping: WHEEL_DAMPING });
  },

  updateFit() {
    const { clientWidth: width, clientHeight: height } = this.viewport;
    this.viewportHeight = height;
    // Portrait crops the side walls, not the artwork scale; each room keeps its dimensions.
    this.fit = width < height
      ? Math.min(width / (this.roomWidth * 0.57), height / (this.roomHeight + this.roomDepth * 0.4))
      : Math.min(width / (this.roomWidth + 170), height / (this.roomHeight + 130));
  },

  paintCamera() {
    this.camera.style.setProperty('--exhibit-scale', this.fit * this.zoom);
    this.camera.style.setProperty('--exhibit-yaw', `${this.yaw}deg`);
    this.camera.style.setProperty('--exhibit-pitch', `${this.pitch}deg`);
  },

  syncFullscreen() {
    const button = this.el.querySelector('[data-fullscreen]');
    button.hidden = !document.fullscreenEnabled;
    button.setAttribute('aria-label', document.fullscreenElement === this.page
      ? 'Salir de pantalla completa'
      : 'Activar pantalla completa');
  },

  destroyed() {
    this.disposed = true;
    this.cancelGesture();
    this.controller.abort();
    this.resizeObserver.disconnect();
  }
};
