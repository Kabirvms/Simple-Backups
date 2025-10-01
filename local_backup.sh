#!/bin/bash

set -euo pipefail

# === DIRECTORY AND PATH SETUP ===
CURRENT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$CURRENT_PATH")"

# === ENVIRONMENT VARIABLES ===
# Load environment variables from .env file
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a 
    source "$ENV_FILE"
    set +a
else
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

# Set up shared variables
GRANDPARENT_DIR="$SCRIPT_DIR"

# Set logs directory dynamically for this backup job
LOGS_DIR="$SCRIPT_DIR/logs/local_backup"

# === SOURCE CORE MODULES ===
source "$SCRIPT_DIR/core/logging.sh"
source "$SCRIPT_DIR/core/setup.sh"
source "$SCRIPT_DIR/core/rsync.sh"
source "$SCRIPT_DIR/core/container.sh"
source "$SCRIPT_DIR/core/verify_remote.sh"
source "$SCRIPT_DIR/core/verify_config.sh"

# === SOURCE OUTLINE SCRIPTS ===
source "$SCRIPT_DIR/outline/pre_backup.sh"
source "$SCRIPT_DIR/outline/backup_items.sh"
source "$SCRIPT_DIR/outline/post_backup.sh"

# === LOGGING SETUP ===
# Create logs directory if it doesn't exist
if [[ ! -d "$LOGS_DIR" ]]; then
    mkdir -p "$LOGS_DIR"
    log_info "Created logs directory: $LOGS_DIR"
fi

# Generate timestamped log filename
LOG_FILE="$LOGS_DIR/$(date +'%Y%m%d_%H%M%S').log"

# Redirect all output to log file and console
exec > >(tee -a "$LOG_FILE") 2>&1
log_info "Logging to file: $LOG_FILE"

# === MAIN BACKUP WORKFLOW ===
main() {
    log_info "Starting Local Backup Process"
    
    # Pre-backup setup and verification
    if ! run_pre_backup; then
        log_error "Pre-backup setup failed"
        exit 1
    fi
    
    # Run backup tasks
    if ! run_backup_items; then
        log_warning "Backup tasks failed"
        exit 0
    fi
    
    # Post-backup operations
    if ! run_post_backup; then
        log_error "Post-backup operations failed"
        exit 1
    fi
    
    log_info "=== Local Backup Process Completed Successfully ==="
    exit 0
}

# Run main function
main
