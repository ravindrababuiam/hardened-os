# Configuration Files for Hardened Laptop OS

This directory contains configuration files for the hardened laptop OS installation.

## Files

### debian-preseed.cfg
Automated installation configuration for Debian stable with:
- LUKS2 full disk encryption
- Custom partition layout
- Hardened package selection
- Security-focused defaults

## Usage

These configuration files are used by the installation scripts in the `scripts/` directory.

See the main installation script: `scripts/install-debian-base.sh`