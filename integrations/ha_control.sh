(The file `/Users/kabir.vms/Git/simple-backups/integrations/ha_control.sh` exists, but is empty)
#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../core/logging.sh"

# === HOME ASSISTANT CONTROL ===
# Configuration variables (set these in your environment or config file)
HA_URL="${HA_URL:-http://homeassistant.local:8123}"
HA_TOKEN="${HA_TOKEN:-}"

# === TOGGLE ENTITY FUNCTION ===
# Usage: ha_toggle_entity <entity_id> <wait_seconds> [service_domain]
# Example: ha_toggle_entity "switch.backup_mode" 30
# Example: ha_toggle_entity "light.office_lamp" 60 "light"
ha_toggle_entity() {
    local entity_id="$1"
    local wait_seconds="$2"
    local service_domain="${3:-}"
    
    # Validate parameters
    if [[ -z "$entity_id" || -z "$wait_seconds" ]]; then
        log_error "Missing required parameters: entity_id and wait_seconds"
        return 1
    fi
    
    # Validate HA_TOKEN is set
    if [[ -z "$HA_TOKEN" ]]; then
        log_error "HA_TOKEN environment variable not set"
        return 1
    fi
    
    # Auto-detect service domain if not provided
    if [[ -z "$service_domain" ]]; then
        service_domain="${entity_id%%.*}"
        log_info "Auto-detected service domain: $service_domain"
    fi
    
    log_info "Toggling Home Assistant entity: $entity_id"
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl command not found. Required for Home Assistant API calls."
        return 1
    fi
    
    # Get current state first
    local current_state
    current_state=$(curl -s -X GET \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        "$HA_URL/api/states/$entity_id" | \
        grep -o '"state":"[^"]*"' | cut -d'"' -f4)
    
    if [[ -z "$current_state" ]]; then
        log_error "Failed to get current state for entity: $entity_id"
        return 1
    fi
    
    log_info "Current state of $entity_id: $current_state"
    
    # Toggle the entity
    local toggle_response
    toggle_response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"entity_id\": \"$entity_id\"}" \
        "$HA_URL/api/services/$service_domain/toggle")
    
    local http_code="${toggle_response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        log_info "Successfully toggled $entity_id"
    else
        log_error "Failed to toggle $entity_id (HTTP: $http_code)"
        return 1
    fi
    
    # Wait specified time
    log_info "Waiting $wait_seconds seconds..."
    sleep "$wait_seconds"
    
    # Toggle back to original state
    log_info "Toggling $entity_id back to original state"
    
    toggle_response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"entity_id\": \"$entity_id\"}" \
        "$HA_URL/api/services/$service_domain/toggle")
    
    http_code="${toggle_response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        log_info "Successfully toggled $entity_id back to original state"
        return 0
    else
        log_error "Failed to toggle $entity_id back (HTTP: $http_code)"
        return 1
    fi
}

# === SET ENTITY STATE FUNCTION ===
# Usage: ha_set_entity <entity_id> <state> <wait_seconds> [service_domain] [service_action]
# Example: ha_set_entity "switch.backup_mode" "on" 30
# Example: ha_set_entity "light.office_lamp" "on" 60 "light" "turn_on"
ha_set_entity() {
    local entity_id="$1"
    local desired_state="$2"
    local wait_seconds="$3"
    local service_domain="${4:-}"
    local service_action="${5:-}"
    
    # Validate parameters
    if [[ -z "$entity_id" || -z "$desired_state" || -z "$wait_seconds" ]]; then
        log_error "Missing required parameters: entity_id, desired_state, and wait_seconds"
        return 1
    fi
    
    # Validate HA_TOKEN is set
    if [[ -z "$HA_TOKEN" ]]; then
        log_error "HA_TOKEN environment variable not set"
        return 1
    fi
    
    # Auto-detect service domain if not provided
    if [[ -z "$service_domain" ]]; then
        service_domain="${entity_id%%.*}"
    fi
    
    # Auto-detect service action if not provided
    if [[ -z "$service_action" ]]; then
        case "$desired_state" in
            "on"|"true") service_action="turn_on" ;;
            "off"|"false") service_action="turn_off" ;;
            *) service_action="toggle" ;;
        esac
    fi
    
    log_info "Setting Home Assistant entity $entity_id to $desired_state for $wait_seconds seconds"
    
    # Get current state
    local current_state
    current_state=$(curl -s -X GET \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        "$HA_URL/api/states/$entity_id" | \
        grep -o '"state":"[^"]*"' | cut -d'"' -f4)
    
    log_info "Current state of $entity_id: $current_state"
    
    # Set to desired state
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"entity_id\": \"$entity_id\"}" \
        "$HA_URL/api/services/$service_domain/$service_action")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        log_info "Successfully set $entity_id to $desired_state"
    else
        log_error "Failed to set $entity_id to $desired_state (HTTP: $http_code)"
        return 1
    fi
    
    # Wait specified time
    log_info "Waiting $wait_seconds seconds..."
    sleep "$wait_seconds"
    
    # Restore original state if different
    if [[ "$current_state" != "$desired_state" ]]; then
        log_info "Restoring $entity_id to original state: $current_state"
        
        local restore_action
        case "$current_state" in
            "on"|"true") restore_action="turn_on" ;;
            "off"|"false") restore_action="turn_off" ;;
            *) restore_action="toggle" ;;
        esac
        
        response=$(curl -s -w "%{http_code}" -X POST \
            -H "Authorization: Bearer $HA_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"entity_id\": \"$entity_id\"}" \
            "$HA_URL/api/services/$service_domain/$restore_action")
        
        http_code="${response: -3}"
        
        if [[ "$http_code" == "200" ]]; then
            log_info "Successfully restored $entity_id to original state"
            return 0
        else
            log_error "Failed to restore $entity_id to original state (HTTP: $http_code)"
            return 1
        fi
    else
        log_info "Entity $entity_id was already in desired state, no restoration needed"
        return 0
    fi
}
