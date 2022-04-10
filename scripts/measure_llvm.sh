source scripts/log.sh

function _prepare_compiler() {
  case "${compiler}" in
    clang)
      COMPILER_DIR=CLANG_DIR
      COMPILER_BIN_DIR="${COMPILER_DIR}/bin"
      COMPILER_OPTIMIZED_FILE="clang-13"
      ;;
    gcc)
      COMPILER_DIR=GCC_DIR
      COMPILER_BIN_DIR="${COMPILER_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0"
      COMPILER_OPTIMIZED_FILE="cc1plus"
      ;;
    *)
      fatal "invalid compiler: ${compiler}";
      ;;
  esac

  [ -d "${COMPILER_DIR}" ] || fatal "invalid ${compiler} directory";
  [ -f "${COMPILER_BIN_DIR}/${COMPILER_OPTIMIZED_FILE}-orig" ] || fatal "invalid ${compiler} installation";

  (
    cd ${COMPILER_BIN_DIR} && \
    rm -rf ${COMPILER_OPTIMIZED_FILE} && \
    if [ "${mode}" == "standard" ]; then
      ln -s ${COMPILER_OPTIMIZED_FILE}{-orig,}
    else
      ln -s ${COMPILER_OPTIMIZED_FILE}{-opt-${mode},}
    fi
  ) || exit 1;
}

function measure_llvm() {
  compiler="$1";
  mode="$2";
  log "-${compiler} ${mode}-"

  SOURCE_DIR="${PROJECT_ROOT}/sources/clang";
  BUILD_DIR="${PROJECT_ROOT}/builds/llvm";
  REPORT_DIR="${PROJECT_ROOT}/report/${compiler}/runs";

  CLANG_DIR="${PROJECT_ROOT}/installs/clang";
  GCC_DIR="${PROJECT_ROOT}/installs/gcc";

  log "preparing compiler"
  _prepare_compiler

  case "${compiler}" in
    clang)
      export CC="${CLANG_DIR}/bin/clang";
      export CXX="${CLANG_DIR}/bin/clang++";
      LINK_FLAGS="";

      ;;
    gcc)
      export CC="${GCC_DIR}/bin/gcc";
      export CXX="${GCC_DIR}/bin/g++";
      LINK_FLAGS="-Wl,-rpath,${GCC_DIR}/lib64 -L${GCC_DIR}/lib64";

      ;;
    *)
      fatal "invalid compiler: ${compiler}";
  esac

  log "Preparing LLVM"
  mkdir -p "${REPORT_DIR}" || fatal "unable to create report directory";

  rm -rf "${BUILD_DIR}" || fatal "unable to remove llvm build dir";
  mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for llvm";
  cd "${BUILD_DIR}" || fatal "unable to get to the llvm build directory";

  cmake -DLLVM_TARGETS_TO_BUILD="X86" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_CXX_LINK_FLAGS="${LINK_FLAGS}" -G "Unix Makefiles" "${SOURCE_DIR}/llvm" || fatal "unable to configure llvm"

  log "Executing"
  log_file=$(mktemp /tmp/time-XXXXXX.txt);
  /usr/bin/time -f '%e' -o "${log_file}" make -j4 || fatal "unable to compile llvm";
  cat "${log_file}" >> "${REPORT_DIR}/${mode}.time";

  unset CC;
  unset CXX;
  log "done"
}