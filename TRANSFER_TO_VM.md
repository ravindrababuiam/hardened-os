# How to Transfer Files to Your Debian VM

## 🎯 **Goal: Get Hardened OS Files into Your VM**

You need to transfer all the scripts and files from your Windows system to the Debian VM for testing.

## 🚀 **Method 1: VirtualBox Shared Folder (Recommended)**

### **Step 1: Configure Shared Folder in VirtualBox**
1. **Shut down your VM** (important!)
2. **In VirtualBox Manager**:
   - Select your VM
   - Click "Settings"
   - Go to "Shared Folders"
   - Click the "+" icon to add folder
   - **Folder Path**: Browse to your Windows project folder (where you have all the scripts)
   - **Folder Name**: `hardened-os` (remember this name)
   - ✅ Check "Auto-mount"
   - ✅ Check "Make Permanent"
   - Click "OK"

### **Step 2: Start VM and Access Shared Folder**
```bash
# Start your VM and login

# Check if shared folder is mounted
ls /media/sf_hardened-os/

# If not auto-mounted, mount manually:
sudo mkdir -p /mnt/shared
sudo mount -t vboxsf hardened-os /mnt/shared

# Copy files to your home directory
cp -r /mnt/shared/* ~/hardened-os-test/

# Make scripts executable
chmod +x ~/hardened-os-test/scripts/*.sh
```

## 🚀 **Method 2: SCP/SFTP Transfer**

### **Step 1: Enable SSH in VM**
```bash
# In your Debian VM:
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# Find VM's IP address
ip addr show | grep inet
```

### **Step 2: Transfer from Windows**
```powershell
# In Windows PowerShell (install OpenSSH client if needed):
# Replace VM_IP with your VM's IP address
scp -r C:\path\to\your\project\* username@VM_IP:~/hardened-os-test/

# Or use WinSCP GUI tool for easier transfer
```

## 🚀 **Method 3: Git Repository (If Available)**

### **If you have a Git repository:**
```bash
# In your VM:
cd ~
git clone https://github.com/yourusername/hardened-laptop-os.git hardened-os-test
cd hardened-os-test
chmod +x scripts/*.sh
```

## 🚀 **Method 4: Manual Copy-Paste (Small Files)**

### **For individual scripts or configs:**
1. **In Windows**: Open file in text editor, copy content
2. **In VM**: Create file with `nano filename.sh`, paste content, save
3. **Make executable**: `chmod +x filename.sh`

## 📋 **Quick Setup After Transfer**

### **Run the VM Setup Helper**
```bash
# After transferring files, run the setup helper:
cd ~/hardened-os-test
chmod +x scripts/vm-setup-helper.sh
bash scripts/vm-setup-helper.sh
```

### **Verify Transfer Success**
```bash
# Check if all files are present:
ls -la ~/hardened-os-test/
ls -la ~/hardened-os-test/scripts/
ls -la ~/hardened-os-test/docs/

# Count scripts (should be 20+ files):
ls ~/hardened-os-test/scripts/*.sh | wc -l
```

## 🎯 **What You Should Have After Transfer**

### **Directory Structure:**
```
~/hardened-os-test/
├── scripts/
│   ├── setup-environment.sh
│   ├── generate-dev-keys.sh
│   ├── setup-hsm-infrastructure.sh
│   ├── validate-task-*.sh
│   └── ... (20+ script files)
├── docs/
│   ├── task-*-implementation.md
│   └── ... (documentation files)
├── configs/
│   └── ... (configuration files)
└── README.md
```

### **Key Files to Verify:**
```bash
# These files should exist:
ls ~/hardened-os-test/scripts/vm-setup-helper.sh
ls ~/hardened-os-test/scripts/validate-task-18.sh
ls ~/hardened-os-test/docs/task-18-hsm-implementation.md
ls ~/hardened-os-test/VM_TESTING_GUIDE.md
```

## 🚀 **Ready to Start Testing!**

### **Once files are transferred:**
```bash
# 1. Run the setup helper
bash ~/hardened-os-test/scripts/vm-setup-helper.sh

# 2. Reboot VM
sudo reboot

# 3. Start testing
~/run-hardened-tests.sh

# 4. Check status anytime
~/check-hardened-status.sh
```

## 🐛 **Troubleshooting Transfer Issues**

### **Shared Folder Not Working:**
```bash
# Install VirtualBox Guest Additions
sudo apt install -y virtualbox-guest-additions-iso
sudo reboot

# Add user to vboxsf group
sudo usermod -aG vboxsf $USER
# Logout/login for group change to take effect
```

### **SSH Connection Issues:**
```bash
# Check SSH service
sudo systemctl status ssh

# Check firewall (if any)
sudo ufw status

# Check VM network settings (should be NAT or Bridged)
```

### **Permission Issues:**
```bash
# Fix script permissions
find ~/hardened-os-test -name "*.sh" -exec chmod +x {} \;

# Fix ownership
sudo chown -R $USER:$USER ~/hardened-os-test/
```

## 💡 **Pro Tips**

1. **Use Shared Folder** - It's the easiest method and keeps files in sync
2. **Take VM Snapshots** - Before major changes, take snapshots for easy rollback
3. **Keep Files Organized** - Use the suggested directory structure
4. **Test Incrementally** - Don't try to run everything at once

---

**Ready to transfer files and start testing?** Choose the method that works best for you and let's get the Hardened OS running in your VM! 🚀