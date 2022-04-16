source scripts/log.sh

function setup_cfggrind() {
  BUILD_DIR="${PROJECT_ROOT}/builds/cfggrind";
  INSTALL_DIR="${PROJECT_ROOT}/installs/cfggrind";

  log "Starting cfggrind set up"
  # Check if we need to setup cfggrind.
  if [ -f "${INSTALL_DIR}/bin/valgrind" ]; then
    log "Cfggrind already set up. Skipping"
    return
  fi

  # If the source is not available, download and compile it.
  if [ ! -d "${BUILD_DIR}" ]; then
    log "Downloading valgrind"
    cd "${PROJECT_ROOT}/builds" || fatal "unable to get to the build directory";
    wget -qO - https://sourceware.org/pub/valgrind/valgrind-3.18.1.tar.bz2 | tar jxv || fatal "unable to uncompress valgrind";
    mv valgrind-3.18.1 cfggrind || fatal "unable to rename cfggrind directory";
    cd cfggrind || fatal "unable to get to the cfggrind directory";
    log "Valgrind download finished"

    log "Downloading cfggrind"
    git clone https://github.com/rimsa/CFGgrind.git cfggrind || fatal "unable to download cfggrid";
    patch -p1 < cfggrind/cfggrind.patch || fatal "unable to patch valgrind with cfggrind"
    wget 'https://raw.githubusercontent.com/lucasMarioza/CFGgrind/master/cfggrind2bolt' || fatal "unable to copy cfggrind2bolt";
    chmod +x cfggrind2bolt || fatal "unable to make cfggrind2bolt executable";
    log "Cfggrind download finished"

    log "Compiling cfggrind"
    ./autogen.sh || fatal "unable to generate configuration files for cfggrind";
    ./configure --prefix="${INSTALL_DIR}" || fatal "unable to configure cfggrind";
    make -j4 || fatal "unable to compile cfggrind"
    log "Cfggrind compilation finished"
  else
    log "Skipping cfggrind download and compilation"
  fi

  # If the binaries are not ready, install them.
  if [ ! -d "${INSTALL_DIR}" ]; then
    log "Installing cfggrind binaries"
    cd "${BUILD_DIR}";
    make install -j4 || fatal "unable to install cfggrind";
    cp cfggrind2bolt "${INSTALL_DIR}/bin/" || fatal "unable to install cfggrind2bolt";
    # rm -rf *
    log "Cfggrind binaries installed"
  else
    log "Skipping cfggrind binaries instalation"
  fi

  log "Cfggrind set up done"
}
