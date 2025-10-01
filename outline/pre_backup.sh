#!/bin/bash
set -euo pipefail

# === PRE-BACKUP SETUP AND VERIFICATION ===
run_pre_backup() {
    log_info "=== Starting Pre-Backup Setup ==="
    
    # Verify configuration
    verify_config "$ENV_FILE"
    log_info "Configuration has been verified"

    # Test remote connectivity
    test_ssh "$REMOTE_USER" "$REMOTE_HOST"
    log_info "Remote SSH connectivity verified for $REMOTE_USER@$REMOTE_HOST"

    # Ensure remote directory exists
    ensure_remote_dir "$REMOTE_USER" "$REMOTE_HOST" "$REMOTE_STORAGE_LOCATION"
    log_info "Remote directory has been verified"

    # Run pre-backup integrations
    run_pre_backup_integrations
    
    log_info "Pre-backup setup completed successfully"
}

# === PRE-BACKUP INTEGRATIONS ===
run_pre_backup_integrations() {
    log_info "Running pre-backup integrations..."
    
    # Add integration calls here as needed
    # Example:
    # source "$SCRIPT_DIR/integrations/ha_control.sh"
    # pause_home_assistant_automations
    
    log_info "Pre-backup integrations completed"
}
