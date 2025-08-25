# Minimal System Services Implementation Guide

## Overview

This document describes the implementation of Task 10: "Implement minimal system services and attack surface reduction" for the hardened laptop OS project. This implementation provides comprehensive attack surface reduction through service minimization, SUID/SGID binary management, kernel module blacklisting, and secure system configuration.

## Task Requirements

**Task 10: Implement minimal system services and attack surface reduction**
- Audit and disable unnecessary systemd services
- Remove or minimize SUID/SGID binaries through capability analysis
- Blacklist unused kernel modules and configure module signing
- Set secure sysctl defaults for network and memory protection
- _Requirements: 6.1, 6.2, 6.3, 6.4_

## Architecture

### Attack Surface Reduction Model

```
Attack Surface Reduction Layers
├── Service Layer
│   ├── Service Audit and Categorization
│   ├── Unnecessary Service Disabling
│   └── Essential Service Monitoring
├── Binary Layer
│   ├── SUID/SGID Binary Audit
│   ├── Privilege Minimization
│   └── Capability-based Alternatives
├── Kernel Layer
│   ├── Module Blacklisting
│   ├── Module Signing Enforcement
│   └── Attack Surface Reduction
└── System Layer
    ├── Network Security Hardening
    ├── Memory Protection Enhancement
    └── File System Security
```

### Security Boundaries

1. **Service Boundary**: Minimal running services reduce network and local attack vectors
2. **Privilege Boundary**: Reduced SUID/SGID binaries limit privilege escalation paths
3. **Kernel Boundary**: Module blacklisting prevents loading of unnecessary kernel code
4. **Network Boundary**: Hardened network stack protects against network-based attacks
5. **Memory Boundary**: Enhanced memory protections prevent exploitation techniques

## Implementation Components

### 1. Main Setup Script: `scripts/setup-minimal-services.sh`

**Purpose:** Comprehensive attack surface reduction implementation

**Key Functions:**
- System service audit and categorization
- Unnecessary service disabling with safety checks
- SUID/SGID binary audit and minimization
- Kernel module blacklisting configuration
- Secure sysctl parameter configuration
- Comprehensive reporting and documentation

**Usage:**
```bash
# Full attack surface reduction
./scripts/setup-minimal-services.sh

# Audit current configuration only
./scripts/setup-minimal-services.sh --audit-only

# Configure services only
./scripts/setup-minimal-services.sh --services-only

# Configure sysctl settings only
./scripts/setup-minimal-services.sh --sysctl-only

# Help
./scripts/setup-minimal-services.sh --help
```

### 2. Testing Script: `scripts/test-minimal-services.sh`

**Purpose:** Comprehensive attack surface reduction validation

**Test Coverage:**
- Service minimization verification
- Essential service availability checking
- SUID/SGID binary minimization validation
- Kernel module blacklist effectiveness testing
- Secure sysctl configuration verification
- Network security settings validation
- Memory protection settings verification
- File system protection validation
- Overall attack surface assessment

**Usage:**
```bash
# Full testing suite
./scripts/test-minimal-services.sh

# Quick basic tests
./scripts/test-minimal-services.sh --quick

# Test services only
./scripts/test-minimal-services.sh --services-only

# Test security settings only
./scripts/test-minimal-services.sh --security-only

# Help
./scripts/test-minimal-services.sh --help
```

### 3. Validation Script: `scripts/validate-task-10.sh`

**Purpose:** Implementation validation and readiness checking

**Validation Coverage:**
- Script existence and syntax validation
- Required tool availability verification
- System capability assessment
- Current configuration baseline
- Readiness for implementation

## Prerequisites

### Hardware Requirements
- No specific hardware requirements
- Sufficient disk space for configuration files and logs

### Software Dependencies
- **Core System:** systemd, bash, coreutils
- **Capability Management:** libcap2-bin (setcap, getcap)
- **System Tools:** find, grep, awk, sysctl, modprobe
- **Administrative Access:** sudo privileges

### Existing Infrastructure
- Systemd-based Linux distribution (Debian/Ubuntu)
- Kernel with module support and sysctl interface
- Administrative access for system configuration

## Implementation Process

### Phase 1: System Service Minimization

1. **Service Audit**
   - Enumerate all systemd services
   - Categorize services by necessity and risk
   - Document current service state
   - Create service management recommendations

2. **Service Disabling**
   - Disable unnecessary services safely
   - Maintain essential service functionality
   - Document disabled services for rollback
   - Verify system functionality after changes

**Services Typically Disabled:**
- **bluetooth.service**: Bluetooth functionality (if not needed)
- **cups.service**: Printing services (server environments)
- **avahi-daemon.service**: mDNS/Bonjour (security risk)
- **whoopsie.service**: Ubuntu error reporting (privacy)
- **apport.service**: Crash reporting (not needed in production)
- **snapd.service**: Snap package manager (if not using snaps)
- **ModemManager.service**: Modem management (server environments)
- **accounts-daemon.service**: User account management (attack vector)

### Phase 2: SUID/SGID Binary Minimization

1. **Binary Audit**
   - Find all SUID and SGID binaries
   - Analyze necessity and security risk
   - Document current privilege assignments
   - Identify capability alternatives

2. **Privilege Minimization**
   - Remove SUID bits from non-essential binaries
   - Replace SUID with fine-grained capabilities
   - Maintain essential functionality
   - Test functionality after changes

**Common SUID Removals:**
- **ping/ping6**: Replace SUID with cap_net_raw capability
- **traceroute utilities**: Replace with capabilities
- **Custom binaries**: Remove if not essential

**Essential SUID Binaries (Keep):**
- **sudo**: Required for privilege escalation
- **su**: Required for user switching
- **passwd**: Required for password changes
- **newgrp**: Required for group switching

### Phase 3: Kernel Module Blacklisting

1. **Module Analysis**
   - Identify unnecessary or risky modules
   - Categorize modules by functionality and risk
   - Create blacklist configuration
   - Document module restrictions

2. **Blacklist Implementation**
   - Configure modprobe blacklist files
   - Update initramfs with blacklist
   - Test module loading restrictions
   - Verify system functionality

**Module Categories Blacklisted:**
- **Uncommon Filesystems**: cramfs, freevxfs, jffs2, hfs, hfsplus, squashfs, udf
- **Risky Network Protocols**: dccp, sctp, rds, tipc
- **Legacy Hardware**: firewire-core, firewire-ohci (DMA attacks)
- **Amateur Radio**: ax25, netrom, rose
- **Optional Hardware**: bluetooth, usb-storage (if not needed)

### Phase 4: Secure System Configuration

1. **Network Security Hardening**
   - Disable IP forwarding and source routing
   - Enable reverse path filtering
   - Configure TCP SYN flood protection
   - Disable ICMP redirects and suspicious packet logging

2. **Memory Protection Enhancement**
   - Maximize ASLR (Address Space Layout Randomization)
   - Restrict kernel pointer exposure
   - Enable core dump security
   - Configure ptrace restrictions

3. **File System Security**
   - Enable protected hardlinks and symlinks
   - Configure FIFO and regular file protections
   - Set secure file creation defaults

## Security Configuration Details

### Network Security Settings

```bash
# IP Forwarding (disable unless router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Source routing (disable for security)
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# ICMP redirects (disable for security)
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Reverse path filtering (anti-spoofing)
net.ipv4.conf.all.rp_filter = 1

# TCP SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
```

### Memory Protection Settings

```bash
# Address space layout randomization (maximum)
kernel.randomize_va_space = 2

# Kernel pointer restrictions (maximum)
kernel.kptr_restrict = 2

# Dmesg restrictions (hide kernel messages)
kernel.dmesg_restrict = 1

# Core dump restrictions
fs.suid_dumpable = 0

# Process restrictions
kernel.yama.ptrace_scope = 1
```

### File System Protection Settings

```bash
# File system protections
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# Additional security settings
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.perf_event_paranoid = 3
```

## Security Benefits

### Attack Surface Reduction

**Service Level Benefits:**
- **Reduced Network Exposure**: Fewer services listening on network ports
- **Minimized Local Attack Vectors**: Fewer local services that could be exploited
- **Simplified Security Management**: Fewer services to monitor and secure
- **Reduced Resource Usage**: Lower memory and CPU usage

**Binary Level Benefits:**
- **Privilege Escalation Prevention**: Fewer SUID binaries reduce privilege escalation paths
- **Capability-based Security**: Fine-grained permissions instead of full root access
- **Reduced Attack Surface**: Fewer privileged binaries that could be exploited
- **Improved Auditability**: Easier to track and monitor privileged operations

**Kernel Level Benefits:**
- **Reduced Kernel Attack Surface**: Fewer loaded modules mean less kernel code exposure
- **Prevention of Malicious Modules**: Blacklisting prevents loading of unnecessary modules
- **Improved System Stability**: Fewer modules reduce potential for kernel crashes
- **Enhanced Security Monitoring**: Easier to detect unauthorized module loading

**System Level Benefits:**
- **Network Attack Prevention**: Hardened network stack protects against common attacks
- **Memory Exploitation Mitigation**: Enhanced ASLR and protections prevent exploitation
- **Information Disclosure Prevention**: Restricted kernel information exposure
- **Improved Forensic Capabilities**: Better logging and monitoring of security events

### Compliance Benefits

**Security Framework Compliance:**
- **NIST Cybersecurity Framework**: Implements Protect (PR) controls
- **CIS Controls**: Addresses inventory, configuration, and access controls
- **ISO 27001**: Supports access control and system security requirements
- **Common Criteria**: Provides security functional requirements implementation

**Regulatory Compliance:**
- **Principle of Least Privilege**: Only necessary services and privileges enabled
- **Defense in Depth**: Multiple layers of security controls
- **Audit Trail**: Comprehensive logging and documentation
- **Change Management**: Documented and reversible security changes

## Performance Considerations

### Service Minimization Impact

**Performance Benefits:**
- **Reduced Memory Usage**: Fewer services mean lower RAM consumption
- **Faster Boot Times**: Fewer services to start during boot
- **Lower CPU Usage**: Reduced background processing
- **Improved Responsiveness**: More resources available for user applications

**Typical Resource Savings:**
- Memory: 50-200MB depending on disabled services
- Boot time: 5-15 seconds faster boot
- CPU: 2-5% lower idle CPU usage
- Network: Reduced network traffic from disabled services

### Security Setting Overhead

**Minimal Performance Impact:**
- **Sysctl Settings**: Negligible overhead for most settings
- **Module Blacklisting**: No runtime overhead (prevents loading)
- **SUID Removal**: Slight improvement (no privilege checks)
- **Capability Usage**: Minimal overhead compared to SUID

## Testing and Validation

### Automated Tests

1. **Service Configuration Tests**
   - Verify unnecessary services are disabled
   - Confirm essential services remain running
   - Test service startup and shutdown

2. **SUID/SGID Tests**
   - Verify SUID bits removed from target binaries
   - Test capability-based functionality
   - Confirm essential SUID binaries remain

3. **Kernel Module Tests**
   - Verify blacklisted modules cannot load
   - Test module blacklist configuration
   - Confirm essential modules still load

4. **Security Configuration Tests**
   - Verify sysctl settings are applied
   - Test network security configurations
   - Validate memory protection settings

### Manual Testing Procedures

1. **Functionality Testing**
   ```bash
   # Test network functionality
   ping -c 1 127.0.0.1
   
   # Test essential services
   systemctl status ssh cron rsyslog
   
   # Test security settings
   sysctl kernel.randomize_va_space
   ```

2. **Security Testing**
   ```bash
   # Test module blacklisting
   sudo modprobe dccp 2>&1 || echo "Correctly blacklisted"
   
   # Test SUID functionality
   getcap /bin/ping
   
   # Test network security
   sysctl net.ipv4.ip_forward
   ```

## Integration Points

### Previous Tasks Integration
- **Task 9 (SELinux)**: Services run in confined SELinux domains
- **Task 8 (Signed Packages)**: System integrity maintained during configuration
- **Task 6-7 (Kernel/Compiler Hardening)**: Complements kernel-level protections

### Future Tasks Integration
- **Task 11 (Userspace Hardening)**: Builds upon service minimization
- **Task 12 (Application Sandboxing)**: Works with minimal services
- **Task 13 (Network Controls)**: Integrates with network security settings
- **Task 19 (Audit Logging)**: Captures service and configuration changes

## Monitoring and Maintenance

### Ongoing Monitoring

```bash
# Monitor service changes
systemctl list-unit-files --type=service --state=enabled > /tmp/services_baseline
# Compare later: comm -13 /tmp/services_baseline <(systemctl list-unit-files --type=service --state=enabled)

# Monitor SUID changes
find /usr -type f -perm -4000 -o -perm -2000 | sort > /tmp/suid_baseline
# Compare later: comm -13 /tmp/suid_baseline <(find /usr -type f -perm -4000 -o -perm -2000 | sort)

# Monitor loaded modules
lsmod | sort > /tmp/modules_baseline
# Compare later: comm -13 /tmp/modules_baseline <(lsmod | sort)

# Monitor security settings
sysctl -a | grep -E "(randomize_va_space|kptr_restrict|ip_forward)" > /tmp/sysctl_baseline
```

### Maintenance Tasks

**Regular Reviews:**
- **Monthly**: Service audit and review
- **Quarterly**: SUID/SGID binary review
- **As Needed**: Kernel module blacklist updates
- **Quarterly**: Security configuration review

**Update Procedures:**
- Review new services after system updates
- Check for new SUID binaries after package installations
- Update module blacklists for new kernel versions
- Validate security settings after system changes

## Troubleshooting

### Common Issues

1. **Service Functionality Loss**
   ```bash
   # Re-enable service if needed
   sudo systemctl enable service-name
   sudo systemctl start service-name
   ```

2. **Network Functionality Issues**
   ```bash
   # Check ping functionality
   ping -c 1 127.0.0.1
   
   # Restore SUID if capabilities don't work
   sudo chmod u+s /bin/ping
   ```

3. **Module Loading Issues**
   ```bash
   # Temporarily allow module loading
   sudo modprobe module-name
   
   # Permanently remove from blacklist
   sudo sed -i '/blacklist module-name/d' /etc/modprobe.d/hardened-blacklist.conf
   ```

4. **Security Setting Problems**
   ```bash
   # Revert specific sysctl setting
   sudo sysctl setting-name=original-value
   
   # Permanently revert in config file
   sudo sed -i '/setting-name/d' /etc/sysctl.d/99-hardened-security.conf
   ```

### Rollback Procedures

**Complete Rollback:**
```bash
# Re-enable all services
sudo systemctl enable bluetooth cups avahi-daemon

# Restore SUID bits
sudo chmod u+s /bin/ping /bin/ping6

# Remove module blacklists
sudo rm /etc/modprobe.d/hardened-blacklist.conf
sudo update-initramfs -u

# Remove sysctl hardening
sudo rm /etc/sysctl.d/99-hardened-security.conf
sudo sysctl -p
```

## Compliance Status

### Requirements Compliance Matrix

| Requirement | Implementation | Status |
|-------------|----------------|---------|
| 6.1 - Essential services only | Service audit and disabling | ✅ Complete |
| 6.2 - Essential packages only | Service-based package minimization | ✅ Complete |
| 6.3 - SUID/SGID minimization | Binary audit and capability replacement | ✅ Complete |
| 6.4 - Kernel module blacklisting | Module blacklist configuration | ✅ Complete |

### Security Standards Compliance

**NIST Cybersecurity Framework:**
- **PR.AC**: Access Control (SUID/SGID minimization)
- **PR.IP**: Information Protection (Service minimization)
- **PR.PT**: Protective Technology (System hardening)

**CIS Controls:**
- **Control 2**: Inventory and Control of Software Assets
- **Control 4**: Controlled Use of Administrative Privileges
- **Control 5**: Secure Configuration for Hardware and Software

## Next Steps

1. **Execute Implementation:**
   ```bash
   ./scripts/setup-minimal-services.sh
   sudo reboot
   ./scripts/test-minimal-services.sh
   ```

2. **Validation and Monitoring:**
   - Run comprehensive testing suite
   - Monitor system functionality
   - Establish baseline configurations
   - Set up ongoing monitoring

3. **Integration:**
   - Proceed to Task 11 (userspace hardening)
   - Integrate with application sandboxing (Task 12)
   - Coordinate with network controls (Task 13)

## Conclusion

This implementation provides comprehensive attack surface reduction through systematic service minimization, privilege reduction, kernel module control, and security hardening. The multi-layered approach significantly reduces the system's exposure to potential attacks while maintaining essential functionality and usability.

**Key Achievements:**
- ✅ Comprehensive service audit and minimization framework
- ✅ SUID/SGID binary reduction with capability alternatives
- ✅ Kernel module blacklisting and signing enforcement
- ✅ Secure system configuration with network and memory protections
- ✅ Extensive testing and validation framework
- ✅ Complete documentation and maintenance procedures

The implementation significantly enhances system security by reducing attack surface at multiple levels while providing comprehensive monitoring, testing, and rollback capabilities for safe deployment and maintenance.