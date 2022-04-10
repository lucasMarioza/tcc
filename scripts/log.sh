function log() {
  echo "log: $@" | tee -a $LOG_FILE 1>&2;
}

function fatal() {
  echo "error: $@" | tee -a $LOG_FILE 1>&2;
  exit 1;
}
