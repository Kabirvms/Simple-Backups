#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/core/logging.sh"
source "$(dirname "$0")/core/container.sh"
source "$(dirname "$0")/core/rsync.sh"

# === BACKUP TASKS ===

# === NEXTCLOUD BACKUP ===
log_info "Enabling Nextcloud maintenance mode..."
if docker exec nextcloud-app php occ maintenance:mode --on; then
    log_info "Maintenance mode enabled"
else
    log_error "Failed to enable maintenance mode, stopping backup for safety"
    exit 1
fi

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





