# VirtualBox Deployment Guide for Hardened Laptop OS

## 🖥️ VirtualBox-Specific Setup

### VM Configuration Requirements

#### Minimum VM Settings
- **CPU**: 2-4 cores with VT-x/AMD-V enabled
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 50GB minimum, 100GB recommended
- **Network**: NAT or Bridged (for package downloads)

#### Required VirtualBox Settings
```bash
# Enable virtualization features
VBoxManage modifyvm "YourVMName" --nested-hw-virt on
VBoxManage modifyvm "YourVMName" --vtxvpid on
VBoxManage modifyvm "YourVMName" --vtxux on

# Enable TPM 2.0 (VirtualBox 6.1+)
VBoxManage modifyvm "YourVMName" --tpm-type 2.0
VBoxManage modifyvm "YourVMName" --tpm-location /path/to/tpm

# Enable UEFI
VBoxManage modifyvm "YourVMName" --firmware efi
VBoxManage modifyvm "YourVMName" --secure-boot on
```

### Pre-Deployment Setup

#### 1. Update VirtualBox Guest Additions
```bash
sudo apt update
sudo apt install -y build-essential dkms linux-headers-$(uname -r)
# Insert Guest Additions CD and install
```

#### 2. Enable Virtualization Features
```bash
# Check if virtualization is available
grep -E "(vmx|svm)" /proc/cpuinfo

# Check if nested virtualization is enabled
cat /sys/module/kvm_intel/parameters/nested  # Should show 'Y'
```

## 🚀 VirtualBox Deployment Process

### Step 1: Fix Permissions and Prepare
```bash
cd ~/Documents/hardened-os

# Fix permissions
chmod +x fix-permissions-and-deploy.sh
./fix-permissions-and-deploy.sh

# Check available disks in VM
lsblk
```

### Step 2: VirtualBox-Specific Deployment
```bash
# Run with VirtualBox-friendly options
sudo ./deploy-hardened-os.sh \
    --mode full \
    --target /dev/sda \
    --skip-hardware-check \
    --dry-run

# If dry-run looks good, run actual deployment
sudo ./deploy-hardened-os.sh \
    --mode full \
    --target /dev/sda \
    --skip-hardware-check
```

### Step 3: Post-Deployment Configuration
```bash
# Verify deployment
sudo ./scripts/verify-deployment.sh

# Test components
sudo ./hardened-os/logging/test-logging-system.sh
sudo ./hardened-os/incident-response/test-incident-response.sh
```

## ⚠️ VirtualBox Limitations and Workarounds

### TPM 2.0 Simulation
If VirtualBox doesn't have TPM 2.0:
```bash
# Use software TPM simulation
sudo apt install swtpm swtpm-tools
sudo mkdir -p /var/lib/swtpm-localca
sudo swtpm_setup --tpm2 --tpmstate /tmp/swtpm --create-ek-cert --create-platform-cert --lock-nvram
```

### UEFI Secure Boot Limitations
```bash
# VirtualBox may not support custom Secure Boot keys
# The deployment will detect this and use development mode
```

### Hardware Security Features
Some features may be limited in VirtualBox:
- TPM 2.0 may be simulated
- Hardware random number generator may not be available
- Some CPU security features may not be exposed

## 🔧 VirtualBox-Specific Fixes

### Fix 1: Missing TPM Device
```bash
# Create mock TPM device for testing
sudo mkdir -p /dev
sudo mknod /dev/tpm0 c 10 224
sudo chmod 666 /dev/tpm0
```

### Fix 2: UEFI Variables Access
```bash
# Mount efivarfs if not available
sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars
```

### Fix 3: Virtualization Detection
```bash
# Some scripts may detect VirtualBox and adjust behavior
export HARDENED_OS_VIRT_MODE="virtualbox"
```

## 📋 VirtualBox Testing Checklist

### Before Deployment
- [ ] VM has sufficient resources (4GB+ RAM, 50GB+ disk)
- [ ] Virtualization features enabled in VM settings
- [ ] Network connectivity for package downloads
- [ ] Guest Additions installed and working

### During Deployment
- [ ] Monitor deployment progress in terminal
- [ ] Check for any VirtualBox-specific warnings
- [ ] Verify network connectivity remains stable
- [ ] Watch for disk space usage

### After Deployment
- [ ] Run verification script
- [ ] Test boot process
- [ ] Verify security features are working
- [ ] Check system performance

## 🐛 Common VirtualBox Issues

### Issue 1: "TPM not found"
**Solution:**
```bash
# Use skip hardware check option
sudo ./deploy-hardened-os.sh --mode full --target /dev/sda --skip-hardware-check
```

### Issue 2: "UEFI variables not accessible"
**Solution:**
```bash
# Mount efivarfs manually
sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars
```

### Issue 3: "Insufficient disk space"
**Solution:**
```bash
# Clean up package cache
sudo apt clean
sudo apt autoremove

# Or expand VM disk in VirtualBox settings
```

### Issue 4: "Network connectivity issues"
**Solution:**
```bash
# Check network configuration
ip addr show
ping -c 3 8.8.8.8

# Restart networking if needed
sudo systemctl restart networking
```

## 🎯 VirtualBox Performance Tips

### Optimize VM Performance
```bash
# Increase VM memory if possible
# Enable hardware acceleration
# Use SSD storage for VM files
# Disable unnecessary services
```

### Monitor Resource Usage
```bash
# Check memory usage
free -h

# Check disk usage
df -h

# Monitor CPU usage
top
```

## 🔍 VirtualBox-Specific Verification

### Check Virtualization Features
```bash
# Verify nested virtualization
cat /proc/cpuinfo | grep -E "(vmx|svm)"

# Check KVM availability
ls -la /dev/kvm

# Verify UEFI boot
ls -la /sys/firmware/efi
```

### Test Security Features
```bash
# Test TPM (may be simulated)
sudo tpm2_getcap properties-fixed

# Check Secure Boot status
sudo mokutil --sb-state

# Verify disk encryption
sudo cryptsetup status
```

## 📊 Expected Results in VirtualBox

### What Will Work Fully
- ✅ Debian base system installation
- ✅ Hardened kernel compilation and installation
- ✅ SELinux enforcing mode
- ✅ Application sandboxing
- ✅ Network security controls
- ✅ Logging and monitoring systems
- ✅ Incident response framework

### What May Be Limited
- ⚠️ TPM 2.0 (simulated, not hardware)
- ⚠️ UEFI Secure Boot (may use development keys)
- ⚠️ Hardware security features (CPU-specific)
- ⚠️ Performance (virtualization overhead)

### What Will Be Simulated
- 🔄 TPM 2.0 operations (software simulation)
- 🔄 Hardware random number generation
- 🔄 Some CPU security features

## 🎉 Success Indicators

After successful deployment in VirtualBox:

```bash
# System should boot with hardened kernel
uname -a

# SELinux should be enforcing
sestatus

# Encryption should be active
lsblk

# Security services should be running
systemctl status hardened-os-monitor
```

## 🚀 Next Steps After VirtualBox Testing

1. **Validate all features work in VM**
2. **Test recovery procedures**
3. **Document any VirtualBox-specific issues**
4. **Prepare for bare metal deployment**
5. **Create VM snapshots for testing**

---

**VirtualBox is perfect for:**
- 🧪 Testing and development
- 📚 Learning the system
- 🔍 Security research
- 🎓 Training and education
- 🐛 Bug reproduction and fixes

**Ready to deploy in VirtualBox!** 🚀