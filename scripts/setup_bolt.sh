source scripts/log.sh

function setup_bolt() {
  SOURCE_DIR="${PROJECT_ROOT}/sources/bolt";
  BUILD_DIR="${PROJECT_ROOT}/builds/bolt";
  INSTALL_DIR="${PROJECT_ROOT}/installs/bolt";

  log "Starting bolt set up"
  # Check if we need to setup bolt.
  if [ -f "${INSTALL_DIR}/bin/llvm-bolt" ]; then
    log "Bolt already set up. Skipping"
    return
  fi

  # If the source is not available, download it.
  if [ ! -d "${SOURCE_DIR}" ]; then
    log "Downloading bolt"
    mkdir -p "${SOURCE_DIR}" || fatal "unable to create source directory for bolt";
    cd "${SOURCE_DIR}" || fatal "unable to get to the bolt source directory";
    git clone --single-branch https://github.com/facebookincubator/BOLT . || fatal "unable to download bolt";
    sed -i 's/TYPE[[:space:]]*BIN/DESTINATION bin/' bolt/tools/driver/CMakeLists.txt || fatal "unable to patch bolt";
    log "Bolt download finished"
  else
    log "Skipping bolt download"
  fi

  # If the project is not built, compile it.
  if [ ! -d "${BUILD_DIR}" ]; then
    log "Building bolt"
    mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for bolt";
    cd "${BUILD_DIR}" || fatal "unable to get to the bolt build directory";
    cmake -DLLVM_TARGETS_TO_BUILD="X86" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_ENABLE_PROJECTS="bolt" -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" -G "Unix Makefiles" "${SOURCE_DIR}/llvm";
    make -j4 || fatal "unable to build bolt";
    log "Bolt build finished"
  else
    log "Skipping bolt build"
  fi

  # If the binaries are not ready, install them.
  if [ ! -d "${INSTALL_DIR}" ]; then
    log "Installing bolt binaries"
    cd "${BUILD_DIR}";
    make install -j4 || fatal "unable to install bolt";
    # rm -rf *
    log "Bolt binaries installed"
  else
    log "Skipping bolt binaries instalation"
  fi

  log "Bolt set up done"
}