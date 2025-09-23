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
LOGS_DIR="$SCRIPT_DIR/logs/kv-imac"

# === SOURCE CORE MODULES ===
source "$SCRIPT_DIR/core/logging.sh"
source "$SCRIPT_DIR/core/setup.sh"
source "$SCRIPT_DIR/core/rsync.sh"
source "$SCRIPT_DIR/core/container.sh"
source "$SCRIPT_DIR/core/cleanup.sh"
source "$SCRIPT_DIR/core/verify_remote.sh"
source "$SCRIPT_DIR/core/verify_config.sh"

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

# === Runs Pre backup Integrations ===

# === Running Pre-Backup checks ===
log_info "Starting setup and verification..."

# Verify configuration
verify_config "$ENV_FILE"
log_info "Configuration has been verified"

# Test remote connectivity
test_ssh "$REMOTE_USER" "$REMOTE_HOST"
log_info "Remote SSH connectivity verified for $REMOTE_USER@$REMOTE_HOST"

ensure_remote_dir "$REMOTE_USER" "$REMOTE_HOST" "$REMOTE_STORAGE_LOCATION"
log_info "Remote directory has been verified"

log_info "Setup completed successfully"

# === Running Backups ===
log_info "Starting backup tasks..."

# Run backup tasks (inline instead of separate script)
# === NEXTCLOUD BACKUP ===
log_info "Enabling Nextcloud maintenance mode..."
if docker exec nextcloud-app php occ maintenance:mode --on; then
    log_info "Maintenance mode enabled"
else
    log_error "Failed to enable maintenance mode, stopping backup for safety"
    exit 1
fi

# Create temp directory for database dump
mkdir -p "$GRANDPARENT_DIR/temp/nextcloud_db/"

log_info "Dumping Nextcloud database..."
if ! docker exec nextcloud-db mariadb-dump -u "$NEXTCLOUD_DB_USER" -p"$NEXTCLOUD_DB_PASSWORD" "$NEXTCLOUD_DB_NAME" > "$GRANDPARENT_DIR/temp/nextcloud_db/nextcloud.sql"; then
    log_error "Failed to dump Nextcloud database"
    exit 1
fi

sync_dir "/home/kabir/nextcloud/nextcloud/data/" "$REMOTE_STORAGE_LOCATION/nextcloud" "Nextcloud data"
sync_dir "/home/kabir/nextcloud/nextcloud/html/config/" "$REMOTE_STORAGE_LOCATION/nextcloud" "Nextcloud config"
sync_dir "/home/kabir/nextcloud/nextcloud/html/themes/" "$REMOTE_STORAGE_LOCATION/nextcloud" "Nextcloud themes"
sync_dir "$GRANDPARENT_DIR/temp/nextcloud_db/" "$REMOTE_STORAGE_LOCATION/nextcloud" "Nextcloud DB dump"

log_info "Disabling Nextcloud maintenance mode..."
if docker exec nextcloud-app php occ maintenance:mode --off; then
    log_info "Maintenance mode disabled"
else
    log_warning "Failed to disable maintenance mode"
fi

log_info "Backup tasks completed successfully"

# === Runs Post backup Integrations ===
cleanup
log_info "Cleanup completed successfully"
log_info "All tasks completed successfully"
exit 0
