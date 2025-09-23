#!/bin/bash
set -euo pipefail

# Note: logging.sh and other dependencies are sourced by the main script

RSYNC_TIMEOUT=14400
MAX_RETRIES=5
RSYNC_OPTS="-a --partial --append-verify --timeout=$RSYNC_TIMEOUT --delete-delay --compress-level=0 --no-perms --no-owner --no-group --links --inplace --no-whole-file --block-size=8192"
SSH_OPTS="ssh -o ConnectTimeout=30 -o ServerAliveInterval=60 -o Compression=no -c aes128-ctr -T -x"

sync_dir() {
	local source="$1"
	local target="$2"
	local label="$3"
	local retry_count=0

	log_info "Starting backup: $label"
	log_info "Source: $source -> Target: ${REMOTE_USER}@${REMOTE_HOST}:$target/"

	if [ ! -d "$source" ]; then
		log_error "Source directory '$source' does not exist"
		return 1
	fi
	if [ ! -r "$source" ]; then
		log_error "Source directory '$source' is not readable"
		return 1
	fi
	local source_size=$(du -sh "$source" 2>/dev/null | cut -f1 || echo "unknown")
	log_info "Source size: $source_size"

	while [ $retry_count -lt $MAX_RETRIES ]; do
		local start_ts=$(date +%s)
		log_info "Attempt $((retry_count + 1))/$MAX_RETRIES for $label"
		if rsync $RSYNC_OPTS -e "$SSH_OPTS" "$source" "${REMOTE_USER}@${REMOTE_HOST}:$target/"; then
			local end_ts=$(date +%s)
			local duration=$((end_ts - start_ts))
			log_info "SUCCESS: $label backup completed in ${duration}s"
			return 0
		else
			local exit_code=$?
			retry_count=$((retry_count + 1))
			log_warning "Attempt $retry_count failed for $label (exit code: $exit_code)"
			if [ $retry_count -lt $MAX_RETRIES ]; then
				local wait_time=$((retry_count * 10))
				log_info "Retrying in ${wait_time}s..."
				sleep $wait_time
			fi
		fi
	done
	log_error "Failed to sync $label after $MAX_RETRIES attempts"
	return 1
}
