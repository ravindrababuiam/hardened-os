# Hardened Laptop OS - Installation Guide

This guide provides step-by-step instructions for installing and configuring the Hardened Laptop OS with GrapheneOS-level security features.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Hardware Requirements](#hardware-requirements)
3. [Pre-Installation Setup](#pre-installation-setup)
4. [Base System Installation](#base-system-installation)
5. [Security Hardening](#security-hardening)
6. [Post-Installation Configuration](#post-installation-configuration)
7. [Verification and Testing](#verification-and-testing)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Knowledge Requirements
- Basic Linux system administration
- Understanding of UEFI/BIOS configuration
- Familiarity with disk encryption concepts
- Basic cryptographic key management knowledge

### Tools Required
- USB flash drive (8GB minimum)
- Network connection for package downloads
- Backup storage for recovery keys
- Hardware Security Module (HSM) - optional but recommended for production

## Hardware Requirements

### Minimum Requirements
- **CPU**: x86_64 processor with hardware security features
  - Intel: CET, TXT, VT-x, AES-NI
  - AMD: SVM, Memory Guard, AES acceleration
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 250GB SSD minimum, 500GB recommended
- **TPM**: TPM 2.0 chip (required)
- **UEFI**: UEFI firmware with Secure Boot support
- **Network**: Ethernet or Wi-Fi capability

### Recommended Hardware
- **CPU**: Intel Core i5/i7 or AMD Ryzen 5/7 (latest generation)
- **RAM**: 32GB for optimal performance
- **Storage**: NVMe SSD with hardware encryption support
- **TPM**: Discrete TPM 2.0 chip (preferred over firmware TPM)
- **Network**: Intel or Realtek network adapters (better Linux support)

### Verified Compatible Systems
- ThinkPad X1 Carbon (Gen 9+)
- ThinkPad T14s (Gen 2+)
- Dell XPS 13 (9310+)
- Dell Latitude 7420
- HP EliteBook 840 G8+
- System76 Lemur Pro

## Pre-Installation Setup

### 1. BIOS/UEFI Configuration

#### Enable Required Features
```
Security Settings:
✓ TPM 2.0 Enabled
✓ Secure Boot Enabled (will be reconfigured later)
✓ Intel TXT / AMD SVM Enabled
✓ Virtualization Technology Enabled

Boot Settings:
✓ UEFI Boot Mode
✓ Fast Boot Disabled
✓ Legacy Boot Disabled
✓ Network Boot Disabled (unless needed)

Advanced Settings:
✓ Intel ME/AMD PSP Disabled (if possible)
✓ SMT/Hyperthreading Enabled
✓ Hardware Random Number Generator Enabled
```

#### Disable Unnecessary Features
```
✗ Wake on LAN
✗ Thunderbolt Security (set to User Authorization)
✗ Wireless charging (if present)
✗ Fingerprint reader (will be configured separately)
✗ Camera (can be re-enabled later)
```

### 2. Create Installation Media

#### Download Base System
```bash
# Download Debian stable netinst ISO
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.2.0-amd64-netinst.iso

# Verify checksum
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing
```

#### Create Bootable USB
```bash
# Identify USB device
lsblk

# Create bootable USB (replace /dev/sdX with your USB device)
sudo dd if=debian-12.2.0-amd64-netinst.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

### 3. Prepare Installation Environment

#### Create Secure Workspace
```bash
# Create working directory
mkdir -p ~/hardened-os-install
cd ~/hardened-os-install

# Download hardened OS components
git clone https://github.com/your-org/hardened-laptop-os.git
cd hardened-laptop-os

# Verify signatures (if available)
gpg --verify hardened-os.sig hardened-os.tar.gz
```

## Base System Installation

### 1. Boot from Installation Media

1. Insert USB installation media
2. Boot system and enter UEFI setup
3. Set USB as first boot device
4. Save and exit to boot installer

### 2. Debian Installation Process

#### Language and Locale
```
Language: English
Country: United States (or your location)
Locale: en_US.UTF-8
Keyboard: US (or your layout)
```

#### Network Configuration
```
Hostname: hardened-laptop
Domain: local (or your domain)
Network: Configure automatically (or manual if needed)
```

#### User Account Setup
```
Root password: [Strong password - will be changed later]
Full name: [Your name]
Username: [Your username]
Password: [Strong password]
```

#### Disk Partitioning (Critical Step)

**⚠️ WARNING: This will erase all data on the target disk**

Select "Manual" partitioning and create:

```
Partition Layout:
/dev/sda1  512MB   EFI System Partition (FAT32)
/dev/sda2  1GB     Boot partition (ext4, unencrypted)
/dev/sda3  Rest    LVM Physical Volume (encrypted)

LVM Configuration:
Volume Group: vg-hardened
  /dev/mapper/vg-hardened-root    50GB    / (ext4)
  /dev/mapper/vg-hardened-home    Rest-8GB /home (ext4)
  /dev/mapper/vg-hardened-swap    8GB     swap
```

#### Encryption Setup
1. Select "Configure encrypted volumes"
2. Create encrypted volume on /dev/sda3
3. Use strong passphrase (minimum 20 characters)
4. **IMPORTANT**: Write down the passphrase securely

#### Package Selection
```
Debian software selection:
✗ Debian desktop environment
✗ GNOME
✗ Xfce
✗ KDE Plasma
✗ Cinnamon
✗ MATE
✗ LXDE
✗ LXQt
✗ web server
✗ SSH server (will be configured later)
✓ standard system utilities
```

### 3. Complete Base Installation

1. Install GRUB bootloader to /dev/sda
2. Finish installation and reboot
3. Remove installation media
4. Boot into new system

## Security Hardening

### 1. Initial System Update

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
    curl wget gnupg2 software-properties-common \
    build-essential git vim tmux \
    cryptsetup tpm2-tools \
    auditd aide rkhunter chkrootkit \
    fail2ban ufw \
    sbctl mokutil
```

### 2. Install Hardened Kernel

```bash
# Navigate to hardened OS directory
cd ~/hardened-laptop-os

# Install hardened kernel
sudo ./kernel/install-hardened-kernel.sh

# Reboot to new kernel
sudo reboot
```

### 3. Configure Secure Boot

```bash
# Generate custom Secure Boot keys
sudo ./secure-boot/setup-secure-boot.sh

# Sign kernel and bootloader
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft
sudo sbctl sign-all

# Verify Secure Boot status
sudo sbctl status
```

### 4. Configure TPM2 and Measured Boot

```bash
# Initialize TPM2
sudo ./tpm/setup-tpm2.sh

# Configure measured boot
sudo ./tpm/configure-measured-boot.sh

# Seal LUKS key to TPM
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+4+7 /dev/sda3
```

### 5. Install Security Components

#### Logging System
```bash
cd logging/
sudo ./install-logging-system.sh
```

#### Incident Response System
```bash
cd ../incident-response/
sudo ./install-incident-response.sh
```

#### SELinux Configuration
```bash
cd ../selinux/
sudo ./configure-selinux.sh
```

### 6. Configure Application Sandboxing

```bash
# Install sandboxing framework
cd ../sandboxing/
sudo ./install-sandboxing.sh

# Configure application profiles
sudo ./configure-app-profiles.sh
```

## Post-Installation Configuration

### 1. User Account Hardening

```bash
# Configure user account security
sudo ./users/harden-user-accounts.sh

# Set up multi-factor authentication
sudo ./users/setup-mfa.sh

# Configure sudo restrictions
sudo visudo
# Add: %sudo ALL=(ALL:ALL) ALL, !NOPASSWD
```

### 2. Network Security

```bash
# Configure firewall
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Configure per-application network controls
sudo ./network/setup-app-firewall.sh

# Configure DNS security
sudo ./network/configure-secure-dns.sh
```

### 3. System Monitoring

```bash
# Configure system monitoring
sudo ./monitoring/setup-monitoring.sh

# Configure log forwarding (optional)
sudo ./monitoring/configure-log-forwarding.sh

# Set up alerting
sudo ./monitoring/setup-alerting.sh
```

### 4. Backup and Recovery

```bash
# Create initial recovery point
sudo recovery-procedures create "Initial installation"

# Configure automated backups
sudo systemctl enable recovery-point-create.timer
sudo systemctl start recovery-point-create.timer

# Test recovery procedures
sudo recovery-procedures verify /var/recovery-points/recovery_*
```

## Verification and Testing

### 1. Security Verification

```bash
# Run comprehensive security scan
sudo incident-response scan all

# Verify kernel hardening
sudo ./testing/verify-kernel-hardening.sh

# Check SELinux status
sudo sestatus
sudo selinux-check-policy

# Verify TPM configuration
sudo tpm2_getcap properties-fixed
sudo systemd-cryptenroll --list /dev/sda3
```

### 2. Functionality Testing

```bash
# Test secure boot
sudo sbctl verify

# Test logging system
sudo journalctl --verify
sudo ./logging/test-logging-system.sh

# Test incident response
sudo ./incident-response/test-incident-response.sh

# Test recovery procedures
sudo recovery-procedures list
sudo recovery-procedures verify /var/recovery-points/recovery_*
```

### 3. Performance Baseline

```bash
# System performance test
sudo ./testing/performance-baseline.sh

# Security overhead measurement
sudo ./testing/measure-security-overhead.sh

# Network performance test
sudo ./testing/network-performance.sh
```

## Troubleshooting

### Common Installation Issues

#### 1. TPM Not Detected
```bash
# Check TPM status
sudo dmesg | grep -i tpm
ls /dev/tpm*

# If missing, check BIOS settings:
# - Enable TPM 2.0
# - Enable Security Device Support
# - Disable TPM Clear
```

#### 2. Secure Boot Issues
```bash
# Check Secure Boot status
sudo mokutil --sb-state

# If disabled:
# 1. Enter BIOS setup
# 2. Enable Secure Boot
# 3. Set to Setup Mode
# 4. Re-run key enrollment
```

#### 3. LUKS Unlock Failures
```bash
# Check LUKS status
sudo cryptsetup status /dev/mapper/sda3_crypt

# Manual unlock
sudo cryptsetup luksOpen /dev/sda3 sda3_crypt

# Reset TPM sealing
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/sda3
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+4+7 /dev/sda3
```

#### 4. Boot Issues
```bash
# Boot from recovery media
# Mount encrypted root
sudo cryptsetup luksOpen /dev/sda3 sda3_crypt
sudo mount /dev/mapper/vg-hardened-root /mnt
sudo mount /dev/sda2 /mnt/boot
sudo mount /dev/sda1 /mnt/boot/efi

# Chroot and fix
sudo chroot /mnt
update-grub
grub-install /dev/sda
```

### Recovery Procedures

#### 1. Emergency Boot
```bash
# Boot from USB recovery media
# Follow emergency recovery procedures in:
# /opt/hardened-os/incident-response/QUICK_REFERENCE.md
```

#### 2. Key Recovery
```bash
# If TPM unsealing fails:
# 1. Boot to recovery mode
# 2. Use backup passphrase
# 3. Re-seal keys to TPM:
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+4+7 /dev/sda3
```

#### 3. System Recovery
```bash
# List available recovery points
sudo recovery-procedures list

# Restore from recovery point
sudo recovery-procedures restore /var/recovery-points/recovery_YYYYMMDD_HHMMSS safe
```

### Getting Help

#### Log Files
- System logs: `journalctl -xe`
- Security logs: `/var/log/audit/audit.log`
- Installation logs: `/var/log/installer/`
- Custom logs: `/var/log/hardened-os/`

#### Support Resources
- Documentation: `/opt/hardened-os/documentation/`
- Quick reference: `/opt/hardened-os/incident-response/QUICK_REFERENCE.md`
- Configuration files: `/etc/hardened-os/`
- Test scripts: `/opt/hardened-os/testing/`

#### Community Support
- GitHub Issues: [Repository URL]
- Security Mailing List: security@hardened-os.org
- Documentation Wiki: [Wiki URL]
- IRC Channel: #hardened-os on Libera.Chat

## Next Steps

After successful installation:

1. **Read the User Guide**: Complete system usage documentation
2. **Configure Applications**: Set up sandboxed applications
3. **Security Training**: Learn about threat model and security features
4. **Backup Strategy**: Implement comprehensive backup procedures
5. **Monitoring Setup**: Configure security monitoring and alerting
6. **Regular Maintenance**: Schedule updates and security reviews

## Security Considerations

### Important Reminders

- **Backup Recovery Keys**: Store LUKS passphrases and recovery keys securely offline
- **Regular Updates**: Keep system and security components updated
- **Monitor Logs**: Review security logs regularly for anomalies
- **Test Recovery**: Regularly test recovery procedures
- **Physical Security**: Secure physical access to the device
- **Network Security**: Use VPN on untrusted networks

### Threat Model Awareness

This system is designed to protect against:
- Physical device theft
- Evil Maid attacks
- Remote network intrusions
- Malware and rootkits
- Supply chain compromises
- Nation-state adversaries

However, it cannot protect against:
- Rubber hose cryptanalysis (physical coercion)
- Hardware implants inserted during manufacturing
- Zero-day exploits in hardware or firmware
- Side-channel attacks on cryptographic operations
- Social engineering attacks

### Compliance and Certification

This installation may help meet requirements for:
- NIST Cybersecurity Framework
- ISO 27001/27002
- Common Criteria EAL4+
- FIPS 140-2 Level 2
- SOC 2 Type II

Consult with compliance experts for specific certification requirements.

---

**Installation Complete!**

Your Hardened Laptop OS is now installed and configured with enterprise-grade security features. Proceed to the User Guide for daily operation instructions.