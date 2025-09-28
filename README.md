# Simple-Backups

A comprehensive, modular bash-based backup system designed for Docker-based homelab environments. This project provides robust backup capabilities with proper error handling, logging, and container management.

## 🚀 Features

- **Modular Architecture**: Easily extensible with new backup targets and integrations
- **Docker Integration**: Safe container stop/start procedures during backups
- **Database Dumps**: Automated database backups for supported services
- **Robust Error Handling**: Comprehensive error checking with retry mechanisms
- **Comprehensive Logging**: Detailed logs with timestamps for monitoring and debugging
- **Remote Sync**: Uses rsync over SSH for efficient file transfers
- **Container Management**: Intelligent Docker container lifecycle management
- **Extensible Integrations**: Built-in support for monitoring and automation systems

## 📋 Prerequisites

- **Bash 4.0+**: For advanced array handling and error management
- **Docker**: For container management
- **rsync**: For file synchronization
- **SSH**: For secure remote connectivity with key-based authentication
- **Linux/Unix environment**: Tested on Ubuntu/Debian systems

## 🛠️ Quick Setup

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd Simple-Backups
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   nano .env  # Edit with your configuration
   ```

3. **Test configuration:**
   ```bash
   # Test environment variables
   bash core/verify_config.sh
   
   # Test remote connectivity
   bash core/verify_remote.sh
   ```

4. **Run backup:**
   ```bash
   ./local_backup.sh
   ```

## ⚙️ Configuration

### Environment Variables (`.env` file)

```bash
# Database Configuration
NEXTCLOUD_DB_USER=nextcloud
NEXTCLOUD_DB_PASSWORD=your_secure_password
NEXTCLOUD_DB_NAME=nextcloud

# Remote Backup Configuration
REMOTE_USER=backup_user
REMOTE_HOST=backup.server.com
REMOTE_BASE_DIR=/backups/homelab
REMOTE_STORAGE_LOCATION=/backups/homelab

# Local Configuration
DUMP_DIR=/tmp/db_dumps
TEMP_DIR=/tmp/simple_backups
```

### SSH Setup

Ensure SSH key-based authentication is configured:
```bash
ssh-keygen -t ed25519 -C "backup@yourdomain.com"
ssh-copy-id backup_user@backup.server.com
```

## 🏗️ Architecture

### Core Modules (`core/`)
- **`logging.sh`**: Centralized logging system
- **`rsync.sh`**: File synchronization with retry logic
- **`container.sh`**: Docker container management
- **`verify_config.sh`**: Configuration validation
- **`verify_remote.sh`**: Remote connectivity testing
- **`setup.sh`**: Environment setup functions

### Backup Workflow (`outline/`)
- **`pre_backup.sh`**: Pre-backup validation and setup
- **`backup_items.sh`**: Main backup logic and service-specific backups
- **`post_backup.sh`**: Post-backup cleanup and integrations

### Integrations (`integrations/`)
- **`uptime_kuma.sh`**: Monitoring notifications
- **`ha_control.sh`**: Home Assistant automation control
- **`tailscale.sh`**: VPN management

## 📦 Supported Services

### Fully Supported (with database dumps)
- **Nextcloud**: Files, config, themes, database
- **Immich**: Media library, database
- **Paperless**: Documents, database
- **Karakeep**: Data and search indices

### File-Only Backups
- **Home Assistant**: Configuration and backups
- **ESPHome**: Device configurations
- **Crafty**: Minecraft server backups

## 🔄 Backup Workflow

1. **Pre-backup Phase:**
   - Validate configuration
   - Test remote connectivity
   - Run integration hooks

2. **Database Dumps:**
   - Create timestamped database dumps
   - Store in temporary directory

3. **Service Backups:**
   - Enable maintenance modes where applicable
   - Stop containers safely
   - Sync data directories
   - Restart containers
   - Disable maintenance modes

4. **Post-backup Phase:**
   - Clean up temporary files
   - Restore any failed states
   - Run monitoring integrations

## 📊 Monitoring and Logging

### Log Files
- Location: `logs/local_backup/YYYYMMDD_HHMMSS.log`
- Format: `[YYYY-MM-DD HH:MM:SS] LEVEL: message`
- Retention: Manual cleanup required

### Integration Points
- **Uptime Kuma**: Backup status notifications
- **Home Assistant**: Automation pause/resume
- **Custom webhooks**: Extensible notification system

## 🚨 Error Handling

- **Strict Mode**: `set -euo pipefail` throughout
- **Retry Logic**: Network operations retry up to 5 times
- **Graceful Degradation**: Services continue if non-critical components fail
- **Safe Cleanup**: Always attempts to restore original state

## 🔧 Customization

### Adding New Backup Targets

1. **Add to `backup_items.sh`:**
   ```bash
   # Your Service backup
   log_info "Stopping YourService containers..."
   if manage_containers "stop" yourservice-container; then
       sync_dir "/path/to/yourservice/" "$REMOTE_BASE_DIR/yourservice" "YourService"
       manage_containers "start" yourservice-container
   else
       log_warning "Failed to stop YourService containers, skipping backup"
   fi
   ```

2. **Add database dump (if applicable):**
   ```bash
   # In create_db_dumps function
   if docker exec yourservice-db pg_dump -U user dbname > "$DUMP_DIR/yourservice.sql"; then
       log_info "YourService database dump completed"
   fi
   ```

### Creating New Integrations

1. **Create integration file:**
   ```bash
   # integrations/yourservice.sh
   #!/bin/bash
   set -euo pipefail
   
   your_integration_function() {
       log_info "Running your integration..."
       # Your integration logic here
   }
   ```

2. **Hook into workflow:**
   ```bash
   # In pre_backup.sh or post_backup.sh
   source "$SCRIPT_DIR/integrations/yourservice.sh"
   your_integration_function
   ```

## 🔐 Security Considerations

- **SSH Keys**: Use key-based authentication only
- **Environment Variables**: Store sensitive data in `.env` file
- **File Permissions**: Ensure `.env` file is readable only by backup user
- **Network Security**: Consider using VPN for remote backups
- **Container Security**: Backup processes run with minimal required permissions

## 📈 Performance Optimization

### Rsync Options
```bash
RSYNC_OPTS="-a --partial --append-verify --timeout=14400 --delete-delay --compress-level=0 --no-perms --no-owner --no-group --links --inplace --no-whole-file --block-size=8192"
```

### SSH Optimization
```bash
SSH_OPTS="ssh -o ConnectTimeout=30 -o ServerAliveInterval=60 -o Compression=no -c aes128-ctr -T -x"
```

## 🐛 Troubleshooting

### Common Issues

1. **Permission Denied:**
   ```bash
   # Ensure SSH keys are properly configured
   ssh-add ~/.ssh/id_ed25519
   ```

2. **Container Not Found:**
   ```bash
   # Check container names
   docker ps -a --format "table {{.Names}}\t{{.Status}}"
   ```

3. **Database Connection Failed:**
   ```bash
   # Verify database credentials in .env
   docker exec -it nextcloud-db mysql -u $NEXTCLOUD_DB_USER -p
   ```

### Debug Mode

Enable verbose logging:
```bash
set -x  # Add to script for debug output
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Test thoroughly in isolated environment
4. Submit pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for homelab enthusiasts
- Inspired by the need for reliable, automated backups
- Community-driven improvements and feedback