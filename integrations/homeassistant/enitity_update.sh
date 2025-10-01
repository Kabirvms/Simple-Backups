#!/bin/bash

# Home Assistant Entity Update Functions for Backup Monitoring
# Usage: Source this file and call the functions as needed

# === CONFIGURATION ===
# These should be set in your .env file:
# HA_URL=http://homeassistant.local:8123
# HA_TOKEN=your_long_lived_access_token

# === UTILITY FUNCTIONS ===

# Create or update a Home Assistant sensor entity
# Usage: ha_update_sensor <entity_id> <state> <friendly_name> [unit] [device_class] [icon]
ha_update_sensor() {
    local entity_id="$1"
    local state="$2"
    local friendly_name="$3"
    local unit="${4:-}"
    local device_class="${5:-}"
    local icon="${6:-mdi:information-outline}"
    
    # Validate parameters
    if [[ -z "$entity_id" || -z "$state" || -z "$friendly_name" ]]; then
        echo "Error: Missing required parameters for ha_update_sensor"
        return 1
    fi
    
    # Validate HA environment variables
    if [[ -z "$HA_URL" || -z "$HA_TOKEN" ]]; then
        echo "Warning: HA_URL or HA_TOKEN not set, skipping Home Assistant update"
        return 0
    fi
    
    # Build JSON payload using simple string concatenation
    local json_payload='{"state": "'$state'", "attributes": {"friendly_name": "'$friendly_name'"'
    
    if [[ -n "$unit" ]]; then
        json_payload="$json_payload"', "unit_of_measurement": "'$unit'"'
    fi
    
    if [[ -n "$device_class" ]]; then
        json_payload="$json_payload"', "device_class": "'$device_class'"'
    fi
    
    json_payload="$json_payload"', "icon": "'$icon'"}}'
    
    # Create/update the sensor
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "$HA_URL/api/states/sensor.$entity_id")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "✓ Updated HA sensor: sensor.$entity_id = $state"
        return 0
    else
        echo "✗ Failed to update HA sensor $entity_id (HTTP: $http_code)"
        echo "JSON sent: $json_payload"
        echo "Response: ${response%???}"
        return 1
    fi
}

# === BACKUP MONITORING FUNCTIONS ===

# Initialize backup monitoring entities in Home Assistant
# Usage: backup_init_entities [backup_type]
backup_init_entities() {
    local backup_type="${1:-general}"
    echo "Initializing Home Assistant backup monitoring entities for: $backup_type"
    
    # Backup status (idle, running, success, failed)
    ha_update_sensor "backup_${backup_type}_status" "idle" "${backup_type^} Backup Status" "" "" "mdi:backup-restore"
    
    # Last backup start time
    ha_update_sensor "backup_${backup_type}_last_started" "unknown" "${backup_type^} Backup Last Started" "" "timestamp" "mdi:play-circle-outline"
    
    # Last backup end time
    ha_update_sensor "backup_${backup_type}_last_finished" "unknown" "${backup_type^} Backup Last Finished" "" "timestamp" "mdi:stop-circle-outline"
    
    # Backup duration in minutes
    ha_update_sensor "backup_${backup_type}_duration" "0" "${backup_type^} Backup Duration" "minutes" "duration" "mdi:timer-outline"
    
    # Last failure code (0=success, 1=script failure, 2=container failure)
    ha_update_sensor "backup_${backup_type}_failure_code" "0" "${backup_type^} Backup Failure Code" "" "" "mdi:alert-circle-outline"
    
    # Failure description
    ha_update_sensor "backup_${backup_type}_failure_reason" "none" "${backup_type^} Backup Failure Reason" "" "" "mdi:alert-outline"
    
    # Total backup count
    ha_update_sensor "backup_${backup_type}_total_count" "0" "${backup_type^} Backup Total Count" "" "" "mdi:counter"
    
    # Success count
    ha_update_sensor "backup_${backup_type}_success_count" "0" "${backup_type^} Backup Success Count" "" "" "mdi:check-circle-outline"
    
    # Failure count
    ha_update_sensor "backup_${backup_type}_failure_count" "0" "${backup_type^} Backup Failure Count" "" "" "mdi:alert-circle"
    
    echo "✓ Backup monitoring entities initialized for $backup_type"
}

# Record backup start
# Usage: backup_started [backup_type]
backup_started() {
    local backup_type="${1:-general}"
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
    echo "Recording $backup_type backup start at: $start_time"
    
    ha_update_sensor "backup_${backup_type}_status" "running" "${backup_type^} Backup Status" "" "" "mdi:backup-restore"
    ha_update_sensor "backup_${backup_type}_last_started" "$start_time" "${backup_type^} Backup Last Started" "" "timestamp" "mdi:play-circle-outline"
    
    # Store start time for duration calculation
    echo "$start_time" > "/tmp/backup_${backup_type}_start_time"
}

# Record backup completion
# Usage: backup_finished <exit_code> [failure_reason] [backup_type]
backup_finished() {
    local exit_code="${1:-0}"
    local failure_reason="${2:-none}"
    local backup_type="${3:-general}"
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
    
    echo "Recording $backup_type backup completion at: $end_time (exit code: $exit_code)"
    
    # Update end time
    ha_update_sensor "backup_${backup_type}_last_finished" "$end_time" "${backup_type^} Backup Last Finished" "" "timestamp" "mdi:stop-circle-outline"
    
    # Calculate duration if start time exists
    if [[ -f "/tmp/backup_${backup_type}_start_time" ]]; then
        local start_time=$(cat "/tmp/backup_${backup_type}_start_time")
        local start_epoch=$(date -d "$start_time" +%s)
        local end_epoch=$(date -d "$end_time" +%s)
        local duration_seconds=$((end_epoch - start_epoch))
        local duration_minutes=$((duration_seconds / 60))
        
        ha_update_sensor "backup_${backup_type}_duration" "$duration_minutes" "${backup_type^} Backup Duration" "minutes" "duration" "mdi:timer-outline"
        
        rm -f "/tmp/backup_${backup_type}_start_time"
    fi
    
    # Update status based on exit code
    case $exit_code in
        0)
            ha_update_sensor "backup_${backup_type}_status" "success" "${backup_type^} Backup Status" "" "" "mdi:backup-restore"
            backup_increment_counter "success" "$backup_type"
            ;;
        1)
            ha_update_sensor "backup_${backup_type}_status" "failed" "${backup_type^} Backup Status" "" "" "mdi:backup-restore"
            ha_update_sensor "backup_${backup_type}_failure_reason" "Script Failure" "${backup_type^} Backup Failure Reason" "" "" "mdi:alert-outline"
            backup_increment_counter "failure" "$backup_type"
            ;;
        2)
            ha_update_sensor "backup_${backup_type}_status" "failed" "${backup_type^} Backup Status" "" "" "mdi:backup-restore"
            ha_update_sensor "backup_${backup_type}_failure_reason" "Container Failure" "${backup_type^} Backup Failure Reason" "" "" "mdi:alert-outline"
            backup_increment_counter "failure" "$backup_type"
            ;;
        *)
            ha_update_sensor "backup_${backup_type}_status" "failed" "${backup_type^} Backup Status" "" "" "mdi:backup-restore"
            ha_update_sensor "backup_${backup_type}_failure_reason" "$failure_reason" "${backup_type^} Backup Failure Reason" "" "" "mdi:alert-outline"
            backup_increment_counter "failure" "$backup_type"
            ;;
    esac
    
    # Update failure code
    ha_update_sensor "backup_${backup_type}_failure_code" "$exit_code" "${backup_type^} Backup Failure Code" "" "" "mdi:alert-circle-outline"
    
    # Increment total counter
    backup_increment_counter "total" "$backup_type"
}

# Helper function to increment counters
# Usage: backup_increment_counter <counter_type> [backup_type]
backup_increment_counter() {
    local counter_type="$1"
    local backup_type="${2:-general}"
    
    if [[ -z "$HA_URL" || -z "$HA_TOKEN" ]]; then
        return 0
    fi
    
    # Get current count
    local current_count
    current_count=$(curl -s -X GET \
        -H "Authorization: Bearer $HA_TOKEN" \
        "$HA_URL/api/states/sensor.backup_${backup_type}_${counter_type}_count" | \
        grep -o '"state":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "0")
    
    # Increment and update
    local new_count=$((current_count + 1))
    
    case $counter_type in
        "total")
            ha_update_sensor "backup_${backup_type}_total_count" "$new_count" "${backup_type^} Backup Total Count" "" "" "mdi:counter"
            ;;
        "success")
            ha_update_sensor "backup_${backup_type}_success_count" "$new_count" "${backup_type^} Backup Success Count" "" "" "mdi:check-circle-outline"
            ;;
        "failure")
            ha_update_sensor "backup_${backup_type}_failure_count" "$new_count" "${backup_type^} Backup Failure Count" "" "" "mdi:alert-circle"
            ;;
    esac
}

# Reset all counters to zero
# Usage: backup_reset_counters [backup_type]
backup_reset_counters() {
    local backup_type="${1:-general}"
    echo "Resetting $backup_type backup counters..."
    
    ha_update_sensor "backup_${backup_type}_total_count" "0" "${backup_type^} Backup Total Count" "" "" "mdi:counter"
    ha_update_sensor "backup_${backup_type}_success_count" "0" "${backup_type^} Backup Success Count" "" "" "mdi:check-circle-outline"
    ha_update_sensor "backup_${backup_type}_failure_count" "0" "${backup_type^} Backup Failure Count" "" "" "mdi:alert-circle"
    
    echo "✓ $backup_type counters reset"
}