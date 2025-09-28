#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/logging.sh"

# === TAILSCALE MANAGEMENT ===
# Usage: tailscale <up|down>
# Returns: 0 on success, 1 on failure
tailscale () {
    local action="$1"
    local timeout=60
    
    # Validate action parameter
    if [[ "$action" != "up" && "$action" != "down" ]]; then
        log_error "Invalid Tailscale action: $action. Use 'up' or 'down'"
        return 1
    fi
    
    log_info "Attempting to bring Tailscale $action"
    
    # Execute tailscale command
    if timeout "$timeout" tailscale "$action"; then
        log_info "Successfully brought Tailscale $action"
        return 0
    else
        local exit_code=$?
        log_error "Failed to bring Tailscale $action after ${timeout} seconds (exit code: $exit_code)"
        return 1
    fi
}

# Check if Tailscale is available
check_tailscale() {
    if ! command -v tailscale >/dev/null 2>&1; then
        log_error "Tailscale command not found. Please fix and verify Tailscale."
        return 1
    fi
    
    log_info "Tailscale is available"
    return 0
} 