#!/bin/bash
set -euo pipefail

# Note: Dependencies are sourced by the main script

# === CONFIG VALIDATION FUNCTION ===
verify_config() {
    local env_file="${1:-$ENV_FILE}"
    log_info "Validating environment file: $env_file"
    if [ -f "$env_file" ]; then
        log_info "Environment file found and accessible"
    else
        log_error ".env file not found at $env_file"
        return 1
    fi

    # Check required environment variables
    local db_pass="${MYSQL_ROOT_PASSWORD:-}"
    if [ -z "$db_pass" ]; then
        log_error "MYSQL_ROOT_PASSWORD not set"
        return 1
    fi
    
    log_info "All required environment variables are set"
    return 0
}
