#!/bin/bash

# Remote Shutdown and Ping Verification Script
# Usage: safe_shutdown <remote_host> [ssh_user] [max_attempts] [wait_time]

safe_shutdown() {
    local REMOTE_HOST="$1"
    local SSH_USER="${2:-$USER}"
    local MAX_ATTEMPTS="${3:-5}"
    local WAIT_TIME="${4:-30}"

    # Check if remote host is provided
    if [ -z "$REMOTE_HOST" ]; then
        if command -v log_error >/dev/null 2>&1; then
            log_error "Remote host not specified for shutdown"
        else
            echo "Error: Remote host not specified for shutdown"
        fi
        return 1
    fi

    if command -v log_info >/dev/null 2>&1; then
        log_info "Sending shutdown command to $SSH_USER@$REMOTE_HOST..."
    else
        echo "Sending shutdown command to $SSH_USER@$REMOTE_HOST..."
    fi
    
    # Send shutdown command
    if ssh "$SSH_USER@$REMOTE_HOST" "sudo shutdown -h now" 2>/dev/null; then
        if command -v log_info >/dev/null 2>&1; then
            log_info "Shutdown command sent successfully"
        else
            echo "Shutdown command sent successfully"
        fi
    else
        if command -v log_error >/dev/null 2>&1; then
            log_error "Failed to send shutdown command to $REMOTE_HOST"
        else
            echo "Error: Failed to send shutdown command to $REMOTE_HOST"
        fi
        return 1
    fi

    if command -v log_info >/dev/null 2>&1; then
        log_info "Waiting $WAIT_TIME seconds before verifying shutdown..."
    else
        echo "Waiting $WAIT_TIME seconds before verifying shutdown..."
    fi
    sleep $WAIT_TIME

    # Verify shutdown by pinging
    for i in $(seq 1 $MAX_ATTEMPTS); do
        if command -v log_info >/dev/null 2>&1; then
            log_info "Ping attempt $i of $MAX_ATTEMPTS..."
        else
            echo "Ping attempt $i of $MAX_ATTEMPTS..."
        fi
        
        if ping -c 1 -W 2 "$REMOTE_HOST" > /dev/null 2>&1; then
            if command -v log_info >/dev/null 2>&1; then
                log_info "Host $REMOTE_HOST is still responding to ping"
            else
                echo "Host $REMOTE_HOST is still responding to ping"
            fi
            
            if [ $i -eq $MAX_ATTEMPTS ]; then
                if command -v log_warning >/dev/null 2>&1; then
                    log_warning "Host is still up after $MAX_ATTEMPTS attempts"
                else
                    echo "Warning: Host is still up after $MAX_ATTEMPTS attempts"
                fi
                return 1
            fi
            
            # Wait a bit before next attempt
            sleep 10
        else
            if command -v log_info >/dev/null 2>&1; then
                log_info "✓ Host $REMOTE_HOST shutdown verified (not responding to ping)"
            else
                echo "✓ Host $REMOTE_HOST shutdown verified (not responding to ping)"
            fi
            return 0
        fi
    done

    if command -v log_warning >/dev/null 2>&1; then
        log_warning "Host may still be shutting down"
    else
        echo "Warning: Host may still be shutting down"
    fi
    return 0
}

# Standalone execution support
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    REMOTE_HOST="$1"
    SSH_USER="${2:-$USER}"
    MAX_ATTEMPTS="${3:-5}"
    WAIT_TIME="${4:-30}"
    
    # Check if remote host is provided
    if [ -z "$REMOTE_HOST" ]; then
        echo "Error: Remote host not specified"
        echo "Usage: $0 <remote_host> [ssh_user] [max_attempts] [wait_time]"
        exit 1
    fi

    safe_shutdown "$REMOTE_HOST" "$SSH_USER" "$MAX_ATTEMPTS" "$WAIT_TIME"
fi