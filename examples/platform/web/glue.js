// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only
//
// JS half of the rhi WebGPU backend, plus the standalone C3 browser boot
// path. The `wgpu` and `webgl` imports are plain wasm imports; no external runtime
// or application framework is required.
//
// Contract with the C3 side:
//
//   * WebGPU objects never cross the boundary. They live in `handles` and are
//     addressed by a u32 index; 0 is null.
//   * Every argument is a scalar or a (ptr, len) pair into wasm linear memory.
//     No struct layout is shared, so there is nothing to drift out of sync.
//   * The enum tables below are positional. Their order must match the
//     corresponding `enum u32` in c3/src/rhi/webgpu.c3 exactly; adding a value means
//     adding it in both files, at the same index.
//   * Sizes and offsets are u32, so no BigInt is ever involved. u64 values that
//     must round-trip (timeline counters) are split into lo/hi halves.

// --- Enum tables (order must match c3/src/rhi/webgpu.c3) --------------------

// Must equal `GLUE_ABI_VERSION` in c3/src/rhi/rhi.c3. The browser caches this file
// and the .wasm independently, so a stale glue can be paired with a fresh
// module; JS would then silently shift every import argument rather than fail.
// `boot()` checks the module's `rhi_glue_abi_version` export against it.
const GLUE_ABI_VERSION = 5;

const TEXTURE_FORMAT = [
  "r8unorm", "r8snorm", "r8uint", "r8sint",
  "r16uint", "r16sint", "r16float",
  "rg8unorm", "rg8snorm", "rg8uint", "rg8sint",
  "r32uint", "r32sint", "r32float",
  "rg16uint", "rg16sint", "rg16float",
  "rgba8unorm", "rgba8unorm-srgb", "rgba8snorm", "rgba8uint", "rgba8sint",
  "bgra8unorm", "bgra8unorm-srgb",
  "rgb9e5ufloat", "rgb10a2uint", "rgb10a2unorm", "rg11b10ufloat",
  "rg32uint", "rg32sint", "rg32float",
  "rgba16uint", "rgba16sint", "rgba16float",
  "rgba32uint", "rgba32sint", "rgba32float",
  "depth16unorm", "depth24plus", "depth24plus-stencil8", "depth32float", "depth32float-stencil8",
  "bc1-rgba-unorm", "bc1-rgba-unorm-srgb", "bc2-rgba-unorm", "bc2-rgba-unorm-srgb",
  "bc3-rgba-unorm", "bc3-rgba-unorm-srgb", "bc4-r-unorm", "bc4-r-snorm",
  "bc5-rg-unorm", "bc5-rg-snorm", "bc6h-rgb-ufloat", "bc6h-rgb-float",
  "bc7-rgba-unorm", "bc7-rgba-unorm-srgb",
  "etc2-rgb8unorm", "etc2-rgb8unorm-srgb", "etc2-rgb8a1unorm", "etc2-rgb8a1unorm-srgb",
  "etc2-rgba8unorm", "etc2-rgba8unorm-srgb",
  "eac-r11unorm", "eac-r11snorm", "eac-rg11unorm", "eac-rg11snorm",
  // `undefined_format`: the Zig-side sentinel for "no such WebGPU format".
  // Reaching JS as an actual format is a bug; as a depth format it means the
  // render pass has no depth attachment.
  null,
];

const TEXTURE_DIMENSION = ["1d", "2d", "3d"];
const VIEW_DIMENSION = ["1d", "2d", "2d-array", "cube", "cube-array", "3d"];
const TEXTURE_ASPECT = ["all", "stencil-only", "depth-only"];
const LOAD_OP = ["load", "clear"];
const STORE_OP = ["store", "discard"];
const TOPOLOGY = ["point-list", "line-list", "line-strip", "triangle-list", "triangle-strip"];
const CULL_MODE = ["none", "front", "back"];
const FRONT_FACE = ["ccw", "cw"];
const COMPARE = ["never", "less", "equal", "less-equal", "greater", "not-equal", "greater-equal", "always"];
const INDEX_FORMAT = ["uint16", "uint32"];
const VERTEX_FORMAT = ["float32", "float32x2", "float32x3", "float32x4"];
const BLEND_FACTOR = [
  "zero", "one",
  "src", "one-minus-src", "src-alpha", "one-minus-src-alpha",
  "dst", "one-minus-dst", "dst-alpha", "one-minus-dst-alpha",
  "src-alpha-saturated", "constant", "one-minus-constant",
];
const BLEND_OP = ["add", "subtract", "reverse-subtract", "min", "max"];
const FILTER_MODE = ["nearest", "linear"];
const ADDRESS_MODE = ["clamp-to-edge", "repeat", "mirror-repeat"];

// --- Handle table ----------------------------------------------------------

// Index 0 is reserved as the null handle, matching `Handle.none` in Zig.
const handles = [null];
const freeList = [];

function put(obj) {
  if (obj === null || obj === undefined) return 0;
  if (freeList.length > 0) {
    const id = freeList.pop();
    handles[id] = obj;
    return id;
  }
  handles.push(obj);
  return handles.length - 1;
}

function get(id) {
  return id === 0 ? null : handles[id];
}

function drop(id) {
  if (id === 0 || id >= handles.length || handles[id] === null) return;
  handles[id] = null;
  freeList.push(id);
}

// --- Boot ------------------------------------------------------------------

/**
 * Load and run a C3 wasm module.
 *
 * The adapter and device are requested before instantiation. This keeps the
 * C3 init path synchronous while still allowing the browser to choose WebGPU
 * or WebGL2 at runtime. The only imported namespaces are `wgpu` and `webgl`.
 *
 * Options:
 *   - `canvas`         canvas selector (default "#canvas")
 *   - `forceBackend`   "webgl" skips the WebGPU probe; "webgpu" never falls back
 *   - `adapterOptions`, `deviceOptions`  forwarded to requestAdapter/requestDevice
 *   - `assetVersion`   cache-bust token appended to the webgl_glue.js import
 *   - `onBackend(name)` called with "webgpu" | "webgl" once selected
 *   - `log`            console-like sink for `[rhi]` messages (default console)
 *
 * The wasm module is expected to export:
 *   - `memory`
 *   - `_start()`                                           (optional wasm start)
 *   - `rhi_glue_abi_version() -> u32`                       (must equal GLUE_ABI_VERSION)
 *   - `rhi_web_alloc(len) -> ptr`                           (0 = allocation failure)
 *   - `rhi_web_init(selectorPtr, selectorLen) -> i32`       (0 = ok)
 *   - `rhi_web_frame(widthPx, heightPx, timeMs: f64) -> i32` (0 = continue)
 *   - `rhi_web_deinit()`                                    (optional)
 *
 * Resolves to `{ backend, instance, exports, stop() }`. `stop()` is
 * idempotent: it cancels the frame loop and runs `rhi_web_deinit`.
 */
export async function boot(wasmUrl, options = {}) {
  const log = options.log ?? console;
  const canvasSelector = options.canvas ?? "#canvas";
  // The WebGL2 half is imported dynamically so it can carry the per-build
  // cache-bust token, and so it resolves relative to this file. It is always
  // loaded: instantiation fails unless every declared import is supplied.
  const assetVersion = options.assetVersion ? `?v=${options.assetVersion}` : "";
  const { makeWebglImports } = await import(`./webgl_glue.js${assetVersion}`);
  const canvas = document.querySelector(canvasSelector);
  if (!canvas) throw new Error(`no element matches canvas selector ${canvasSelector}`);

  // Probe WebGPU, then fall back to WebGL2. A canvas can only ever hand out one
  // context type, so WebGL2 is only requested when WebGPU is unusable.
  let adapter = null;
  let device = null;
  let webgpuError = "not attempted";
  if (options.forceBackend !== "webgl") {
    const gpu = globalThis.navigator?.gpu;
    if (!gpu) {
      webgpuError = "navigator.gpu is undefined (needs a secure context and a browser with WebGPU enabled)";
    } else {
      try {
        adapter = await gpu.requestAdapter(options.adapterOptions);
        if (!adapter) {
          webgpuError = "requestAdapter() returned null (on Linux, Chrome needs --enable-unsafe-webgpu)";
        } else {
          device = await adapter.requestDevice(options.deviceOptions);
          if (!device) webgpuError = "requestDevice() returned null";
        }
      } catch (e) {
        webgpuError = String(e && e.message ? e.message : e);
      }
      if (!device) adapter = null;
    }
  }
  if (!device && options.forceBackend === "webgpu") {
    throw new Error(`WebGPU was forced but is unavailable: ${webgpuError}`);
  }

  let gl = null;
  let webglError = "not attempted";
  if (!device) {
    gl = canvas.getContext("webgl2", { alpha: false, antialias: false, depth: false, stencil: false });
    if (!gl) webglError = "canvas.getContext('webgl2') returned null";
  }
  if (!device && !gl) {
    throw new Error(`no usable GPU backend.\n  WebGPU: ${webgpuError}\n  WebGL2: ${webglError}`);
  }
  const backend = device ? "webgpu" : "webgl";
  log.info(`[rhi] backend: ${device ? "WebGPU" : "WebGL2"}`);
  options.onBackend?.(backend);

  if (device) {
    device.lost?.then((info) => {
      log.error(`[rhi] WebGPU device lost (${info?.reason}): ${info?.message}`);
    });
    // Validation failures are otherwise reported asynchronously and are easy
    // to miss; surfacing them eagerly keeps the cause near the effect.
    device.addEventListener?.("uncapturederror", (e) => {
      log.error("[rhi] WebGPU error:", e.error?.message ?? e.error);
    });
  }

  // Filled in after instantiation; imports close over this object rather than
  // the instance so they can be built first.
  const wasm = { memory: null, exports: null };
  const u8 = () => new Uint8Array(wasm.memory.buffer);
  const u32 = () => new Uint32Array(wasm.memory.buffer);
  const f32 = () => new Float32Array(wasm.memory.buffer);
  const bytes = (ptr, len) => u8().subarray(ptr, ptr + len);
  const str = (ptr, len) => new TextDecoder().decode(bytes(ptr, len));

  const imports = {
    wgpu: makeImports({ adapter, device, wasm, u8, u32, bytes, str }),
    webgl: makeWebglImports({ gl, wasm, u8, f32, bytes, str }),
  };

  const instance = await instantiate(wasmUrl, imports);
  const exports = instance.exports;
  wasm.memory = exports.memory;
  wasm.exports = exports;

  // Catch a cached-glue/fresh-wasm pairing before any export runs with
  // mismatched arguments.
  const moduleAbi = typeof exports.rhi_glue_abi_version === "function" ? exports.rhi_glue_abi_version() : undefined;
  if (moduleAbi !== GLUE_ABI_VERSION) {
    throw new Error(
      `glue.js is ABI version ${GLUE_ABI_VERSION} but ${wasmUrl} ` +
      (moduleAbi === undefined ? "does not export rhi_glue_abi_version" : `was built for ABI version ${moduleAbi}`) +
      `. This is almost always a stale browser cache — hard reload (Ctrl+Shift+R).`,
    );
  }

  exports._start?.();

  // Hand the selector to C3 through wasm memory so the swapchain can resolve
  // the same canvas when it creates its surface.
  const selectorBytes = new TextEncoder().encode(canvasSelector);
  const selectorPtr = exports.rhi_web_alloc(selectorBytes.length);
  if (!selectorPtr) throw new Error(`rhi_web_alloc(${selectorBytes.length}) failed`);
  u8().set(selectorBytes, selectorPtr);
  const initRc = exports.rhi_web_init(selectorPtr, selectorBytes.length);
  if (initRc !== 0) throw new Error(`rhi_web_init failed with ${initRc}`);

  // Queue pointer input until the next frame. This keeps browser callbacks
  // outside command recording and is harmless for examples that do not use
  // the platform event callback.
  const pointerEvent = exports.rhi_web_pointer_event;
  const dpr = () => globalThis.devicePixelRatio || 1;
  const pointer = (event, type) => {
    if (typeof pointerEvent !== "function") return;
    const rect = canvas.getBoundingClientRect();
    const scale = dpr();
    pointerEvent(
      type,
      (event.clientX - rect.left) * scale,
      (event.clientY - rect.top) * scale,
      event.button < 0 ? 0 : event.button,
    );
  };
  const onMove = (event) => pointer(event, 0);
  const onDown = (event) => {
    pointer(event, 1);
    canvas.setPointerCapture?.(event.pointerId);
  };
  const onUp = (event) => {
    pointer(event, 2);
    canvas.releasePointerCapture?.(event.pointerId);
  };
  const onContextMenu = (event) => event.preventDefault();
  canvas.addEventListener?.("pointermove", onMove);
  canvas.addEventListener?.("pointerdown", onDown);
  canvas.addEventListener?.("pointerup", onUp);
  canvas.addEventListener?.("contextmenu", onContextMenu);

  let running = true;
  let rafId = 0;
  const stop = () => {
    if (!running) return;
    running = false;
    if (rafId) globalThis.cancelAnimationFrame?.(rafId);
    rafId = 0;
    canvas.removeEventListener?.("pointermove", onMove);
    canvas.removeEventListener?.("pointerdown", onDown);
    canvas.removeEventListener?.("pointerup", onUp);
    canvas.removeEventListener?.("contextmenu", onContextMenu);
    try {
      exports.rhi_web_deinit?.();
    } catch (e) {
      log.error("[rhi] shutdown threw:", e);
    }
  };

  const frame = (timeMs) => {
    rafId = 0;
    if (!running) return;
    // Track the backing-store size to the CSS size. Zero is preserved so a
    // hidden canvas can be skipped by the C3 example without acquiring it.
    const scale = dpr();
    const w = Math.max(0, Math.floor(canvas.clientWidth * scale));
    const h = Math.max(0, Math.floor(canvas.clientHeight * scale));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }
    let rc;
    try {
      rc = exports.rhi_web_frame(w, h, timeMs ?? 0);
    } catch (e) {
      log.error("[rhi] frame threw, stopping loop:", e);
      stop();
      return;
    }
    if (rc !== 0) {
      stop();
      return;
    }
    rafId = requestAnimationFrame(frame);
  };
  rafId = requestAnimationFrame(frame);

  return { backend, instance, exports, stop };
}

// Streaming compile when the server sends `application/wasm`; otherwise (wrong
// MIME, or no instantiateStreaming at all) fall back to a buffered compile.
async function instantiate(url, imports) {
  const response = await fetch(url);
  if (typeof WebAssembly.instantiateStreaming === "function") {
    const fallback = response.clone();
    try {
      return (await WebAssembly.instantiateStreaming(response, imports)).instance;
    } catch (e) {
      // Link/compile errors would recur with the buffered path; only a
      // TypeError (MIME or Response problems) is worth retrying.
      if (!(e instanceof TypeError)) throw e;
      console.warn("[rhi] instantiateStreaming failed, falling back to arrayBuffer():", e.message);
      return (await WebAssembly.instantiate(await fallback.arrayBuffer(), imports)).instance;
    }
  }
  return (await WebAssembly.instantiate(await response.arrayBuffer(), imports)).instance;
}

// --- Imports ---------------------------------------------------------------

export function makeImports(ctx) {
  const { wasm, u8, u32, bytes, str } = ctx;
  // Providers can be used by a host bootloader (which already owns handles)
  // or directly by a test/embedding. The object form seeds this module's
  // private table without requiring wasm instantiation here.
  const adapterHandle = ctx.adapterHandle ?? put(ctx.adapter);
  const deviceHandle = ctx.deviceHandle ?? put(ctx.device);
  // The queue is a device-owned singleton. Cache its handle so renderer and
  // device bootstrap both observe exactly one foreign handle to release.
  const queueHandles = new Map();

  // Per-surface state. A surface handle wraps the canvas context plus the
  // configuration it was last given, because `getCurrentTexture` needs both and
  // WebGPU has no object that bundles them.
  const surfaces = new Map();

  return {
    // -- Adapter / device --------------------------------------------------
    wgpu_adapter_get: () => adapterHandle,
    wgpu_device_get: () => deviceHandle,
    wgpu_device_get_queue: (dev) => {
      if (queueHandles.has(dev)) return queueHandles.get(dev);
      const queue = put(get(dev)?.queue);
      queueHandles.set(dev, queue);
      return queue;
    },

    wgpu_adapter_name: (adapter, bufPtr, bufLen) => {
      const a = get(adapter);
      // `info` is the modern spelling; older builds exposed only the (removed)
      // async requestAdapterInfo, so fall back to an empty description rather
      // than throwing.
      const name = a?.info?.description || a?.info?.vendor || "WebGPU";
      const enc = new TextEncoder().encode(name);
      const n = Math.min(enc.length, bufLen);
      u8().set(enc.subarray(0, n), bufPtr);
      return n;
    },
    // The browser deliberately withholds vendor/device ids from most origins;
    // 0 means "not reported" and the Zig side maps it to `.unknown`.
    wgpu_adapter_vendor_id: (adapter) => {
      const v = get(adapter)?.info?.vendor;
      // Chrome reports a vendor string ("nvidia"), not a PCI id. Map the ones
      // the RHI's Vendor enum knows about back to their PCI ids.
      if (typeof v === "string") {
        const s = v.toLowerCase();
        if (s.includes("nvidia")) return 0x10de;
        if (s.includes("amd") || s.includes("ati")) return 0x1002;
        if (s.includes("intel")) return 0x8086;
      }
      return 0;
    },
    wgpu_adapter_device_id: (adapter) => {
      const d = get(adapter)?.info?.device;
      return typeof d === "number" ? d : 0;
    },
    // 0 = discrete, 1 = integrated, 2 = cpu, 3 = unknown.
    wgpu_adapter_type: (adapter) => {
      const a = get(adapter);
      if (a?.info?.architecture === "cpu" || a?.isFallbackAdapter) return 2;
      const t = a?.info?.type;
      if (t === "discrete-gpu") return 0;
      if (t === "integrated-gpu") return 1;
      return 3;
    },
    wgpu_adapter_limit: (adapter, namePtr, nameLen) => {
      const v = get(adapter)?.limits?.[str(namePtr, nameLen)];
      return typeof v === "number" ? v : 0;
    },

    wgpu_release: (handle) => {
      const obj = get(handle);
      // GPUBuffer/GPUTexture/GPUQuerySet own real memory and expose destroy();
      // everything else is reclaimed by GC once the table entry is cleared.
      if (obj && typeof obj.destroy === "function") {
        try {
          obj.destroy();
        } catch {
          // A canvas texture is destroyed by the browser at end of frame;
          // destroying it again is harmless but throws in some builds.
        }
      }
      surfaces.delete(handle);
      drop(handle);
    },

    // -- Surface (canvas) --------------------------------------------------
    wgpu_surface_create: (selPtr, selLen) => {
      const selector = str(selPtr, selLen);
      const canvas = document.querySelector(selector);
      if (!canvas) {
        console.error(`[rhi] no element matches canvas selector ${selector}`);
        return 0;
      }
      const context = canvas.getContext("webgpu");
      if (!context) {
        console.error("[rhi] canvas.getContext('webgpu') returned null");
        return 0;
      }
      const id = put(context);
      surfaces.set(id, { canvas, context, format: null });
      return id;
    },
    wgpu_surface_preferred_format: () => {
      const name = navigator.gpu.getPreferredCanvasFormat();
      const idx = TEXTURE_FORMAT.indexOf(name);
      if (idx < 0) {
        console.error(`[rhi] preferred canvas format ${name} is not in the format table`);
        // bgra8unorm is what every current browser reports; falling back to it
        // is better than handing Zig an out-of-range enum value.
        return TEXTURE_FORMAT.indexOf("bgra8unorm");
      }
      return idx;
    },
    wgpu_surface_configure: (surface, dev, format, width, height) => {
      const s = surfaces.get(surface);
      if (!s) return;
      // The backing store must match what we configure, or getCurrentTexture
      // returns a texture of a different size than the pass expects.
      s.canvas.width = width;
      s.canvas.height = height;
      s.format = TEXTURE_FORMAT[format];
      s.context.configure({
        device: get(dev),
        format: s.format,
        alphaMode: "opaque",
        usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC,
      });
    },
    wgpu_surface_get_current_texture: (surface) => {
      const s = surfaces.get(surface);
      if (!s) return 0;
      try {
        return put(s.context.getCurrentTexture());
      } catch (e) {
        // Thrown when the context is unconfigured or was lost; the Zig side
        // reads a null handle as `.out_of_date` and reconfigures.
        console.warn("[rhi] getCurrentTexture failed:", e);
        return 0;
      }
    },

    // -- Textures ----------------------------------------------------------
    wgpu_device_create_texture: (dev, format, width, height, depthOrLayers, mipLevelCount, sampleCount, dimension, usage) =>
      put(get(dev).createTexture({
        size: { width, height, depthOrArrayLayers: depthOrLayers },
        mipLevelCount,
        sampleCount,
        dimension: TEXTURE_DIMENSION[dimension],
        format: TEXTURE_FORMAT[format],
        usage,
      })),

    wgpu_texture_create_view: (texture, format, dimension, aspect, baseMipLevel, mipLevelCount, baseArrayLayer, arrayLayerCount) =>
      put(get(texture).createView({
        format: TEXTURE_FORMAT[format],
        dimension: VIEW_DIMENSION[dimension],
        aspect: TEXTURE_ASPECT[aspect],
        baseMipLevel,
        mipLevelCount,
        baseArrayLayer,
        arrayLayerCount,
      })),

    // -- Buffers -----------------------------------------------------------
    wgpu_device_create_buffer: (dev, size, usage) =>
      put(get(dev).createBuffer({ size, usage })),

    wgpu_queue_write_buffer: (queue, buffer, bufferOffset, dataPtr, dataLen) => {
      // writeBuffer copies synchronously, so a view into (growable) wasm memory
      // is safe here as long as it is taken fresh.
      get(queue).writeBuffer(get(buffer), bufferOffset, bytes(dataPtr, dataLen));
    },
    wgpu_queue_write_texture: (
      queue, texture, mipLevel, x, y, z, width, height, depth,
      dataPtr, dataLen, bytesPerRow, rowsPerImage,
    ) => {
      // Same freshness rule as writeBuffer: the copy is synchronous, but the
      // view must be taken now because wasm memory can grow.
      get(queue).writeTexture(
        { texture: get(texture), mipLevel, origin: { x, y, z } },
        bytes(dataPtr, dataLen),
        { offset: 0, bytesPerRow, rowsPerImage },
        { width, height, depthOrArrayLayers: depth },
      );
    },

    // -- Shaders -----------------------------------------------------------
    wgpu_device_create_shader_module: (dev, wgslPtr, wgslLen) => {
      const code = str(wgslPtr, wgslLen);
      const module = get(dev).createShaderModule({ code });
      // Compilation is async but the messages are worth surfacing: a WGSL error
      // otherwise shows up only as a pipeline creation failure.
      module.getCompilationInfo?.().then((info) => {
        for (const m of info.messages) {
          if (m.type === "error") console.error(`[rhi] WGSL ${m.lineNum}:${m.linePos}: ${m.message}`);
          else if (m.type === "warning") console.warn(`[rhi] WGSL ${m.lineNum}:${m.linePos}: ${m.message}`);
        }
      });
      return put(module);
    },

    // -- Pipelines ---------------------------------------------------------
    wgpu_device_create_render_pipeline: (
      dev,
      vsModule, vsEntryPtr, vsEntryLen,
      fsModule, fsEntryPtr, fsEntryLen,
      colorFormat, depthFormat,
      topology, cullMode, frontFace,
      depthWrite, depthCompare,
      vertexStride, attrsPtr, attrsLen,
      blendEnable, srcColor, dstColor, colorOp, srcAlpha, dstAlpha, alphaOp, writeMask,
    ) => {
      // Attributes arrive as a flat (location, format, offset) triple array
      // rather than a struct, so there is no field layout to keep in sync.
      const flat = u32().subarray(attrsPtr >> 2, (attrsPtr >> 2) + attrsLen);
      const attributes = [];
      for (let i = 0; i < attrsLen; i += 3) {
        attributes.push({
          shaderLocation: flat[i],
          format: VERTEX_FORMAT[flat[i + 1]],
          offset: flat[i + 2],
        });
      }

      const desc = {
        // "auto" derives bind group layouts from the shader, which is why the
        // backend needs no explicit pipeline layout object.
        layout: "auto",
        vertex: {
          module: get(vsModule),
          entryPoint: str(vsEntryPtr, vsEntryLen),
          buffers: attributes.length > 0
            ? [{ arrayStride: vertexStride, stepMode: "vertex", attributes }]
            : [],
        },
        primitive: {
          topology: TOPOLOGY[topology],
          cullMode: CULL_MODE[cullMode],
          frontFace: FRONT_FACE[frontFace],
        },
      };
      if (fsModule !== 0) {
        desc.fragment = {
          module: get(fsModule),
          entryPoint: str(fsEntryPtr, fsEntryLen),
          targets: [{
            format: TEXTURE_FORMAT[colorFormat],
            writeMask,
            // Omitted entirely when disabled: WebGPU has no "blend off" flag,
            // the absence of the member is what turns it off.
            ...(blendEnable !== 0 ? {
              blend: {
                color: { srcFactor: BLEND_FACTOR[srcColor], dstFactor: BLEND_FACTOR[dstColor], operation: BLEND_OP[colorOp] },
                alpha: { srcFactor: BLEND_FACTOR[srcAlpha], dstFactor: BLEND_FACTOR[dstAlpha], operation: BLEND_OP[alphaOp] },
              },
            } : {}),
          }],
        };
      }
      const depth = TEXTURE_FORMAT[depthFormat];
      if (depth !== null && depth !== undefined) {
        desc.depthStencil = {
          format: depth,
          depthWriteEnabled: depthWrite !== 0,
          depthCompare: COMPARE[depthCompare],
        };
      }
      try {
        return put(get(dev).createRenderPipeline(desc));
      } catch (e) {
        console.error("[rhi] createRenderPipeline failed:", e);
        return 0;
      }
    },

    wgpu_device_create_sampler: (
      dev, magFilter, minFilter, mipmapFilter,
      addressU, addressV, addressW, lodMin, lodMax, maxAnisotropy,
    ) => put(get(dev).createSampler({
      magFilter: FILTER_MODE[magFilter],
      minFilter: FILTER_MODE[minFilter],
      mipmapFilter: FILTER_MODE[mipmapFilter],
      addressModeU: ADDRESS_MODE[addressU],
      addressModeV: ADDRESS_MODE[addressV],
      addressModeW: ADDRESS_MODE[addressW],
      lodMinClamp: lodMin,
      lodMaxClamp: lodMax,
      maxAnisotropy,
      // `compare` is deliberately omitted: a sampler that carries it becomes a
      // comparison sampler and cannot bind against a plain texture_2d<f32>.
    })),
    wgpu_device_create_bind_group_textures: (dev, layout, entriesPtr, entriesLen) => {
      const flat = u32().subarray(entriesPtr >> 2, (entriesPtr >> 2) + entriesLen);
      const entries = [];
      for (let i = 0; i < entriesLen; i += 2) {
        entries.push({ binding: flat[i], resource: get(flat[i + 1]) });
      }
      return put(get(dev).createBindGroup({ layout: get(layout), entries }));
    },
    wgpu_render_pipeline_get_bind_group_layout: (pipeline, index) => {
      try {
        return put(get(pipeline).getBindGroupLayout(index));
      } catch (e) {
        console.error(`[rhi] getBindGroupLayout(${index}) failed:`, e);
        return 0;
      }
    },

    wgpu_device_create_bind_group_uniform: (dev, layout, buffer, offset, size) => {
      try {
        return put(get(dev).createBindGroup({
          layout: get(layout),
          entries: [{ binding: 0, resource: { buffer: get(buffer), offset, size } }],
        }));
      } catch (e) {
        console.error("[rhi] createBindGroup failed:", e);
        return 0;
      }
    },

    // -- Command encoding --------------------------------------------------
    wgpu_device_create_command_encoder: (dev) => put(get(dev).createCommandEncoder()),

    wgpu_command_encoder_begin_render_pass: (
      encoder,
      colorView, colorLoadOp, colorStoreOp, r, g, b, a,
      depthView, depthLoadOp, depthStoreOp, clearDepth,
      depthReadOnly, hasStencil, stencilLoadOp, stencilStoreOp, clearStencil,
    ) => {
      // A null color view is a depth-only pass: WebGPU accepts an empty
      // colorAttachments list as long as a depth attachment is present.
      const desc = {
        colorAttachments: colorView !== 0 ? [{
          view: get(colorView),
          loadOp: LOAD_OP[colorLoadOp],
          storeOp: STORE_OP[colorStoreOp],
          clearValue: { r, g, b, a },
        }] : [],
      };
      if (depthView !== 0) {
        // A read-only aspect must not carry load/store ops, and stencil ops
        // are only legal when the view has a stencil aspect.
        const ds = { view: get(depthView) };
        if (depthReadOnly) {
          ds.depthReadOnly = true;
        } else {
          ds.depthLoadOp = LOAD_OP[depthLoadOp];
          ds.depthStoreOp = STORE_OP[depthStoreOp];
          ds.depthClearValue = clearDepth;
        }
        if (hasStencil) {
          if (depthReadOnly) {
            ds.stencilReadOnly = true;
          } else {
            ds.stencilLoadOp = LOAD_OP[stencilLoadOp];
            ds.stencilStoreOp = STORE_OP[stencilStoreOp];
            ds.stencilClearValue = clearStencil;
          }
        }
        desc.depthStencilAttachment = ds;
      }
      return put(get(encoder).beginRenderPass(desc));
    },

    wgpu_command_encoder_copy_buffer_to_buffer: (encoder, src, srcOffset, dst, dstOffset, size) =>
      get(encoder).copyBufferToBuffer(get(src), srcOffset, get(dst), dstOffset, size),

    // `z` is origin.z: the first array layer of a 2D texture or the first
    // depth slice of a 3D one. `depthOrLayers` is the matching extent.
    wgpu_command_encoder_copy_buffer_to_texture: (
      encoder, buffer, offset, bytesPerRow, rowsPerImage,
      texture, mipLevel, x, y, z, width, height, depthOrLayers,
    ) =>
      get(encoder).copyBufferToTexture(
        { buffer: get(buffer), offset, bytesPerRow, rowsPerImage },
        { texture: get(texture), mipLevel, origin: { x, y, z } },
        { width, height, depthOrArrayLayers: depthOrLayers },
      ),

    // Origins follow copy_buffer_to_texture: `z` is the first array layer of
    // a 2D texture or the first depth slice of a 3D one.
    wgpu_command_encoder_copy_texture_to_texture: (
      encoder, src, srcMip, srcX, srcY, srcZ,
      dst, dstMip, dstX, dstY, dstZ, width, height, depthOrLayers,
    ) =>
      get(encoder).copyTextureToTexture(
        { texture: get(src), mipLevel: srcMip, origin: { x: srcX, y: srcY, z: srcZ } },
        { texture: get(dst), mipLevel: dstMip, origin: { x: dstX, y: dstY, z: dstZ } },
        { width, height, depthOrArrayLayers: depthOrLayers },
      ),

    wgpu_command_encoder_finish: (encoder) => put(get(encoder).finish()),

    // -- Render pass -------------------------------------------------------
    wgpu_render_pass_set_viewport: (pass, x, y, width, height, minDepth, maxDepth) =>
      get(pass).setViewport(x, y, width, height, minDepth, maxDepth),
    wgpu_render_pass_set_scissor_rect: (pass, x, y, width, height) =>
      get(pass).setScissorRect(x, y, width, height),
    wgpu_render_pass_set_pipeline: (pass, pipeline) => get(pass).setPipeline(get(pipeline)),
    wgpu_render_pass_set_bind_group: (pass, index, bindGroup) =>
      get(pass).setBindGroup(index, get(bindGroup)),
    wgpu_render_pass_set_vertex_buffer: (pass, slot, buffer, offset) =>
      get(pass).setVertexBuffer(slot, get(buffer), offset),
    wgpu_render_pass_set_index_buffer: (pass, buffer, format, offset) =>
      get(pass).setIndexBuffer(get(buffer), INDEX_FORMAT[format], offset),
    wgpu_render_pass_draw: (pass, vertexCount, instanceCount, firstVertex, firstInstance) =>
      get(pass).draw(vertexCount, instanceCount, firstVertex, firstInstance),
    wgpu_render_pass_draw_indexed: (pass, indexCount, instanceCount, firstIndex, baseVertex, firstInstance) =>
      get(pass).drawIndexed(indexCount, instanceCount, firstIndex, baseVertex, firstInstance),
    wgpu_render_pass_draw_indirect: (pass, buffer, offset) =>
      get(pass).drawIndirect(get(buffer), offset),
    wgpu_render_pass_draw_indexed_indirect: (pass, buffer, offset) =>
      get(pass).drawIndexedIndirect(get(buffer), offset),
    wgpu_render_pass_end: (pass) => get(pass).end(),

    // -- Queue -------------------------------------------------------------
    wgpu_queue_submit: (queue, bufsPtr, count) => {
      const ids = u32().subarray(bufsPtr >> 2, (bufsPtr >> 2) + count);
      const list = [];
      for (let i = 0; i < count; i++) list.push(get(ids[i]));
      get(queue).submit(list);
    },

    // Writes `value` back to `outPtr` as two little-endian u32s once the GPU
    // has finished the work submitted so far. Splitting the u64 keeps BigInt
    // out of the boundary entirely. `outPtr` points at a `[2]u32` inside a
    // Timeline, which outlives the callback.
    wgpu_queue_on_submitted_work_done: (queue, outPtr, valueLo, valueHi) => {
      get(queue).onSubmittedWorkDone().then(() => {
        const idx = outPtr >> 2;
        const view = u32();
        // Callbacks can retire out of order relative to each other; only ever
        // move the completed value forward.
        const prev = view[idx + 1] * 0x100000000 + view[idx];
        const next = valueHi * 0x100000000 + valueLo;
        if (next > prev) {
          view[idx] = valueLo;
          view[idx + 1] = valueHi;
        }
      });
    },

    // -- Diagnostics -------------------------------------------------------
    wgpu_log: (level, ptr, len) => {
      const msg = str(ptr, len);
      if (level >= 3) console.error(msg);
      else if (level === 2) console.warn(msg);
      else if (level === 1) console.info(msg);
      else console.debug(msg);
    },
  };
}
export { GLUE_ABI_VERSION, makeImports as makeWebgpuImports, put, get, drop };
