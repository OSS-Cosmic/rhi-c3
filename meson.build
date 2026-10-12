project(
  'rhi', 'c', 'cpp',
  version: '0.1.0',
  meson_version: '>=1.1',
  default_options: ['warning_level=0'],
)

# Meson has no C3 support: it builds the vendor C++ archives natively and
# wraps c3c. c3c writes into this repo's own build/ dir (project.json), so the
# Meson build directory must not be build/ (use e.g. `meson setup build-meson`).

fs = import('fs')
root = meson.project_source_root()
python = find_program('python3', 'python')
stage = files('tools/stage_lib.py')

if fs.is_samepath(meson.project_build_root(), root / 'build')
  error('Meson build dir must not be build/ (c3c owns it); use `meson setup build-meson`')
endif

# --- vma ----------------------------------------------------------------
vma = static_library(
  'vma', 'vendor/vma_impl.cpp',
  include_directories: include_directories('vendor/VulkanMemoryAllocator/include'),
  cpp_args: ['-DVMA_STATIC_VULKAN_FUNCTIONS=0', '-DVMA_DYNAMIC_VULKAN_FUNCTIONS=1'],
  override_options: ['cpp_std=c++17', 'optimization=2', 'b_staticpic=true'],
  build_by_default: false,
)
stage_vma = custom_target(
  'stage-vma',
  input: vma, output: 'vma.stamp',
  command: [python, stage, '@INPUT@', root / 'vendor/lib', '@OUTPUT@'],
  build_by_default: false,
)
vulkan_deps = [vma, stage_vma]
test_deps = [vma, stage_vma]
imgui_test_deps = []

# --- imgui (optional: needs the vendor/imgui_c/imgui submodules) -----------------
if fs.is_file('vendor/imgui_c/imgui/imgui.cpp')
  imgui = static_library(
    'imgui',
    'vendor/imgui_c/imgui/imgui.cpp', 'vendor/imgui_c/imgui/imgui_draw.cpp',
    'vendor/imgui_c/imgui/imgui_tables.cpp', 'vendor/imgui_c/imgui/imgui_widgets.cpp',
    'vendor/imgui_c/imgui/imgui_demo.cpp', 'vendor/imgui_c/imgui_c.cpp',
    include_directories: include_directories('vendor/imgui_c/imgui', 'vendor/imgui_c'),
    override_options: [
      'cpp_std=c++17', 'optimization=2', 'b_staticpic=true',
      'cpp_eh=none', 'cpp_rtti=false', 'b_ndebug=true',
    ],
  )
  stage_imgui = custom_target(
    'stage-imgui',
    input: imgui, output: 'imgui.stamp',
    command: [python, stage, '@INPUT@', root / 'vendor/imgui_c/lib', '@OUTPUT@'],
    build_by_default: true,
  )
  imgui_test_deps += [imgui, stage_imgui]
  vulkan_deps += [imgui, stage_imgui]
  test_deps += [imgui, stage_imgui]
else
  message('imgui skipped: vendor/imgui_c/imgui is missing; run: git submodule update --init vendor/imgui_c/imgui')
endif

# --- d3d12ma (windows-x64 cross build, built by default when mingw is found) ---
d3d12ma_target = []
d3d12ma_cxx = get_option('d3d12ma_cxx')
if d3d12ma_cxx == ''
  d3d12ma_cxx = run_command(python, '-c', 'import os;print(os.environ.get("D3D12MA_CXX",""))', check: true).stdout().strip()
endif
if d3d12ma_cxx != ''
  d3d12ma_cxx = find_program(d3d12ma_cxx, required: false)
else
  d3d12ma_cxx = find_program('x86_64-w64-mingw32-g++', required: false)
endif
if d3d12ma_cxx.found()
  d3d12ma_ar = find_program('x86_64-w64-mingw32-ar', 'ar')
  d3d12ma_target = custom_target(
    'd3d12ma',
    output: 'libd3d12ma.a',
    command: [python, files('tools/build_d3d12ma.py'), d3d12ma_cxx, d3d12ma_ar, root, '@OUTPUT@'],
    depend_files: files(
      'vendor/d3d12ma/D3D12MemAlloc.cpp', 'vendor/d3d12ma/d3d12ma_c.cpp',
      'vendor/d3d12ma/d3d12ma_c.h', 'vendor/d3d12ma/include/D3D12MemAlloc.h'),
    build_by_default: true,
  )
else
  message('d3d12ma skipped: x86_64-w64-mingw32-g++ not found; install mingw-w64 or set D3D12MA_CXX')
endif

# --- c3c ----------------------------------------------------------------
c3c_name = get_option('c3c')
if c3c_name == ''
  c3c_name = run_command(python, '-c', 'import os;print(os.environ.get("C3C") or "c3c")', check: true).stdout().strip()
endif
c3c = find_program(c3c_name, required: false)

# --- Vulkan.c3 -----------------------------------------------------------
# Fetched from subprojects/vulkan_c3.wrap; bump `revision` there to update.
vulkan_c3 = subproject('vulkan_c3')
vulkan_c3_dir = meson.project_source_root() / 'subprojects' / 'vulkan_c3'

# --- sdl3 ---------------------------------------------------------------
# Linux builds SDL3 from the pinned wrap (subprojects/sdl3.wrap) so no system
# dev package is needed; -Dsdl3_wrap=disabled falls back to the system library.
sdl3_flags = []
sdl3_deps = []
if host_machine.system() == 'linux' and get_option('sdl3_wrap').allowed()
  cmake = import('cmake')
  sdl3_opts = cmake.subproject_options()
  sdl3_opts.add_cmake_defines({
    'CMAKE_BUILD_TYPE': 'Release',
    'SDL_SHARED': true, 'SDL_STATIC': false,
    'SDL_TESTS': false, 'SDL_EXAMPLES': false, 'SDL_TEST_LIBRARY': false,
    'SDL_INSTALL': false,
  })
  sdl3_sub = cmake.subproject('sdl3', options: sdl3_opts)
  sdl3_lib = sdl3_sub.target('SDL3-shared')
  sdl3_link_dir = meson.project_build_root() / 'lib'
  sdl3_deps += custom_target(
    'sdl3-link',
    input: sdl3_lib, output: 'sdl3-link.stamp',
    command: [python, files('tools/link_sdl3.py'), '@INPUT0@', sdl3_link_dir, '@OUTPUT@'],
    build_by_default: false,
  )
  sdl3_flags = ['-z', '-L' + sdl3_link_dir, '-z', '-Wl,-rpath,' + meson.project_build_root() / 'subprojects' / 'sdl3']
else
  sdl3_flags = run_command(
    python, files('tools/sdl3_link_flags.py'), meson.project_build_root() / 'lib',
    check: true,
  ).stdout().strip().split('\n')
  if sdl3_flags == ['']
    sdl3_flags = []
  endif
endif

if c3c.found()
  # The macOS host exercises Metal and does not need Vulkan support libraries.
  host_test_deps = host_machine.system() == 'darwin' ? imgui_test_deps : test_deps
  test(
    'c3-host', c3c,
    args: ['test'] + sdl3_flags,
    workdir: root,
    depends: host_test_deps + sdl3_deps,
    is_parallel: false,
    timeout: 600,
  )

  check_runner = files('tools/c3_check.py')
  legs = ['linux-x64', 'windows-x64', 'macos-aarch64', 'wasm32', 'headless', 'tests-macos']
  foreach leg : legs
    run_target('check-' + leg, command: [python, check_runner, c3c, leg])
  endforeach
  foreach group : ['vulkan', 'dx12', 'metal']
    run_target('check-' + group, command: [python, check_runner, c3c, group],
               depends: group == 'dx12' ? d3d12ma_target : [])
  endforeach
  run_target('check', command: [python, check_runner, c3c])

  # --- shaders and examples, grouped per backend ---------------------------
  slangc_name = get_option('slangc')
  if slangc_name == ''
    slangc_name = run_command(python, '-c', 'import os;print(os.environ.get("SLANGC") or "slangc")', check: true).stdout().strip()
  endif
  slangc = find_program(slangc_name, required: false)
  build_shaders = files('tools/build_shaders.py')
  c3_example = files('tools/c3_example.py')

  spirv_cross_name = get_option('spirv_cross')
  if spirv_cross_name == ''
    spirv_cross_name = run_command(python, '-c', 'import os;print(os.environ.get("SPIRV_CROSS") or "spirv-cross")', check: true).stdout().strip()
  endif
  spirv_cross = find_program(spirv_cross_name, required: false)

  native_examples = ['00_clear', '01_shader', '02_mesh', '03_imgui', '04_svt']
  web_examples = ['00_clear', '01_shader', '02_mesh', '05_texture']
  has_shaders = ['01_shader', '02_mesh', '03_imgui', '04_svt', '05_texture']
  c3_sources = files(
    'src/rhi/accel_structure.c3', 'src/rhi/alloc/index_pool.c3',
    'src/rhi/alloc/offset_alloc.c3', 'src/rhi/alloc/segment_alloc.c3',
    'src/rhi/backend_stubs.c3', 'src/rhi/buffer.c3', 'src/rhi/cmd.c3',
    'src/rhi/cmd_ring.c3', 'src/rhi/descriptor.c3', 'src/rhi/device.c3',
    'src/rhi/dx12_barrier.c3', 'src/rhi/dx12_mip_generation.c3',
    'src/rhi/fence.c3', 'src/rhi/format.c3', 'src/rhi/gpu_preset.c3',
    'src/rhi/gpu_ref.c3', 'src/rhi/image.c3', 'src/rhi/image_view.c3',
    'src/rhi/imgui.c3', 'src/rhi/physical_adapter.c3', 'src/rhi/pipeline.c3',
    'src/rhi/pogo_buffer.c3', 'src/rhi/pool.c3', 'src/rhi/query.c3',
    'src/rhi/queue.c3', 'src/rhi/renderer.c3', 'src/rhi/rhi.c3',
    'src/rhi/rpi_program.c3', 'src/rhi/sampler.c3', 'src/rhi/scratch_alloc.c3',
    'src/rhi/semaphore.c3', 'src/rhi/shader.c3', 'src/rhi/swapchain.c3',
    'src/rhi/time_keeper.c3', 'src/rhi/timeline.c3', 'src/rhi/vk_helpers.c3',
    'src/rhi/vk_pending.c3', 'src/rhi/webgl.c3', 'src/rhi/webgpu.c3',
    'src/vendor/d3d12/d3d12.c3',
    'src/vendor/d3d12/dxgi.c3', 'src/vendor/d3d12/layout.c3',
    'src/vendor/d3d12/procedures.c3', 'src/vendor/d3d12ma/d3d12ma.c3',
    'src/vendor/imgui/imgui.c3', 'src/vendor/metal/foundation.c3',
    'src/vendor/metal/metal.c3', 'src/vendor/metal/quartzcore.c3',
    'src/vendor/metal/types.c3', 'src/vendor/metal/wrapper.c3',
    'src/vendor/sdl3/sdl3.c3', 'src/vendor/vma/vma.c3',
  )
  # backend -> [c3c target, shader formats, library targets, examples]
  backends = {
    'vulkan': ['linux-x64', ['spirv'], vulkan_deps, native_examples],
    'dx12': ['windows-x64', ['spirv'], d3d12ma_target, native_examples],
    'metal': ['macos-aarch64', ['metal'], imgui_test_deps, ['00_clear', '01_shader', '02_mesh', '03_imgui']],
    'web': ['wasm32', ['wgsl', 'glsl'], [], web_examples],
  }
  all_examples = []
  all_shader_targets = []
  macos_examples = []
  linux_examples = []
  foreach backend, cfg : backends
    outputs = []
    shader_targets = []
    foreach ex : cfg[3]
      ex_shaders = []
      if ex in has_shaders
        foreach shader_backend : cfg[1]
          if not slangc.found()
            message('shaders-' + backend + '-' + ex + ' skipped: slangc not found (set $SLANGC or -Dslangc=)')
          elif shader_backend == 'glsl' and not spirv_cross.found()
            message('shaders-' + backend + '-glsl-' + ex + ' skipped: spirv-cross not found (set $SPIRV_CROSS or -Dspirv_cross=)')
          else
            ex_shaders += custom_target(
              'shaders-' + backend + '-' + shader_backend + '-' + ex,
              output: 'shaders-' + backend + '-' + shader_backend + '-' + ex + '.stamp',
              command: [python, build_shaders, slangc, shader_backend,
                        files('examples' / ex / 'shaders.txt'),
                        root / 'build' / 'examples' / ex / 'shaders',
                        '@OUTPUT@'] + (shader_backend == 'glsl' ? [spirv_cross] : []),
              build_by_default: false,
            )
          endif
        endforeach
      endif
      if backend == 'web' and ex in has_shaders and not spirv_cross.found()
        message('example-web-' + ex + ' skipped: embeds GLSL, spirv-cross not found')
        continue
      endif
      outdir = backend == 'web' ? 'web' / ex : 'examples' / backend / ex
      ex_output = custom_target(
        'example-' + backend + '-' + ex,
        output: 'example-' + backend + '-' + ex + '.stamp',
        command: [python, c3_example, c3c, ex, cfg[0],
                  meson.project_build_root() / outdir,
                  '@OUTPUT@'] + (backend == 'vulkan' ? sdl3_flags : []),
        depends: cfg[2] + ex_shaders + (backend == 'vulkan' ? sdl3_deps : []),
        depend_files: c3_sources + files('examples' / ex / 'main.c3', 'examples/platform/platform.c3'),
        env: {'VULKAN_C3_DIR': vulkan_c3_dir},
        build_by_default: false,
      )
      # one target per example: <backend>-<example>, e.g. vulkan-01_shader
      alias_target(backend + '-' + ex, ex_output, ex_shaders)
      outputs += ex_output
      shader_targets += ex_shaders
    endforeach
    alias_target(backend, outputs, shader_targets)
    all_examples += [outputs, shader_targets]
    all_shader_targets += shader_targets
    if backend == 'vulkan' or backend == 'web'
      linux_examples += outputs
      linux_examples += shader_targets
    endif
    if backend == 'metal'
      macos_examples += outputs
      macos_examples += shader_targets
    endif
  endforeach
  # On macOS, the aggregate means examples runnable on the host. Other hosts
  # retain the all-backend aggregate, including Vulkan's VMA dependency.
  if host_machine.system() == 'darwin'
    alias_target('examples', macos_examples)
  elif host_machine.system() == 'linux'
    alias_target('examples', linux_examples)
  else
    alias_target('examples', all_examples + all_shader_targets)
  endif
else
  message('c3c not found: meson test and check targets disabled (set $C3C or -Dc3c=)')
endif
