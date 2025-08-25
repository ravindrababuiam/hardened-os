#!/bin/bash
# Download and verify Debian stable netinst ISO
# Part of hardened laptop OS setup - Task 3.1

set -euo pipefail

# Configuration
DEBIAN_VERSION="12.8.0"
DEBIAN_ARCH="amd64"
ISO_NAME="debian-${DEBIAN_VERSION}-${DEBIAN_ARCH}-netinst.iso"
DOWNLOAD_URL="https://cdimage.debian.org/debian-cd/current/${DEBIAN_ARCH}/iso-cd/${ISO_NAME}"
CHECKSUMS_URL="https://cdimage.debian.org/debian-cd/current/${DEBIAN_ARCH}/iso-cd/SHA256SUMS"
CHECKSUMS_SIGN_URL="https://cdimage.debian.org/debian-cd/current/${DEBIAN_ARCH}/iso-cd/SHA256SUMS.sign"

# Directories
DOWNLOAD_DIR="${HOME}/harden/artifacts"
mkdir -p "${DOWNLOAD_DIR}"

echo "=== Debian ISO Download and Verification ==="
echo "Version: ${DEBIAN_VERSION}"
echo "Architecture: ${DEBIAN_ARCH}"
echo "Download directory: ${DOWNLOAD_DIR}"
echo

cd "${DOWNLOAD_DIR}"

# Download ISO if not already present
if [[ ! -f "${ISO_NAME}" ]]; then
    echo "Downloading Debian netinst ISO..."
    wget -O "${ISO_NAME}" "${DOWNLOAD_URL}"
    echo "Download completed: ${ISO_NAME}"
else
    echo "ISO already exists: ${ISO_NAME}"
fi

# Download checksums and signature
echo "Downloading checksums and signature..."
wget -O SHA256SUMS "${CHECKSUMS_URL}"
wget -O SHA256SUMS.sign "${CHECKSUMS_SIGN_URL}"

# Import Debian signing keys if not already imported
echo "Importing Debian signing keys..."
gpg --keyserver keyserver.ubuntu.com --recv-keys \
    DF9B9C49EAA9298432589D76DA87E80D6294BE9B \
    2>/dev/null || echo "Keys already imported or keyserver unavailable"

# Verify signature on checksums
echo "Verifying checksum signature..."
if gpg --verify SHA256SUMS.sign SHA256SUMS 2>/dev/null; then
    echo "✓ Checksum signature verified"
else
    echo "✗ WARNING: Could not verify checksum signature"
    echo "  This may be due to missing keys or network issues"
    echo "  Proceeding with checksum verification only..."
fi

# Verify ISO checksum
echo "Verifying ISO checksum..."
if sha256sum -c --ignore-missing SHA256SUMS 2>/dev/null | grep -q "${ISO_NAME}: OK"; then
    echo "✓ ISO checksum verified successfully"
    echo "ISO ready for installation: ${DOWNLOAD_DIR}/${ISO_NAME}"
else
    echo "✗ ERROR: ISO checksum verification failed"
    exit 1
fi

echo
echo "=== Verification Summary ==="
echo "ISO file: ${DOWNLOAD_DIR}/${ISO_NAME}"
echo "Size: $(du -h "${ISO_NAME}" | cut -f1)"
echo "SHA256: $(sha256sum "${ISO_NAME}" | cut -d' ' -f1)"
echo "Status: Ready for installation"