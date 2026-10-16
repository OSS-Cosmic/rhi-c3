load("@rules_foreign_cc//foreign_cc:defs.bzl", "cmake")

filegroup(
    name = "all_srcs",
    srcs = glob(["**"]),
)

cmake(
    name = "sdl3",
    cache_entries = {
        "CMAKE_BUILD_TYPE": "Release",
        "SDL_SHARED": "ON",
        "SDL_STATIC": "OFF",
        "SDL_TESTS": "OFF",
        "SDL_EXAMPLES": "OFF",
        "SDL_INSTALL": "ON",
        "CMAKE_POSITION_INDEPENDENT_CODE": "ON",
    },
    lib_source = ":all_srcs",
    out_shared_libs = ["libSDL3.so.0"],
    visibility = ["//visibility:public"],
)
