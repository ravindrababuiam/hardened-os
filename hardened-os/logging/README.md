# Tamper-Evident Logging System

This directory contains the complete implementation of a tamper-evident logging system with cryptographic integrity verification for the hardened laptop OS.

## Overview

The logging system provides:

- **Cryptographic Signing**: All journal entries are cryptographically signed using systemd's sealing feature
- **Integrity Verification**: Regular automated checks detect log tampering
- **Secure Remote Forwarding**: Logs are forwarded to a secure remote server with TLS and client certificates
- **Comprehensive Auditing**: Detailed audit rules capture security-relevant events
- **Automated Monitoring**: Continuous monitoring with alerting on integrity violations
- **Tamper Detection**: Hash chains and signature verification detect unauthorized modifications

## Components

### Core Files

- `install-logging-system.sh` - Main installation script
- `setup-journal-signing.sh` - Journal signing configuration
- `systemd-journal-sign.service` - Systemd service for journal signing
- `journal-upload.conf` - Configuration for secure log forwarding
- `audit-rules.conf` - Comprehensive audit rules
- `log-server-config.py` - Secure remote log server implementation

### Key Features

#### 1. Journal Signing and Sealing
- Uses systemd's Forward Secure Sealing (FSS) for tamper-evident logs
- Cryptographic signatures prevent undetected log modification
- Automatic key rotation and secure key storage

#### 2. Comprehensive Audit Rules
- Authentication and authorization events
- File system modifications
- Network configuration changes
- Kernel module loading/unloading
- Privileged command execution
- SELinux policy violations
- TPM and cryptographic operations

#### 3. Secure Remote Logging
- TLS-encrypted log forwarding
- Client certificate authentication
- Signature verification at the server
- Integrity database with hash chains
- Tamper detection and alerting

#### 4. Automated Monitoring
- Hourly integrity verification
- Real-time tamper detection
- Email and syslog alerting
- Security event analysis tools

## Installation

### Quick Installation

```bash
# Make installation script executable
chmod +x install-logging-system.sh

# Run installation (requires root)
sudo ./install-logging-system.sh
```

### Manual Installation

1. **Install Dependencies**:
   ```bash
   apt-get update
   apt-get install -y systemd auditd openssl python3 python3-pip
   pip3 install aiohttp aiofiles cryptography
   ```

2. **Configure Journal Signing**:
   ```bash
   ./setup-journal-signing.sh
   ```

3. **Set up Remote Logging**:
   ```bash
   # Configure certificates (see Certificate Setup section)
   systemctl enable systemd-journal-upload
   systemctl start systemd-journal-upload
   ```

4. **Start Log Server**:
   ```bash
   systemctl enable hardened-log-server
   systemctl start hardened-log-server
   ```

## Certificate Setup

### For Log Server

```bash
# Generate server certificate
openssl genpkey -algorithm RSA -out /etc/ssl/private/log-server.key -pkeyopt rsa_keygen_bits:4096
openssl req -new -key /etc/ssl/private/log-server.key -out /tmp/log-server.csr \
    -subj "/C=US/ST=Security/L=Hardened/O=HardenedOS/OU=Logging/CN=log-server.local"
openssl x509 -req -in /tmp/log-server.csr -signkey /etc/ssl/private/log-server.key \
    -out /etc/ssl/certs/log-server.crt -days 365
```

### For Client Authentication

```bash
# Generate client certificate (done automatically by setup script)
openssl genpkey -algorithm RSA -out /etc/ssl/private/journal-upload.key -pkeyopt rsa_keygen_bits:4096
openssl req -new -key /etc/ssl/private/journal-upload.key -out /tmp/journal-upload.csr \
    -subj "/C=US/ST=Security/L=Hardened/O=HardenedOS/OU=Logging/CN=journal-client"
openssl x509 -req -in /tmp/journal-upload.csr -signkey /etc/ssl/private/journal-upload.key \
    -out /etc/ssl/certs/journal-upload.crt -days 365
```

## Usage

### Verify Log Integrity

```bash
# Verify all journal files
journalctl --verify

# Verify specific journal file
journalctl --verify --file=/var/log/journal/machine-id/system.journal

# Run integrity check script
/usr/local/bin/verify-journal-integrity
```

### Analyze Security Events

```bash
# Analyze recent security events
/usr/local/bin/analyze-security-events

# Analyze events from specific timeframe
/usr/local/bin/analyze-security-events 24h
```

### Monitor Log Integrity

```bash
# Manual integrity monitoring
/usr/local/bin/monitor-log-integrity

# Check monitoring service status
systemctl status log-integrity-monitor.timer
```

### Query Audit Logs

```bash
# Search for authentication failures
ausearch -m USER_LOGIN -sv no

# Search for privilege escalation
ausearch -k privileged

# Search for file modifications
ausearch -k identity
```

## Configuration

### Journal Configuration

Edit `/etc/systemd/journald.conf.d/99-hardened-signing.conf`:

```ini
[Journal]
Seal=yes
Storage=persistent
Compress=yes
SystemMaxUse=1G
MaxRetentionSec=30d
SyncIntervalSec=5m
```

### Audit Configuration

Edit `/etc/audit/rules.d/99-hardened-os.rules` to customize audit rules.

### Log Server Configuration

Edit `/etc/log-server/config.json`:

```json
{
    "host": "0.0.0.0",
    "port": 8443,
    "storage_path": "/var/log/remote",
    "cert_file": "/etc/ssl/certs/log-server.crt",
    "key_file": "/etc/ssl/private/log-server.key",
    "ca_file": "/etc/ssl/certs/ca.crt",
    "max_log_size": 104857600,
    "retention_days": 90
}
```

## Monitoring and Alerting

### Service Status

```bash
# Check all logging services
systemctl status systemd-journald auditd hardened-log-server
systemctl status journal-integrity-check.timer log-integrity-monitor.timer
```

### Log Files

- Journal integrity: `/var/log/journal-verification.log`
- Monitoring alerts: `/var/log/log-integrity-monitor.log`
- Audit logs: `/var/log/audit/audit.log`
- Remote logs: `/var/log/remote/`

### Alerts

Configure email alerts by setting the `ALERT_EMAIL` environment variable:

```bash
export ALERT_EMAIL="security@example.com"
```

## Troubleshooting

### Common Issues

1. **Journal Verification Fails**:
   - Check if sealing is enabled: `journalctl --verify`
   - Verify journal permissions: `ls -la /var/log/journal/`
   - Check systemd-journald status: `systemctl status systemd-journald`

2. **Audit Rules Not Loading**:
   - Check audit status: `auditctl -s`
   - Verify rules syntax: `auditctl -l`
   - Check auditd logs: `journalctl -u auditd`

3. **Remote Logging Fails**:
   - Verify certificates: `openssl x509 -in /etc/ssl/certs/journal-upload.crt -text -noout`
   - Check network connectivity: `curl -k https://log-server:8443/`
   - Review upload logs: `journalctl -u systemd-journal-upload`

4. **Log Server Issues**:
   - Check server logs: `journalctl -u hardened-log-server`
   - Verify port binding: `netstat -tlnp | grep 8443`
   - Test certificate: `openssl s_client -connect localhost:8443`

### Performance Tuning

- Adjust journal size limits in `/etc/systemd/journald.conf.d/99-hardened-signing.conf`
- Tune audit buffer size in `/etc/audit/auditd.conf`
- Configure log rotation frequency in `/etc/logrotate.d/`

## Security Considerations

1. **Key Protection**: Journal signing keys are stored in `/etc/systemd/journal-sign/` with restricted permissions
2. **Certificate Security**: Use proper CA-signed certificates in production
3. **Network Security**: Log server uses TLS with client certificate authentication
4. **Access Control**: Log files have appropriate permissions and SELinux contexts
5. **Retention Policy**: Logs are retained according to compliance requirements

## Integration with Requirements

This implementation satisfies the following requirements:

- **14.1**: Cryptographically signed and tamper-evident logs
- **14.2**: Detailed logging of security events for forensic analysis
- **14.3**: Secure remote storage with integrity verification
- **14.4**: Opt-in telemetry with privacy preservation
- **14.5**: Tamper detection with alerting and compromise recording

## Future Enhancements

- Integration with SIEM systems
- Machine learning-based anomaly detection
- Blockchain-based log integrity verification
- Advanced forensic analysis tools
- Real-time log streaming and analysis