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

    # Load environment variables if not already loaded
    if [[ -z "${NEXTCLOUD_DB_PASSWORD:-}" ]]; then
        log_info "Loading environment variables from $env_file"
        set -a 
        source "$env_file"
        set +a
    fi

    # Check required environment variables
    local db_pass="${NEXTCLOUD_DB_PASSWORD:-}"
    if [ -z "$db_pass" ]; then
        log_error "NEXTCLOUD_DB_PASSWORD not set"
        return 1
    fi
    
    # Check other required variables
    if [[ -z "${REMOTE_USER:-}" ]]; then
        log_error "REMOTE_USER not set"
        return 1
    fi
    
    if [[ -z "${REMOTE_HOST:-}" ]]; then
        log_error "REMOTE_HOST not set"
        return 1
    fi
    
    if [[ -z "${REMOTE_STORAGE_LOCATION:-}" ]]; then
        log_error "REMOTE_STORAGE_LOCATION not set"
        return 1
    fi
    
    if [[ -z "${DUMP_DIR:-}" ]]; then
        log_error "DUMP_DIR not set"
        return 1
    fi
    
    log_info "All required environment variables are set"
    return 0
}
