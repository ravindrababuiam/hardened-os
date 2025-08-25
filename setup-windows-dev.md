# Hardened Laptop OS - Windows Development Setup

## Overview

Since you're currently on Windows, this document provides instructions for setting up a development environment to work on the Hardened Laptop OS project. The actual target system will be Ubuntu LTS, but development can be prepared on Windows.

## Current Environment Status

✓ Directory structure created at: `%USERPROFILE%\harden\`
- src/        - Source code repositories  
- keys/       - Signing keys (development and production)
- build/      - Build outputs and temporary files
- ci/         - CI/CD scripts and configurations
- artifacts/  - Final build artifacts (ISOs, packages)

## Development Options

### Option 1: WSL2 (Recommended)

Install Windows Subsystem for Linux 2 with Ubuntu:

```powershell
# Enable WSL2
wsl --install -d Ubuntu-22.04

# After installation, update and install tools
wsl -d Ubuntu-22.04
sudo apt update
sudo apt install -y git build-essential clang gcc python3 make cmake
```

### Option 2: Virtual Machine

Set up Ubuntu LTS in a VM with:
- **Hyper-V** (Windows Pro/Enterprise)
- **VMware Workstation**  
- **VirtualBox**

VM Requirements:
- 16+ GB RAM allocated
- 250+ GB disk space
- Enable virtualization passthrough
- Enable TPM 2.0 in VM settings

### Option 3: Dual Boot

Install Ubuntu LTS alongside Windows for native performance.

## Cross-Platform Development Tools

### Git Configuration
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global init.defaultBranch main
```

### Code Editor Setup
- **VS Code** with Remote-WSL extension
- **CLion** or **Visual Studio** for C/C++ development
- **Vim/Neovim** for terminal-based editing

## Project Structure

The scripts created are designed for Ubuntu/Linux environments:

- `scripts/setup-environment.sh` - Complete Ubuntu setup
- `scripts/check-tpm2.sh` - TPM2 hardware verification
- `scripts/check-uefi.sh` - UEFI/Secure Boot verification  
- `scripts/check-resources.sh` - System resource verification
- `setup-dev-environment.md` - Detailed Ubuntu setup guide

## Next Steps

1. **Choose development approach** (WSL2 recommended)
2. **Set up Ubuntu environment** using provided scripts
3. **Run hardware verification** on target laptop
4. **Proceed to task 2** - Create development signing keys

## Windows-Specific Notes

- The hardened OS targets x86_64 laptops with TPM2 and UEFI
- Development requires Linux toolchain (kernel compilation, etc.)
- Testing will require QEMU/KVM or physical hardware
- Cross-compilation from Windows is complex and not recommended

## Verification Checklist

Before proceeding to Ubuntu setup:

- [ ] Target laptop has TPM 2.0 chip
- [ ] Target laptop has UEFI firmware (not Legacy BIOS)
- [ ] Target laptop is x86_64 architecture
- [ ] Development machine has sufficient resources (16+ GB RAM, 250+ GB storage)
- [ ] Ubuntu LTS environment available (WSL2, VM, or dual boot)

## Security Considerations

- Keep development and production keys separate
- Use secure key storage (hardware tokens recommended)
- Regularly backup development environment
- Follow principle of least privilege for development access

The actual hardened OS development must be done in a Linux environment due to kernel compilation requirements and security tooling dependencies.