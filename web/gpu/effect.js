// WebGPU backgrounds for the marketing site, written with vgpu.
//
// The bundle produced from this file is loaded lazily by /js/webgpu.js, only on
// pages that opt in with <canvas data-webgpu="...">. Everything here is an
// enhancement: the pages look correct without it.
//
// Both shaders render premultiplied alpha into a transparent canvas, so the
// page background shows through and the effect can fade in over the static
// design. Bindings are addressed by their WGSL names through `set()`.

import { effect, frame, init, surface } from 'vgpu';

const aurora = /* wgsl */ `
struct Params {
  time: f32,
  aspect: f32,
  intensity: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

fn blob(point: vec2f, center: vec2f, radius: f32) -> f32 {
  let d = distance(point, center) / radius;
  return 1.0 - smoothstep(0.35, 1.0, d);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let t = params.time * 0.05;
  let p = vec2f((uv.x - 0.5) * params.aspect, uv.y - 0.5);

  // Two large light sources that drift slowly on the right half of the frame,
  // where the hero artwork lives.
  let a = vec2f(0.26 + sin(t) * 0.07, -0.14 + cos(t * 0.8) * 0.06);
  let b = vec2f(0.46 + cos(t * 0.7) * 0.08, 0.12 + sin(t * 0.6) * 0.05);

  var color = vec3f(0.0);
  color += vec3f(0.09, 0.36, 0.87) * blob(p, a, 0.42) * 0.85;
  color += vec3f(0.30, 0.52, 0.98) * blob(p, b, 0.34) * 0.55;

  let rgb = clamp(color, vec3f(0.0), vec3f(1.0));

  // Nothing bleeds into the copy column or past the section edges.
  let vignette =
    smoothstep(0.32, 0.78, uv.x) *
    smoothstep(0.0, 0.26, uv.y) *
    smoothstep(1.0, 0.58, uv.y);

  let alpha = clamp(length(rgb) * params.intensity * vignette, 0.0, 0.55);
  return vec4f(rgb * alpha, alpha);
}
`;

const ribbon = /* wgsl */ `
struct Params {
  time: f32,
  aspect: f32,
  intensity: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Three desynchronised waves read as a market curve without any randomness.
fn curve(x: f32, t: f32) -> f32 {
  return sin(x * 3.1 + t * 0.70) * 0.10
       + sin(x * 1.7 - t * 0.45) * 0.15
       + sin(x * 5.3 + t * 0.90) * 0.03;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let t = params.time * 0.6;
  let y = 0.58 + curve(uv.x, t);
  let above = y - uv.y;

  let thickness = 0.004 + 0.003 * abs(uv.x - 0.5) * 2.0;
  let line = 1.0 - smoothstep(0.0, thickness, abs(above));
  let fill = smoothstep(0.0, 0.34, above) * (1.0 - smoothstep(0.34, 0.58, above));
  let fade = smoothstep(0.0, 0.14, uv.x) * smoothstep(1.0, 0.82, uv.x);

  let color = mix(vec3f(0.09, 0.36, 0.87), vec3f(0.47, 0.68, 1.0), uv.x);
  let alpha = clamp((line * 0.85 + fill * 0.30) * fade * params.intensity, 0.0, 1.0);
  return vec4f(color * alpha, alpha);
}
`;

const sources = { aurora, ribbon };

let gpuPromise;

export async function mount(canvas, mode = 'aurora') {
  const source = sources[mode] ?? sources.aurora;
  gpuPromise ??= init();
  const gpu = await gpuPromise;

  const dark = matchMedia('(prefers-color-scheme: dark)');
  const base = Number(canvas.dataset.intensity ?? (mode === 'ribbon' ? 0.55 : 0.45));
  const target = surface(gpu, canvas, {
    dpr: [1, 1.5],
    clearColor: [0, 0, 0, 0],
    alphaMode: 'premultiplied',
    label: `webgpu-${mode}`,
  });
  const pass = effect(gpu, source, { label: `webgpu-${mode}` });

  let last = 0;
  let raf = 0;
  let onScreen = true;

  const write = time => pass.set({
    params: {
      time,
      aspect: target.size[0] / target.size[1],
      intensity: base * (dark.matches ? 0.65 : 1),
    },
  });

  const step = now => {
    raf = requestAnimationFrame(step);
    // A background does not need 60 fps, and halving the work keeps laptops cool.
    if (now - last < 33) return;
    last = now;
    write(now / 1000);
    frame(gpu, f => f.pass(target, pass));
  };

  const pause = () => {
    cancelAnimationFrame(raf);
    raf = 0;
  };
  const resume = () => {
    if (raf || document.hidden || !onScreen) return;
    last = performance.now();
    write(last / 1000);
    frame(gpu, f => f.pass(target, pass));
    canvas.dataset.ready = '';
    raf = requestAnimationFrame(step);
  };

  write(0);
  target.onResize(() => write(last / 1000));

  const observer = new IntersectionObserver(entries => {
    onScreen = entries.some(entry => entry.isIntersecting);
    onScreen ? resume() : pause();
  });
  observer.observe(canvas);

  const onVisibility = () => (document.hidden ? pause() : resume());
  document.addEventListener('visibilitychange', onVisibility);
  addEventListener('pagehide', pause, { once: true });

  return {
    pause,
    resume,
    dispose() {
      pause();
      observer.disconnect();
      document.removeEventListener('visibilitychange', onVisibility);
      delete canvas.dataset.ready;
      target.dispose();
    },
  };
}
