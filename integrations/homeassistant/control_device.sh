#!/bin/bash

# Simple Home Assistant device control function
# Usage: control_device <entity_id> <action> [wait_time]
control_device() {    
    # Check arguments
    if [ $# -lt 2 ]; then
        echo "Usage: control_device <entity_id> <action> [wait_time]"
        echo "Example: control_device light.living_room turn_on"
        echo "Example: control_device switch.desk_loop turn_off 45"
        return 1
    fi
    
    local entity_id="$1"
    local action="$2"
    local wait_time="${3:-30}"
    
    # Validate required environment variables
    if [[ -z "$HA_URL" || -z "$HA_TOKEN" ]]; then
        echo "✗ Error: HA_URL and HA_TOKEN environment variables must be set"
        return 1
    fi
    
    # Extract domain from entity_id (e.g., "light" from "light.living_room")
    local domain="${entity_id%%.*}"
    
    # Build the service endpoint
    local service_url="${HA_URL}/api/services/${domain}/${action}"
    
    # Build simple JSON payload
    local json_payload='{"entity_id": "'${entity_id}'"}'
    
    # Make the API call
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer ${HA_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "${service_url}")
    
    # Extract HTTP status code (last 3 characters)
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    # Check if request was successful
    if [[ "$http_code" == "200" ]]; then
        echo "✓ Successfully called ${action} on ${entity_id}"
        
        # Wait for specified time before continuing
        if [[ "$wait_time" =~ ^[0-9]+$ ]] && [ "$wait_time" -gt 0 ]; then
            echo "⏳ Waiting ${wait_time} seconds before continuing..."
            sleep "$wait_time"
            echo "✓ Wait complete, continuing..."
        fi
        return 0
    else
        echo "✗ Failed to call ${action} on ${entity_id} (HTTP: ${http_code})"
        if [[ -n "$response_body" ]]; then
            echo "Response: $response_body"
        fi
        return 1
    fi
}
