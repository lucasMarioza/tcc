source scripts/log.sh

function _prepare_cfggrind_wrapper() {
  $wrapper="$1"
  cat > "${wrapper}" << 'EOF'
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
}

function _prepare_binaries() {
  log "Preparing binaries"
  case "${compiler}" in
    clang)
      COMPILER_DIR="${PROJECT_ROOT}/installs/clang";
      COMPILER_BIN_DIR="${COMPILER_DIR}/bin"
      COMPILER_INSTRUMENTED_FILE="clang-13"
      # COMPILER_EXE_FILE="clang++"
      ;;
    gcc)
      COMPILER_DIR="${PROJECT_ROOT}/installs/gcc";
      COMPILER_BIN_DIR="${COMPILER_DIR}/libexec/gcc/x86_64-pc-linux-gnu/11.2.0"
      COMPILER_INSTRUMENTED_FILE="cc1plus"
      # COMPILER_EXE_FILE="cc1plus"
      ;;
    *)
      fatal "invalid compiler: ${compiler}";
      ;;
  esac

  [ -d "${COMPILER_DIR}" ] || fatal "invalid $compiler directory";
  [ -f "${COMPILER_BIN_DIR}/${COMPILER_INSTRUMENTED_FILE}-orig" ] || fatal "invalid $compiler installation";
  
  (
    log "cleaning previous build"
    cd ${COMPILER_BIN_DIR};
    rm -rf ${COMPILER_INSTRUMENTED_FILE};
    case "${mode}" in
      standard|perf)
        log "Using original bins for ${mode} mode"
        ln -s ${COMPILER_INSTRUMENTED_FILE}{-orig,}
        ;;
      cfggrind)
        log "Instrumenting with cfggrind"
        gcc -g -O3 -no-pie -fno-PIE -fno-stack-protector \
            -DVALGRIND=\"${PROJECT_ROOT}/installs/cfggrind/bin/valgrind\" \
            -DCFG_FILE=\"${REPORT_DIR}/${mode}.data\" \
            #-DPROGRAM=\"${COMPILER_BIN_DIR}/${COMPILER_EXE_FILE}-orig\" \
            -DPROGRAM=\"${COMPILER_BIN_DIR}/${COMPILER_INSTRUMENTED_FILE}-orig\" \
            -o ${COMPILER_INSTRUMENTED_FILE}-wrapper ${WRAPPER} || fatal "unable to compile wrapper";
        ln -s ${COMPILER_INSTRUMENTED_FILE}{-wrapper,}
        rm -rf "${WRAPPER}";
        ;;
      *)
        fatal "invalid mode: ${mode}";
        ;;
    esac
  ) || fatal "unable to finish instrumentation for ${compiler} on ${mode}"

  log "Binary files prepared"
}

function _run_profiling() {
  case "${compiler}" in
    clang)
      CLANG_DIR="${PROJECT_ROOT}/installs/clang/bin";
      export CC="${CLANG_DIR}/bin/clang";
      export CXX="${CLANG_DIR}/bin/clang++";
      #[ "${mode}" == "cfggrind" ] \
      #  && export CXX="${CLANG_DIR}/bin/clang++-wrapper" \
      #  || export CXX="${CLANG_DIR}/bin/clang++";
      LINK_FLAGS="";

      ;;
    gcc)
      GCC_DIR="${PROJECT_ROOT}/installs/gcc/libexec/gcc/x86_64-pc-linux-gnu/11.2.0";
      export CC="${GCC_DIR}/bin/gcc";
      export CXX="${GCC_DIR}/bin/g++";
      LINK_FLAGS="-Wl,-rpath,${GCC_DIR}/lib64 -L${GCC_DIR}/lib64";
      ;;
    *)
      fatal "invalid compiler: ${compiler}";
      ;;
  esac
  
  log "Configuring LLVM"
  cmake -DLLVM_TARGETS_TO_BUILD="X86" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_CXX_LINK_FLAGS="${LINK_FLAGS}" -G "Unix Makefiles" "${SOURCE_DIR}/llvm" || fatal "unable to configure llvm"

  log "Running instrumented version"
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

  log "Profiling finished"
}

function _generate_fdata() {
  case "${compiler}" in
      clang)
        CLANG_DIR="${PROJECT_ROOT}/installs/clang/bin";
        BINARY_FILE="${CLANG_DIR}/clang-13-orig";
        EXTRA_ARGS="-skip-funcs='.*parseOptionalAttributes.*' -strict=0"
        ;;
      gcc)
        GCC_DIR="${PROJECT_ROOT}/installs/gcc/libexec/gcc/x86_64-pc-linux-gnu/11.2.0";
        BINARY_FILE="${GCC_DIR}/cc1plus-orig";
        EXTRA_ARGS=""
        ;;
      *)
        fatal "invalid compiler: ${compiler}";
        ;;
    esac

    [ -f "${BINARY_FILE}" ] || fatal "invalid binary file: ${BINARY_FILE}";
    [ -f "${REPORT_DIR}/${mode}.data" ] || fatal "invalid data file: ${REPORT_DIR}/${mode}.data";

    case "${mode}" in
      perf)
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
}

function _optimize() {
  case "${compiler}" in
    clang)
      CLANG_DIR="${PROJECT_ROOT}/installs/clang/bin";
      BINARY_FILE="${CLANG_DIR}/clang-13-orig";
      BINARY_OPT_FILE="${CLANG_DIR}/clang-13-opt-${mode}";
      EXTRA_ARGS=""
      ;;
    gcc)
      GCC_DIR="${PROJECT_ROOT}/installs/gcc/libexec/gcc/x86_64-pc-linux-gnu/11.2.0";
      BINARY_FILE="${GCC_DIR}/cc1plus-orig";
      BINARY_OPT_FILE="${GCC_DIR}/cc1plus-opt-${mode}";
      EXTRA_ARGS="-skip-funcs=.*gimplify.*"
      ;;
    *)
      fatal "invalid compiler: ${compiler}";
      ;;
  esac

  if [ ! -f "${BINARY_OPT_FILE}" ]; then
    log "Generating optimized version"
    ${PROJECT_ROOT}/installs/bolt/bin/llvm-bolt "${BINARY_FILE}" -o "${BINARY_OPT_FILE}" \
        -data="${REPORT_DIR}/${mode}.fdata" -reorder-blocks=cache+ -reorder-functions=hfsort \
        -split-functions=2 -split-all-cold -split-eh -dyno-stats ${EXTRA_ARGS} || fatal "unable to generate optimized binary";
    log "optimized version generated"
  else
    log "Optimized binary already exists. Skipping"
  fi
}

function instrument_compiler() {
  compiler="$1";
  mode="$2";

  SOURCE_DIR="${PROJECT_ROOT}/sources/clang";
  BUILD_DIR="${PROJECT_ROOT}/builds/llvm";
  REPORT_DIR="${PROJECT_ROOT}/report/${compiler}/instrument";

  log "Starting ${compiler} instrumentation on ${mode} mode"
  # Check if we need to instrument llvm.
  if [ ! -f "${REPORT_DIR}/${mode}.time" ]; then
    if [ "${mode}" == "cfggrind" ]; then
      log "Preparing wrapper"
      WRAPPER=$(mktemp /tmp/wrapper-XXXXXX.c);
      _prepare_cfggrind_wrapper $WRAPPER
      log "Wrapper preparation finished"
    fi

    _prepare_binaries

    log "Preparing for profiling"
    mkdir -p "${REPORT_DIR}" || fatal "unable to create report directory";

    rm -rf "${BUILD_DIR}" || fatal "unable to remove llvm build dir";
    mkdir -p "${BUILD_DIR}" || fatal "unable to create build directory for llvm";
    cd "${BUILD_DIR}" || fatal "unable to get to the llvm build directory";

    _run_profiling

    unset CC;
    unset CXX;
  else
    log "Skipping instrumentation"
  fi

  # After this point, we are only interested in data collected from perf or cfggrind.
  [ "${mode}" == "standard" ] && return;

  if [ ! -f "${REPORT_DIR}/${mode}.fdata" ]; then
    log "Generating fdata"
    _generate_fdata
    log "fdata generated"
  else
    log "Skipping fdata generation"
  fi

  _optimize
  log "Done"
}