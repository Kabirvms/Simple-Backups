#!/bin/bash
set -euo pipefail

# === DATABASE DUMP FUNCTIONS ===
create_db_dumps() {
    log_info "=== Creating Database Dumps ==="
    
    # Create dump directory
    mkdir -p "$DUMP_DIR"
    
    # Nextcloud database dump
    log_info "Dumping Nextcloud database..."
    if ! docker exec nextcloud-db mariadb-dump -u "$NEXTCLOUD_DB_USER" -p"$NEXTCLOUD_DB_PASSWORD" "$NEXTCLOUD_DB_NAME" > "$DUMP_DIR/nextcloud.sql"; then
        log_error "Failed to dump Nextcloud database"
        return 1
    fi
    log_info "Nextcloud database dump completed"
    
    # Immich database dump
    log_info "Dumping Immich database..."
    if docker exec immich_postgres pg_dump -U postgres immich > "$DUMP_DIR/immich.sql" 2>/dev/null; then
        log_info "Immich database dump completed"
    else
        log_warning "Failed to dump Immich database (container may not be running)"
    fi
    
}
# === MAIN BACKUP EXECUTION ===
run_backup_items() {
    # === MAIN BACKUP PROCESS ===
    log_info "Starting backup process"
    
    # Create database dumps first
    if ! create_db_dumps; then
        log_error "Database dump creation failed"
        return 2
    fi

    # Nextcloud backup
    log_info "Enabling Nextcloud maintenance mode..."
    if docker exec nextcloud-app php occ maintenance:mode --on; then
        log_info "Maintenance mode enabled"
    else
        log_warning "Failed to enable maintenance mode, Stopping Containers Instead..."
        if ! manage_containers "stop" nextcloud-app nextcloud-db; then
            log_warning "Failed to stop Nextcloud containers"
            exit 2
        fi
    fi

    sync_dir "/home/kabir/nextcloud/nextcloud/data/" "$REMOTE_STORAGE_LOCATION/nextcloud" "Nextcloud data"
    sync_dir "/home/kabir/nextcloud/nextcloud/html/config/" "$REMOTE_STORAGE_LOCATION/nextcloud" "Nextcloud config"
    sync_dir "/home/kabir/nextcloud/nextcloud/html/themes/" "$REMOTE_STORAGE_LOCATION/nextcloud" "Nextcloud themes"
    sync_dir "$DUMP_DIR/" "$REMOTE_STORAGE_LOCATION/nextcloud" "Nextcloud DB dump"

    log_info "Disabling Nextcloud maintenance mode..."
    if docker exec nextcloud-app php occ maintenance:mode --off; then
        log_info "Maintenance mode disabled"
    else
        log_warning "Failed to disable maintenance mode"
        if ! manage_containers "start" nextcloud-app nextcloud-db; then
            log_warning "Failed to start Nextcloud containers"
        fi
    fi

    # Affine Backup
    log_info "Stopping Affine container..."
    if manage_containers "stop" affine_postgres affine_redis affine_server; then
        log_info "Affine container stopped successfully backup can proceed"
        sync_dir "/home/kabir/affine/" "$REMOTE_STORAGE_LOCATION/affine" "Affine"
        log_info "Starting Affine container..."
        manage_containers "start" affine_postgres affine_redis affine_server
    else
        log_warning "Failed to stop Affine container"
        exit 2
    fi

    # Bytestash Backup
    log_info "Stopping Bytestash container..."
    if manage_containers "stop" bytestash; then
        sync_dir "/home/kabir/bytestash/data/" "$REMOTE_STORAGE_LOCATION/bytestash" "Bytestash"
        log_info "Starting Bytestash container..."
        manage_containers "start" bytestash
    else
        log_warning "Failed to stop Bytestash container"
        exit 2
    fi

    # Crafty Controller Backup
    log_info "Live backup of Crafty Controller data..."
    sync_dir "/home/kabir/crafty/docker/backups/" "$REMOTE_STORAGE_LOCATION/crafty" "Crafty"
    log_info "Crafty Controller backup completed"


    # ESPHome Backup
    log_info "Stopping ESPHome container..."
    if manage_containers "stop" esphome; then
        sync_dir "/home/kabir/esphome/" "$REMOTE_STORAGE_LOCATION/esphome" "ESPHome"
        log_info "Starting ESPHome container..."
        manage_containers "start" esphome
    else
        log_warning "Failed to stop ESPHome container"
        exit 2
    fi

    # Homer Dashboard Backup
    log_info "Stopping Homer Dashboard container..."
    if manage_containers "stop" homer; then
        sync_dir "/home/kabir/homer/" "$REMOTE_STORAGE_LOCATION/homer" "Homer Dashboard"
        log_info "Starting Homer Dashboard container..."
        manage_containers "start" homer
    else
        log_warning "Failed to stop Homer Dashboard container"
        exit 2
    fi

    # Immich backup
    log_info "Stopping Immich containers..."
    if manage_containers "stop" immich_machine_learning immich_postgres immich_redis immich_server; then
        sync_dir "/home/kabir/immich/library/" "$REMOTE_STORAGE_LOCATION/immich" "Immich"
        log_info "Starting Immich containers..."
        manage_containers "start" immich_machine_learning immich_postgres immich_redis immich_server
    else
        log_warning "Failed to stop Immich containers"
        exit 2
    fi

    # Karakeep Backup
    log_info "Stopping Karakeep containers..."
    if manage_containers "stop" karakeep-chrome karakeep-meilisearch karakeep-web; then
        sync_dir "/var/lib/docker/volumes/karakeep_data/_data" "$REMOTE_STORAGE_LOCATION/karakeep_data" "Karakeep Data"
        sync_dir "/var/lib/docker/volumes/karakeep_meilisearch/_data" "$REMOTE_STORAGE_LOCATION/karakeep_meilisearch" "Karakeep Meilisearch "
        log_info "Starting Karakeep containers..."
        manage_containers "start" karakeep-chrome karakeep-meilisearch karakeep-web
    else
        log_warning "Failed to stop Karakeep containers"
        exit 2
    fi
    
    # Paperless Backup
    log_info "Stopping Paperless containers..."
    if manage_containers "stop" paperless-broker paperless-db paperless-webserver paperless-gotenberg paperless-tika; then
        sync_dir "/home/kabir/paperless/" "$REMOTE_STORAGE_LOCATION/paperless" "Paperless"
        log_info "Starting Paperless containers..."
        manage_containers "start" paperless-broker paperless-db paperless-webserver paperless-gotenberg paperless-tika
    else
        log_warning "Failed to stop Paperless containers"
        exit 2
    fi  

    #Uptime Kuma Backup
    log_info "Stopping Uptime Kuma container..."
    if manage_containers "stop" uptime-kuma; then
        sync_dir "/home/kabir/uptime-kuma/data/" "$REMOTE_STORAGE_LOCATION/uptime-kuma" "Uptime Kuma"
        log_info "Starting Uptime Kuma container..."
        manage_containers "start" uptime-kuma
    else
        log_warning "Failed to stop Uptime Kuma container"
        exit 2
    fi  

    return 0
}