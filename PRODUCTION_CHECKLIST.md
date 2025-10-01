# Production Readiness Checklist

## ✅ Pre-Deployment Verification

### Configuration
- [ ] `.env` file properly configured with production values
- [ ] SSH key-based authentication set up and tested
- [ ] Remote backup server accessible and configured
- [ ] Database credentials verified and tested
- [ ] Docker containers names match configuration

### Security
- [ ] `.env` file permissions set to 600 (`chmod 600 .env`)
- [ ] SSH keys have proper permissions (600 for private, 644 for public)
- [ ] Backup server has dedicated backup user with limited privileges
- [ ] Network connectivity secured (VPN recommended for remote backups)

### Testing
- [ ] Run `./setup.sh` successfully
- [ ] Verify configuration: `bash core/verify_config.sh`
- [ ] Test remote connectivity: `bash core/verify_remote.sh` 
- [ ] Test database connections manually
- [ ] Verify all Docker containers exist and are accessible
- [ ] Run a test backup in non-production environment

### Monitoring
- [ ] Log rotation configured or manual cleanup process established
- [ ] Monitoring integrations configured (Uptime Kuma, etc.)
- [ ] Backup success/failure notification system working
- [ ] Disk space monitoring on both source and destination

### Documentation
- [ ] Backup schedule documented
- [ ] Recovery procedures documented
- [ ] Emergency contact information available
- [ ] Service dependencies and critical paths identified

## ⚠️ Known Limitations & Considerations

### Performance
- Large file transfers may take significant time
- Container downtime during backup (minimal but present)
- Network bandwidth requirements for remote sync

### Dependencies
- Requires Docker containers to be named exactly as configured
- SSH connectivity must be reliable
- Sufficient disk space on backup destination

### Recovery
- Full restore procedures should be tested periodically
- Database restore procedures should be documented
- Container recreation steps should be available

## 🚨 Emergency Procedures

### If Backup Fails
1. Check logs in `logs/local_backup/` directory
2. Verify network connectivity to backup server
3. Check container status: `docker ps -a`
4. Verify disk space on both source and destination
5. Run cleanup manually if needed: `bash outline/post_backup.sh`

### If Containers Don't Restart
```bash
# Manual container restart commands
docker start nextcloud-app nextcloud-db
docker start immich_machine_learning immich_postgres immich_redis immich_server
docker start paperless-broker paperless-db paperless-webserver paperless-gotenberg paperless-tika
docker start karakeep-chrome karakeep-meilisearch karakeep-web
docker start esphome
```

### If Maintenance Mode Stuck
```bash
# Disable Nextcloud maintenance mode
docker exec nextcloud-app php occ maintenance:mode --off
```

## 📅 Maintenance Tasks

### Daily
- [ ] Monitor backup completion status
- [ ] Check available disk space

### Weekly  
- [ ] Review backup logs for errors or warnings
- [ ] Verify backup file integrity on remote server

### Monthly
- [ ] Test backup restoration process
- [ ] Clean up old log files
- [ ] Update backup documentation if services change

### Quarterly
- [ ] Review and update SSH keys if needed
- [ ] Test emergency recovery procedures
- [ ] Review backup retention policies
- [ ] Performance optimization review

## 🔧 Production Optimization

### Performance Tuning
```bash
# Rsync performance options (already optimized)
RSYNC_OPTS="-a --partial --append-verify --timeout=14400 --delete-delay --compress-level=0"

# SSH connection optimization (already configured)  
SSH_OPTS="ssh -o ConnectTimeout=30 -o ServerAliveInterval=60 -o Compression=no -c aes128-ctr"
```

### Resource Management
- Consider backup scheduling during low-usage periods
- Monitor system resources during backup operations
- Implement backup retention policies on remote server

### Automation
- Set up cron job for automated backups
- Configure log rotation
- Implement backup verification scripts