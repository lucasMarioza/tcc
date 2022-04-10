source scripts/log.sh

function setup_gcc() {
  COMPILE_FLAGS="-g -O3 -no-pie -fno-PIE";
  LINK_FLAGS="-Wl,-q,-znow -no-pie -fno-PIE -static-libstdc++ -static-libgcc";

  SOURCE_DIR="${PROJECT_ROOT}/sources/gcc";
  BUILD_DIR="${PROJECT_ROOT}/builds/gcc";
  INSTALL_DIR="${PROJECT_ROOT}/installs/gcc";

  log "Starting gcc set up"
  # Check if we need to setup gcc.
  if [ -f "${INSTALL_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0/cc1plus-orig" ]; then
    log "Gcc already set up. Skipping"
    return
  fi

  # If the source is not available, download it.
  if [ ! -d "${SOURCE_DIR}" ]; then
    log "Downloading gcc"
    mkdir -p "${SOURCE_DIR}" || fatal "unable to create source directory for gcc";
    cd "${SOURCE_DIR}" || fatal "unable to get to the gcc source directory";
    git clone --single-branch -b releases/gcc-11.2.0 git://gcc.gnu.org/git/gcc.git . || fatal "unable to download gcc";
    ./contrib/download_prerequisites || fatal "unable to download gcc's prerequisities";
    log "Gcc download finished"
  else
    log "Skipping gcc download"
  fi

  # If the project is not built, compile it.
  if [ ! -d "${BUILD_DIR}" ]; then
    log "Building gcc"
    mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for gcc";
    cd "${BUILD_DIR}" || fatal "unable to get to the gcc build directory";
    ${SOURCE_DIR}/configure --enable-bootstrap \
        --enable-linker-build-id --enable-languages=c,c++ \
        --with-gnu-as --with-gnu-ld --disable-multilib \
        --with-boot-ldflags="${LINK_FLAGS}" \
        --with-stage1-ldflags="${LINK_FLAGS}" \
        --prefix="${INSTALL_DIR}" || falal "unable to configure gcc";
    make BOOT_CFLAGS="${COMPILE_FLAGS}" bootstrap -j4 || falal "unable to compile gcc";
    log "Gcc build finished"
  else
    log "Skipping gcc build"
  fi

  # If the binaries are not ready, install them.
  if [ ! -d "${INSTALL_DIR}" ]; then
    log "Installing gcc binaries"
    cd "${BUILD_DIR}";
    make install -j4 || fatal "unable to install gcc";
    cp ${INSTALL_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0/cc1plus{,-orig} || fatal "unable to backup gcc's cc1plus";
    # rm -rf *
    log "Gcc binaries installed"
  else
    log "Skipping gcc binaries instalation"
  fi

  log "Gcc set up done"
}
