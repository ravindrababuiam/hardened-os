# Hardened Laptop OS - User Guide

This guide provides comprehensive instructions for daily operation, security features, and maintenance of your Hardened Laptop OS.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Daily Operations](#daily-operations)
3. [Security Features](#security-features)
4. [Application Management](#application-management)
5. [System Maintenance](#system-maintenance)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Features](#advanced-features)
8. [Best Practices](#best-practices)

## Getting Started

### First Boot Experience

#### 1. System Startup
```
1. Power on the system
2. TPM will automatically unseal disk encryption keys
3. If TPM unsealing fails, enter backup passphrase
4. System will boot to login screen
```

#### 2. Initial Login
```
Username: [your-username]
Password: [your-password]
```

#### 3. Desktop Environment
The system boots to a minimal, hardened desktop environment with:
- Secure application launcher
- System status indicators
- Security monitoring dashboard
- Quick access to security tools

### Understanding Your Security Status

#### Security Dashboard
Access the security dashboard from the system tray:
```
Security Status:
✓ Secure Boot: Active
✓ TPM: Operational
✓ Disk Encryption: Active
✓ SELinux: Enforcing
✓ Firewall: Active
✓ Monitoring: Running
```

#### Quick Security Check
```bash
# Run comprehensive security status check
system-health-check

# View recent security events
incident-response status

# Check system integrity
sudo aide --check
```

## Daily Operations

### Secure Application Usage

#### Web Browsing
```bash
# Launch sandboxed browser
secure-browser

# Browser runs with:
# - Network access restricted to HTTP/HTTPS
# - Filesystem access limited to Downloads
# - No access to system files or other applications
# - Automatic security updates
```

#### Office Applications
```bash
# Launch sandboxed office suite
secure-office

# Office applications run with:
# - Access only to Documents folder
# - No network access by default
# - Isolated from other applications
# - Document encryption support
```

#### Development Tools
```bash
# Launch development environment
secure-dev-env

# Development tools run with:
# - Isolated project directories
# - Controlled network access
# - Separate from personal data
# - Version control integration
```

### File Management

#### Secure File Operations
```bash
# Encrypted file storage
secure-files create encrypted-folder
secure-files mount encrypted-folder
secure-files unmount encrypted-folder

# Secure file deletion
secure-delete sensitive-file.txt

# File integrity verification
verify-file-integrity document.pdf
```

#### Backup and Sync
```bash
# Create encrypted backup
secure-backup create ~/Documents backup-device

# Sync with encrypted cloud storage
secure-sync setup provider-name
secure-sync sync ~/Documents
```

### Network Operations

#### Secure Networking
```bash
# Connect to VPN
secure-vpn connect work-vpn

# Check network security status
network-security-status

# Monitor network connections
network-monitor
```

#### DNS Security
```bash
# Configure secure DNS
sudo configure-dns --provider cloudflare --doh

# Check DNS security status
dns-security-check

# Flush DNS cache
sudo flush-dns-cache
```

### System Updates

#### Automatic Updates
The system automatically:
- Downloads security updates
- Verifies cryptographic signatures
- Stages updates for next reboot
- Creates recovery points before applying

#### Manual Update Process
```bash
# Check for updates
sudo system-update check

# Download and verify updates
sudo system-update download

# Apply updates (requires reboot)
sudo system-update apply

# Rollback if needed
sudo system-update rollback
```

## Security Features

### Threat Detection and Response

#### Real-time Monitoring
The system continuously monitors for:
- Rootkit infections
- Unauthorized privilege escalation
- Suspicious network activity
- File system modifications
- Malware behavior patterns

#### Automated Response
When threats are detected:
```
1. Immediate containment (network isolation)
2. Process termination
3. Forensic evidence collection
4. User notification
5. Recovery point creation
```

#### Manual Security Scans
```bash
# Full system security scan
incident-response scan all

# Specific threat detection
incident-response scan rootkit
incident-response scan intrusion
incident-response scan malware

# View scan results
incident-response status
```

### Application Sandboxing

#### Sandbox Profiles
Each application type has a security profile:

**Browser Profile:**
- Network: HTTP/HTTPS only
- Filesystem: Downloads folder only
- System: No system file access
- Hardware: Camera/microphone with permission

**Office Profile:**
- Network: None by default
- Filesystem: Documents folder only
- System: No system access
- Hardware: Printer access only

**Media Profile:**
- Network: None
- Filesystem: Media folders (read-only)
- System: No system access
- Hardware: Audio/video output only

#### Managing Sandbox Permissions
```bash
# View application permissions
sandbox-manager list-permissions firefox

# Grant additional permissions
sandbox-manager grant-permission firefox network

# Revoke permissions
sandbox-manager revoke-permission firefox camera

# Create custom profile
sandbox-manager create-profile custom-app
```

### Cryptographic Key Management

#### Key Status Monitoring
```bash
# Check all key expiration status
key-rotation check

# View key details
key-rotation status

# List key backups
ls -la /var/backups/keys/
```

#### Manual Key Rotation
```bash
# Rotate specific key types
sudo key-rotation rotate ssh
sudo key-rotation rotate tls
sudo key-rotation rotate secure-boot

# Emergency key revocation
sudo key-rotation revoke ssh "Suspected compromise"
```

### System Recovery

#### Recovery Points
```bash
# List available recovery points
recovery-procedures list

# Create manual recovery point
sudo recovery-procedures create "Before major changes"

# Restore from recovery point (safe mode)
sudo recovery-procedures restore /var/recovery-points/recovery_20240826_143022 safe
```

#### Emergency Procedures
```bash
# Emergency system lockdown
sudo emergency-lockdown

# Collect forensic evidence
sudo collect-forensics

# Emergency recovery mode
sudo recovery-procedures emergency
```

## Application Management

### Installing Applications

#### Verified Application Installation
```bash
# Install from verified repositories only
sudo secure-install package-name

# Verify package signatures
sudo verify-package package-name

# Install with automatic sandboxing
sudo secure-install --sandbox package-name
```

#### Application Verification
```bash
# Verify installed applications
sudo verify-installed-apps

# Check application integrity
sudo check-app-integrity firefox

# Scan for malicious applications
sudo scan-applications
```

### Application Security Profiles

#### Default Security Profiles

**High Security (Default):**
- Minimal system access
- No network access unless required
- Isolated filesystem access
- Hardware access by permission only

**Medium Security:**
- Limited system access
- Restricted network access
- Broader filesystem access
- Standard hardware access

**Development Mode:**
- Extended system access for development
- Full network access
- Broader filesystem access
- Development tool integration

#### Customizing Security Profiles
```bash
# Create custom profile
sudo sandbox-manager create-profile my-app \
  --network restricted \
  --filesystem ~/Projects \
  --no-system-access

# Apply profile to application
sudo sandbox-manager apply-profile my-app custom-profile

# Test profile
sandbox-manager test-profile my-app
```

### Application Updates

#### Automatic Security Updates
Applications receive automatic security updates:
- Cryptographic signature verification
- Sandbox compatibility testing
- Rollback capability
- Security impact assessment

#### Manual Application Updates
```bash
# Update specific application
sudo secure-update firefox

# Update all applications
sudo secure-update --all

# Check update status
secure-update status
```

## System Maintenance

### Regular Maintenance Tasks

#### Daily Tasks (Automated)
- Security monitoring scans
- Log integrity verification
- System health checks
- Threat intelligence updates

#### Weekly Tasks
```bash
# System integrity check
sudo aide --check

# Security log review
sudo analyze-security-events 7d

# Key expiration check
key-rotation check

# Performance monitoring
system-performance-check
```

#### Monthly Tasks
```bash
# Full system security audit
sudo security-audit --comprehensive

# Recovery point cleanup
sudo recovery-procedures cleanup 30

# Key backup verification
sudo verify-key-backups

# Update security policies
sudo update-security-policies
```

### Log Management

#### Viewing Security Logs
```bash
# Recent security events
journalctl -u hardened-os-monitor --since "24 hours ago"

# Audit logs
sudo ausearch -ts recent

# Incident response logs
sudo tail -f /var/log/incident-response.log

# System integrity logs
sudo tail -f /var/log/aide/aide.log
```

#### Log Analysis
```bash
# Analyze security events
analyze-security-events 24h

# Generate security report
generate-security-report --period weekly

# Export logs for analysis
export-security-logs --format json --output security-data.json
```

### Performance Monitoring

#### System Performance
```bash
# Current system status
system-status

# Performance metrics
performance-monitor --realtime

# Resource usage by security components
security-overhead-monitor
```

#### Security Performance Impact
```bash
# Measure security overhead
measure-security-overhead

# Optimize security settings
optimize-security-performance

# Performance tuning recommendations
security-performance-advisor
```

## Troubleshooting

### Common Issues

#### 1. TPM Unsealing Failures
```bash
# Symptoms: Boot requires manual passphrase entry
# Causes: Hardware changes, BIOS updates, kernel updates

# Diagnosis:
sudo tpm2_getcap properties-fixed
sudo systemd-cryptenroll --list /dev/sda3

# Resolution:
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/sda3
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+4+7 /dev/sda3
```

#### 2. Application Sandbox Issues
```bash
# Symptoms: Application won't start or missing functionality
# Causes: Restrictive sandbox profile, missing permissions

# Diagnosis:
sandbox-manager diagnose application-name

# Resolution:
sandbox-manager grant-permission application-name required-permission
# or
sandbox-manager apply-profile application-name less-restrictive-profile
```

#### 3. Network Connectivity Issues
```bash
# Symptoms: No network access or blocked connections
# Causes: Firewall rules, DNS filtering, VPN issues

# Diagnosis:
network-diagnose

# Resolution:
sudo ufw status
sudo systemctl status systemd-resolved
sudo vpn-diagnose
```

#### 4. Performance Issues
```bash
# Symptoms: Slow system performance
# Causes: Security overhead, resource constraints

# Diagnosis:
performance-diagnose

# Resolution:
optimize-security-performance
# or adjust security profiles for better performance
```

### Recovery Procedures

#### System Won't Boot
```bash
# Boot from recovery USB
# Mount encrypted system
sudo cryptsetup luksOpen /dev/sda3 sda3_crypt
sudo mount /dev/mapper/vg-hardened-root /mnt

# Check for issues
sudo chroot /mnt
journalctl -xe

# Restore from recovery point
sudo recovery-procedures restore /var/recovery-points/latest safe
```

#### Forgotten Passwords
```bash
# Boot from recovery USB
# Reset user password
sudo chroot /mnt
passwd username

# Reset LUKS passphrase (requires current passphrase)
sudo cryptsetup luksChangeKey /dev/sda3
```

#### Corrupted System Files
```bash
# Check file system integrity
sudo fsck /dev/mapper/vg-hardened-root

# Restore from recovery point
sudo recovery-procedures restore /var/recovery-points/recovery_date forensic

# Reinstall system packages
sudo apt install --reinstall systemd
```

## Advanced Features

### Remote Attestation

#### TPM-based Attestation
```bash
# Generate attestation quote
sudo tpm2_quote --pcr-list=sha256:0,1,2,3,4,5,6,7 \
  --key-context=attestation.ctx \
  --message=attestation.msg \
  --signature=attestation.sig \
  --quote=attestation.quote

# Verify system integrity remotely
sudo remote-attestation verify --quote attestation.quote
```

#### System Integrity Reporting
```bash
# Generate integrity report
sudo generate-integrity-report

# Submit to monitoring server
sudo submit-integrity-report --server monitoring.company.com

# Automated integrity reporting
sudo systemctl enable integrity-reporting.timer
```

### Advanced Threat Detection

#### Behavioral Analysis
```bash
# Enable behavioral monitoring
sudo behavioral-monitor enable

# Configure detection sensitivity
sudo behavioral-monitor configure --sensitivity high

# View behavioral analysis results
behavioral-monitor status
```

#### Custom Detection Rules
```bash
# Create custom detection rule
sudo detection-rules create --name custom-rule \
  --pattern "suspicious-behavior" \
  --action quarantine

# Test detection rule
sudo detection-rules test custom-rule

# Deploy detection rule
sudo detection-rules deploy custom-rule
```

### Enterprise Integration

#### Domain Integration
```bash
# Join Active Directory domain
sudo domain-join --domain company.com \
  --user domain-admin \
  --ou "OU=Hardened Laptops,DC=company,DC=com"

# Configure group policies
sudo configure-group-policies

# Sync with enterprise certificate authority
sudo sync-enterprise-ca
```

#### Centralized Management
```bash
# Register with management server
sudo management-client register --server mgmt.company.com

# Apply enterprise policies
sudo apply-enterprise-policies

# Report compliance status
sudo compliance-report generate
```

## Best Practices

### Security Best Practices

#### Daily Habits
1. **Regular Security Checks**: Run `system-health-check` daily
2. **Monitor Alerts**: Review security notifications promptly
3. **Update Awareness**: Apply security updates quickly
4. **Backup Verification**: Ensure recovery points are created
5. **Network Caution**: Use VPN on untrusted networks

#### Application Usage
1. **Principle of Least Privilege**: Use minimal required permissions
2. **Sandbox Verification**: Verify application sandbox status
3. **Download Verification**: Only install verified applications
4. **Regular Updates**: Keep applications updated
5. **Permission Review**: Regularly review application permissions

#### Data Protection
1. **Encryption**: Encrypt sensitive data at rest and in transit
2. **Secure Deletion**: Use secure deletion for sensitive files
3. **Backup Strategy**: Maintain encrypted backups
4. **Access Control**: Limit access to sensitive data
5. **Data Classification**: Classify and handle data appropriately

### Operational Best Practices

#### System Maintenance
1. **Regular Monitoring**: Review security logs weekly
2. **Performance Monitoring**: Monitor system performance impact
3. **Recovery Testing**: Test recovery procedures monthly
4. **Key Management**: Monitor key expiration and rotate regularly
5. **Documentation**: Keep security documentation updated

#### Incident Response
1. **Preparation**: Understand incident response procedures
2. **Detection**: Monitor for security incidents
3. **Response**: Follow established response procedures
4. **Recovery**: Use verified recovery procedures
5. **Lessons Learned**: Document and learn from incidents

### Compliance Considerations

#### Regulatory Compliance
- **GDPR**: Data protection and privacy controls
- **HIPAA**: Healthcare data security requirements
- **SOX**: Financial data integrity controls
- **PCI DSS**: Payment card data security
- **NIST**: Cybersecurity framework alignment

#### Audit Preparation
1. **Log Retention**: Maintain required log retention periods
2. **Access Controls**: Document access control procedures
3. **Change Management**: Track system changes
4. **Incident Documentation**: Maintain incident records
5. **Compliance Reporting**: Generate compliance reports

### Performance Optimization

#### Security vs. Performance Balance
1. **Profile Optimization**: Adjust security profiles for performance
2. **Resource Monitoring**: Monitor resource usage
3. **Selective Hardening**: Apply hardening where most needed
4. **Performance Testing**: Regular performance benchmarking
5. **Tuning Guidelines**: Follow performance tuning recommendations

## Support and Resources

### Getting Help

#### Built-in Help
```bash
# System help
man hardened-os

# Command help
incident-response help
recovery-procedures help
key-rotation help
```

#### Documentation
- Installation Guide: `/opt/hardened-os/documentation/INSTALLATION_GUIDE.md`
- Troubleshooting Guide: `/opt/hardened-os/documentation/TROUBLESHOOTING_GUIDE.md`
- Security Guide: `/opt/hardened-os/documentation/SECURITY_GUIDE.md`
- Quick Reference: `/opt/hardened-os/incident-response/QUICK_REFERENCE.md`

#### Community Resources
- GitHub Repository: [Repository URL]
- Documentation Wiki: [Wiki URL]
- Security Mailing List: security@hardened-os.org
- User Forum: [Forum URL]
- IRC Channel: #hardened-os on Libera.Chat

#### Professional Support
- Enterprise Support: enterprise@hardened-os.org
- Security Consulting: consulting@hardened-os.org
- Training Services: training@hardened-os.org
- Certification Programs: certification@hardened-os.org

### Reporting Issues

#### Security Issues
```bash
# Report security vulnerabilities
security-report create --type vulnerability \
  --description "Description of issue" \
  --severity high

# Submit to security team
security-report submit --encrypted
```

#### Bug Reports
```bash
# Generate system information
generate-system-info

# Create bug report
bug-report create --component system \
  --description "Bug description" \
  --logs /var/log/system.log
```

### Contributing

#### Community Contributions
- Documentation improvements
- Translation efforts
- Testing and validation
- Feature requests
- Bug reports and fixes

#### Development Contributions
- Security enhancements
- Performance optimizations
- New features
- Integration improvements
- Testing frameworks

---

**Welcome to Hardened Laptop OS!**

This user guide provides the foundation for secure daily operations. For additional information, consult the specialized guides for installation, security, and troubleshooting.