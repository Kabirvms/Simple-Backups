#!/bin/bash
# This script provides reusable logging functions for other bash scripts.
# Source this file in your scripts to use log_info, log_error, and log_warning.

set -euo pipefail
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit immediately.
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status.

# === LOGGING FUNCTIONS ===
# log_info: Print an informational message with a timestamp.
# Usage: log_info "Your message here"
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
}

# log_error: Print an error message with a timestamp to stderr (standard error).
# Usage: log_error "Your error message here"
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# log_warning: Print a warning message with a timestamp.
# Usage: log_warning "Your warning message here"
log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1"
}
