# Hardened Laptop OS Installation Guide

## Overview

This guide walks you through installing the Hardened Laptop OS, which provides GrapheneOS-level security for laptops with comprehensive hardening features.

## 🔒 Security Features

- **UEFI Secure Boot** with custom keys
- **TPM2 Measured Boot** and key sealing
- **LUKS2 Full Disk Encryption** with Argon2id KDF
- **Hardened Kernel** with KSPP configuration and exploit mitigations
- **SELinux Mandatory Access Control** in enforcing mode
- **Application Sandboxing** with bubblewrap
- **Per-Application Network Controls** with nftables
- **TUF-based Secure Updates** with cryptographic verification
- **Reproducible Builds** with Software Bill of Materials (SBOM)

## 📋 Prerequisites

### Hardware Requirements

#### Minimum Requirements
- **Architecture**: x86_64 (Intel/AMD 64-bit)
- **Firmware**: UEFI (Legacy BIOS not supported)
- **TPM**: TPM 2.0 chip (recommended, some features work without)
- **RAM**: 8GB minimum, 16GB+ recommended
- **Storage**: 250GB+ SSD (NVMe recommended for performance)
- **Network**: Internet connection for package downloads

#### Recommended Hardware
- **CPU**: Modern Intel/AMD with hardware security features
- **RAM**: 16GB+ for optimal performance
- **Storage**: 500GB+ NVMe SSD
- **TPM**: TPM 2.0 with firmware support
- **Secure Boot**: UEFI with Secure Boot capability

### Software Requirements

#### Host System (for building/preparing)
- **OS**: Ubuntu 20.04+ LTS or Debian 11+ stable
- **Tools**: git, wget, curl, cryptsetup, parted, debootstrap
- **Container**: Docker or Podman (for reproducible builds)
- **Development**: gcc, clang, make, cmake, python3

#### Target System
- **Clean Installation**: Target device will be completely wiped
- **UEFI Boot**: System must support UEFI boot mode
- **Secure Boot**: Firmware should support custom Secure Boot keys

## 🚨 Important Warnings

### ⚠️ **DATA LOSS WARNING**
**This installation will completely wipe the target device and all existing data will be permanently lost!**

### ⚠️ **Development Keys**
This installation uses development signing keys. For production use, implement proper key management (Task 18).

### ⚠️ **Backup Requirements**
- Backup all important data before installation
- Have recovery media available
- Document current system configuration

## 📝 Pre-Installation Checklist

### 1. Hardware Verification
```bash
# Check UEFI support
[ -d /sys/firmware/efi ] && echo "✓ UEFI supported" || echo "✗ UEFI required"

# Check TPM2 support
[ -c /dev/tpm0 ] || [ -c /dev/tpmrm0 ] && echo "✓ TPM2 detected" || echo "⚠ TPM2 not found"

# Check memory
free -h | grep "Mem:"

# Check target device
lsblk
```

### 2. Firmware Configuration
1. **Enable UEFI Boot Mode** (disable Legacy/CSM)
2. **Enable Secure Boot** (will be configured with custom keys)
3. **Enable TPM 2.0** in firmware settings
4. **Disable Fast Boot** for proper initialization
5. **Enable Virtualization** (VT-x/AMD-V) if available

### 3. Development Environment Setup
```bash
# Clone the repository
git clone <repository-url>
cd hardened-laptop-os

# Run environment setup
bash scripts/setup-environment.sh

# Verify all components are ready
bash scripts/run-all-tests.sh
```

### 4. Target Device Preparation
```bash
# Identify target device (CAREFUL!)
lsblk -f

# Verify device (replace /dev/sdX with your target)
sudo fdisk -l /dev/sdX

# Backup partition table (optional)
sudo sfdisk -d /dev/sdX > partition-backup.txt
```

## 🚀 Installation Process

### Step 1: Run Pre-Installation Checks
```bash
# Verify system requirements
bash scripts/check-uefi.sh
bash scripts/check-tpm2.sh
bash scripts/check-resources.sh
```

### Step 2: Start Installation
```bash
# Run the main installation script
# Replace /dev/sdX with your target device
sudo bash scripts/install-hardened-os.sh /dev/sdX
```

### Step 3: Installation Phases

The installer will automatically execute these phases:

#### **M1: Boot Security Foundation**
- ✅ Verify development environment
- ✅ Generate/verify signing keys
- ✅ Create partition layout (EFI + Recovery + Encrypted LVM)
- ✅ Set up LUKS2 encryption with Argon2id
- ✅ Install Debian base system
- ✅ Configure UEFI Secure Boot with custom keys
- ✅ Configure TPM2 measured boot and key sealing

#### **M2: Kernel Hardening & MAC**
- ✅ Build and install hardened kernel with KSPP config
- ✅ Configure compiler hardening (CFI, stack protection)
- ✅ Create signed kernel packages
- ✅ Configure SELinux in enforcing mode
- ✅ Minimize system services and attack surface
- ✅ Configure userspace hardening and memory protection

#### **M3: Application Security**
- ✅ Configure bubblewrap application sandboxing
- ✅ Set up per-application network controls with nftables
- ✅ Configure user onboarding wizard

#### **M4: Updates & Supply Chain Security**
- ✅ Configure secure update system (development mode)
- ✅ Set up automatic rollback and recovery mechanisms
- ✅ Configure reproducible build pipeline with SBOM

### Step 4: Post-Installation Validation
The installer automatically runs validation tests for all components.

## 🔧 First Boot Configuration

### 1. Initial Boot
1. **Reboot** the system from the target device
2. **Enter LUKS passphrase** when prompted
3. **Complete TPM2 enrollment** (if available)
4. **Follow first-boot wizard** for user account setup

### 2. TPM2 Configuration
```bash
# Check TPM2 status
sudo systemd-cryptenroll --tpm2-device=list

# Enroll TPM2 for automatic unlocking (optional)
sudo systemd-cryptenroll --tpm2-device=auto /dev/mapper/luks-root

# Test TPM2 unsealing
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/mapper/luks-root
```

### 3. User Account Setup
```bash
# Create user account with proper groups
sudo adduser username
sudo usermod -aG sudo,audio,video,plugdev username

# Configure SELinux user mapping
sudo semanage user -a -R "user_r" username
```

### 4. Application Configuration
```bash
# Install sandboxed browser
sudo apt install firefox-esr
bwrap-firefox  # Launches in sandbox

# Configure office applications
sudo apt install libreoffice
bwrap-office   # Launches in sandbox

# Test network controls
sudo nft list ruleset  # View firewall rules
```

## 🔍 Verification and Testing

### Security Feature Testing
```bash
# Test Secure Boot
sudo mokutil --sb-state

# Test TPM2 functionality
sudo tpm2_getcap properties-fixed

# Test SELinux enforcement
sudo getenforce
sudo seinfo

# Test application sandboxing
ps aux | grep bwrap

# Test network controls
sudo ss -tulpn
```

### Recovery Testing
```bash
# Test recovery boot
# Reboot and select recovery option from GRUB menu

# Test automatic rollback
# Simulate boot failure to trigger rollback
```

## 📚 Post-Installation Tasks

### Essential Configuration
1. **Configure Applications**: Set up sandboxed browser, office suite
2. **Network Setup**: Configure WiFi, VPN, firewall rules
3. **User Permissions**: Set up additional user accounts
4. **Backup Setup**: Configure system and data backups

### Security Hardening
1. **Review SELinux Policies**: Customize for your use case
2. **Configure Network Rules**: Adjust per-application controls
3. **Test Recovery Procedures**: Verify all recovery mechanisms
4. **Update Configuration**: Set up secure update preferences

### Monitoring and Maintenance
1. **Log Monitoring**: Review security logs regularly
2. **Update Management**: Keep system updated through secure channels
3. **Security Auditing**: Regular security assessments
4. **Backup Verification**: Test backup and recovery procedures

## 🆘 Troubleshooting

### Common Issues

#### Boot Issues
```bash
# Boot fails after installation
# 1. Boot from recovery partition
# 2. Check GRUB configuration
# 3. Verify Secure Boot keys
# 4. Check TPM2 PCR values
```

#### TPM2 Issues
```bash
# TPM2 unsealing fails
# 1. Check PCR measurements: sudo tpm2_pcrread
# 2. Re-enroll with current PCRs
# 3. Use fallback passphrase
```

#### SELinux Issues
```bash
# Application blocked by SELinux
# 1. Check denials: sudo ausearch -m AVC
# 2. Generate policy: sudo audit2allow
# 3. Apply temporary permissive: sudo setenforce 0
```

#### Network Issues
```bash
# Application network blocked
# 1. Check nftables rules: sudo nft list ruleset
# 2. Review SELinux network policy
# 3. Adjust per-app network controls
```

### Recovery Procedures

#### Emergency Recovery
1. **Boot Recovery Partition**: Select from GRUB menu
2. **Use LUKS Passphrase**: If TPM2 fails
3. **Disable Secure Boot**: Temporarily if needed
4. **Rollback System**: Use automatic rollback feature

#### System Restoration
```bash
# Restore from backup
# 1. Boot recovery environment
# 2. Mount encrypted volumes
# 3. Restore from backup media
# 4. Reconfigure boot chain
```

## 📖 Additional Resources

### Documentation
- **Technical Documentation**: `~/harden/docs/`
- **Security Policies**: `~/harden/selinux/policies/`
- **Configuration Files**: `~/harden/configs/`
- **Installation Logs**: `~/harden/logs/`

### Validation Scripts
- **Security Validation**: `scripts/validate-task-*.sh`
- **System Testing**: `scripts/test-*.sh`
- **Recovery Testing**: `scripts/test-recovery-boot.sh`

### Support and Community
- **Issue Tracker**: Report bugs and issues
- **Security Advisories**: Subscribe to security updates
- **Community Forum**: Get help and share experiences
- **Documentation Wiki**: Contribute to documentation

## 🔐 Security Considerations

### Development vs Production
- **Development Keys**: Current installation uses development keys
- **Production Deployment**: Implement HSM-based signing (Task 18)
- **Key Management**: Proper key rotation and revocation procedures
- **Monitoring**: Implement tamper-evident logging (Task 19)

### Threat Model
- **Physical Access**: Secure Boot + TPM2 protect against Evil Maid attacks
- **Network Attacks**: Per-application network controls limit exposure
- **Privilege Escalation**: SELinux + sandboxing provide defense in depth
- **Supply Chain**: Reproducible builds with SBOM ensure integrity

### Best Practices
1. **Regular Updates**: Keep system updated through secure channels
2. **Backup Strategy**: Maintain secure backups of keys and data
3. **Access Control**: Use principle of least privilege
4. **Monitoring**: Monitor security logs and system behavior
5. **Testing**: Regularly test security features and recovery procedures

---

## 🎯 Quick Start Summary

For experienced users, here's the quick installation process:

```bash
# 1. Prepare environment
git clone <repo> && cd hardened-laptop-os
bash scripts/setup-environment.sh

# 2. Verify hardware
bash scripts/check-uefi.sh && bash scripts/check-tpm2.sh

# 3. Install (WILL WIPE TARGET DEVICE!)
sudo bash scripts/install-hardened-os.sh /dev/sdX

# 4. Reboot and configure
# - Enter LUKS passphrase
# - Complete TPM2 enrollment
# - Set up user accounts
# - Configure applications
```

**Remember**: This will completely wipe the target device. Ensure you have backups and have verified the target device is correct!

---

*Installation Guide for Hardened Laptop OS v1.0.0*
*Last Updated: $(date)*