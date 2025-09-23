(The file `/Users/kabir.vms/Git/simple-backups/core/rclone.sh` exists, but is empty)
#!/bin/bash
set -euo pipefail

# Note: Dependencies are sourced by the main script

# === RCLONE CONFIGURATION ===
RCLONE_TIMEOUT=14400  # 4 hours timeout
MAX_RETRIES=5
RCLONE_OPTS="--progress --transfers=4 --checkers=8 --contimeout=60s --timeout=300s --retries=3 --low-level-retries=10 --stats=1m"

# === RCLONE SYNC FUNCTION ===
# Usage: rclone_sync <source> <remote:target> <label>
# Similar to rsync but for cloud storage
rclone_sync() {
    local source="$1"
    local target="$2"
    local label="$3"
    local retry_count=0
    
    # Validate parameters
    if [[ -z "$source" || -z "$target" || -z "$label" ]]; then
        log_error "Missing required parameters: source, target, or label"
        return 1
    fi
    
    log_info "Starting rclone sync: $label"
    log_info "Source: $source -> Target: $target"
    
    # Validate source directory exists and is readable
    if [[ ! -d "$source" ]]; then
        log_error "Source directory '$source' does not exist"
        return 1
    fi
    
    if [[ ! -r "$source" ]]; then
        log_error "Source directory '$source' is not readable"
        return 1
    fi
    
    # Get source size for logging
    local source_size=$(du -sh "$source" 2>/dev/null | cut -f1 || echo "unknown")
    log_info "Source size: $source_size"
    
    # Check if rclone is available
    if ! command -v rclone >/dev/null 2>&1; then
        log_error "rclone command not found. Please install rclone."
        return 1
    fi
    
    # Retry logic similar to rsync
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        local start_ts=$(date +%s)
        log_info "Attempt $((retry_count + 1))/$MAX_RETRIES for $label"
        
        # Use rclone sync with timeout
        if timeout "$RCLONE_TIMEOUT" rclone sync "$source" "$target" $RCLONE_OPTS; then
            local end_ts=$(date +%s)
            local duration=$((end_ts - start_ts))
            log_info "SUCCESS: $label rclone sync completed in ${duration}s"
            return 0
        else
            local exit_code=$?
            retry_count=$((retry_count + 1))
            log_warning "Attempt $retry_count failed for $label (exit code: $exit_code)"
            
            if [[ $retry_count -lt $MAX_RETRIES ]]; then
                local wait_time=$((retry_count * 10))
                log_info "Retrying in ${wait_time}s..."
                sleep $wait_time
            fi
        fi
    done
    
    log_error "Failed to sync $label after $MAX_RETRIES attempts"
    return 1
}

# === RCLONE COPY FUNCTION ===
# Usage: rclone_copy <source> <remote:target> <label>
# Copy files without deleting extras at destination
rclone_copy() {
    local source="$1"
    local target="$2"
    local label="$3"
    local retry_count=0
    
    # Validate parameters
    if [[ -z "$source" || -z "$target" || -z "$label" ]]; then
        log_error "Missing required parameters: source, target, or label"
        return 1
    fi
    
    log_info "Starting rclone copy: $label"
    log_info "Source: $source -> Target: $target"
    
    # Similar validation as sync function
    if [[ ! -d "$source" ]]; then
        log_error "Source directory '$source' does not exist"
        return 1
    fi
    
    if [[ ! -r "$source" ]]; then
        log_error "Source directory '$source' is not readable"
        return 1
    fi
    
    local source_size=$(du -sh "$source" 2>/dev/null | cut -f1 || echo "unknown")
    log_info "Source size: $source_size"
    
    if ! command -v rclone >/dev/null 2>&1; then
        log_error "rclone command not found. Please install rclone."
        return 1
    fi
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        local start_ts=$(date +%s)
        log_info "Attempt $((retry_count + 1))/$MAX_RETRIES for $label"
        
        if timeout "$RCLONE_TIMEOUT" rclone copy "$source" "$target" $RCLONE_OPTS; then
            local end_ts=$(date +%s)
            local duration=$((end_ts - start_ts))
            log_info "SUCCESS: $label rclone copy completed in ${duration}s"
            return 0
        else
            local exit_code=$?
            retry_count=$((retry_count + 1))
            log_warning "Attempt $retry_count failed for $label (exit code: $exit_code)"
            
            if [[ $retry_count -lt $MAX_RETRIES ]]; then
                local wait_time=$((retry_count * 10))
                log_info "Retrying in ${wait_time}s..."
                sleep $wait_time
            fi
        fi
    done
    
    log_error "Failed to copy $label after $MAX_RETRIES attempts"
    return 1
}

# === CHECK RCLONE REMOTE ===
# Usage: check_rclone_remote <remote_name>
check_rclone_remote() {
    local remote_name="$1"
    
    if [[ -z "$remote_name" ]]; then
        log_error "Remote name not specified"
        return 1
    fi
    
    log_info "Checking rclone remote: $remote_name"
    
    if rclone listremotes | grep -q "^${remote_name}:$"; then
        log_info "Remote '$remote_name' is configured"
        return 0
    else
        log_error "Remote '$remote_name' is not configured in rclone"
        return 1
    fi
}
