# VM Testing Guide for Hardened Laptop OS

## 🎯 **Current Status: Debian VM Ready**

Great! You have VirtualBox with Debian installed. Now let's test all the hardened OS components we've implemented (Tasks 1-18) in your safe VM environment.

## 📋 **Pre-Testing Setup**

### **Step 1: Prepare Your VM**

First, let's get your Debian VM ready for testing:

```bash
# Login to your Debian VM and run these commands:

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y git wget curl sudo vim build-essential

# Install development tools needed for our scripts
sudo apt install -y python3 python3-pip bash-completion

# Create working directory
mkdir -p ~/hardened-os-test
cd ~/hardened-os-test
```

### **Step 2: Transfer Hardened OS Files to VM**

You have several options to get our scripts into the VM:

#### **Option A: Shared Folder (Recommended)**
1. In VirtualBox: VM Settings → Shared Folders
2. Add your Windows project folder as shared folder
3. In VM:
```bash
# Install VirtualBox Guest Additions first
sudo apt install -y virtualbox-guest-additions-iso
sudo mount /dev/cdrom /mnt
sudo /mnt/VBoxLinuxAdditions.run

# Mount shared folder
sudo mkdir -p /mnt/shared
sudo mount -t vboxsf YourSharedFolderName /mnt/shared

# Copy files to VM
cp -r /mnt/shared/* ~/hardened-os-test/
```

#### **Option B: Git Clone (If you have repository)**
```bash
# If you've pushed to a git repository
git clone <your-repository-url> ~/hardened-os-test
```

#### **Option C: Manual File Transfer**
```bash
# Use SCP, SFTP, or copy-paste for smaller files
# Enable SSH in VM first:
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

## 🧪 **Testing Phase 1: Environment Setup (Tasks 1-3)**

### **Test 1: Development Environment**
```bash
cd ~/hardened-os-test

# Make scripts executable
chmod +x scripts/*.sh

# Test environment setup
bash scripts/setup-environment.sh

# Verify tools are installed
which git clang gcc python3 make cmake
```

### **Test 2: Key Management Infrastructure**
```bash
# Test development key generation
bash scripts/generate-dev-keys.sh

# Verify keys were created
ls -la ~/harden/keys/

# Test key management tools
bash scripts/key-manager.sh list-keys
```

### **Test 3: Base System Preparation**
```bash
# Since we already have Debian installed, test the validation
bash scripts/validate-debian-installation.sh

# Test partition layout tools (simulation mode)
bash scripts/create-partition-layout.sh --simulate
```

## 🧪 **Testing Phase 2: Boot Security (Tasks 4-5)**

### **Test 4: UEFI Secure Boot Simulation**
```bash
# Install Secure Boot tools
sudo apt install -y sbsigntool efitools

# Test Secure Boot setup (simulation in VM)
sudo bash scripts/setup-secure-boot.sh --vm-mode

# Validate implementation
bash scripts/validate-task-4.sh
```

### **Test 5: TPM2 Measured Boot**
```bash
# Install TPM2 tools
sudo apt install -y tpm2-tools

# Test TPM2 setup (using software TPM in VM)
sudo bash scripts/setup-tpm2-measured-boot.sh --vm-mode

# Validate TPM2 functionality
bash scripts/validate-task-5.sh
```

## 🧪 **Testing Phase 3: Kernel Hardening (Tasks 6-8)**

### **Test 6: Hardened Kernel Build**
```bash
# This will take time - kernel compilation
sudo bash scripts/build-hardened-kernel.sh

# Validate kernel hardening
bash scripts/validate-task-6.sh
```

### **Test 7: Compiler Hardening**
```bash
# Test compiler hardening setup
sudo bash scripts/setup-compiler-hardening.sh

# Validate compiler settings
bash scripts/validate-task-7.sh
```

### **Test 8: Signed Kernel Packages**
```bash
# Create signed kernel packages
sudo bash scripts/create-signed-kernel.sh

# Validate kernel signing
bash scripts/validate-task-8.sh
```

## 🧪 **Testing Phase 4: Access Control (Tasks 9-11)**

### **Test 9: SELinux Enforcing Mode**
```bash
# Install and configure SELinux
sudo bash scripts/setup-selinux-enforcing.sh

# Reboot VM to activate SELinux
sudo reboot

# After reboot, validate SELinux
bash scripts/validate-task-9.sh
```

### **Test 10: Minimal System Services**
```bash
# Reduce attack surface
sudo bash scripts/minimize-services.sh

# Validate service reduction
bash scripts/validate-task-10.sh
```

### **Test 11: Userspace Hardening**
```bash
# Apply userspace hardening
sudo bash scripts/setup-userspace-hardening.sh

# Validate hardening measures
bash scripts/validate-task-11.sh
```

## 🧪 **Testing Phase 5: Application Security (Tasks 12-14)**

### **Test 12: Application Sandboxing**
```bash
# Setup bubblewrap sandboxing
sudo bash scripts/setup-bubblewrap-sandboxing.sh

# Test sandbox functionality
bash scripts/validate-task-12.sh
```

### **Test 13: Network Controls**
```bash
# Configure per-application firewall
sudo bash scripts/setup-network-controls.sh

# Test network restrictions
bash scripts/validate-task-13.sh
```

### **Test 14: User Onboarding**
```bash
# Setup user onboarding wizard
sudo bash scripts/setup-user-onboarding.sh

# Test user experience
bash scripts/validate-task-14.sh
```

## 🧪 **Testing Phase 6: Updates & Supply Chain (Tasks 15-17)**

### **Test 15: Secure Updates (TUF)**
```bash
# Setup TUF-based update system
sudo bash scripts/setup-secure-updates.sh

# Test update functionality
bash scripts/validate-task-15.sh
```

### **Test 16: Rollback Mechanisms**
```bash
# Configure automatic rollback
sudo bash scripts/setup-rollback-system.sh

# Test rollback functionality
bash scripts/validate-task-16.sh
```

### **Test 17: Reproducible Builds**
```bash
# Setup reproducible build pipeline
bash scripts/setup-reproducible-builds.sh

# Validate build reproducibility
bash scripts/validate-task-17.sh
```

## 🧪 **Testing Phase 7: Production Infrastructure (Task 18)**

### **Test 18: HSM Signing Infrastructure**
```bash
# Setup HSM infrastructure (using SoftHSM in VM)
sudo bash scripts/setup-hsm-infrastructure.sh

# Test HSM functionality
bash scripts/validate-task-18.sh

# Test key rotation procedures
sudo bash scripts/production-key-rotation.sh check HardenedOS-Dev 1234
```

## 🔍 **Comprehensive System Testing**

### **Run All Validation Tests**
```bash
# Create comprehensive test script
cat > ~/test-all-components.sh << 'EOF'
#!/bin/bash
echo "=== Hardened OS Comprehensive Test Suite ==="

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo "Testing: $test_name"
    if bash "$test_script"; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $test_name"
        ((TESTS_FAILED++))
    fi
    echo
}

# Run all validation tests
run_test "Environment Setup" "scripts/validate-task-1.sh"
run_test "Key Management" "scripts/validate-task-2.sh"
run_test "Debian Installation" "scripts/validate-debian-installation.sh"
run_test "Secure Boot" "scripts/validate-task-4.sh"
run_test "TPM2 Measured Boot" "scripts/validate-task-5.sh"
run_test "Hardened Kernel" "scripts/validate-task-6.sh"
run_test "Compiler Hardening" "scripts/validate-task-7.sh"
run_test "Signed Kernel" "scripts/validate-task-8.sh"
run_test "SELinux Enforcing" "scripts/validate-task-9.sh"
run_test "Minimal Services" "scripts/validate-task-10.sh"
run_test "Userspace Hardening" "scripts/validate-task-11.sh"
run_test "Application Sandboxing" "scripts/validate-task-12.sh"
run_test "Network Controls" "scripts/validate-task-13.sh"
run_test "User Onboarding" "scripts/validate-task-14.sh"
run_test "Secure Updates" "scripts/validate-task-15.sh"
run_test "Rollback System" "scripts/validate-task-16.sh"
run_test "Reproducible Builds" "scripts/validate-task-17.sh"
run_test "HSM Infrastructure" "scripts/validate-task-18.sh"

echo "=== Test Results ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "🎉 All tests passed! Hardened OS is working correctly."
    exit 0
else
    echo "⚠️ Some tests failed. Check individual test outputs."
    exit 1
fi
EOF

chmod +x ~/test-all-components.sh
bash ~/test-all-components.sh
```

## 📊 **Performance and Security Testing**

### **Security Feature Verification**
```bash
# Test exploit mitigations
echo "Testing ASLR..."
cat /proc/sys/kernel/randomize_va_space

echo "Testing stack protection..."
gcc -fstack-protector-strong -o test-stack test.c

echo "Testing SELinux enforcement..."
getenforce
sestatus

echo "Testing sandbox isolation..."
bwrap --ro-bind /usr /usr --tmpfs /tmp --proc /proc --dev /dev --unshare-all echo "Sandbox test"
```

### **Performance Benchmarking**
```bash
# Install benchmarking tools
sudo apt install -y sysbench stress-ng htop iotop

# CPU performance test
sysbench cpu --threads=4 run

# Memory performance test
sysbench memory run

# I/O performance test
sysbench fileio --file-test-mode=rndrw prepare
sysbench fileio --file-test-mode=rndrw run
sysbench fileio --file-test-mode=rndrw cleanup

# Network performance (if applicable)
iperf3 -c speedtest.net -p 5201
```

## 🐛 **Troubleshooting Common VM Issues**

### **If Tests Fail**
```bash
# Check system logs
sudo journalctl -xe

# Check SELinux denials
sudo ausearch -m avc -ts recent

# Check service status
sudo systemctl status

# Check disk space
df -h

# Check memory usage
free -h
```

### **VM-Specific Limitations**
```bash
# Some features may not work in VM:
echo "Checking VM limitations..."

# TPM2 - may be emulated
ls /dev/tpm*

# Secure Boot - simulated
mokutil --sb-state 2>/dev/null || echo "Secure Boot not available in VM"

# Hardware security features - limited
grep -E "(vmx|svm)" /proc/cpuinfo
```

## 📝 **Testing Checklist**

### **Phase 1: Basic Setup** ✅
- [ ] VM has sufficient resources (8GB+ RAM, 80GB+ disk)
- [ ] Debian base system is updated
- [ ] Development tools installed
- [ ] Hardened OS files transferred to VM

### **Phase 2: Security Components** ✅
- [ ] All scripts are executable
- [ ] Environment setup completed
- [ ] Key management working
- [ ] Boot security configured

### **Phase 3: Kernel & Access Control** ✅
- [ ] Hardened kernel built and installed
- [ ] SELinux enforcing mode active
- [ ] Services minimized
- [ ] Userspace hardening applied

### **Phase 4: Application Security** ✅
- [ ] Sandboxing functional
- [ ] Network controls operational
- [ ] User onboarding working

### **Phase 5: Updates & Infrastructure** ✅
- [ ] Secure update system configured
- [ ] Rollback mechanisms tested
- [ ] Build reproducibility verified
- [ ] HSM infrastructure operational

### **Phase 6: Validation** ✅
- [ ] All validation scripts pass
- [ ] Performance is acceptable
- [ ] No critical errors in logs
- [ ] Security features verified

## 🎯 **Next Steps After VM Testing**

### **If All Tests Pass** 🎉
1. **Document any VM-specific issues**
2. **Create installation checklist for real hardware**
3. **Prepare backup strategy for your laptop**
4. **Plan installation timeline**

### **If Some Tests Fail** 🔧
1. **Debug issues in safe VM environment**
2. **Fix problems and re-test**
3. **Document solutions for future reference**
4. **Consider alternative approaches if needed**

## 🚀 **Ready to Start Testing?**

You now have a complete testing plan! Start with Phase 1 and work through each phase systematically. The VM environment is perfect for:

- ✅ **Safe testing** without risk to your main system
- ✅ **Learning the interface** and procedures
- ✅ **Identifying issues** before real installation
- ✅ **Verifying compatibility** with your workflow

Would you like me to help you with any specific testing phase or troubleshoot any issues you encounter?

---

*VM Testing Guide for Hardened Laptop OS*  
*Complete validation in safe virtual environment*