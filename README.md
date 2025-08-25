# Hardened Laptop OS - Development Environment

## Project Overview

This project implements a production-grade hardened laptop operating system with GrapheneOS-level security principles applied to laptop computing. The system provides comprehensive security hardening including UEFI Secure Boot, TPM2 integration, full disk encryption, hardened kernel configuration, mandatory access controls, and secure update mechanisms.

## Development Environment Status

✅ **Task 1 Complete**: Bootstrap development environment and workspace

### Directory Structure Created

```
~/harden/                    # Main development workspace
├── src/                     # Source code repositories
├── keys/                    # Signing keys (secure permissions)
├── build/                   # Build outputs and temporary files  
├── ci/                      # CI/CD scripts and configurations
└── artifacts/               # Final build artifacts (ISOs, packages)
```

### Setup Scripts Available

- `scripts/setup-environment.sh` - Complete Ubuntu LTS environment setup
- `scripts/check-tpm2.sh` - Verify TPM2 hardware availability
- `scripts/check-uefi.sh` - Verify UEFI and Secure Boot support
- `scripts/check-resources.sh` - Verify system meets hardware requirements
- `scripts/check-all.sh` - Run all verification checks

### Documentation

- `setup-dev-environment.md` - Detailed Ubuntu setup instructions
- `setup-windows-dev.md` - Windows development environment options
- `README.md` - This file

## Hardware Requirements

### Build Host (Ubuntu LTS)
- **RAM**: 16-64GB (minimum 16GB for kernel compilation)
- **Storage**: 250+ GB SSD
- **CPU**: x86_64 with virtualization support
- **OS**: Ubuntu LTS 22.04 or later

### Target Laptop
- **Architecture**: x86_64 (Intel/AMD 64-bit)
- **UEFI**: UEFI firmware with Secure Boot support
- **TPM**: TPM 2.0 chip (required for measured boot)
- **Storage**: NVMe SSD recommended

## Quick Start

### For Ubuntu/Linux Users

1. **Run the setup script**:
   ```bash
   chmod +x scripts/setup-environment.sh
   ./scripts/setup-environment.sh
   ```

2. **Log out and back in** to apply group membership changes

3. **Load the development environment**:
   ```bash
   source ~/harden/.env
   ```

4. **Verify hardware compatibility**:
   ```bash
   ./scripts/check-all.sh
   ```

### For Windows Users

1. **Review Windows setup options**: `setup-windows-dev.md`
2. **Install WSL2 with Ubuntu** (recommended)
3. **Follow Ubuntu setup steps** in WSL2 environment

## Required Tools Installed

- **Core**: git, clang, gcc, python3, make, cmake
- **Kernel**: libncurses-dev, flex, bison, libssl-dev, libelf-dev
- **Virtualization**: qemu-kvm, libvirt, virt-manager
- **Security**: cryptsetup, tpm2-tools, efibootmgr, sbctl
- **Containers**: docker, debootstrap, squashfs-tools

## Next Steps

With the development environment bootstrapped, proceed to:

**Task 2**: Create development signing keys and recovery infrastructure
- Generate Platform Keys (PK), Key Exchange Keys (KEK), and Database (DB) keys
- Set up secure key storage with proper permissions
- Create signed recovery partition and fallback kernel
- Document key hierarchy and recovery procedures

## Security Notes

- The `~/harden/keys` directory has restricted permissions (700)
- Development keys are separate from production keys
- All build processes should use isolated environments
- Regular backups of the development environment are recommended

## Project Structure

This workspace follows the milestone-based implementation plan:

- **M1**: Boot Security Foundation (Tasks 1-5)
- **M2**: Kernel Hardening & MAC (Tasks 6-11)  
- **M3**: Application Security (Tasks 12-14)
- **M4**: Updates & Supply Chain (Tasks 15-17)
- **M5**: Production & Documentation (Tasks 18-21)
- **M6**: Advanced Features (Tasks 22-25)

## Support

- Review `setup-dev-environment.md` for detailed setup instructions
- Check hardware compatibility with verification scripts
- Ensure all requirements are met before proceeding to implementation tasks

---

**Status**: Development environment ready for Task 2 implementation
**Next**: Create development signing keys and recovery infrastructure