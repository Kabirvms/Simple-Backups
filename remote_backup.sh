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
REMOTE_USER="$REMOTE_BACKUP_USER"
REMOTE_HOST="$REMOTE_BACKUP_HOST"
REMOTE_STORAGE_LOCATION="$REMOTE_BACKUP_LOCATION"
REMOTE_BASE_DIR="${REMOTE_STORAGE_LOCATION}"

# Set up shared variables
GRANDPARENT_DIR="$SCRIPT_DIR"

# Set logs directory dynamically for this backup job
LOGS_DIR="$SCRIPT_DIR/logs/remote_backup"

# === SOURCE CORE MODULES ===
source "$SCRIPT_DIR/core/logging.sh"
source "$SCRIPT_DIR/core/setup.sh"
source "$SCRIPT_DIR/core/rsync.sh"
source "$SCRIPT_DIR/core/container.sh"
source "$SCRIPT_DIR/core/verify_remote.sh"
source "$SCRIPT_DIR/core/verify_config.sh"
source "$SCRIPT_DIR/core/safe_shutdown.sh"

# === SOURCE INTEGRATIONS SCRIPTS ===
source "$SCRIPT_DIR/integrations/homeassistant/control_device.sh"
source "$SCRIPT_DIR/integrations/homeassistant/enitity_update.sh"

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

control_device "switch.remote_site" "turn_on" 180

log_info "Establishing SSH connection to $REMOTE_USER@$REMOTE_HOST"
tailscale up 
sleep 30

if ping -c 1 -W 2 "$REMOTE_HOST" &>/dev/null; then
    log_info "Connection to $REMOTE_USER@$REMOTE_HOST successful"
else
    log_error "Unable to reach $REMOTE_USER@$REMOTE_HOST. Please check the connection."
    # Initialize HA monitoring even for failed connection
    backup_started "remote"
    backup_finished 1 "Unable to reach remote host" "remote"
    control_device "switch.remote_site" "turn_off" 30
    exit 1
fi
# === MAIN BACKUP WORKFLOW ===
main() {
    local exit_code=0
    
    log_info "Starting Remote Backup Process"
    
    # Record backup start in Home Assistant
    backup_started "remote"
    
    # Pre-backup setup and verification
    if ! run_pre_backup; then
        log_error "Pre-backup setup failed"
        backup_finished 1 "Pre-backup setup failed" "remote"
        exit 1
    fi

    # Run backup tasks
    if ! run_backup_items; then
        log_warning "Backup tasks failed"
        backup_finished 2 "Backup tasks failed" "remote"
        exit 2
    fi
    
    # Post-backup operations
    if ! run_post_backup; then
        log_error "Post-backup operations failed"
        backup_finished 1 "Post-backup operations failed" "remote"
        exit 1
    fi

    log_info "=== Remote Backup Process Completed Successfully ==="
    
    # Safely shutdown remote host using SSH
    log_info "Initiating safe shutdown of remote host..."
    if safe_shutdown "$REMOTE_HOST" "$REMOTE_USER" 5 30; then
        log_info "Remote host shutdown completed successfully"
    else
        log_warning "Remote host shutdown may have failed or is taking longer than expected"
        # Continue with cleanup even if shutdown failed
    fi
    
    # Turn off the switch after shutdown
    control_device "switch.remote_site" "turn_off" 60
    log_info "Turning off devices after backup and shutdown"

    backup_finished 0 "Success" "remote"
    exit 0
}

# Run main function
main

