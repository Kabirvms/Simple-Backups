#!/bin/bash
set -euo pipefail

# === CLEANUP FUNCTION ===
cleanup() {
    log_info "Starting cleanup..."

    # Remove temporary files
    if [[ -d "$GRANDPARENT_DIR/tmp/" ]]; then
        rm -rf "$GRANDPARENT_DIR/tmp/"* 2>/dev/null || true
        log_info "Removed temporary directory: $GRANDPARENT_DIR/tmp/"
    fi

    # Disable Nextcloud maintenance mode if enabled
    if docker exec nextcloud-app php occ maintenance:mode --is 2>/dev/null | grep -q "enabled"; then
        if docker exec nextcloud-app php occ maintenance:mode --off 2>/dev/null; then
            log_info "Disabled Nextcloud maintenance mode"
        else
            log_warning "Failed to disable Nextcloud maintenance mode"
        fi
    fi

    # Start stopped containers
    local containers=(
        immich_machine_learning immich_postgres immich_redis immich_server
        karakeep-chrome karakeep-meilisearch karakeep-web
        esphome
    )
    for container in "${containers[@]}"; do
        if docker start "$container" 2>/dev/null; then
            log_info "Started container: $container"
        fi
    done

    log_info "Cleanup completed successfully"
}
