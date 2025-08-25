# Hardened OS Virtual Machine Installation Guide

## 🎯 **Safe Testing with Virtual Machines**

This guide walks you through installing and testing the Hardened Laptop OS in a virtual machine - completely safe with zero risk to your current system.

## 📋 **Prerequisites**

### **Host System Requirements**
- **OS**: Windows 10/11 (your current system)
- **RAM**: 16GB+ recommended (8GB minimum)
- **Storage**: 100GB+ free space
- **CPU**: Virtualization support (Intel VT-x or AMD-V)
- **Network**: Internet connection for downloads

### **Virtual Machine Software Options**

#### **Option 1: VirtualBox (Free, Recommended)**
- ✅ **Free and open source**
- ✅ **Good UEFI support**
- ✅ **TPM 2.0 emulation**
- ✅ **Easy to use**
- ❌ **Slightly slower performance**

#### **Option 2: VMware Workstation Pro (Paid)**
- ✅ **Better performance**
- ✅ **Excellent hardware emulation**
- ✅ **Professional features**
- ❌ **Requires license ($200+)**

#### **Option 3: Hyper-V (Windows Pro/Enterprise)**
- ✅ **Built into Windows**
- ✅ **Good performance**
- ❌ **Limited UEFI features**
- ❌ **More complex setup**

## 🚀 **Step-by-Step Installation**

### **Phase 1: Setup VirtualBox**

#### **1.1: Download and Install VirtualBox**
```powershell
# Download VirtualBox from official site
# https://www.virtualbox.org/wiki/Downloads

# Install VirtualBox with default settings
# Enable virtualization in BIOS if prompted
```

#### **1.2: Enable Virtualization Features**
1. **Check CPU Virtualization**:
   - Open Task Manager → Performance → CPU
   - Look for "Virtualization: Enabled"
   - If disabled, enable in BIOS/UEFI settings

2. **Windows Features** (if using Hyper-V):
   - Disable Hyper-V if using VirtualBox
   - Control Panel → Programs → Windows Features
   - Uncheck "Hyper-V" and reboot

### **Phase 2: Create Hardened OS VM**

#### **2.1: Create New Virtual Machine**
```
VM Configuration:
- Name: "Hardened-OS-Test"
- Type: Linux
- Version: Debian (64-bit)
- Memory: 8192 MB (8GB) minimum, 16384 MB (16GB) recommended
- Hard Disk: Create new, 80GB minimum, 120GB recommended
- Disk Type: VDI (VirtualBox Disk Image)
- Storage: Dynamically allocated
```

#### **2.2: Configure VM Settings**
```
System Settings:
- Motherboard:
  ✓ Enable EFI (UEFI boot)
  ✓ Hardware Clock in UTC Time
  ✓ Enable I/O APIC
  
- Processor:
  ✓ 4+ CPU cores (if available)
  ✓ Enable PAE/NX
  ✓ Enable VT-x/AMD-V
  
- Acceleration:
  ✓ Enable VT-x/AMD-V
  ✓ Enable Nested Paging

Storage Settings:
- Controller: SATA
- Enable Host I/O Cache
- Enable SSD (if host has SSD)

Network Settings:
- Adapter 1: NAT (for internet access)
- Advanced: Intel PRO/1000 MT Desktop

Security Settings (VirtualBox 7.0+):
- Enable Secure Boot (if available)
- Enable TPM 2.0 (if available)
```

### **Phase 3: Prepare Installation Media**

#### **3.1: Create Debian Live USB (Virtual)**
Since we're in a VM, we'll use ISO files directly:

```powershell
# Download Debian stable netinst ISO
# https://www.debian.org/CD/netinst/

# For testing, we'll use the standard Debian ISO first
# Then apply our hardening scripts after installation
```

#### **3.2: Mount Installation ISO**
1. **In VirtualBox**:
   - VM Settings → Storage
   - Click CD/DVD icon
   - Choose "Choose a disk file"
   - Select downloaded Debian ISO

### **Phase 4: Install Base Debian System**

#### **4.1: Boot VM and Install Debian**
```
Boot Process:
1. Start VM
2. Boot from CD/DVD (Debian ISO)
3. Select "Install" (not graphical install)
4. Follow installation wizard:
   - Language: English
   - Country: Your country
   - Keyboard: Your layout
   - Hostname: hardened-test
   - Domain: (leave blank)
   - Root password: (set strong password)
   - User account: Create regular user
   - Partitioning: Use entire disk, separate /home
   - Software: Standard system utilities only
   - GRUB: Install to master boot record
```

#### **4.2: Initial System Setup**
After Debian installation completes:
```bash
# Login as root and update system
apt update && apt upgrade -y

# Install essential tools
apt install -y git wget curl sudo vim

# Add user to sudo group
usermod -aG sudo username

# Reboot to ensure clean state
reboot
```

### **Phase 5: Install Hardened OS Components**

#### **5.1: Transfer Hardened OS Scripts**
```bash
# Method 1: Git clone (if repository is public)
git clone <hardened-os-repository>
cd hardened-laptop-os

# Method 2: Shared folder (VirtualBox)
# VM Settings → Shared Folders → Add folder
# Mount: sudo mount -t vboxsf SharedFolder /mnt/shared

# Method 3: Copy files via network/USB
```

#### **5.2: Run Hardened OS Installation**
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run pre-installation check
sudo bash scripts/pre-installation-check.sh

# Install Hardened OS components
# Note: Skip disk partitioning since we're in VM
sudo bash scripts/install-hardened-os.sh --vm-mode
```

### **Phase 6: Test Security Features**

#### **6.1: Boot Security Testing**
```bash
# Test UEFI Secure Boot (simulated in VM)
sudo mokutil --sb-state

# Test TPM functionality (if VM supports it)
sudo tpm2_getcap properties-fixed

# Test LUKS encryption
sudo cryptsetup status
```

#### **6.2: Kernel Hardening Testing**
```bash
# Verify hardened kernel
uname -a
cat /proc/version

# Check security features
sudo sysctl kernel.dmesg_restrict
sudo sysctl kernel.kptr_restrict
sudo sysctl kernel.yama.ptrace_scope

# Test exploit mitigations
cat /proc/sys/kernel/randomize_va_space
```

#### **6.3: SELinux Testing**
```bash
# Check SELinux status
sudo getenforce
sudo sestatus

# Test policy enforcement
sudo seinfo
sudo sesearch --allow --source unconfined_t
```

#### **6.4: Application Sandboxing Testing**
```bash
# Test bubblewrap sandboxing
bwrap --version

# Test sandboxed applications
# Install test applications and verify sandboxing
```

#### **6.5: Network Controls Testing**
```bash
# Check nftables rules
sudo nft list ruleset

# Test per-application network controls
# Verify firewall rules are working
```

## 🧪 **Comprehensive Testing Scenarios**

### **Security Feature Testing**
```bash
# Run all validation scripts
bash scripts/validate-task-4.sh   # Secure Boot
bash scripts/validate-task-5.sh   # TPM2
bash scripts/validate-task-6.sh   # Hardened Kernel
bash scripts/validate-task-9.sh   # SELinux
bash scripts/validate-task-12.sh  # Sandboxing
bash scripts/validate-task-13.sh  # Network Controls
bash scripts/validate-task-16.sh  # Rollback
bash scripts/validate-task-17.sh  # Reproducible Builds
```

### **User Experience Testing**
```bash
# Test user onboarding
# Test application installation
# Test security mode switching
# Test recovery procedures
```

### **Performance Testing**
```bash
# Monitor system performance
htop
iotop
nethogs

# Test resource usage under load
stress-ng --cpu 4 --timeout 60s
```

## 📊 **VM vs Real Hardware Differences**

### **What Works in VM**
- ✅ **Kernel hardening** - Full functionality
- ✅ **SELinux enforcement** - Complete testing
- ✅ **Application sandboxing** - Full functionality
- ✅ **Network controls** - Complete testing
- ✅ **Update system** - Full functionality
- ✅ **User interface** - Complete experience

### **What's Limited in VM**
- ⚠️ **TPM 2.0** - Emulated, not real hardware
- ⚠️ **Secure Boot** - Simulated, not real UEFI
- ⚠️ **Hardware security** - CPU features may be limited
- ⚠️ **Performance** - Slower than bare metal
- ⚠️ **Power management** - Different behavior

### **What to Test Separately**
- 🔍 **Hardware compatibility** - WiFi, graphics, audio
- 🔍 **Real TPM behavior** - Actual hardware sealing
- 🔍 **Boot performance** - Real hardware timing
- 🔍 **Power efficiency** - Battery life impact

## 🎯 **VM Testing Checklist**

### **Phase 1: Basic Installation** ✅
- [ ] VM created with proper settings
- [ ] Debian base system installed
- [ ] Network connectivity working
- [ ] User accounts configured

### **Phase 2: Security Components** ✅
- [ ] Hardened kernel installed and booting
- [ ] SELinux enforcing mode active
- [ ] Application sandboxing functional
- [ ] Network controls operational
- [ ] Update system configured

### **Phase 3: Feature Testing** ✅
- [ ] All validation scripts pass
- [ ] Security features work as expected
- [ ] User interface is functional
- [ ] Applications install and run
- [ ] Recovery procedures work

### **Phase 4: Performance Assessment** ✅
- [ ] System performance acceptable
- [ ] Resource usage reasonable
- [ ] No critical errors in logs
- [ ] All core functionality working

## 🚀 **Next Steps After VM Testing**

### **If VM Testing is Successful**
1. **Document any issues** found during testing
2. **Verify hardware compatibility** for your laptop
3. **Create complete backup** of current system
4. **Prepare installation media** for real hardware
5. **Plan installation timeline** with downtime

### **If Issues are Found**
1. **Debug and fix issues** in VM environment
2. **Test fixes thoroughly** before real installation
3. **Consider alternative approaches** if needed
4. **Seek community support** for complex issues

### **Before Real Hardware Installation**
1. **Complete system backup** (cannot be overstated)
2. **Create Windows recovery media**
3. **Document current system configuration**
4. **Verify all preparations complete**
5. **Schedule installation during low-risk time**

## 💡 **Pro Tips for VM Testing**

### **Performance Optimization**
```bash
# Allocate maximum safe RAM to VM
# Use SSD storage for VM files
# Enable hardware acceleration
# Close unnecessary host applications
```

### **Snapshot Management**
```bash
# Take snapshots before major changes
# Name snapshots descriptively
# Test rollback procedures
# Keep clean baseline snapshot
```

### **Testing Methodology**
```bash
# Test one component at a time
# Document all issues and solutions
# Verify fixes don't break other components
# Test edge cases and error conditions
```

## 🎉 **Ready to Start VM Testing?**

You now have a complete guide for safely testing Hardened OS in a virtual machine. This approach will let you:

- ✅ **Experience the full system** without risk
- ✅ **Test all security features** in safe environment
- ✅ **Learn the interface** before committing
- ✅ **Identify potential issues** early
- ✅ **Verify compatibility** with your workflow

Would you like me to help you with any specific part of the VM setup process?

---

*VM Installation Guide for Hardened Laptop OS v1.0.0*
*Safe testing without risk to your current system*