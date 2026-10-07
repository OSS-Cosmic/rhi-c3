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
  'vma', 'vendor/vma/vma_impl.cpp',
  include_directories: include_directories('vendor/vma/include'),
  override_options: ['cpp_std=c++17', 'optimization=2', 'b_staticpic=true'],
)
stage_vma = custom_target(
  'stage-vma',
  input: vma, output: 'vma.stamp',
  command: [python, stage, '@INPUT@', root / 'vendor/vma/lib', '@OUTPUT@'],
  build_by_default: true,
)
stage_deps = [stage_vma]
test_deps = [vma, stage_vma]

# --- volk (Vulkan loader; needs the vendor/volk submodule) ---------------
if fs.is_file('vendor/volk/volk.c')
  volk = static_library(
    'volk', 'vendor/volk/volk.c',
    include_directories: include_directories('vendor/volk'),
    c_args: ['-DVK_NO_PROTOTYPES'],
    override_options: ['optimization=2', 'b_staticpic=true'],
  )
  stage_volk = custom_target(
    'stage-volk',
    input: volk, output: 'volk.stamp',
    command: [python, stage, '@INPUT@', root / 'vendor/volk/lib', '@OUTPUT@'],
    build_by_default: true,
  )
  stage_deps += [stage_volk]
  test_deps += [volk, stage_volk]
else
  message('volk skipped: vendor/volk is missing; run: git submodule update --init vendor/volk')
endif

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
      'cpp_eh=none', 'cpp_rtti=false',
    ],
  )
  stage_imgui = custom_target(
    'stage-imgui',
    input: imgui, output: 'imgui.stamp',
    command: [python, stage, '@INPUT@', root / 'vendor/imgui_c/lib', '@OUTPUT@'],
    build_by_default: true,
  )
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

sdl3_flags = run_command(
  python, files('tools/sdl3_link_flags.py'), meson.project_build_root() / 'lib',
  check: true,
).stdout().strip().split('\n')
if sdl3_flags == ['']
  sdl3_flags = []
endif

if c3c.found()
  test(
    'c3-host', c3c,
    args: ['test', '-z', '-lSDL3'] + sdl3_flags,
    workdir: root,
    depends: test_deps,
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
  # backend -> [c3c target, slangc targets, library targets the build needs, examples]
  backends = {
    'vulkan': ['linux-x64', ['spirv'], test_deps, native_examples],
    'dx12': ['windows-x64', [], d3d12ma_target, native_examples],
    'metal': ['macos-aarch64', ['metal'], [], native_examples],
    'web': ['wasm32', ['wgsl', 'glsl'], [], web_examples],
  }
  all_examples = []
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
            # web examples keep shaders next to the wasm bundle
            shader_dir = backend == 'web' ? 'web' / ex : 'examples' / ex / 'shaders'
            ex_shaders += custom_target(
              'shaders-' + backend + '-' + shader_backend + '-' + ex,
              output: 'shaders-' + backend + '-' + shader_backend + '-' + ex + '.stamp',
              command: [python, build_shaders, slangc, shader_backend,
                        files('examples' / ex / 'shaders.txt'),
                        meson.project_build_root() / shader_dir,
                        '@OUTPUT@'] + (shader_backend == 'glsl' ? [spirv_cross] : []),
              build_by_default: false,
            )
          endif
        endforeach
      endif
      outdir = backend == 'web' ? 'web' / ex : 'examples' / backend / ex
      ex_output = custom_target(
        'example-' + backend + '-' + ex,
        output: 'example-' + backend + '-' + ex + '.stamp',
        command: [python, c3_example, c3c, ex, cfg[0],
                  meson.project_build_root() / outdir,
                  '@OUTPUT@'] + (backend == 'vulkan' ? sdl3_flags : []),
        depends: cfg[2],
        build_by_default: false,
      )
      # one target per example: <backend>-<example>, e.g. vulkan-01_shader
      alias_target(backend + '-' + ex, ex_output, ex_shaders)
      outputs += ex_output
      shader_targets += ex_shaders
    endforeach
    alias_target(backend, outputs, shader_targets)
    all_examples += [outputs, shader_targets]
  endforeach
  # every example on every backend
  alias_target('examples', all_examples)
else
  message('c3c not found: meson test and check targets disabled (set $C3C or -Dc3c=)')
endif
