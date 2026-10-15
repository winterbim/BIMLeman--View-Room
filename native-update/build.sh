#!/usr/bin/env bash
set -euo pipefail
export PATH="/c/Program Files/Git/cmd:$PATH"
export MINGW_PREFIX="$(cygpath -m "$MINGW_PREFIX")"
mkdir -p native-output/evidence
pacman -Q > native-output/evidence/packages.txt
cmake --version
c++ --version
python -m unittest discover -s native-update -p test_native.py -v
python native-update/prepare_native.py --source upstream-veyon --logo assets/brand/BIMLeman-View-Room-logo.png --report native-output/evidence/branding.json
# Only the user-mode Interception library is linked; no driver is installed.
gcc -shared -O2 -DINTERCEPTION_EXPORT interception/library/interception.c -o "$MINGW_PREFIX/bin/interception.dll" -Wl,--out-implib,"$MINGW_PREFIX/lib/libinterception.dll.a"
cp interception/library/interception.h "$MINGW_PREFIX/include/"
cmake -S upstream-veyon -B native-build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/native-update/toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$MINGW_PREFIX" \
  -DCMAKE_INSTALL_PREFIX="$PWD/native-install" -DWITH_PCH=OFF -DWITH_UNITY_BUILD=ON \
  -DQT_TRANSLATIONS_DIR="$MINGW_PREFIX/share/qt6/translations" \
  2>&1 | tee native-output/evidence/configure.log
cmake --build native-build --target veyon-master --parallel 2 2>&1 | tee native-output/evidence/build-master.log
cmake --build native-build --parallel 2 2>&1 | tee native-output/evidence/build-all.log
python native-update/package_native.py
