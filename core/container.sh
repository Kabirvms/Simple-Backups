#!/bin/bash
set -euo pipefail

# Note: Dependencies are sourced by the main script

# === CONTAINER MANAGEMENT ===
# Usage: manage_containers <action> <container1> [container2] ...
# Actions: start, stop, restart, etc.
# Returns: 0 on success, 1 on any failure
manage_containers() {
	local action="$1"
	shift
	local containers=("$@")
	local failed_containers=()
	local exit_code=0
	
	# Validate action parameter
	if [[ -z "$action" ]]; then
		log_error "Container action not specified"
		return 1
	fi
	
	# Validate containers parameter
	if [[ ${#containers[@]} -eq 0 ]]; then
		log_error "No container names specified"
		return 1
	fi
	
	log_info "Attempting to $action containers: ${containers[*]}"
	
	for container in "${containers[@]}"; do
		# Check if container exists first
		if ! docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
			log_error "Container '$container' does not exist"
			failed_containers+=("$container (not found)")
			exit_code=1
			continue
		fi
		
		# Attempt the action with detailed error output
		if docker "$action" "$container" 2>&1; then
			log_info "Successfully ${action}ed container: $container"
		else
			local docker_exit_code=$?
			log_error "Failed to $action container: $container (exit code: $docker_exit_code)"
			failed_containers+=("$container")
			exit_code=1
		fi
	done
	
	# Report final status
	if [[ $exit_code -eq 0 ]]; then
		log_info "All containers successfully ${action}ed"
	else
		log_error "Failed to $action containers: ${failed_containers[*]}"
		log_error "Script must stop due to container management failure"
	fi
	
	return $exit_code
}
