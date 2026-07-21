#!/bin/bash -eu
# Web build, following karl-zylinski/odin-raylib-web: Odin compiles
# the game to one wasm object file, emcc links it against the raylib
# web library that ships inside the Odin distribution, and the HTML
# shell (src/main_web/index_template.html) drives the frame loop.

EMSCRIPTEN_SDK_DIR="$HOME/Tools/emsdk"
OUT_DIR="build/web"

mkdir -p $OUT_DIR

export EMSDK_QUIET=1
[[ -f "$EMSCRIPTEN_SDK_DIR/emsdk_env.sh" ]] && . "$EMSCRIPTEN_SDK_DIR/emsdk_env.sh"

# RAYLIB_WASM_LIB=env.o defers the raylib symbols to link time; emcc
# supplies the real library below.
odin build src/main_web -target:js_wasm32 -build-mode:obj -vet \
  -define:RAYLIB_WASM_LIB=env.o \
  -out:$OUT_DIR/game.wasm.o "$@"

ODIN_PATH=$(odin root)

cp "$ODIN_PATH/core/sys/wasm/js/odin.js" $OUT_DIR

# Current Odin nightlies emit `.obj` regardless of the -out extension.
OBJ=$OUT_DIR/game.wasm.o
[[ -f $OUT_DIR/game.wasm.obj ]] && OBJ=$OUT_DIR/game.wasm.obj

files="$OBJ $ODIN_PATH/vendor/raylib/wasm/libraylib.web.a"

# The game reads shaders/ at runtime; --preload-file bundles it into
# index.data, served alongside the wasm. The art is typed in (art.odin)
# and built at load time, so there is no asset pack left to preload.
# No ALLOW_MEMORY_GROWTH: a growable heap is a resizable ArrayBuffer,
# and Chrome rejects views of those in texImage2D. Fixed 64 MB instead.
flags="-sEXPORTED_RUNTIME_METHODS=['HEAPF32'] -sUSE_GLFW=3 -sWASM_BIGINT
       -sWARN_ON_UNDEFINED_SYMBOLS=0 -sINITIAL_MEMORY=64MB -sASSERTIONS
       --shell-file src/main_web/index_template.html
       --preload-file shaders"

emcc -o $OUT_DIR/index.html $files $flags

rm "$OBJ"

echo "Web build created in ${OUT_DIR} — serve it, don't file:// it:"
echo "  python3 -m http.server -d ${OUT_DIR}"
