# Incident Response and Recovery System

This directory contains a comprehensive incident response and recovery system for the hardened laptop OS, providing automated threat detection, containment, forensic analysis, and system recovery capabilities.

## Overview

The incident response system provides:

- **Automated Threat Detection**: Continuous monitoring for rootkits, intrusions, and malware
- **Threat Containment**: Automated isolation and quarantine of detected threats
- **Forensic Analysis**: Evidence collection and system state preservation
- **System Recovery**: Automated recovery procedures with multiple restore modes
- **Key Management**: Cryptographic key rotation and compromise response
- **Emergency Response**: Rapid system lockdown and security procedures

## Components

### Core Scripts

- **`incident-response-framework.sh`** - Main incident detection and response system
- **`recovery-procedures.sh`** - System recovery and backup management
- **`key-rotation-procedures.sh`** - Cryptographic key rotation and management
- **`install-incident-response.sh`** - Complete system installation script

### Emergency Tools

- **`emergency-lockdown`** - Immediate system isolation and lockdown
- **`system-health-check`** - Quick system health assessment
- **`collect-forensics`** - Forensic evidence collection

## Installation

### Quick Installation

```bash
# Make installation script executable
chmod +x install-incident-response.sh

# Run installation (requires root)
sudo ./install-incident-response.sh
```

### Manual Installation Steps

1. **Install Dependencies**:
   ```bash
   apt-get update
   apt-get install -y systemd openssl cryptsetup openssh-server auditd bc jq
   ```

2. **Install Framework**:
   ```bash
   ./install-incident-response.sh
   ```

3. **Configure Settings**:
   ```bash
   # Edit configuration files
   nano /etc/hardened-os/incident-response.conf
   nano /etc/hardened-os/recovery.conf
   nano /etc/hardened-os/key-rotation.conf
   ```

## Usage

### Incident Response

#### Run Security Scans
```bash
# Full security scan
incident-response scan all

# Specific threat detection
incident-response scan rootkit
incident-response scan intrusion
incident-response scan malware

# Check system status
incident-response status
```

#### Manual Threat Containment
```bash
# Contain specific threat
incident-response contain malware "Suspicious process detected"

# Create forensic snapshot
incident-response snapshot manual "Security investigation"
```

### System Recovery

#### Create Recovery Points
```bash
# Create manual recovery point
recovery-procedures create "Pre-maintenance backup"

# List available recovery points
recovery-procedures list
```

#### System Restore
```bash
# Safe restore (configuration only)
recovery-procedures restore /var/recovery-points/recovery_20240826_143022 safe

# Full system restore
recovery-procedures restore /var/recovery-points/recovery_20240826_143022 full

# Forensic analysis mode
recovery-procedures restore /var/recovery-points/recovery_20240826_143022 forensic
```

#### Emergency Recovery
```bash
# Emergency system lockdown and recovery
recovery-procedures emergency

# Check recovery system status
recovery-procedures status
```

### Key Management

#### Key Rotation
```bash
# Check key expiration status
key-rotation check

# Rotate specific key types
key-rotation rotate ssh
key-rotation rotate tls
key-rotation rotate secure-boot
key-rotation rotate luks

# Rotate all keys
key-rotation rotate all
```

#### Emergency Key Revocation
```bash
# Revoke compromised keys
key-rotation revoke ssh compromise
key-rotation revoke tls "Certificate authority breach"

# Check key management status
key-rotation status
```

### Emergency Response

#### Immediate Response Commands
```bash
# Emergency system lockdown
emergency-lockdown

# Quick health check
system-health-check

# Collect forensic evidence
collect-forensics
```

## Configuration

### Incident Response Configuration
Edit `/etc/hardened-os/incident-response.conf`:

```bash
# Alert settings
ALERT_EMAIL="security@example.com"
ALERT_WEBHOOK="https://alerts.example.com/webhook"

# Automated response settings
AUTO_CONTAINMENT="true"
AUTO_RECOVERY="false"
FORENSIC_MODE="false"
```

### Recovery Configuration
Edit `/etc/hardened-os/recovery.conf`:

```bash
# Backup settings
BACKUP_RETENTION_DAYS="30"
AUTO_BACKUP_ENABLED="true"
RECOVERY_VERIFICATION="true"
FORENSIC_PRESERVATION="true"
```

### Key Rotation Configuration
Edit `/etc/hardened-os/key-rotation.conf`:

```bash
# Rotation settings
KEY_ROTATION_INTERVAL_DAYS="90"
EMERGENCY_ROTATION_ENABLED="true"
KEY_BACKUP_RETENTION_DAYS="365"
REQUIRE_CONFIRMATION="true"

# HSM settings (if available)
HSM_ENABLED="false"
HSM_SLOT="0"
```

## Automated Monitoring

The system includes automated monitoring services:

### Security Monitoring
- **Service**: `hardened-os-monitor.timer`
- **Frequency**: Every 15 minutes
- **Function**: Continuous threat detection and alerting

### Recovery Point Creation
- **Service**: `recovery-point-create.timer`
- **Frequency**: Daily
- **Function**: Automated system backup creation

### Key Expiration Monitoring
- **Service**: `key-expiration-check.timer`
- **Frequency**: Weekly
- **Function**: Monitor and alert on key expiration

### Service Management
```bash
# Check service status
systemctl status hardened-os-monitor.timer
systemctl status recovery-point-create.timer
systemctl status key-expiration-check.timer

# View service logs
journalctl -u hardened-os-monitor.service -f
journalctl -u recovery-point-create.service -f
journalctl -u key-expiration-check.service -f
```

## Threat Detection Capabilities

### Rootkit Detection
- SUID binary analysis
- Kernel module verification
- Network connection monitoring
- File system integrity checks

### Intrusion Detection
- Failed authentication monitoring
- Privilege escalation detection
- SELinux violation analysis
- Network activity analysis

### Malware Detection
- Process behavior analysis
- Suspicious file detection
- CPU usage pattern analysis
- Temporary file monitoring

## Recovery Modes

### Safe Mode
- Restores configuration files only
- Minimal system impact
- Preserves current system state
- Recommended for most scenarios

### Full Mode
- Complete system restoration
- Includes services and network configuration
- May require system restart
- Use for major system corruption

### Forensic Mode
- Read-only analysis and comparison
- Preserves evidence integrity
- Generates detailed reports
- Use for security investigations

## Key Management Features

### Supported Key Types
- **Secure Boot Keys**: UEFI Platform Keys (PK), Key Exchange Keys (KEK), Database Keys (DB)
- **LUKS Keys**: Disk encryption passphrases and keyfiles
- **SSH Keys**: Host keys for SSH server
- **TLS Certificates**: SSL/TLS certificates for services

### Key Rotation Process
1. **Backup Creation**: Secure backup of current keys
2. **New Key Generation**: Cryptographically secure key generation
3. **Service Integration**: Automatic service configuration updates
4. **Verification**: Key functionality testing
5. **Cleanup**: Secure disposal of old keys

## Forensic Capabilities

### Evidence Collection
- System state snapshots
- Process and network information
- Log file preservation
- File system analysis
- Memory dumps (where applicable)

### Chain of Custody
- Cryptographic integrity verification
- Timestamp preservation
- Access logging
- Secure storage

### Analysis Tools
- Configuration comparison
- Timeline reconstruction
- Anomaly detection
- Report generation

## Security Considerations

### Access Control
- Root privileges required for most operations
- Secure file permissions (600/700)
- SELinux integration
- Audit trail logging

### Data Protection
- Encrypted backup storage
- Secure key handling
- Memory clearing after operations
- Secure deletion of temporary files

### Network Security
- Isolated containment procedures
- Secure alert transmission
- Certificate-based authentication
- Network segmentation support

## Troubleshooting

### Common Issues

1. **Service Not Starting**:
   ```bash
   # Check service status
   systemctl status hardened-os-monitor.service
   
   # Check logs
   journalctl -u hardened-os-monitor.service --since "1 hour ago"
   
   # Restart service
   systemctl restart hardened-os-monitor.service
   ```

2. **Recovery Point Creation Fails**:
   ```bash
   # Check disk space
   df -h /var/recovery-points
   
   # Check permissions
   ls -la /var/recovery-points
   
   # Manual recovery point creation
   recovery-procedures create "Manual test"
   ```

3. **Key Rotation Issues**:
   ```bash
   # Check key status
   key-rotation status
   
   # Verify key files
   ls -la /etc/ssh/ssh_host_*
   
   # Test key functionality
   ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub
   ```

### Log Files
- **Incident Response**: `/var/log/incident-response.log`
- **Recovery Operations**: `/var/log/recovery.log`
- **Key Management**: `/var/log/key-rotation.log`
- **System Logs**: `journalctl -u hardened-os-monitor.service`

### Performance Tuning
- Adjust scan frequency in systemd timers
- Configure alert thresholds in configuration files
- Optimize backup retention policies
- Tune forensic collection scope

## Integration with Requirements

This implementation satisfies the following requirements:

- **11.1**: Documented incident response procedures with automated scripts
- **11.2**: Automated recovery scripts and recovery partition support
- **11.3**: Key rotation procedures with automated and manual options
- **11.4**: Secure logging and audit trails for all operations
- **12.3**: Key rotation procedures that don't require system reinstallation
- **12.4**: Key revocation through secure channels and procedures

## Advanced Features

### HSM Integration
- Hardware Security Module support for production keys
- Secure key generation and storage
- Tamper-evident key operations

### Remote Attestation
- TPM-based system integrity verification
- Remote system health reporting
- Automated compliance checking

### Threat Intelligence
- Integration with threat intelligence feeds
- Automated indicator of compromise (IoC) checking
- Behavioral analysis and anomaly detection

## Future Enhancements

- Machine learning-based threat detection
- Integration with SIEM systems
- Automated patch management
- Cloud-based backup and recovery
- Mobile device management integration