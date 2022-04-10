source scripts/log.sh

function setup_clang() {
  COMPILE_FLAGS="-g -O3 -no-pie -fno-PIE";
  LINK_FLAGS="-Wl,-q -no-pie -fno-PIE";

  SOURCE_DIR="${PROJECT_ROOT}/sources/clang";
  BUILD_DIR="${PROJECT_ROOT}/builds/clang";
  INSTALL_DIR="${PROJECT_ROOT}/installs/clang";

  log "Starting clang set up"
  # Check if we need to setup clang.
  if [ -f "${INSTALL_DIR}/bin/clang-13-orig" ]; then
    log "Clang already set up. Skipping"
    return
  fi

  # If the source is not available, download it.
  if [ ! -d "${SOURCE_DIR}" ]; then
    log "Downloading clang"
    mkdir -p "${SOURCE_DIR}" || fatal "unable to create source directory for clang";
    cd "${SOURCE_DIR}" || fatal "unable to get to the clang source directory";
    git clone --single-branch -b llvmorg-13.0.0 https://github.com/llvm/llvm-project.git . || fatal "unable to download clang";
    log "Clang download finished"
  else
    log "Skipping clang download"
  fi

  # If the project is not built, compile it.
  if [ ! -d "${BUILD_DIR}" ]; then
    log "Building clang"
    mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for clang";
    cd "${BUILD_DIR}" || fatal "unable to get to the clang build directory";
    cmake -DLLVM_ENABLE_PROJECTS=clang -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" -DCMAKE_C_FLAGS="${COMPILE_FLAGS}" -DCMAKE_CXX_FLAGS="${COMPILE_FLAGS}" -DCMAKE_CXX_LINK_FLAGS="${LINK_FLAGS}" -G "Unix Makefiles" "${SOURCE_DIR}/llvm" || falal "unable to configure clang";
    make -j4 || fatal "unable to build clang";
    log "Clang build finished"
  else
    log "Skipping clang build"
  fi

  # If the binaries are not ready, install them.
  if [ ! -d "${INSTALL_DIR}" ]; then
    log "Installing clang binaries"
    cd "${BUILD_DIR}";
    make install -j4 || fatal "unable to install clang";
    cp ${INSTALL_DIR}/bin/clang-13{,-orig} || fatal "unable to backup clang";
    cp ${INSTALL_DIR}/bin/clang++{,-orig} || fatal "unable to backup clang++";
    # rm -rf *
    log "Clang binaries installed"
  else
    log "Skipping clang binaries instalation"
  fi

  log "Clang set up done"
}