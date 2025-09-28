#!/bin/bash
set -euo pipefail

#This scripts tests the remote connection and ensures the remote directory exists

test_ssh() {
    local user="$1"
    local host="$2"
    
    # Validate input parameters
    if [[ -z "$user" || -z "$host" ]]; then
        log_error "test_ssh: Missing required parameters (user: '$user', host: '$host')"
        return 1
    fi
    
    log_info "Testing SSH connectivity to ${user}@${host}"
    
    # Attempt SSH connection with specific options:
    # -o ConnectTimeout=10: Wait max 10 seconds for connection
    # -o BatchMode=yes: Don't prompt for passwords (use keys only)
    # -o StrictHostKeyChecking=no: Don't prompt for unknown hosts (optional - remove if you want strict checking)
    # >/dev/null 2>&1: Suppress all output
    if ssh -o ConnectTimeout=30 \
           -o BatchMode=yes \
           "${user}@${host}" \
           "echo 'SSH connection test successful'" >/dev/null 2>&1; then
        log_info "SSH connectivity test passed for ${user}@${host}"
        return 0
    else
        log_error "Cannot connect to ${user}@${host} via SSH"
        log_error "Possible causes: network issues, wrong credentials, host unreachable, or SSH service not running"
        return 1
    fi
}


ensure_remote_dir() {
    local user="$1"
    local host="$2"
    local dir="$3"
    
    # Validate input parameters
    if [[ -z "$user" || -z "$host" || -z "$dir" ]]; then
        log_error "ensure_remote_dir: Missing required parameters (user: '$user', host: '$host', dir: '$dir')"
        return 1
    fi
    
    log_info "Ensuring remote directory exists: ${user}@${host}:${dir}"
    
    # Create directory on remote host:
    # -p flag: create parent directories as needed, don't error if directory exists
    # Single quotes around $dir: prevent local shell expansion
    # 2>/dev/null: suppress error messages (we handle errors with return code)
    if ssh -o ConnectTimeout=30 \
           -o BatchMode=yes \
           "${user}@${host}" \
           "mkdir -p '$dir' && echo 'Directory ready: $dir'" 2>/dev/null; then
        log_info "Successfully ensured remote directory exists: $dir"
        return 0
    else
        log_error "Failed to create remote directory: ${user}@${host}:${dir}"
        log_error "Possible causes: insufficient permissions, disk full, or connection issues"
        return 1
    fi
}

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