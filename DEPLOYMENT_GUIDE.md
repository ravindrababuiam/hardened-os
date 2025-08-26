# Hardened Laptop OS - Production Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the complete Hardened Laptop OS system in production environments. The system implements GrapheneOS-level security for laptop computing with comprehensive hardening features.

## Prerequisites

### Hardware Requirements

#### Build Host (Ubuntu LTS)
- **CPU**: x86_64 with virtualization support (Intel VT-x/AMD-V)
- **RAM**: 16-64GB (minimum 16GB for kernel compilation)
- **Storage**: 250+ GB SSD
- **Network**: Internet connection for package downloads
- **OS**: Ubuntu LTS 22.04 or later

#### Target Laptop
- **Architecture**: x86_64 (Intel/AMD 64-bit)
- **UEFI**: UEFI firmware with Secure Boot support
- **TPM**: TPM 2.0 chip (required for measured boot)
- **Storage**: NVMe SSD recommended (minimum 128GB)
- **RAM**: 8GB minimum, 16GB+ recommended

### Software Prerequisites
- Ubuntu LTS 22.04+ on build host
- Root access on both build host and target system
- Internet connection for initial setup

## Deployment Options

### Option 1: Full Automated Deployment (Recommended)
Complete system deployment with all security features enabled.

### Option 2: Staged Deployment
Deploy components incrementally for testing and validation.

### Option 3: Custom Deployment
Select specific security features based on requirements.

## Quick Start - Full Deployment

### Step 1: Clone and Prepare
```bash
# Clone the repository
git clone <repository-url> hardened-laptop-os
cd hardened-laptop-os

# Make deployment script executable
chmod +x deploy-hardened-os.sh

# Run full deployment
sudo ./deploy-hardened-os.sh --mode full --target /dev/sda
```

### Step 2: Hardware Configuration
```bash
# Configure UEFI settings (run before installation)
sudo ./scripts/configure-uefi-settings.sh

# Verify hardware compatibility
sudo ./scripts/verify-hardware-compatibility.sh
```

### Step 3: System Installation
```bash
# Install base Debian system with hardening
sudo ./scripts/install-hardened-os.sh

# Configure security features
sudo ./scripts/configure-all-security-features.sh
```

### Step 4: Verification
```bash
# Run comprehensive system tests
sudo ./scripts/run-deployment-tests.sh

# Verify security configuration
sudo ./scripts/verify-security-configuration.sh
```

## Detailed Deployment Steps

### Phase 1: Environment Preparation

#### 1.1 Build Host Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build dependencies
sudo apt install -y git build-essential clang gcc python3 make cmake \
    qemu-kvm libvirt-daemon-system virt-manager \
    cryptsetup tpm2-tools efibootmgr sbctl \
    debootstrap squashfs-tools

# Create build environment
mkdir -p ~/harden/{src,keys,build,ci,artifacts}
chmod 700 ~/harden/keys
```

#### 1.2 Target Hardware Verification
```bash
# Check UEFI support
sudo ./scripts/check-uefi.sh

# Verify TPM 2.0
sudo ./scripts/check-tpm2.sh

# Check system resources
sudo ./scripts/check-resources.sh
```

### Phase 2: Security Infrastructure Setup

#### 2.1 Cryptographic Keys
```bash
# Generate development keys
sudo ./scripts/key-manager.sh generate-dev-keys

# Set up HSM infrastructure (for production)
sudo ./scripts/setup-hsm-infrastructure.sh

# Configure key rotation
sudo ./scripts/production-key-rotation.sh check HardenedOS-Dev 1234
```

#### 2.2 Secure Boot Configuration
```bash
# Set up UEFI Secure Boot
sudo ./scripts/setup-secure-boot.sh

# Configure TPM2 measured boot
sudo ./scripts/setup-tpm2-measured-boot.sh
```

### Phase 3: Base System Installation

#### 3.1 Debian Base System
```bash
# Download and verify Debian ISO
sudo ./scripts/download-debian-iso.sh

# Create partition layout
sudo ./scripts/create-partition-layout.sh /dev/sda

# Set up LUKS2 encryption
sudo ./scripts/setup-luks2-encryption.sh /dev/sda2

# Install Debian base
sudo ./scripts/install-debian-base.sh
```

#### 3.2 Kernel Hardening
```bash
# Build hardened kernel
sudo ./scripts/build-hardened-kernel.sh

# Create signed kernel packages
sudo ./scripts/create-signed-kernel-packages.sh

# Configure compiler hardening
sudo ./scripts/setup-compiler-hardening.sh
```

### Phase 4: Security Layer Configuration

#### 4.1 Mandatory Access Control
```bash
# Configure SELinux enforcing mode
sudo ./scripts/setup-selinux-enforcing-fixed.sh

# Set up minimal services
sudo ./scripts/setup-minimal-services.sh

# Configure userspace hardening
sudo ./scripts/setup-userspace-hardening.sh
```

#### 4.2 Application Security
```bash
# Set up bubblewrap sandboxing
sudo ./scripts/setup-bubblewrap-sandboxing.sh

# Configure network controls
sudo ./scripts/setup-network-controls.sh

# Set up user onboarding
sudo ./scripts/setup-user-onboarding.sh
```

### Phase 5: Update and Supply Chain Security

#### 5.1 Secure Updates
```bash
# Configure secure update system
sudo ./scripts/setup-secure-updates.sh
sudo ./scripts/setup-secure-updates-part2.sh

# Set up automatic rollback
sudo ./scripts/setup-automatic-rollback.sh

# Configure reproducible builds
sudo ./scripts/setup-reproducible-builds-complete.sh
```

### Phase 6: Production Features

#### 6.1 Logging and Monitoring
```bash
# Install tamper-evident logging
cd hardened-os/logging
sudo ./install-logging-system.sh
```

#### 6.2 Incident Response
```bash
# Install incident response framework
cd ../incident-response
sudo ./install-incident-response.sh
```

## Deployment Verification

### Security Feature Verification
```bash
# Verify boot security
sudo sbctl verify
sudo tpm2_pcrread

# Check SELinux status
sudo sestatus

# Verify encryption
sudo cryptsetup luksDump /dev/sda2

# Test sandboxing
sudo systemctl status bubblewrap-sandbox@browser.service

# Check logging integrity
sudo journalctl --verify
```

### System Health Checks
```bash
# Run comprehensive tests
cd hardened-os/logging
sudo ./test-logging-system.sh

cd ../incident-response
sudo ./test-incident-response.sh

# Verify documentation
cd ../documentation
sudo ./test-documentation-simple.sh
```

## Production Considerations

### Security Hardening Checklist
- [ ] UEFI Secure Boot enabled with custom keys
- [ ] TPM 2.0 measured boot configured
- [ ] Full disk encryption with LUKS2
- [ ] SELinux in enforcing mode
- [ ] Minimal services running
- [ ] Application sandboxing active
- [ ] Network controls configured
- [ ] Secure updates enabled
- [ ] Logging system operational
- [ ] Incident response ready

### Performance Optimization
```bash
# Optimize boot time
sudo systemctl disable unnecessary-service

# Configure memory settings
echo 'vm.swappiness=10' >> /etc/sysctl.conf

# Optimize SSD performance
echo 'elevator=noop' >> /etc/default/grub
```

### Backup and Recovery
```bash
# Create system recovery point
sudo ./hardened-os/incident-response/recovery-procedures.sh create "post-deployment"

# Backup encryption keys
sudo cp /etc/luks-keys/* /secure-backup/

# Test recovery procedures
sudo ./hardened-os/incident-response/recovery-procedures.sh test
```

## Troubleshooting

### Common Issues

#### Boot Problems
```bash
# Check Secure Boot status
sudo mokutil --sb-state

# Verify TPM measurements
sudo tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements

# Test recovery boot
sudo systemctl reboot --boot-loader-entry=recovery
```

#### SELinux Issues
```bash
# Check denials
sudo ausearch -m avc -ts recent

# Generate policy
sudo audit2allow -M local_policy < /var/log/audit/audit.log
```

#### Network Problems
```bash
# Check firewall rules
sudo nft list ruleset

# Verify DNS configuration
sudo systemd-resolve --status
```

### Emergency Recovery
```bash
# Emergency system lockdown
sudo /usr/local/bin/emergency-lockdown

# Boot from recovery partition
# (Select recovery option in GRUB menu)

# Restore from backup
sudo ./hardened-os/incident-response/recovery-procedures.sh restore /backup/recovery-point
```

## Maintenance

### Regular Tasks
```bash
# Weekly security updates
sudo apt update && sudo apt upgrade

# Monthly key rotation check
sudo ./scripts/production-key-rotation.sh check HardenedOS-Prod $HSM_PIN

# Quarterly security audit
sudo ./scripts/security-audit.sh

# Log integrity verification
sudo journalctl --verify
```

### Monitoring
```bash
# Check system health
sudo systemctl status hardened-os-monitor

# Review security events
sudo /usr/local/bin/analyze-security-events

# Monitor log integrity
sudo /usr/local/bin/monitor-log-integrity
```

## Support and Documentation

### Documentation Locations
- **Installation Guide**: `hardened-os/documentation/INSTALLATION_GUIDE.md`
- **User Guide**: `hardened-os/documentation/USER_GUIDE.md`
- **Security Guide**: `hardened-os/documentation/SECURITY_GUIDE.md`
- **Troubleshooting**: `hardened-os/documentation/TROUBLESHOOTING_GUIDE.md`

### Getting Help
- **GitHub Issues**: Report bugs and feature requests
- **Security Issues**: security@example.com
- **Community Forum**: community.hardened-os.org
- **Professional Support**: support@hardened-os.com

## Compliance and Certification

### Standards Compliance
- **NIST 800-171**: Defense contractor requirements
- **Common Criteria**: EAL4+ evaluation
- **FIPS 140-2**: Cryptographic module validation
- **ISO 27001**: Information security management

### Audit Support
- Comprehensive audit logs
- Tamper-evident logging
- Cryptographic integrity verification
- Incident response documentation

---

**Deployment Status**: Ready for production deployment with comprehensive security features and enterprise-grade hardening.