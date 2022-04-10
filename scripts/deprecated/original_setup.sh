#!/bin/bash

function fatal() {
  echo "error: $@" 1>&2;
  exit 1;
}

function setup_clang() {
  COMPILE_FLAGS="-g -O3 -no-pie -fno-PIE";
  LINK_FLAGS="-Wl,-q -no-pie -fno-PIE";

  SOURCE_DIR="${PROJECT_ROOT}/sources/clang";
  BUILD_DIR="${PROJECT_ROOT}/builds/clang";
  INSTALL_DIR="${PROJECT_ROOT}/installs/clang";

  # Check if we need to setup clang.
  [ -f "${INSTALL_DIR}/bin/clang-13-orig" ] && return;

  # If the source is not available, download it.
  if [ ! -d "${SOURCE_DIR}" ]; then
    mkdir -p "${SOURCE_DIR}" || fatal "unable to create source directory for clang";
    cd "${SOURCE_DIR}" || fatal "unable to get to the clang source directory";
    git clone --single-branch -b llvmorg-13.0.0 https://github.com/llvm/llvm-project.git . || fatal "unable to download clang";
  fi

  # If the project is not built, compile it.
  if [ ! -d "${BUILD_DIR}" ]; then
    mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for clang";
    cd "${BUILD_DIR}" || fatal "unable to get to the clang build directory";
    cmake -DLLVM_ENABLE_PROJECTS=clang -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" -DCMAKE_C_FLAGS="${COMPILE_FLAGS}" -DCMAKE_CXX_FLAGS="${COMPILE_FLAGS}" -DCMAKE_CXX_LINK_FLAGS="${LINK_FLAGS}" -G "Unix Makefiles" "${SOURCE_DIR}/llvm" || falal "unable to configure clang";
    make -j4 || fatal "unable to build clang";
  fi

  # If the binaries are not ready, install them.
  if [ ! -d "${INSTALL_DIR}" ]; then
    cd "${BUILD_DIR}";
    make install -j4 || fatal "unable to install clang";
    cp ${INSTALL_DIR}/bin/clang-13{,-orig} || fatal "unable to backup clang";
    # rm -rf *
  fi
}

function setup_gcc() {
  COMPILE_FLAGS="-g -O3 -no-pie -fno-PIE";
  LINK_FLAGS="-Wl,-q,-znow -no-pie -fno-PIE -static-libstdc++ -static-libgcc";

  SOURCE_DIR="${PROJECT_ROOT}/sources/gcc";
  BUILD_DIR="${PROJECT_ROOT}/builds/gcc";
  INSTALL_DIR="${PROJECT_ROOT}/installs/gcc";

  # Check if we need to setup gcc.
  [ -f "${INSTALL_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0/cc1plus-orig" ] && return;

  # If the source is not available, download it.
  if [ ! -d "${SOURCE_DIR}" ]; then
    mkdir -p "${SOURCE_DIR}" || fatal "unable to create source directory for gcc";
    cd "${SOURCE_DIR}" || fatal "unable to get to the gcc source directory";
    git clone --single-branch -b releases/gcc-11.2.0 git://gcc.gnu.org/git/gcc.git . || fatal "unable to download gcc";
    ./contrib/download_prerequisites || fatal "unable to download gcc's prerequisities";
  fi

  # If the project is not built, compile it.
  if [ ! -d "${BUILD_DIR}" ]; then
    mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for gcc";
    cd "${BUILD_DIR}" || fatal "unable to get to the gcc build directory";
    ${SOURCE_DIR}/configure --enable-bootstrap \
        --enable-linker-build-id --enable-languages=c,c++ \
        --with-gnu-as --with-gnu-ld --disable-multilib \
        --with-boot-ldflags="${LINK_FLAGS}" \
        --with-stage1-ldflags="${LINK_FLAGS}" \
        --prefix="${INSTALL_DIR}" || falal "unable to configure gcc";
    make BOOT_CFLAGS="${COMPILE_FLAGS}" bootstrap -j4 || falal "unable to compile gcc";
  fi

  # If the binaries are not ready, install them.
  if [ ! -d "${INSTALL_DIR}" ]; then
    cd "${BUILD_DIR}";
    make install -j4 || fatal "unable to install gcc";
    cp ${INSTALL_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0/cc1plus{,-orig} || fatal "unable to backup gcc's cc1plus";
    # rm -rf *
  fi
}

function setup_bolt() {
  SOURCE_DIR="${PROJECT_ROOT}/sources/bolt";
  BUILD_DIR="${PROJECT_ROOT}/builds/bolt";
  INSTALL_DIR="${PROJECT_ROOT}/installs/bolt";

  # Check if we need to setup bolt.
  [ -f "${INSTALL_DIR}/bin/llvm-bolt" ] && return;

  # If the source is not available, download it.
  if [ ! -d "${SOURCE_DIR}" ]; then
    mkdir -p "${SOURCE_DIR}" || fatal "unable to create source directory for bolt";
    cd "${SOURCE_DIR}" || fatal "unable to get to the bolt source directory";
    git clone --single-branch https://github.com/facebookincubator/BOLT . || fatal "unable to download bolt";
    sed -i 's/TYPE[[:space:]]*BIN/DESTINATION bin/' bolt/tools/driver/CMakeLists.txt || fatal "unable to patch bolt";
  fi

  # If the project is not built, compile it.
  if [ ! -d "${BUILD_DIR}" ]; then
    mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for bolt";
    cd "${BUILD_DIR}" || fatal "unable to get to the bolt build directory";
    cmake -DLLVM_TARGETS_TO_BUILD="X86" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_ENABLE_PROJECTS="bolt" -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" -G "Unix Makefiles" "${SOURCE_DIR}/llvm";
    make -j4 || fatal "unable to build bolt";
  fi

  # If the binaries are not ready, install them.
  if [ ! -d "${INSTALL_DIR}" ]; then
    cd "${BUILD_DIR}";
    make install -j4 || fatal "unable to install bolt";
    # rm -rf *
  fi
}

function setup_cfggrind() {
  BUILD_DIR="${PROJECT_ROOT}/builds/cfggrind";
  INSTALL_DIR="${PROJECT_ROOT}/installs/cfggrind";

  # Check if we need to setup cfggrind.
  [ -f "${INSTALL_DIR}/bin/valgrind" ] && return;

  # If the source is not available, download and compile it.
  if [ ! -d "${BUILD_DIR}" ]; then
    cd "${PROJECT_ROOT}/builds" || fatal "unable to get to the build directory";
    wget -qO - https://sourceware.org/pub/valgrind/valgrind-3.18.1.tar.bz2 | tar jxv || fatal "unable to uncompress valgrind";
    mv valgrind-3.18.1 cfggrind || fatal "unable to rename cfggrind directory";
    cd cfggrind || fatal "unable to get to the cfggrind directory";
    git clone https://github.com/rimsa/CFGgrind.git cfggrind || fatal "unable to download cfggrid";
    patch -p1 < cfggrind/cfggrind.patch || fatal "unable to patch valgrind with cfggrind"
    wget 'https://raw.githubusercontent.com/lucasMarioza/CFGgrind/master/cfggrind2bolt' || fatal "unable to copy cfggrind2bolt";
    chmod +x cfggrind2bolt || fatal "unable to make cfggrind2bolt executable";

   ./autogen.sh || fatal "unable to generate configuration files for cfggrind";
   ./configure --prefix="${INSTALL_DIR}" || fatal "unable to configure cfggrind";
   make -j4 || fatal "unable to compile cfggrind"
  fi

  # If the binaries are not ready, install them.
  if [ ! -d "${INSTALL_DIR}" ]; then
    cd "${BUILD_DIR}";
    make install -j4 || fatal "unable to install cfggrind";
    cp cfggrind/cfggrind2bolt "${INSTALL_DIR}/bin/" || fatal "unable to install cfggrind2bolt";
    # rm -rf *
  fi
}

function instrument_compiler() {
  compiler="$1";
  mode="$2";

  SOURCE_DIR="${PROJECT_ROOT}/sources/clang";
  BUILD_DIR="${PROJECT_ROOT}/builds/llvm";
  REPORT_DIR="${PROJECT_ROOT}/report/${compiler}/instrument";

  # Check if we need to instrument llvm.
  if [ ! -f "${REPORT_DIR}/${mode}.time" ]; then
    if [ "${mode}" == "cfggrind" ]; then
      WRAPPER=$(mktemp /tmp/wrapper-XXXXXX.c);
      cat > "${WRAPPER}" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>

#define OFFSET 9

#if !defined(VALGRIND) || !defined(CFG_FILE) || !defined(PROGRAM)
#error "a property is missing"
#endif

int main(int argc, char* argv[], char* envp[]) {
    int i, j;
    int my_argc;
    char** my_argv;

    my_argc = argc + OFFSET;
    my_argv = (char**) malloc(my_argc * sizeof(char*));
    assert(my_argv != 0);

    my_argv[0] = argv[0];
    my_argv[1] = strdup("-q");
    my_argv[2] = strdup("--tool=cfggrind");
    my_argv[3] = strdup("--demangle=no");
    my_argv[4] = strdup("--ignore-failed-cfg=yes");
    my_argv[5] = strdup("--cfg-infile=" CFG_FILE);
    my_argv[6] = strdup("--cfg-outfile=" CFG_FILE);
    my_argv[7] = strdup("--");
    my_argv[8] = strdup(PROGRAM);

    for (i = 1, j = OFFSET; i < argc; i++, j++)
        my_argv[j] = argv[i];

    my_argv[j] = 0;

    return execve(VALGRIND, my_argv, envp);
}
EOF
    fi

    case "${compiler}" in
      clang)
        CLANG_DIR="${PROJECT_ROOT}/installs/clang";
        [ -d "${CLANG_DIR}" ] || fatal "invalid clang directory";
        [ -f "${CLANG_DIR}/bin/clang-13-orig" ] || fatal "invalid clang installation";

        (
          cd ${CLANG_DIR}/bin;
          rm -rf clang-13;

          case "${mode}" in
            standard|perf)
              ln -s clang-13{-orig,}
              ;;
            cfggrind)
              ln -s clang-13{-orig,}
              gcc -g -O3 -no-pie -fno-PIE -fno-stack-protector \
                  -DVALGRIND=\"${PROJECT_ROOT}/installs/cfggrind/bin/valgrind\" \
                  -DCFG_FILE=\"${REPORT_DIR}/${mode}.data\" \
                  -DPROGRAM=\"${PROJECT_ROOT}/installs/clang/bin/clang++\" \
                  -o clang++-wrapper "${WRAPPER}" || fatal "unable to compile wrapper";
              rm -rf "${WRAPPER}";
              ;;
            *)
              fatal "invalid mode: ${mode}";
              ;;
          esac
        ) || exit 1;

        export CC="${CLANG_DIR}/bin/clang";
        export CXX="${CLANG_DIR}/bin/clang++";
        [ "${mode}" == "cfggrind" ] \
          && export CXX="${CLANG_DIR}/bin/clang++-wrapper" \
          || export CXX="${CLANG_DIR}/bin/clang++";
        LINK_FLAGS="";

        ;;
      gcc)
        GCC_DIR="${PROJECT_ROOT}/installs/gcc";
        [ -d "${GCC_DIR}" ] || fatal "invalid gcc directory";
        [ -f "${GCC_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0/cc1plus-orig" ] || fatal "invalid gcc installation";

        (
          cd ${GCC_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0;
          rm -rf cc1plus;
          case "${mode}" in
            standard|perf)
              ln -s cc1plus{-orig,}
              ;;
            cfggrind)
              gcc -g -O3 -no-pie -fno-PIE -fno-stack-protector \
                  -DVALGRIND=\"${PROJECT_ROOT}/installs/cfggrind/bin/valgrind\" \
                  -DCFG_FILE=\"${REPORT_DIR}/${mode}.data\" \
                  -DPROGRAM=\"${PROJECT_ROOT}/installs/gcc/libexec/gcc/x86_64-pc-linux-gnu/11.2.0/cc1plus-orig\" \
                  -o cc1plus-wrapper ${WRAPPER} || fatal "unable to compile wrapper";
              ln -s cc1plus{-wrapper,}
              rm -rf "${WRAPPER}";
              ;;
            *)
              fatal "invalid mode: ${mode}";
              ;;
          esac
        ) || exit 1

        export CC="${GCC_DIR}/bin/gcc";
        export CXX="${GCC_DIR}/bin/g++";
        LINK_FLAGS="-Wl,-rpath,${GCC_DIR}/lib64 -L${GCC_DIR}/lib64";
        ;;
      *)
        fatal "invalid compiler: ${compiler}";
        ;;
    esac

    mkdir -p "${REPORT_DIR}" || fatal "unable to create report directory";

    rm -rf "${BUILD_DIR}" || fatal "unable to remove llvm build dir";
    mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for llvm";
    cd "${BUILD_DIR}" || fatal "unable to get to the llvm build directory";

    cmake -DLLVM_TARGETS_TO_BUILD="X86" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_CXX_LINK_FLAGS="${LINK_FLAGS}" -G "Unix Makefiles" "${SOURCE_DIR}/llvm" || fatal "unable to configure llvm"

    case "${mode}" in
      standard)
        /usr/bin/time -f '%e' -o "${REPORT_DIR}/${mode}.time" make || fatal "unable to compile llvm";
        ;;
      perf)
        /usr/bin/time -f '%e' -o "${REPORT_DIR}/${mode}.time" perf record -q -e cycles:u -j any,u -o "${REPORT_DIR}/${mode}.data" -- make || fatal "unable to compile llvm";
        ;;
      cfggrind)
        /usr/bin/time -f '%e' -o "${REPORT_DIR}/${mode}.time" make || fatal "unable to compile llvm";
        ;;
      *)
        fatal "invalid mode: ${mode}";
        ;;
    esac

    unset CC;
    unset CXX;
  fi

  # After this point, we are only interested in data collected from perf or cfggrind.
  [ "${mode}" == "standard" ] && return;

  if [ ! -f "${REPORT_DIR}/${mode}.fdata" ]; then
    case "${compiler}" in
      clang)
        CLANG_DIR="${PROJECT_ROOT}/installs/clang/bin";
        BINARY_FILE="${CLANG_DIR}/clang-13-orig";
        ;;
      gcc)
        GCC_DIR="${PROJECT_ROOT}/installs/gcc/libexec/gcc/x86_64-pc-linux-gnu/11.2.0";
        BINARY_FILE="${GCC_DIR}/cc1plus-orig";
        ;;
      *)
        fatal "invalid compiler: ${compiler}";
        ;;
    esac

    [ -f "${BINARY_FILE}" ] || fatal "invalid binary file: ${BINARY_FILE}";
    [ -f "${REPORT_DIR}/${mode}.data" ] || fatal "invalid data file: ${REPORT_DIR}/${mode}.data";

    case "${mode}" in
      perf)
        [ "${compiler}" == "clang" ] && EXTRA_ARGS="-skip-funcs='.*parseOptionalAttributes.*' -strict=0" || EXTRA_ARGS="";
        ${PROJECT_ROOT}/installs/bolt/bin/perf2bolt -p "${REPORT_DIR}/${mode}.data" \
            -o "${REPORT_DIR}/${mode}.fdata" "${BINARY_FILE}" ${EXTRA_ARGS} || fatal "unable to convert perf to bolt format";
        ;;
      cfggrind)
        ${PROJECT_ROOT}/installs/cfggrind/bin/cfggrind2bolt -b "${BINARY_FILE}" \
            "${REPORT_DIR}/${mode}.data" > "${REPORT_DIR}/${mode}.fdata" || fatal "unable to convert cfggrind to bolt format";
        ;;
      *)
        fatal "invalid mode: ${mode}";
        ;;
    esac
  fi

  case "${compiler}" in
    clang)
      CLANG_DIR="${PROJECT_ROOT}/installs/clang/bin";
      BINARY_FILE="${CLANG_DIR}/clang-13-orig";
      BINARY_OPT_FILE="${CLANG_DIR}/clang-13-opt-${mode}";
      ;;
    gcc)
      GCC_DIR="${PROJECT_ROOT}/installs/gcc/libexec/gcc/x86_64-pc-linux-gnu/11.2.0";
      BINARY_FILE="${GCC_DIR}/cc1plus-orig";
      BINARY_OPT_FILE="${GCC_DIR}/cc1plus-opt-${mode}";
      ;;
    *)
      fatal "invalid compiler: ${compiler}";
      ;;
  esac

  if [ ! -f "${BINARY_OPT_FILE}" ]; then
    [ "${compiler}" == "gcc" ] && EXTRA_ARGS="-skip-funcs=.*gimplify.*" || EXTRA_ARGS="";

    ${PROJECT_ROOT}/installs/bolt/bin/llvm-bolt "${BINARY_FILE}" -o "${BINARY_OPT_FILE}" \
        -data="${REPORT_DIR}/${mode}.fdata" -reorder-blocks=cache+ -reorder-functions=hfsort \
        -split-functions=2 -split-all-cold -split-eh -dyno-stats ${EXTRA_ARGS} || fatal "unable to generate optimized binary";
  fi
}

function measure_llvm() {
  compiler="$1";
  mode="$2";

  SOURCE_DIR="${PROJECT_ROOT}/sources/clang";
  BUILD_DIR="${PROJECT_ROOT}/builds/llvm";
  REPORT_DIR="${PROJECT_ROOT}/report/${compiler}/runs";

  case "${compiler}" in
    clang)
      CLANG_DIR="${PROJECT_ROOT}/installs/clang";
      [ -d "${CLANG_DIR}" ] || fatal "invalid clang directory";
      [ -f "${CLANG_DIR}/bin/clang-13-orig" ] || fatal "invalid clang installation";

      (
        cd ${CLANG_DIR}/bin && \
        rm -rf clang-13 && \
        if [ "${mode}" == "standard" ]; then
          ln -s clang-13{-orig,}
        else
          ln -s clang-13{-opt-${mode},}
        fi
      ) || exit 1;

      export CC="${CLANG_DIR}/bin/clang";
      export CXX="${CLANG_DIR}/bin/clang++";
      LINK_FLAGS="";

      ;;
    gcc)
      GCC_DIR="${PROJECT_ROOT}/installs/gcc";
      [ -d "${GCC_DIR}" ] || fatal "invalid gcc directory";
      [ -f "${GCC_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0/cc1plus-orig" ] || fatal "invalid gcc installation";

      (
        cd ${GCC_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0 && \
        rm -rf cc1plus && \
        if [ "${mode}" == "standard" ]; then
          ln -s cc1plus{-orig,}
        else
          ln -s cc1plus{-opt-${mode},}
        fi
      ) || exit 1;

      export CC="${GCC_DIR}/bin/gcc";
      export CXX="${GCC_DIR}/bin/g++";
      LINK_FLAGS="-Wl,-rpath,${GCC_DIR}/lib64 -L${GCC_DIR}/lib64";

      ;;
    *)
      fatal "invalid compiler: ${compiler}";
  esac

  mkdir -p "${REPORT_DIR}" || fatal "unable to create report directory";

  rm -rf "${BUILD_DIR}" || fatal "unable to remove llvm build dir";
  mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for llvm";
  cd "${BUILD_DIR}" || fatal "unable to get to the llvm build directory";

  cmake -DLLVM_TARGETS_TO_BUILD="X86" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_CXX_LINK_FLAGS="${LINK_FLAGS}" -G "Unix Makefiles" "${SOURCE_DIR}/llvm" || fatal "unable to configure llvm"

  log=$(mktemp /tmp/time-XXXXXX.txt);
  /usr/bin/time -f '%e' -o "${log}" make -j4 || fatal "unable to compile llvm";
  cat "${log}" >> "${REPORT_DIR}/${mode}.time";

  unset CC;
  unset CXX;
}

# Setup some global flags.
export PROJECT_ROOT="$(cd $(dirname $0); pwd)"

# Create project structure.
mkdir -p ${PROJECT_ROOT}/{sources,builds,installs,report}

# Download, configure, build and install clang.
setup_clang;

# Download, configure, build and install gcc.
setup_gcc;

# Download, configure, build and install bolt.
setup_bolt;

# Download, configure, build and install CFGgrind.
setup_cfggrind;

# Instrument clang and gcc.
instrument_compiler "clang" "standard"
instrument_compiler "gcc" "standard"
instrument_compiler "clang" "perf"
instrument_compiler "gcc" "perf"
instrument_compiler "clang" "cfggrind"
instrument_compiler "gcc" "cfggrind"

# Perform measurements.
while true; do
  measure_llvm "clang" "standard"
  measure_llvm "gcc" "standard"
  measure_llvm "clang" "perf"
  measure_llvm "gcc" "perf"
  measure_llvm "clang" "cfggrind"
  measure_llvm "gcc" "cfggrind"
done
