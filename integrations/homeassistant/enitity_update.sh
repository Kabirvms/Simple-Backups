#!/bin/bash

# Home Assistant Entity Update Functions for Backup Monitoring
# Usage: Source this file and call the functions as needed

# === CONFIGURATION ===
# These should be set in your .env file:
# HA_URL=http://homeassistant.local:8123
# HA_TOKEN=your_long_lived_access_token

# === UTILITY FUNCTIONS ===

# Create or update a Home Assistant sensor entity with proper persistence
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
    
    # Build JSON payload with proper attributes for persistence
    local json_payload='{"state": "'$state'", "attributes": {"friendly_name": "'$friendly_name'"'
    
    if [[ -n "$unit" ]]; then
        json_payload="$json_payload"', "unit_of_measurement": "'$unit'"'
    fi
    
    if [[ -n "$device_class" ]]; then
        json_payload="$json_payload"', "device_class": "'$device_class'"'
    fi
    
    # Add persistence attributes to prevent entity removal
    json_payload="$json_payload"', "icon": "'$icon'"'
    json_payload="$json_payload"', "last_updated": "'$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")'"'
    json_payload="$json_payload"', "source": "simple_backups"'
    json_payload="$json_payload"', "entity_category": "diagnostic"'
    json_payload="$json_payload"'}}'
    
    # Create/update the sensor with retry logic
    local response
    local attempts=0
    local max_attempts=3
    
    while [[ $attempts -lt $max_attempts ]]; do
        response=$(curl -s -w "%{http_code}" -X POST \
            -H "Authorization: Bearer $HA_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            "$HA_URL/api/states/sensor.$entity_id" 2>/dev/null)
        
        local http_code="${response: -3}"
        
        if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
            echo "✓ Updated HA sensor: sensor.$entity_id = $state"
            
            # Store entity info for heartbeat
            local entity_file="/tmp/ha_entities_${entity_id}"
            echo "$(date +%s)|$entity_id|$friendly_name" > "$entity_file"
            
            return 0
        else
            ((attempts++))
            echo "⚠ Attempt $attempts failed for HA sensor $entity_id (HTTP: $http_code)"
            if [[ $attempts -lt $max_attempts ]]; then
                sleep 2
            fi
        fi
    done
    
    echo "✗ Failed to update HA sensor $entity_id after $max_attempts attempts"
    echo "JSON sent: $json_payload"
    echo "Response: ${response%???}"
    return 1
}

# Send heartbeat to prevent entity removal
# Usage: ha_send_heartbeat [backup_type]
ha_send_heartbeat() {
    local backup_type="${1:-general}"
    
    if [[ -z "$HA_URL" || -z "$HA_TOKEN" ]]; then
        return 0
    fi
    
    # Update a simple heartbeat sensor to keep entities alive
    local heartbeat_time=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
    ha_update_sensor "backup_${backup_type}_heartbeat" "$heartbeat_time" "${backup_type^} Backup Heartbeat" "" "timestamp" "mdi:heart-pulse"
    
    echo "✓ Sent heartbeat for $backup_type entities"
}

# Ensure entities are registered and available
# Usage: ha_ensure_entities [backup_type]
ha_ensure_entities() {
    local backup_type="${1:-general}"
    
    if [[ -z "$HA_URL" || -z "$HA_TOKEN" ]]; then
        return 0
    fi
    
    echo "Ensuring entities are available for: $backup_type"
    
    # Check if main status entity exists, if not reinitialize all
    local response
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $HA_TOKEN" \
        "$HA_URL/api/states/sensor.backup_${backup_type}_status" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ "$response" == *"Entity not found"* ]] || [[ -z "$response" ]]; then
        echo "Entities missing, reinitializing..."
        backup_init_entities "$backup_type"
    else
        echo "✓ Entities verified for $backup_type"
        ha_send_heartbeat "$backup_type"
    fi
}

# === BACKUP MONITORING FUNCTIONS ===

# Initialize backup monitoring entities in Home Assistant
# Usage: backup_init_entities [backup_type]
backup_init_entities() {
    local backup_type="${1:-general}"
    echo "Initializing Home Assistant backup monitoring entities for: $backup_type"
    
    # Ensure entities before creating new ones
    ha_ensure_entities "$backup_type"
    
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
    
    # Initialize heartbeat
    ha_send_heartbeat "$backup_type"
    
    echo "✓ Backup monitoring entities initialized for $backup_type"
}

# Record backup start
# Usage: backup_started [backup_type]
backup_started() {
    local backup_type="${1:-general}"
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
    echo "Recording $backup_type backup start at: $start_time"
    
    # Ensure entities exist before updating
    ha_ensure_entities "$backup_type"
    
    ha_update_sensor "backup_${backup_type}_status" "running" "${backup_type^} Backup Status" "" "" "mdi:backup-restore"
    ha_update_sensor "backup_${backup_type}_last_started" "$start_time" "${backup_type^} Backup Last Started" "" "timestamp" "mdi:play-circle-outline"
    
    # Store start time for duration calculation
    echo "$start_time" > "/tmp/backup_${backup_type}_start_time"
    
    # Send heartbeat
    ha_send_heartbeat "$backup_type"
}

# Record backup completion
# Usage: backup_finished <exit_code> [failure_reason] [backup_type]
backup_finished() {
    local exit_code="${1:-0}"
    local failure_reason="${2:-none}"
    local backup_type="${3:-general}"
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
    
    echo "Recording $backup_type backup completion at: $end_time (exit code: $exit_code)"
    
    # Ensure entities exist before updating
    ha_ensure_entities "$backup_type"
    
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
    
    # Send final heartbeat
    ha_send_heartbeat "$backup_type"
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
    
    # Ensure entities exist before resetting
    ha_ensure_entities "$backup_type"
    
    ha_update_sensor "backup_${backup_type}_total_count" "0" "${backup_type^} Backup Total Count" "" "" "mdi:counter"
    ha_update_sensor "backup_${backup_type}_success_count" "0" "${backup_type^} Backup Success Count" "" "" "mdi:check-circle-outline"
    ha_update_sensor "backup_${backup_type}_failure_count" "0" "${backup_type^} Backup Failure Count" "" "" "mdi:alert-circle"
    
    # Send heartbeat after reset
    ha_send_heartbeat "$backup_type"
    
    echo "✓ $backup_type counters reset"
}

# Create a periodic heartbeat script to keep entities alive
# Usage: create_heartbeat_script [backup_type] [interval_minutes]
create_heartbeat_script() {
    local backup_type="${1:-general}"
    local interval="${2:-30}"  # Default 30 minutes
    local script_path="/tmp/ha_heartbeat_${backup_type}.sh"
    
    cat > "$script_path" << EOF
#!/bin/bash
# Auto-generated heartbeat script for $backup_type backup entities
# Sends periodic updates to prevent entity removal

# Source the entity update functions
source "$(dirname "\$0")/../integrations/homeassistant/enitity_update.sh"

# Set environment variables (you may need to adjust these paths)
if [[ -f "\$(dirname "\$0")/../.env" ]]; then
    source "\$(dirname "\$0")/../.env"
fi

while true; do
    echo "\$(date): Sending heartbeat for $backup_type entities"
    ha_send_heartbeat "$backup_type"
    sleep \$((60 * $interval))  # Sleep for $interval minutes
done
EOF
    
    chmod +x "$script_path"
    echo "✓ Created heartbeat script: $script_path"
    echo "  To run in background: nohup $script_path > /dev/null 2>&1 &"
    echo "  To stop: pkill -f ha_heartbeat_${backup_type}"
}

# Start background heartbeat process
# Usage: start_heartbeat_daemon [backup_type] [interval_minutes]
start_heartbeat_daemon() {
    local backup_type="${1:-general}"
    local interval="${2:-30}"
    
    # Check if already running
    if pgrep -f "ha_heartbeat_${backup_type}" > /dev/null; then
        echo "Heartbeat daemon already running for $backup_type"
        return 0
    fi
    
    create_heartbeat_script "$backup_type" "$interval"
    
    local script_path="/tmp/ha_heartbeat_${backup_type}.sh"
    nohup "$script_path" > "/tmp/ha_heartbeat_${backup_type}.log" 2>&1 &
    
    echo "✓ Started heartbeat daemon for $backup_type (PID: $!)"
    echo "  Log file: /tmp/ha_heartbeat_${backup_type}.log"
}

# Stop background heartbeat process
# Usage: stop_heartbeat_daemon [backup_type]
stop_heartbeat_daemon() {
    local backup_type="${1:-general}"
    
    if pkill -f "ha_heartbeat_${backup_type}"; then
        echo "✓ Stopped heartbeat daemon for $backup_type"
    else
        echo "No heartbeat daemon running for $backup_type"
    fi
}