// Progressive enhancement for the WebGPU backgrounds.
//
// This file is served as /js/webgpu.js (about 1 KB, no dependencies) and is the
// only GPU related script the pages load up front. It waits for an idle moment,
// for the canvas to approach the viewport, and for the visitor to allow motion
// before pulling the effect bundle. If anything is missing — no WebGPU adapter,
// reduced motion, slow connection, an exception — the page keeps its static
// background and nothing else changes.
(() => {
  const canvases = Array.from(document.querySelectorAll('canvas[data-webgpu]'));
  if (!canvases.length) return;

  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const connection = navigator.connection ?? {};
  const handles = [];
  let loading;

  const load = async () => {
    loading ??= import('/js/webgpu-effect.js');
    const { mount } = await loading;
    for (const canvas of canvases) {
      if (!canvas.dataset.ready) handles.push(await mount(canvas, canvas.dataset.webgpu));
    }
  };

  const idle = task => ('requestIdleCallback' in window
    ? requestIdleCallback(task, { timeout: 2000 })
    : setTimeout(task, 250));

  // Never compete with anything in the critical path: the enhancement starts
  // once the page has finished loading and the browser is idle again.
  const afterLoad = task => {
    if (document.readyState === 'complete') idle(task);
    else addEventListener('load', () => idle(task), { once: true });
  };

  const begin = () => {
    afterLoad(() => {
      load().catch(() => {
        // Keep the static design: an unsupported browser, a lost adapter or a
        // CSP that blocks the module must never break the page.
      });
    });
  };

  const supported = !!navigator.gpu && !reducedMotion.matches && !connection.saveData;
  if (!supported) return;

  if (!('IntersectionObserver' in window)) {
    begin();
  } else {
    const observer = new IntersectionObserver((entries, self) => {
      if (!entries.some(entry => entry.isIntersecting)) return;
      self.disconnect();
      begin();
    }, { rootMargin: '300px' });
    canvases.forEach(canvas => observer.observe(canvas));
  }

  // Honour a change of mind without a reload.
  reducedMotion.addEventListener('change', event => {
    if (event.matches) handles.forEach(handle => handle.pause());
    else if (handles.length) handles.forEach(handle => handle.resume());
    else begin();
  });
})();
