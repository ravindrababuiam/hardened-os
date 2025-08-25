# Task 3: Debian Base System Installation

## Overview

This document describes the implementation of Task 3: "Set up Debian stable base system with custom partitioning" from the hardened laptop OS specification.

## Requirements Addressed

- **3.1**: Full disk encryption for all storage
- **3.2**: LUKS2 with secure key derivation parameters (1GB memory, 4 iterations)
- **3.3**: Root filesystem and swap encryption using LUKS2 with Argon2id KDF
- **3.4**: Custom partition layout: 512MB EFI + 1GB recovery + encrypted LVM root/swap

## Implementation Components

### 1. Scripts Created

#### `scripts/download-debian-iso.sh`
- Downloads Debian stable netinst ISO
- Verifies cryptographic signatures and checksums
- Ensures authentic installation media

#### `scripts/create-partition-layout.sh`
- Creates GPT partition table
- Sets up 512MB EFI System Partition (FAT32)
- Creates 1GB recovery partition (ext4)
- Allocates remaining space for LUKS2 container

#### `scripts/setup-luks2-encryption.sh`
- Configures LUKS2 with Argon2id KDF
- Uses 1GB memory and 4 iterations as specified
- Sets up LVM inside encrypted container
- Creates root, swap, and home logical volumes

#### `scripts/install-debian-base.sh`
- Orchestrates the complete installation process
- Installs Debian base system with essential packages
- Configures system files (fstab, crypttab, etc.)
- Sets up user account and basic security

#### `scripts/validate-debian-installation.sh`
- Validates all Task 3 requirements are met
- Checks partition layout, LUKS2 configuration, LVM setup
- Verifies filesystem types and system configuration
- Generates validation report

### 2. Configuration Files

#### `configs/debian-preseed.cfg`
- Automated installation configuration
- Hardened package selection
- Security-focused defaults
- LUKS2 and LVM configuration

## Partition Layout

```
/dev/sda1  512MB   EFI System Partition (FAT32, unencrypted)
/dev/sda2  1GB     Recovery Partition (ext4, unencrypted)
/dev/sda3  Rest    LUKS2 Encrypted Container
  └─ hardened-vg (LVM Volume Group)
     ├─ root (40% of space, ext4, mounted at /)
     ├─ swap (10% of space, swap)
     └─ home (50% of space, ext4, mounted at /home)
```

## LUKS2 Configuration

- **Cipher**: AES-256-XTS
- **Key Derivation Function**: Argon2id
- **Memory**: 1GB (1,048,576 KB)
- **Iterations**: 4
- **Hash**: SHA-256
- **Key Size**: 512 bits

## Security Features Implemented

### Encryption
- Full disk encryption except for EFI and recovery partitions
- Strong key derivation parameters resistant to brute force
- Hardware-accelerated AES where available

### Partition Security
- Separate recovery partition for system restoration
- LVM for flexible storage management
- Encrypted swap to prevent memory dumps

### Package Hardening
- Minimal package installation
- Security-focused package selection
- Essential hardening tools included

## Usage Instructions

### Prerequisites
- Target system with UEFI firmware and TPM2
- Ubuntu/Debian build host with required tools
- Internet connection for package downloads

### Installation Process

1. **Prepare Environment**
   ```bash
   # Create directory structure
   mkdir -p ~/harden/{src,keys,build,ci,artifacts}
   
   # Install required tools
   sudo apt update
   sudo apt install -y parted cryptsetup lvm2 debootstrap wget gnupg
   ```

2. **Run Installation**
   ```bash
   # Make scripts executable (on Linux)
   chmod +x scripts/*.sh
   
   # Run complete installation (WARNING: Destructive!)
   sudo ./scripts/install-debian-base.sh /dev/sda
   ```

3. **Validate Installation**
   ```bash
   # After reboot, validate the installation
   sudo ./scripts/validate-debian-installation.sh /dev/sda
   ```

### Manual Installation Steps

If you prefer manual installation or need to customize:

1. **Download and Verify ISO**
   ```bash
   ./scripts/download-debian-iso.sh
   ```

2. **Create Partition Layout**
   ```bash
   sudo ./scripts/create-partition-layout.sh /dev/sda
   ```

3. **Setup LUKS2 Encryption**
   ```bash
   sudo ./scripts/setup-luks2-encryption.sh /dev/sda3
   ```

4. **Continue with base installation...**

## Validation Criteria

The installation is considered successful when:

- ✅ GPT partition table with correct layout
- ✅ LUKS2 container with Argon2id KDF (1GB memory, 4 iterations)
- ✅ LVM volume group with root, swap, and home volumes
- ✅ Proper filesystem types (FAT32 for EFI, ext4 for others)
- ✅ System configuration files (fstab, crypttab) properly configured
- ✅ Essential packages installed and configured
- ✅ GRUB bootloader installed and configured for LUKS

## Security Considerations

### Implemented Protections
- Strong encryption with modern algorithms
- Secure key derivation resistant to GPU attacks
- Minimal attack surface through package selection
- Separate recovery partition for system restoration

### Known Limitations
- EFI and recovery partitions remain unencrypted (by design)
- Temporary password used during installation (must be changed)
- Development keys used (production deployment needs HSM keys)

## Next Steps

After successful completion of Task 3:

1. **Task 4**: Implement UEFI Secure Boot with custom keys
2. **Task 5**: Configure TPM2 measured boot and key sealing
3. **Task 6**: Build hardened kernel with KSPP configuration

## Troubleshooting

### Common Issues

1. **TPM2 Not Available**
   - Ensure TPM2 is enabled in UEFI firmware
   - Install tpm2-tools package
   - Check `/dev/tpm0` exists

2. **LUKS Unlock Fails**
   - Verify correct passphrase
   - Check PCR values haven't changed
   - Use recovery passphrase if TPM sealing fails

3. **Boot Failures**
   - Boot from recovery partition
   - Check GRUB configuration
   - Verify initramfs includes cryptsetup

### Log Files
- Installation log: `/var/log/hardened-validation.log`
- System logs: `journalctl -b`
- LUKS status: `cryptsetup status hardened-crypt`

## References

- [Debian Installation Guide](https://www.debian.org/releases/stable/installmanual/)
- [LUKS2 Documentation](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/LUKS-standard/on-disk-format.pdf)
- [Argon2 Specification](https://tools.ietf.org/html/rfc9106)
- [LVM HOWTO](https://tldp.org/HOWTO/LVM-HOWTO/)