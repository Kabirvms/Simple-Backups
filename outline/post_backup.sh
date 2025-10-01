#!/bin/bash
set -euo pipefail

# === POST-BACKUP OPERATIONS ===
run_post_backup() {
    log_info "=== Starting Post-Backup Operations ==="
    
    # Run cleanup
    cleanup
    
    # Run post-backup integrations
    run_post_backup_integrations
    
    log_info "Post-backup operations completed successfully"
}

# === POST-BACKUP INTEGRATIONS ===
run_post_backup_integrations() {
    log_info "Running post-backup integrations..."
    
    # Add integration calls here as needed
    # Example:
    # source "$SCRIPT_DIR/integrations/uptime_kuma.sh"
    # send_backup_status_to_uptime_kuma
    
    log_info "Post-backup integrations completed"
}

# === CLEANUP FUNCTION ===
cleanup() {
    log_info "Starting cleanup..."

    # Remove temporary files
    if [[ -d "$GRANDPARENT_DIR/temp/" ]]; then
        rm -rf "$GRANDPARENT_DIR/temp/"* 2>/dev/null || true
        log_info "Removed temporary directory: $GRANDPARENT_DIR/temp/"
    fi

    # Remove database dumps
    if [[ -d "$DUMP_DIR" ]]; then
        rm -rf "$DUMP_DIR"/*.sql 2>/dev/null || true
        log_info "Cleaned up database dumps in: $DUMP_DIR"
    fi

    # Disable Nextcloud maintenance mode if enabled
    if docker exec nextcloud-app php occ maintenance:mode 2>/dev/null | grep -q "Maintenance mode is currently enabled"; then
        if docker exec nextcloud-app php occ maintenance:mode --off 2>/dev/null; then
            log_info "Disabled Nextcloud maintenance mode"
        else
            log_warning "Failed to disable Nextcloud maintenance mode"
        fi
    fi

    # Start stopped containers - only if they exist and are stopped
    local containers=(
        immich_machine_learning immich_postgres immich_redis immich_server
        paperless-broker paperless-db paperless-webserver paperless-gotenberg paperless-tika
        karakeep-chrome karakeep-meilisearch karakeep-web
        esphome
    )
    
    for container in "${containers[@]}"; do
        if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
            if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
                if docker start "$container" 2>/dev/null; then
                    log_info "Started container: $container"
                else
                    log_warning "Failed to start container: $container"
                fi
            fi
        fi
    done

    log_info "Cleanup completed successfully"
}
