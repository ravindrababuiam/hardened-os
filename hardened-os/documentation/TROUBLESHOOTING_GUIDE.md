# Hardened Laptop OS - Troubleshooting Guide

This guide provides comprehensive troubleshooting procedures for common issues encountered with the Hardened Laptop OS.

## Table of Contents

1. [Boot Issues](#boot-issues)
2. [Encryption and TPM Issues](#encryption-and-tpm-issues)
3. [Security Feature Issues](#security-feature-issues)
4. [Application Issues](#application-issues)
5. [Network Issues](#network-issues)
6. [Performance Issues](#performance-issues)
7. [System Recovery](#system-recovery)
8. [Log Analysis](#log-analysis)
9. [Emergency Procedures](#emergency-procedures)
10. [Getting Help](#getting-help)

## Boot Issues

### System Won't Boot

#### Symptom: Black screen, no boot activity
**Possible Causes:**
- Hardware failure
- Corrupted bootloader
- UEFI configuration issues
- Secure Boot key problems

**Diagnosis Steps:**
```bash
# Boot from recovery USB
# Check UEFI settings
# Verify hardware functionality
# Check boot device priority
```

**Resolution:**
```bash
# 1. Check UEFI settings
# Enter UEFI setup during boot
# Verify Secure Boot is enabled
# Check boot device order
# Ensure TPM is enabled

# 2. Boot from recovery USB
# Create recovery USB from another system
# Boot from USB
# Access recovery environment

# 3. Repair bootloader
sudo mount /dev/sda2 /mnt/boot
sudo mount /dev/sda1 /mnt/boot/efi
sudo mount /dev/mapper/vg-hardened-root /mnt
sudo chroot /mnt
grub-install /dev/sda
update-grub
exit
sudo umount /mnt/boot/efi /mnt/boot /mnt
```

#### Symptom: Secure Boot verification failed
**Possible Causes:**
- Invalid or missing Secure Boot keys
- Unsigned bootloader or kernel
- Corrupted boot signatures
- Hardware TPM issues

**Diagnosis Steps:**
```bash
# Check Secure Boot status
sudo mokutil --sb-state

# Check enrolled keys
sudo mokutil --list-enrolled

# Verify signatures
sudo sbctl verify

# Check TPM status
sudo tpm2_getcap properties-fixed
```

**Resolution:**
```bash
# 1. Re-enroll Secure Boot keys
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft
sudo sbctl sign-all

# 2. Verify key enrollment
sudo sbctl status

# 3. If keys are corrupted, reset and re-create
sudo sbctl reset
sudo sbctl create-keys
sudo sbctl enroll-keys
sudo sbctl sign-all

# 4. Reboot and test
sudo reboot
```

### GRUB Issues

#### Symptom: GRUB rescue prompt
**Possible Causes:**
- Corrupted GRUB configuration
- Missing kernel files
- Filesystem corruption
- Incorrect partition UUIDs

**Diagnosis Steps:**
```bash
# From GRUB rescue prompt
ls
ls (hd0,gpt1)
ls (hd0,gpt2)
ls (hd0,gpt3)

# Check for kernel files
ls (hd0,gpt2)/vmlinuz*
ls (hd0,gpt2)/initrd*
```

**Resolution:**
```bash
# 1. Boot manually from GRUB rescue
set root=(hd0,gpt2)
linux /vmlinuz-5.x.x-hardened root=/dev/mapper/vg-hardened-root
initrd /initrd.img-5.x.x-hardened
boot

# 2. Once booted, repair GRUB
sudo update-grub
sudo grub-install /dev/sda

# 3. If GRUB files are corrupted
sudo apt install --reinstall grub-efi-amd64
sudo grub-install /dev/sda
sudo update-grub
```

## Encryption and TPM Issues

### TPM Unsealing Failures

#### Symptom: System requires manual passphrase entry
**Possible Causes:**
- TPM PCR values changed
- Hardware modifications
- BIOS/UEFI updates
- Kernel updates
- Boot configuration changes

**Diagnosis Steps:**
```bash
# Check TPM status
sudo tpm2_getcap properties-fixed

# Check PCR values
sudo tpm2_pcrread

# Check LUKS keyslots
sudo cryptsetup luksDump /dev/sda3

# Check systemd-cryptenroll status
sudo systemd-cryptenroll --list /dev/sda3
```

**Resolution:**
```bash
# 1. Re-seal keys to current PCR values
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/sda3
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+4+7 /dev/sda3

# 2. If TPM is locked or corrupted
sudo tpm2_clear
# Reboot and re-seal
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+4+7 /dev/sda3

# 3. Test unsealing
sudo systemctl restart systemd-cryptsetup@sda3_crypt.service
```

#### Symptom: TPM not detected
**Possible Causes:**
- TPM disabled in BIOS
- Hardware TPM failure
- Driver issues
- Firmware TPM not supported

**Diagnosis Steps:**
```bash
# Check TPM device files
ls -la /dev/tpm*

# Check kernel messages
sudo dmesg | grep -i tpm

# Check TPM modules
lsmod | grep tpm

# Check BIOS settings
# Enter UEFI setup and verify TPM is enabled
```

**Resolution:**
```bash
# 1. Enable TPM in BIOS
# Enter UEFI setup
# Navigate to Security settings
# Enable TPM 2.0
# Save and exit

# 2. Load TPM modules
sudo modprobe tpm_tis
sudo modprobe tpm_crb

# 3. Install TPM tools if missing
sudo apt install tpm2-tools

# 4. Initialize TPM if needed
sudo tpm2_startup -c
sudo tpm2_clear
```

### LUKS Issues

#### Symptom: Cannot unlock encrypted disk
**Possible Causes:**
- Incorrect passphrase
- Corrupted LUKS header
- Damaged keyslots
- Hardware issues

**Diagnosis Steps:**
```bash
# Check LUKS header
sudo cryptsetup luksDump /dev/sda3

# Test passphrase
sudo cryptsetup luksOpen --test-passphrase /dev/sda3

# Check for header backup
ls -la /boot/luks-header-backup*

# Check disk health
sudo smartctl -a /dev/sda
```

**Resolution:**
```bash
# 1. Try all available keyslots
sudo cryptsetup luksOpen /dev/sda3 sda3_crypt --key-slot 0
sudo cryptsetup luksOpen /dev/sda3 sda3_crypt --key-slot 1

# 2. Restore LUKS header from backup
sudo cryptsetup luksHeaderRestore /dev/sda3 --header-backup-file /boot/luks-header-backup

# 3. Add new keyslot if one is corrupted
sudo cryptsetup luksAddKey /dev/sda3

# 4. Remove corrupted keyslot
sudo cryptsetup luksRemoveKey /dev/sda3 --key-slot 2
```

## Security Feature Issues

### SELinux Issues

#### Symptom: Applications fail to start or function
**Possible Causes:**
- SELinux policy denials
- Incorrect security contexts
- Missing policy modules
- Policy conflicts

**Diagnosis Steps:**
```bash
# Check SELinux status
sudo sestatus

# Check for denials
sudo ausearch -m avc -ts recent

# Check security contexts
ls -Z /path/to/application

# Check policy modules
sudo semodule -l
```

**Resolution:**
```bash
# 1. Analyze denials
sudo ausearch -m avc -ts recent | audit2allow -M local_policy

# 2. Review and install policy (only if safe)
sudo semodule -i local_policy.pp

# 3. Fix security contexts
sudo restorecon -R /path/to/application

# 4. Temporarily set permissive mode for testing
sudo setenforce 0
# Test application
sudo setenforce 1

# 5. Create custom policy for application
sudo sealert -a /var/log/audit/audit.log
```

#### Symptom: SELinux in permissive mode
**Possible Causes:**
- Configuration error
- Policy loading failure
- System recovery mode
- Manual override

**Diagnosis Steps:**
```bash
# Check SELinux configuration
cat /etc/selinux/config

# Check current mode
getenforce

# Check for policy errors
sudo journalctl -u selinux-policy-load
```

**Resolution:**
```bash
# 1. Set enforcing mode
sudo setenforce 1

# 2. Update configuration file
sudo sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config

# 3. Relabel filesystem if needed
sudo touch /.autorelabel
sudo reboot

# 4. Check for policy issues
sudo selinux-check-policy
```

### Sandboxing Issues

#### Symptom: Applications won't start in sandbox
**Possible Causes:**
- Missing dependencies in sandbox
- Incorrect sandbox profile
- Permission issues
- Resource constraints

**Diagnosis Steps:**
```bash
# Check sandbox status
sandbox-manager status application-name

# Test sandbox profile
sandbox-manager test-profile application-name

# Check sandbox logs
journalctl -u sandbox@application-name.service

# Check resource usage
systemctl status sandbox@application-name.service
```

**Resolution:**
```bash
# 1. Grant additional permissions
sandbox-manager grant-permission application-name filesystem:/path

# 2. Use less restrictive profile
sandbox-manager apply-profile application-name standard

# 3. Debug sandbox environment
sandbox-manager debug application-name

# 4. Create custom profile
sandbox-manager create-profile application-name \
  --filesystem ~/Documents \
  --network restricted \
  --devices minimal
```

## Application Issues

### Application Crashes

#### Symptom: Applications crash on startup
**Possible Causes:**
- Missing dependencies
- Sandbox restrictions
- SELinux denials
- Resource limits
- Corrupted application files

**Diagnosis Steps:**
```bash
# Check application logs
journalctl -u application-name

# Check system logs
sudo journalctl -xe

# Check for core dumps
ls -la /var/crash/

# Check sandbox restrictions
sandbox-manager diagnose application-name

# Check SELinux denials
sudo ausearch -m avc -c application-name
```

**Resolution:**
```bash
# 1. Install missing dependencies
sudo apt install --fix-broken

# 2. Adjust sandbox permissions
sandbox-manager grant-permission application-name required-permission

# 3. Fix SELinux contexts
sudo restorecon -R /usr/bin/application-name

# 4. Increase resource limits
sudo systemctl edit application-name.service
# Add:
# [Service]
# LimitNOFILE=65536
# MemoryMax=2G

# 5. Reinstall application
sudo apt remove --purge application-name
sudo apt install application-name
```

### Permission Issues

#### Symptom: Applications can't access files or resources
**Possible Causes:**
- Insufficient file permissions
- SELinux restrictions
- Sandbox limitations
- Missing capabilities

**Diagnosis Steps:**
```bash
# Check file permissions
ls -la /path/to/file

# Check SELinux contexts
ls -Z /path/to/file

# Check sandbox permissions
sandbox-manager list-permissions application-name

# Check capabilities
getcap /usr/bin/application-name
```

**Resolution:**
```bash
# 1. Fix file permissions
sudo chmod 644 /path/to/file
sudo chown user:group /path/to/file

# 2. Fix SELinux contexts
sudo chcon -t application_exec_t /usr/bin/application-name

# 3. Grant sandbox permissions
sandbox-manager grant-permission application-name filesystem:/path/to/file

# 4. Add required capabilities
sudo setcap cap_net_bind_service+ep /usr/bin/application-name
```

## Network Issues

### No Network Connectivity

#### Symptom: No internet access
**Possible Causes:**
- Firewall blocking traffic
- DNS resolution issues
- Network interface problems
- VPN configuration issues

**Diagnosis Steps:**
```bash
# Check network interfaces
ip addr show

# Check routing table
ip route show

# Check firewall rules
sudo ufw status verbose

# Test DNS resolution
nslookup google.com

# Check network services
sudo systemctl status systemd-networkd
sudo systemctl status systemd-resolved
```

**Resolution:**
```bash
# 1. Restart network services
sudo systemctl restart systemd-networkd
sudo systemctl restart systemd-resolved

# 2. Check firewall rules
sudo ufw allow out 53
sudo ufw allow out 80
sudo ufw allow out 443

# 3. Fix DNS configuration
sudo systemctl edit systemd-resolved
# Add:
# [Service]
# Environment=SYSTEMD_LOG_LEVEL=debug

# 4. Reset network configuration
sudo netplan apply

# 5. Disable VPN temporarily
sudo systemctl stop openvpn@client
```

### DNS Resolution Issues

#### Symptom: Cannot resolve domain names
**Possible Causes:**
- DNS server issues
- DNS filtering blocking domains
- systemd-resolved problems
- Network configuration issues

**Diagnosis Steps:**
```bash
# Check DNS configuration
systemd-resolve --status

# Test DNS resolution
dig google.com
nslookup google.com

# Check DNS logs
sudo journalctl -u systemd-resolved

# Test different DNS servers
dig @8.8.8.8 google.com
dig @1.1.1.1 google.com
```

**Resolution:**
```bash
# 1. Restart DNS resolver
sudo systemctl restart systemd-resolved

# 2. Configure DNS servers
sudo systemctl edit systemd-resolved
# Add:
# [Service]
# Environment=SYSTEMD_RESOLVED_DNS_SERVERS=1.1.1.1,8.8.8.8

# 3. Flush DNS cache
sudo systemd-resolve --flush-caches

# 4. Reset DNS configuration
sudo rm /etc/systemd/resolved.conf.d/*
sudo systemctl restart systemd-resolved

# 5. Use alternative DNS
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

### Firewall Issues

#### Symptom: Applications can't connect to network
**Possible Causes:**
- Restrictive firewall rules
- Per-application blocking
- Port blocking
- Protocol restrictions

**Diagnosis Steps:**
```bash
# Check firewall status
sudo ufw status verbose

# Check nftables rules
sudo nft list ruleset

# Check application network permissions
network-security-status

# Check blocked connections
sudo journalctl -u ufw
```

**Resolution:**
```bash
# 1. Allow application network access
sudo ufw allow out from any to any port 80,443

# 2. Grant per-application access
network-manager grant-access application-name http,https

# 3. Temporarily disable firewall for testing
sudo ufw disable
# Test connectivity
sudo ufw enable

# 4. Reset firewall rules
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

## Performance Issues

### Slow System Performance

#### Symptom: System is slow or unresponsive
**Possible Causes:**
- High CPU usage from security processes
- Memory constraints
- Disk I/O bottlenecks
- Security overhead

**Diagnosis Steps:**
```bash
# Check system resources
top
htop
iotop

# Check security process usage
ps aux | grep -E "(audit|selinux|sandbox)"

# Check memory usage
free -h
cat /proc/meminfo

# Check disk usage
df -h
iostat -x 1

# Measure security overhead
measure-security-overhead
```

**Resolution:**
```bash
# 1. Optimize security settings
optimize-security-performance

# 2. Adjust audit rules
sudo auditctl -D
sudo auditctl -R /etc/audit/rules.d/minimal.rules

# 3. Tune SELinux
sudo setsebool -P selinux_use_current_range on

# 4. Optimize sandbox settings
sandbox-manager optimize-performance

# 5. Increase system resources
# Add more RAM or use faster storage
```

### High CPU Usage

#### Symptom: Constant high CPU usage
**Possible Causes:**
- Security monitoring processes
- Malware or cryptomining
- Inefficient applications
- System misconfiguration

**Diagnosis Steps:**
```bash
# Identify high CPU processes
top -o %CPU
ps aux --sort=-%cpu | head -20

# Check for malware
sudo incident-response scan malware

# Check security processes
systemctl status hardened-os-monitor
systemctl status auditd

# Monitor CPU usage over time
sar -u 1 60
```

**Resolution:**
```bash
# 1. Reduce monitoring frequency
sudo systemctl edit hardened-os-monitor.timer
# Change OnCalendar to less frequent

# 2. Optimize audit rules
sudo auditctl -l | wc -l
# Reduce number of audit rules if excessive

# 3. Check for malware
sudo incident-response scan all
sudo rkhunter --check

# 4. Limit process resources
sudo systemctl edit resource-intensive.service
# Add:
# [Service]
# CPUQuota=50%

# 5. Kill suspicious processes
sudo pkill -f suspicious-process
```

## System Recovery

### Recovery from Corruption

#### Symptom: System files corrupted
**Possible Causes:**
- Disk errors
- Power failures
- Malware infection
- Hardware issues

**Diagnosis Steps:**
```bash
# Check filesystem integrity
sudo fsck /dev/mapper/vg-hardened-root

# Check for hardware errors
sudo smartctl -a /dev/sda

# Check system integrity
sudo aide --check

# Check for malware
sudo incident-response scan all
```

**Resolution:**
```bash
# 1. Boot from recovery media
# Mount encrypted system
sudo cryptsetup luksOpen /dev/sda3 sda3_crypt
sudo mount /dev/mapper/vg-hardened-root /mnt

# 2. Repair filesystem
sudo fsck -y /dev/mapper/vg-hardened-root

# 3. Restore from recovery point
sudo recovery-procedures restore /var/recovery-points/latest safe

# 4. Reinstall corrupted packages
sudo chroot /mnt
apt install --reinstall systemd
apt install --reinstall linux-image-hardened

# 5. Update integrity database
sudo aide --update
```

### Emergency Recovery

#### Symptom: System completely unbootable
**Possible Causes:**
- Complete system corruption
- Hardware failure
- Malware infection
- Configuration errors

**Emergency Procedure:**
```bash
# 1. Boot from recovery USB
# 2. Access emergency recovery tools
emergency-recovery-menu

# 3. Collect forensic evidence
collect-forensics

# 4. Attempt system recovery
recovery-procedures emergency

# 5. If recovery fails, restore from backup
restore-from-backup --source external-drive --target /dev/sda

# 6. Reinstall system if necessary
# Follow installation guide for clean install
```

## Log Analysis

### Understanding Log Files

#### System Logs
```bash
# System messages
sudo journalctl -xe

# Boot messages
sudo journalctl -b

# Kernel messages
sudo dmesg

# Authentication logs
sudo journalctl -u ssh
sudo tail -f /var/log/auth.log
```

#### Security Logs
```bash
# Audit logs
sudo ausearch -ts recent

# SELinux logs
sudo ausearch -m avc

# Incident response logs
sudo tail -f /var/log/incident-response.log

# Security monitoring
sudo journalctl -u hardened-os-monitor
```

#### Application Logs
```bash
# Application-specific logs
sudo journalctl -u application-name

# Sandbox logs
sudo journalctl -u sandbox@application-name

# Crash logs
ls -la /var/crash/
```

### Log Analysis Tools

#### Automated Analysis
```bash
# Analyze security events
analyze-security-events 24h

# Generate security report
generate-security-report --period daily

# Check for anomalies
detect-log-anomalies

# Correlate events
correlate-security-events --timeframe 1h
```

#### Manual Analysis
```bash
# Search for specific events
sudo journalctl --grep "error"
sudo ausearch -k network

# Filter by time
sudo journalctl --since "2024-01-01" --until "2024-01-02"

# Follow logs in real-time
sudo journalctl -f
sudo tail -f /var/log/syslog
```

## Emergency Procedures

### Security Incident Response

#### Suspected Compromise
```bash
# 1. Immediate containment
sudo emergency-lockdown

# 2. Collect evidence
sudo collect-forensics

# 3. Analyze threat
sudo incident-response scan all

# 4. Isolate system
sudo systemctl stop NetworkManager
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT DROP

# 5. Contact security team
# Use out-of-band communication
```

#### Malware Detection
```bash
# 1. Run comprehensive scan
sudo incident-response scan malware

# 2. Quarantine threats
sudo incident-response contain malware

# 3. Clean system
sudo rkhunter --check
sudo chkrootkit

# 4. Restore from clean backup
sudo recovery-procedures restore /var/recovery-points/clean-backup full

# 5. Update security measures
sudo update-security-policies
```

### Hardware Failure

#### Disk Failure
```bash
# 1. Check disk health
sudo smartctl -a /dev/sda

# 2. Create emergency backup
sudo dd if=/dev/sda of=/external/disk-image.img bs=4M

# 3. Replace disk and restore
# Install new disk
# Restore from backup or recovery point

# 4. Verify system integrity
sudo aide --check
sudo incident-response scan all
```

#### Memory Issues
```bash
# 1. Test memory
sudo memtest86+

# 2. Check for memory errors
sudo dmesg | grep -i memory

# 3. Reduce memory usage
sudo systemctl stop non-essential-services

# 4. Replace faulty memory
# Power down system
# Replace memory modules
# Test system stability
```

## Getting Help

### Self-Help Resources

#### Documentation
```bash
# Built-in help
man hardened-os
incident-response help
recovery-procedures help

# Documentation directory
ls /opt/hardened-os/documentation/

# Quick reference
cat /opt/hardened-os/incident-response/QUICK_REFERENCE.md
```

#### Diagnostic Tools
```bash
# System health check
system-health-check

# Generate system report
generate-system-report

# Performance analysis
performance-diagnose

# Security assessment
security-assessment --comprehensive
```

### Community Support

#### Online Resources
- GitHub Issues: [Repository URL]
- Documentation Wiki: [Wiki URL]
- User Forum: [Forum URL]
- IRC Channel: #hardened-os on Libera.Chat

#### Mailing Lists
- User Support: users@hardened-os.org
- Security Issues: security@hardened-os.org
- Development: dev@hardened-os.org

### Professional Support

#### Enterprise Support
- Email: enterprise@hardened-os.org
- Phone: +1-555-HARDENED
- Support Portal: [Support URL]

#### Consulting Services
- Security Assessment: consulting@hardened-os.org
- Custom Implementation: custom@hardened-os.org
- Training Services: training@hardened-os.org

### Reporting Issues

#### Bug Reports
```bash
# Generate bug report
generate-bug-report --component system

# Include system information
generate-system-info

# Submit report
submit-bug-report --encrypted
```

#### Security Vulnerabilities
```bash
# Report security issue
security-report create --severity high

# Encrypt report
gpg --encrypt --recipient security@hardened-os.org report.txt

# Submit securely
# Use secure communication channels
```

---

**Remember: When in Doubt, Seek Help**

Don't hesitate to reach out for help when troubleshooting complex issues. The Hardened Laptop OS community and support team are here to help you maintain a secure and functional system.