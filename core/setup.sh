#!/bin/bash
#This script provides setup functions for the backup process

# Exit on any error, undefined variables, or pipe failures
set -euo pipefail

# Note: Environment variables and core modules are loaded by the main script

# === LOG FILE SETUP ===

# Function to set up logging - called by main script
setup_logging() {
    # Create logs directory if it doesn't exist
    if [[ ! -d "$LOGS_DIR" ]]; then
        log_info "Logs directory $LOGS_DIR does not exist, creating it"
        mkdir -p "$LOGS_DIR"
    fi

    # Generate timestamped log filename (format: YYYYMMDD_HHMMSS.log)
    LOG_FILE="$LOGS_DIR/$(date +'%Y%m%d_%H%M%S').log"

    # Redirect all output (stdout and stderr) to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1

    log_info "Logging to file: $LOG_FILE"
}

# Function to run setup tasks - called by main script
run_setup() {
    # === Verifies the Config ===
    bash "$(dirname "$0")/verify_config.sh"
    log_info "Configuration has been verified"

    # === Tests Remote Connection ===
    test_ssh "$REMOTE_USER" "$REMOTE_HOST"
    log_info "Remote SSH connectivity verified for $REMOTE_USER@$REMOTE_HOST"
    ensure_remote_dir "$REMOTE_USER" "$REMOTE_HOST" "$REMOTE_STORAGE_LOCATION"
    log_info "Remote directory has been verified"
    # === Final Setup Steps ===
    log_info "Setup script completed successfully"
}
