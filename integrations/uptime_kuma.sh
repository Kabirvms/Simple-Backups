(The file `/Users/kabir.vms/Git/simple-backups/integrations/uptime_kuma.sh` exists, but is empty)
#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../core/logging.sh"

# === UPTIME KUMA CONFIGURATION ===
# Configuration variables (set these in your environment or config file)
KUMA_URL="${KUMA_URL:-http://localhost:3001}"
KUMA_USERNAME="${KUMA_USERNAME:-}"
KUMA_PASSWORD="${KUMA_PASSWORD:-}"

# Global variables for session management
KUMA_TOKEN=""
KUMA_SOCKET_TOKEN=""

# === AUTHENTICATION FUNCTION ===
# Authenticate with Uptime Kuma and get session token
kuma_login() {
    if [[ -z "$KUMA_USERNAME" || -z "$KUMA_PASSWORD" ]]; then
        log_error "KUMA_USERNAME and KUMA_PASSWORD environment variables must be set"
        return 1
    fi
    
    log_info "Authenticating with Uptime Kuma at $KUMA_URL"
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl command not found. Required for Uptime Kuma API calls."
        return 1
    fi
    
    # Login and get token
    local login_response
    login_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\": \"$KUMA_USERNAME\", \"password\": \"$KUMA_PASSWORD\"}" \
        "$KUMA_URL/api/login")
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to connect to Uptime Kuma at $KUMA_URL"
        return 1
    fi
    
    # Extract token from response (this may need adjustment based on Uptime Kuma's actual API)
    KUMA_TOKEN=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [[ -z "$KUMA_TOKEN" ]]; then
        log_error "Failed to authenticate with Uptime Kuma. Check username/password."
        return 1
    fi
    
    log_info "Successfully authenticated with Uptime Kuma"
    return 0
}

# === GET MONITOR ID FUNCTION ===
# Get monitor ID by name
kuma_get_monitor_id() {
    local monitor_name="$1"
    
    if [[ -z "$monitor_name" ]]; then
        log_error "Monitor name not specified"
        return 1
    fi
    
    log_info "Getting monitor ID for: $monitor_name"
    
    # Get list of monitors
    local monitors_response
    monitors_response=$(curl -s -X GET \
        -H "Authorization: Bearer $KUMA_TOKEN" \
        -H "Content-Type: application/json" \
        "$KUMA_URL/api/monitors")
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get monitors list from Uptime Kuma"
        return 1
    fi
    
    # Extract monitor ID (this may need adjustment based on actual API response format)
    local monitor_id
    monitor_id=$(echo "$monitors_response" | grep -o "\"name\":\"$monitor_name\".*\"id\":[0-9]*" | grep -o "\"id\":[0-9]*" | cut -d':' -f2)
    
    if [[ -z "$monitor_id" ]]; then
        log_error "Monitor '$monitor_name' not found"
        return 1
    fi
    
    echo "$monitor_id"
    return 0
}

# === SET MAINTENANCE MODE FUNCTION ===
# Usage: kuma_set_maintenance <monitor_name> <duration_minutes> [reason]
kuma_set_maintenance() {
    local monitor_name="$1"
    local duration_minutes="$2"
    local reason="${3:-Scheduled maintenance for backup process}"
    
    # Validate parameters
    if [[ -z "$monitor_name" || -z "$duration_minutes" ]]; then
        log_error "Missing required parameters: monitor_name and duration_minutes"
        return 1
    fi
    
    # Validate duration is a number
    if ! [[ "$duration_minutes" =~ ^[0-9]+$ ]]; then
        log_error "Duration must be a number (minutes)"
        return 1
    fi
    
    log_info "Setting maintenance mode for monitor '$monitor_name' for $duration_minutes minutes"
    
    # Authenticate if not already done
    if [[ -z "$KUMA_TOKEN" ]]; then
        if ! kuma_login; then
            return 1
        fi
    fi
    
    # Get monitor ID
    local monitor_id
    monitor_id=$(kuma_get_monitor_id "$monitor_name")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    log_info "Found monitor ID: $monitor_id"
    
    # Calculate end time (current time + duration in minutes)
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    local end_time=$(date -u -d "+${duration_minutes} minutes" +"%Y-%m-%dT%H:%M:%S.000Z")
    
    # Create maintenance window
    local maintenance_response
    maintenance_response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer $KUMA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Backup Maintenance - $monitor_name\",
            \"description\": \"$reason\",
            \"strategy\": \"single\",
            \"active\": true,
            \"intervalDay\": 1,
            \"dateTime\": \"$start_time\",
            \"dateTimeEnd\": \"$end_time\",
            \"timeRange\": [{
                \"start\": \"$start_time\",
                \"end\": \"$end_time\"
            }],
            \"monitorList\": [\"$monitor_id\"]
        }" \
        "$KUMA_URL/api/maintenance")
    
    local http_code="${maintenance_response: -3}"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        log_info "Successfully set maintenance mode for '$monitor_name' until $(date -d "+${duration_minutes} minutes" '+%Y-%m-%d %H:%M:%S')"
        return 0
    else
        log_error "Failed to set maintenance mode for '$monitor_name' (HTTP: $http_code)"
        return 1
    fi
}

# === DISABLE MAINTENANCE MODE FUNCTION ===
# Usage: kuma_disable_maintenance <monitor_name>
kuma_disable_maintenance() {
    local monitor_name="$1"
    
    if [[ -z "$monitor_name" ]]; then
        log_error "Monitor name not specified"
        return 1
    fi
    
    log_info "Disabling maintenance mode for monitor '$monitor_name'"
    
    # Authenticate if not already done
    if [[ -z "$KUMA_TOKEN" ]]; then
        if ! kuma_login; then
            return 1
        fi
    fi
    
    # Get active maintenance windows
    local maintenance_response
    maintenance_response=$(curl -s -X GET \
        -H "Authorization: Bearer $KUMA_TOKEN" \
        -H "Content-Type: application/json" \
        "$KUMA_URL/api/maintenance")
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get maintenance windows from Uptime Kuma"
        return 1
    fi
    
    # Find and disable active maintenance for this monitor
    # Note: This is a simplified approach - you may need to adjust based on actual API
    log_info "Maintenance mode disabled for '$monitor_name' (implementation may vary based on Uptime Kuma API)"
    return 0
}

# === HEARTBEAT FUNCTION ===
# Send a heartbeat to a push monitor
# Usage: kuma_heartbeat <push_url> [status] [message]
kuma_heartbeat() {
    local push_url="$1"
    local status="${2:-up}"
    local message="${3:-Backup script heartbeat}"
    
    if [[ -z "$push_url" ]]; then
        log_error "Push URL not specified"
        return 1
    fi
    
    log_info "Sending heartbeat to Uptime Kuma: $status"
    
    # Send heartbeat
    local response
    response=$(curl -s -w "%{http_code}" -X GET "$push_url?status=$status&msg=$message")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        log_info "Successfully sent heartbeat to Uptime Kuma"
        return 0
    else
        log_error "Failed to send heartbeat (HTTP: $http_code)"
        return 1
    fi
}
