(The file `/Users/kabir.vms/Git/simple-backups/integrations/ha_monitoring.sh` exists, but is empty)
#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../core/logging.sh"

# === HOME ASSISTANT MONITORING CONFIGURATION ===
HA_URL="${HA_URL:-http://homeassistant.local:8123}"
HA_TOKEN="${HA_TOKEN:-}"

# === CREATE/UPDATE SENSOR ENTITY ===
# Usage: ha_create_sensor <entity_id> <state> <friendly_name> [unit] [device_class] [attributes_json]
ha_create_sensor() {
    local entity_id="$1"
    local state="$2"
    local friendly_name="$3"
    local unit="${4:-}"
    local device_class="${5:-}"
    local attributes="${6:-{}}"
    
    # Validate parameters
    if [[ -z "$entity_id" || -z "$state" || -z "$friendly_name" ]]; then
        log_error "Missing required parameters: entity_id, state, or friendly_name"
        return 1
    fi
    
    # Validate HA_TOKEN is set
    if [[ -z "$HA_TOKEN" ]]; then
        log_error "HA_TOKEN environment variable not set"
        return 1
    fi
    
    log_info "Creating/updating sensor: $entity_id"
    
    # Build attributes JSON
    local full_attributes="{\"friendly_name\": \"$friendly_name\""
    
    if [[ -n "$unit" ]]; then
        full_attributes="$full_attributes, \"unit_of_measurement\": \"$unit\""
    fi
    
    if [[ -n "$device_class" ]]; then
        full_attributes="$full_attributes, \"device_class\": \"$device_class\""
    fi
    
    # Add custom attributes if provided
    if [[ "$attributes" != "{}" ]]; then
        # Remove the closing brace from full_attributes and opening brace from custom attributes
        full_attributes="${full_attributes%?}, ${attributes#?}"
    else
        full_attributes="$full_attributes}"
    fi
    
    # Create/update the sensor
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"state\": \"$state\",
            \"attributes\": $full_attributes
        }" \
        "$HA_URL/api/states/sensor.$entity_id")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        log_info "Successfully created/updated sensor: sensor.$entity_id"
        return 0
    else
        log_error "Failed to create/update sensor $entity_id (HTTP: $http_code)"
        return 1
    fi
}

# === CREATE BACKUP STATUS ENTITIES ===
backup_create_status_entities() {
    log_info "Creating Home Assistant backup monitoring entities"
    
    # Main backup status sensor
    ha_create_sensor "backup_status" "idle" "Backup Status" "" "enum" \
        '{"icon": "mdi:backup-restore", "possible_states": ["idle", "running", "success", "failed"]}'
    
    # Last backup time
    ha_create_sensor "backup_last_run" "$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")" "Last Backup Run" "" "timestamp" \
        '{"icon": "mdi:clock-outline"}'
    
    # Backup duration
    ha_create_sensor "backup_duration" "0" "Backup Duration" "minutes" "duration" \
        '{"icon": "mdi:timer-outline"}'
    
    # Backup size
    ha_create_sensor "backup_size" "0" "Backup Size" "GB" "" \
        '{"icon": "mdi:harddisk"}'
    
    # Current operation
    ha_create_sensor "backup_current_operation" "none" "Current Backup Operation" "" "" \
        '{"icon": "mdi:cog-outline"}'
    
    # Error count
    ha_create_sensor "backup_error_count" "0" "Backup Error Count" "" "" \
        '{"icon": "mdi:alert-circle-outline"}'
    
    # Last error message
    ha_create_sensor "backup_last_error" "none" "Last Backup Error" "" "" \
        '{"icon": "mdi:alert"}'
    
    log_info "Backup monitoring entities created successfully"
}

# === UPDATE BACKUP STATUS ===
# Usage: backup_update_status <status> [operation] [error_message]
backup_update_status() {
    local status="$1"
    local operation="${2:-none}"
    local error_message="${3:-none}"
    
    if [[ -z "$status" ]]; then
        log_error "Status parameter required"
        return 1
    fi
    
    log_info "Updating backup status to: $status"
    
    # Update main status
    ha_create_sensor "backup_status" "$status" "Backup Status" "" "enum" \
        '{"icon": "mdi:backup-restore", "possible_states": ["idle", "running", "success", "failed"]}'
    
    # Update current operation
    ha_create_sensor "backup_current_operation" "$operation" "Current Backup Operation" "" "" \
        '{"icon": "mdi:cog-outline"}'
    
    # Update last run time if not running
    if [[ "$status" != "running" ]]; then
        ha_create_sensor "backup_last_run" "$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")" "Last Backup Run" "" "timestamp" \
            '{"icon": "mdi:clock-outline"}'
    fi
    
    # Handle error status
    if [[ "$status" == "failed" && "$error_message" != "none" ]]; then
        # Increment error count
        local current_errors
        current_errors=$(curl -s -X GET \
            -H "Authorization: Bearer $HA_TOKEN" \
            "$HA_URL/api/states/sensor.backup_error_count" | \
            grep -o '"state":"[^"]*"' | cut -d'"' -f4)
        
        local new_error_count=$((current_errors + 1))
        
        ha_create_sensor "backup_error_count" "$new_error_count" "Backup Error Count" "" "" \
            '{"icon": "mdi:alert-circle-outline"}'
        
        ha_create_sensor "backup_last_error" "$error_message" "Last Backup Error" "" "" \
            '{"icon": "mdi:alert"}'
    fi
}

# === UPDATE BACKUP PROGRESS ===
# Usage: backup_update_progress <operation> [size_gb] [duration_minutes]
backup_update_progress() {
    local operation="$1"
    local size_gb="${2:-}"
    local duration_minutes="${3:-}"
    
    if [[ -z "$operation" ]]; then
        log_error "Operation parameter required"
        return 1
    fi
    
    log_info "Updating backup progress: $operation"
    
    # Update current operation
    ha_create_sensor "backup_current_operation" "$operation" "Current Backup Operation" "" "" \
        '{"icon": "mdi:cog-outline"}'
    
    # Update size if provided
    if [[ -n "$size_gb" ]]; then
        ha_create_sensor "backup_size" "$size_gb" "Backup Size" "GB" "" \
            '{"icon": "mdi:harddisk"}'
    fi
    
    # Update duration if provided
    if [[ -n "$duration_minutes" ]]; then
        ha_create_sensor "backup_duration" "$duration_minutes" "Backup Duration" "minutes" "duration" \
            '{"icon": "mdi:timer-outline"}'
    fi
}

# === CREATE BACKUP CONTROL ENTITIES ===
backup_create_control_entities() {
    log_info "Creating Home Assistant backup control entities"
    
    # Backup trigger switch (input_boolean equivalent)
    ha_create_sensor "backup_trigger" "off" "Trigger Backup" "" "" \
        '{"icon": "mdi:play-circle-outline"}'
    
    # Backup enabled switch
    ha_create_sensor "backup_enabled" "on" "Backup Enabled" "" "" \
        '{"icon": "mdi:backup-restore"}'
    
    # Maintenance mode switch
    ha_create_sensor "backup_maintenance_mode" "off" "Backup Maintenance Mode" "" "" \
        '{"icon": "mdi:wrench"}'
    
    log_info "Backup control entities created successfully"
}

# === CREATE INDIVIDUAL SERVICE ENTITIES ===
# Usage: backup_create_service_entities <service_name>
backup_create_service_entities() {
    local service_name="$1"
    
    if [[ -z "$service_name" ]]; then
        log_error "Service name parameter required"
        return 1
    fi
    
    log_info "Creating entities for service: $service_name"
    
    # Service status
    ha_create_sensor "backup_${service_name}_status" "idle" "$service_name Backup Status" "" "enum" \
        '{"icon": "mdi:server", "possible_states": ["idle", "running", "success", "failed"]}'
    
    # Service last backup time
    ha_create_sensor "backup_${service_name}_last_run" "$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")" "$service_name Last Backup" "" "timestamp" \
        '{"icon": "mdi:clock-outline"}'
    
    # Service backup size
    ha_create_sensor "backup_${service_name}_size" "0" "$service_name Backup Size" "MB" "" \
        '{"icon": "mdi:harddisk"}'
}

# === UPDATE SERVICE STATUS ===
# Usage: backup_update_service_status <service_name> <status> [size_mb]
backup_update_service_status() {
    local service_name="$1"
    local status="$2"
    local size_mb="${3:-0}"
    
    if [[ -z "$service_name" || -z "$status" ]]; then
        log_error "Service name and status parameters required"
        return 1
    fi
    
    log_info "Updating $service_name backup status to: $status"
    
    # Update service status
    ha_create_sensor "backup_${service_name}_status" "$status" "$service_name Backup Status" "" "enum" \
        '{"icon": "mdi:server", "possible_states": ["idle", "running", "success", "failed"]}'
    
    # Update last run time
    ha_create_sensor "backup_${service_name}_last_run" "$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")" "$service_name Last Backup" "" "timestamp" \
        '{"icon": "mdi:clock-outline"}'
    
    # Update size
    ha_create_sensor "backup_${service_name}_size" "$size_mb" "$service_name Backup Size" "MB" "" \
        '{"icon": "mdi:harddisk"}'
}

# === INITIALIZE ALL BACKUP ENTITIES ===
backup_init_all_entities() {
    log_info "Initializing all Home Assistant backup monitoring entities"
    
    # Create main status entities
    backup_create_status_entities
    
    # Create control entities
    backup_create_control_entities
    
    # Create entities for common services
    local services=("nextcloud" "immich" "paperless" "karakeep" "crafty" "homeassistant" "esphome")
    
    for service in "${services[@]}"; do
        backup_create_service_entities "$service"
    done
    
    log_info "All backup monitoring entities initialized successfully"
}