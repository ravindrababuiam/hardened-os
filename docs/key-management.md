# Key Management Documentation

## Overview
This document describes the key hierarchy, usage procedures, and recovery workflows for the Hardened OS development environment.

**⚠️ WARNING: These procedures are for DEVELOPMENT keys only. Production systems require HSM-backed keys and different procedures.**

## Key Hierarchy

### Platform Key (PK)
- **Purpose**: Root of trust for Secure Boot
- **Location**: `~/harden/keys/dev/PK/`
- **Usage**: Self-signs and enrolls other keys
- **Security**: Highest level - controls entire boot chain

### Key Exchange Key (KEK)
- **Purpose**: Intermediate signing authority
- **Location**: `~/harden/keys/dev/KEK/`
- **Usage**: Signs Database (DB) keys and updates
- **Security**: Signed by Platform Key

### Database Key (DB)
- **Purpose**: Signs bootloaders, kernels, and drivers
- **Location**: `~/harden/keys/dev/DB/`
- **Usage**: Day-to-day signing of boot components
- **Security**: Signed by KEK

## Key Generation Procedures

### Initial Key Generation
```bash
# Generate all development keys
./scripts/generate-dev-keys.sh

# Verify key generation
ls -la ~/harden/keys/dev/*/
cat ~/harden/keys/dev/key_metadata.json
```

### Key Enrollment in UEFI
```bash
# Check current Secure Boot status
mokutil --sb-state

# Enroll Platform Key (requires physical presence)
sudo efi-updatevar -f ~/harden/keys/dev/PK/PK.auth PK

# Enroll KEK
sudo efi-updatevar -f ~/harden/keys/dev/KEK/KEK.auth KEK

# Enroll DB key
sudo efi-updatevar -f ~/harden/keys/dev/DB/DB.auth db

# Verify enrollment
efi-readvar -v PK
efi-readvar -v KEK
efi-readvar -v db
```

## Signing Procedures

### Kernel Signing
```bash
# Sign kernel with DB key
sbsign --key ~/harden/keys/dev/DB/DB.key \
       --cert ~/harden/keys/dev/DB/DB.crt \
       --output /boot/vmlinuz-signed \
       /boot/vmlinuz

# Verify signature
sbverify --cert ~/harden/keys/dev/DB/DB.crt /boot/vmlinuz-signed
```

### Bootloader Signing
```bash
# Sign GRUB bootloader
sbsign --key ~/harden/keys/dev/DB/DB.key \
       --cert ~/harden/keys/dev/DB/DB.crt \
       --output /boot/efi/EFI/debian/grubx64.efi.signed \
       /boot/efi/EFI/debian/grubx64.efi
```

### Module Signing
```bash
# Sign kernel modules (during build)
scripts/sign-file sha256 \
    ~/harden/keys/dev/DB/DB.key \
    ~/harden/keys/dev/DB/DB.crt \
    module.ko
```

## Key Backup and Recovery

### Creating Backups
```bash
# Encrypted backup (recommended)
tar -czf - -C ~/harden/keys dev | \
    gpg --symmetric --cipher-algo AES256 \
    --output ~/harden/keys/backup/keys_$(date +%Y%m%d).tar.gz.gpg

# Verify backup
gpg --decrypt ~/harden/keys/backup/keys_$(date +%Y%m%d).tar.gz.gpg | \
    tar -tzf - | head -10
```

### Restoring from Backup
```bash
# Restore encrypted backup
gpg --decrypt ~/harden/keys/backup/keys_YYYYMMDD.tar.gz.gpg | \
    tar -xzf - -C ~/harden/keys/

# Set correct permissions
chmod -R 600 ~/harden/keys/dev/
chmod 700 ~/harden/keys/dev/*/
```

## Key Rotation Procedures

### Emergency Key Rotation
When keys are compromised:

1. **Generate new keys**:
   ```bash
   # Backup old keys
   mv ~/harden/keys/dev ~/harden/keys/dev.old.$(date +%Y%m%d)
   
   # Generate new keys
   ./scripts/generate-dev-keys.sh
   ```

2. **Update UEFI firmware**:
   ```bash
   # Clear old keys (requires physical presence)
   sudo efi-updatevar -f /dev/null PK
   
   # Enroll new keys
   sudo efi-updatevar -f ~/harden/keys/dev/PK/PK.auth PK
   sudo efi-updatevar -f ~/harden/keys/dev/KEK/KEK.auth KEK
   sudo efi-updatevar -f ~/harden/keys/dev/DB/DB.auth db
   ```

3. **Re-sign all components**:
   ```bash
   # Re-sign kernel
   sbsign --key ~/harden/keys/dev/DB/DB.key \
          --cert ~/harden/keys/dev/DB/DB.crt \
          --output /boot/vmlinuz-signed \
          /boot/vmlinuz
   
   # Re-sign bootloader
   sbsign --key ~/harden/keys/dev/DB/DB.key \
          --cert ~/harden/keys/dev/DB/DB.crt \
          --output /boot/efi/EFI/debian/grubx64.efi \
          /boot/efi/EFI/debian/grubx64.efi.unsigned
   ```

### Scheduled Key Rotation
For regular key updates (recommended annually):

1. **Plan rotation window** (requires system downtime)
2. **Generate new keys** with overlapping validity
3. **Test new keys** in development environment
4. **Deploy new keys** during maintenance window
5. **Revoke old keys** after successful deployment

## Security Considerations

### Development vs Production
- **Development keys**: Generated locally, stored on filesystem
- **Production keys**: Generated in HSM, never leave secure hardware
- **Key separation**: Never use development keys in production

### Access Control
- Key files: `chmod 600` (owner read/write only)
- Key directories: `chmod 700` (owner access only)
- Backup encryption: Always encrypt backups with strong passphrase

### Audit Trail
- Log all key operations
- Track key usage and signing events
- Monitor for unauthorized key access

## Troubleshooting

### Common Issues

#### "Verification failed: Invalid signature"
- **Cause**: Wrong key used for signing or key not enrolled
- **Solution**: Verify key enrollment and re-sign with correct key

#### "mokutil: Failed to get Secure Boot state"
- **Cause**: Not running on UEFI system or insufficient privileges
- **Solution**: Ensure UEFI system and run with sudo

#### "Permission denied" accessing keys
- **Cause**: Incorrect file permissions
- **Solution**: Reset permissions with `chmod 600 key_file`

### Recovery Procedures

#### Lost Private Keys
1. Boot from recovery media
2. Disable Secure Boot temporarily
3. Generate new keys
4. Re-enroll and re-sign all components

#### Corrupted Key Database
1. Clear UEFI key database
2. Re-enroll Platform Key (requires physical presence)
3. Re-enroll KEK and DB keys
4. Re-sign all boot components

## References
- [UEFI Specification](https://uefi.org/specifications)
- [Secure Boot Documentation](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)
- [sbctl Documentation](https://github.com/Foxboron/sbctl)
- [efitools Documentation](https://git.kernel.org/pub/scm/linux/kernel/git/jejb/efitools.git)