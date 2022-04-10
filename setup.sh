#!/bin/bash

# Setup some global flags.
export PROJECT_ROOT="$(cd $(dirname $0)/project; pwd)"
export SCRIPTS_ROOT="$(cd $(dirname $0)/scripts; pwd)"
export LOG_FILE="${SCRIPTS_ROOT}/log.txt"
export NUM_MEASUREMENTS=10

# import function definitions
source ${SCRIPTS_ROOT}/log.sh
source ${SCRIPTS_ROOT}/setup_clang.sh
source ${SCRIPTS_ROOT}/setup_gcc.sh
source ${SCRIPTS_ROOT}/setup_bolt.sh
source ${SCRIPTS_ROOT}/setup_cfggrind.sh
source ${SCRIPTS_ROOT}/instrument_compiler.sh
source ${SCRIPTS_ROOT}/measure_llvm.sh

# Create project structure.
mkdir -p ${PROJECT_ROOT}/{sources,builds,installs,report}
[ -f $LOG_FILE ] && mv $LOG_FILE $(dirname ${LOG_FILE})/old_$(basename ${LOG_FILE})

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
for run in (1..${NUM_MEASUREMENTS}); do
  log "---MEASUREMENT ${run}---"
  measure_llvm "clang" "standard"
  measure_llvm "gcc" "standard"
  measure_llvm "clang" "perf"
  measure_llvm "gcc" "perf"
  measure_llvm "clang" "cfggrind"
  measure_llvm "gcc" "cfggrind"
done
