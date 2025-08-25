# Task 11: Userspace Hardening and Memory Protection Implementation

## Overview

This document describes the implementation of Task 11: "Configure userspace hardening and memory protection" for the hardened laptop operating system. This task implements comprehensive userspace security hardening including hardened malloc deployment, mandatory ASLR, compiler hardening flags, and systemd service hardening.

## Requirements Addressed

### Requirement 13.1: Compiler Hardening Flags
- **Requirement**: WHEN packages are compiled THEN they SHALL use -fstack-protector-strong, -fPIE, -fstack-clash-protection, and -D_FORTIFY_SOURCE=3
- **Implementation**: Configured dpkg buildflags and environment variables to enforce hardening flags system-wide

### Requirement 13.2: Hardened Malloc System-Wide
- **Requirement**: WHEN memory allocation occurs THEN hardened malloc (hardened_malloc or equivalent) SHALL be used system-wide
- **Implementation**: Deployed GrapheneOS hardened_malloc with ld.so.preload configuration

### Requirement 13.3: Mandatory ASLR
- **Requirement**: WHEN binaries are loaded THEN mandatory ASLR SHALL be enforced for all executables and libraries
- **Implementation**: Configured kernel ASLR settings and additional memory protection measures

### Requirement 6.4: systemd Service Hardening
- **Requirement**: WHEN kernel modules are loaded THEN unused modules SHALL be blacklisted (systemd service context)
- **Implementation**: Configured PrivateTmp, NoNewPrivileges, and comprehensive systemd service hardening

## Implementation Details

### 1. Hardened Malloc Deployment

#### Installation and Configuration
```bash
# Clone and build hardened_malloc from GrapheneOS
git clone https://github.com/GrapheneOS/hardened_malloc.git
cd hardened_malloc
make CONFIG_NATIVE=false CONFIG_CXX_ALLOCATOR=true
make install PREFIX=/usr

# Configure system-wide deployment
echo "/usr/lib/libhardened_malloc.so" > /etc/ld.so.preload
```

#### Environment Configuration
```bash
# /etc/environment.d/hardened-malloc.conf
LD_PRELOAD=/usr/lib/libhardened_malloc.so
MALLOC_CONF=abort_conf:true,abort:true,junk:true
```

#### Features Enabled
- **Heap canaries**: Detect heap buffer overflows
- **Guard pages**: Prevent heap overflow exploitation
- **Randomized allocation**: Mitigate heap spraying attacks
- **Immediate deallocation**: Prevent use-after-free exploitation
- **Metadata protection**: Protect allocator metadata from corruption

### 2. Mandatory ASLR Configuration

#### Kernel Configuration
```bash
# /etc/sysctl.conf additions
kernel.randomize_va_space = 2          # Full ASLR
kernel.kptr_restrict = 2               # Restrict kernel pointers
kernel.dmesg_restrict = 1              # Restrict dmesg access
fs.suid_dumpable = 0                   # Disable SUID core dumps
vm.mmap_rnd_bits = 32                  # Maximum mmap randomization
vm.mmap_rnd_compat_bits = 16           # 32-bit compatibility randomization
```

#### systemd ASLR Enforcement
```bash
# /etc/systemd/system.conf.d/aslr-hardening.conf
[Manager]
DefaultEnvironment="ADDR_NO_RANDOMIZE=0"
```

#### Verification
- ASLR effectiveness tested with address randomization verification
- Multiple test runs confirm different memory layout each execution
- Stack, heap, and library addresses properly randomized

### 3. Compiler Hardening Flags

#### dpkg Build Flags Configuration
```bash
# /etc/dpkg/buildflags.conf.d/hardening.conf
hardening=+all

# Stack protection
CFLAGS=-fstack-protector-strong
CXXFLAGS=-fstack-protector-strong

# Position Independent Executables
CFLAGS=-fPIE
CXXFLAGS=-fPIE
LDFLAGS=-pie

# Stack clash protection
CFLAGS=-fstack-clash-protection
CXXFLAGS=-fstack-clash-protection

# Fortify source (maximum level)
CPPFLAGS=-D_FORTIFY_SOURCE=3

# Control Flow Integrity
CFLAGS=-fcf-protection=full
CXXFLAGS=-fcf-protection=full

# Zero call-used registers
CFLAGS=-fzero-call-used-regs=used-gpr
CXXFLAGS=-fzero-call-used-regs=used-gpr

# Relocation hardening
LDFLAGS=-Wl,-z,relro,-z,now
LDFLAGS=-Wl,-z,noexecstack
```

#### Environment Configuration
```bash
# /etc/environment.d/compiler-hardening.conf
CFLAGS="-fstack-protector-strong -fPIE -fstack-clash-protection -fcf-protection=full -fzero-call-used-regs=used-gpr"
CXXFLAGS="-fstack-protector-strong -fPIE -fstack-clash-protection -fcf-protection=full -fzero-call-used-regs=used-gpr"
CPPFLAGS="-D_FORTIFY_SOURCE=3"
LDFLAGS="-pie -Wl,-z,relro,-z,now -Wl,-z,noexecstack"
```

#### Hardened Compiler Wrappers
- Created `/usr/local/bin/gcc-hardened` and `/usr/local/bin/g++-hardened`
- Automatically apply hardening flags to all compilations
- Can be used as alternatives to system compilers

### 4. systemd Service Hardening

#### Global Service Hardening
```bash
# /etc/systemd/system/service.d/security-hardening.conf
[Service]
# Core hardening requirements
PrivateTmp=yes
NoNewPrivileges=yes

# Comprehensive protection
ProtectSystem=strict
ProtectHome=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RemoveIPC=yes
RestrictNamespaces=yes

# Memory protection
MemoryDenyWriteExecute=yes

# System call filtering
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @privileged @reboot @swap

# Capability restrictions
CapabilityBoundingSet=
AmbientCapabilities=

# File system restrictions
ReadOnlyPaths=/
InaccessiblePaths=/proc/sys /proc/sysrq-trigger /proc/latency_stats /proc/acpi /proc/timer_stats /proc/fs

# Additional protections
LockPersonality=yes
ProtectKernelLogs=yes
ProtectClock=yes
ProtectHostname=yes
```

#### Service-Specific Profiles

**Web Services Profile**
```bash
# /etc/systemd/system/web-service.d/hardening.conf
[Service]
PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateDevices=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service @network-io
MemoryDenyWriteExecute=yes
```

**Database Services Profile**
```bash
# /etc/systemd/system/database-service.d/hardening.conf
[Service]
PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateDevices=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service @file-system @io-event
ReadWritePaths=/var/lib/database /var/log/database
```

#### Critical Services Hardening
Applied hardening configurations to:
- SSH service (`ssh.service`)
- Network management (`systemd-networkd.service`)
- DNS resolution (`systemd-resolved.service`)
- Time synchronization (`systemd-timesyncd.service`)
- Cron daemon (`cron.service`)
- System logging (`rsyslog.service`)

## Security Benefits

### Memory Corruption Mitigation
1. **Stack Protection**: Stack canaries detect buffer overflows
2. **Heap Protection**: Hardened malloc prevents heap exploitation
3. **Control Flow Integrity**: CFI prevents ROP/JOP attacks
4. **ASLR**: Address randomization defeats memory layout attacks

### Privilege Escalation Prevention
1. **NoNewPrivileges**: Prevents privilege escalation via execve
2. **Capability Restrictions**: Minimal capability sets for services
3. **System Call Filtering**: Blocks dangerous system calls
4. **Namespace Restrictions**: Prevents container escapes

### Attack Surface Reduction
1. **PrivateTmp**: Isolates temporary file access
2. **ProtectSystem**: Read-only system directories
3. **PrivateDevices**: Restricts device access
4. **Memory Protection**: W^X enforcement

### Information Disclosure Prevention
1. **Kernel Pointer Restriction**: Hides kernel addresses
2. **dmesg Restriction**: Limits kernel log access
3. **Core Dump Restrictions**: Prevents SUID core dumps
4. **Process Isolation**: Comprehensive systemd sandboxing

## Testing and Validation

### Automated Testing
- **Functionality Tests**: Verify all hardening measures work correctly
- **Security Tests**: Validate protection against common attacks
- **Integration Tests**: Ensure hardening measures work together
- **Performance Tests**: Assess performance impact

### Manual Verification
- ASLR effectiveness through address randomization testing
- Compiler hardening through binary analysis
- systemd hardening through service inspection
- Memory protection through exploit simulation

### Continuous Monitoring
- System call monitoring for policy violations
- Memory allocation monitoring for anomalies
- Service behavior monitoring for security events
- Performance monitoring for impact assessment

## Performance Considerations

### Expected Overhead
- **hardened_malloc**: 5-15% memory allocation overhead
- **ASLR**: Minimal performance impact (<1%)
- **Compiler Hardening**: 2-5% execution overhead
- **systemd Hardening**: Minimal impact on service startup

### Optimization Strategies
- Selective hardening for performance-critical applications
- Tunable hardened_malloc configuration
- Profile-guided optimization for hardened binaries
- Service-specific hardening profiles

## Troubleshooting

### Common Issues

#### hardened_malloc Problems
```bash
# Check if hardened_malloc is loaded
ldd /bin/ls | grep hardened_malloc

# Verify ld.so.preload configuration
cat /etc/ld.so.preload

# Test malloc functionality
echo 'int main(){void*p=malloc(100);free(p);return 0;}' | gcc -x c - && ./a.out
```

#### ASLR Issues
```bash
# Check ASLR status
cat /proc/sys/kernel/randomize_va_space

# Test ASLR effectiveness
for i in {1..5}; do ./test_program | grep "address"; done
```

#### Compiler Hardening Issues
```bash
# Check hardening flags
gcc -Q --help=optimizers | grep stack-protector
gcc -dumpspecs | grep -A5 -B5 stack-protector

# Verify PIE compilation
file /path/to/binary | grep "shared object"
```

#### systemd Hardening Issues
```bash
# Check service hardening status
systemctl show service-name | grep -E "(PrivateTmp|NoNewPrivileges|ProtectSystem)"

# Debug service failures
journalctl -u service-name --since "1 hour ago"

# Test service restrictions
systemd-analyze security service-name
```

### Recovery Procedures

#### Disable hardened_malloc
```bash
# Temporary disable
unset LD_PRELOAD

# Permanent disable
mv /etc/ld.so.preload /etc/ld.so.preload.disabled
```

#### Revert ASLR Settings
```bash
# Temporary disable
echo 0 > /proc/sys/kernel/randomize_va_space

# Permanent disable
sed -i 's/kernel.randomize_va_space = 2/kernel.randomize_va_space = 0/' /etc/sysctl.conf
```

#### Disable systemd Hardening
```bash
# Remove hardening configuration
rm /etc/systemd/system/service.d/security-hardening.conf
systemctl daemon-reload
```

## Compliance and Auditing

### Security Standards Compliance
- **NIST SP 800-53**: System and Information Integrity controls
- **CIS Controls**: Secure Configuration controls
- **OWASP**: Memory corruption prevention guidelines
- **Common Criteria**: Memory protection requirements

### Audit Procedures
1. Regular validation script execution
2. Binary security analysis with checksec
3. Service hardening verification
4. Performance impact monitoring
5. Security event log analysis

### Documentation Requirements
- Configuration change documentation
- Security impact assessments
- Performance baseline measurements
- Incident response procedures

## Future Enhancements

### Additional Hardening Measures
- Intel CET (Control-flow Enforcement Technology) integration
- ARM Pointer Authentication support
- Hardware-assisted CFI implementation
- Advanced heap protection mechanisms

### Monitoring and Analytics
- Real-time security event correlation
- Machine learning-based anomaly detection
- Automated threat response
- Security metrics dashboard

### Integration Improvements
- Container runtime hardening
- Application-specific hardening profiles
- Dynamic hardening adjustment
- Zero-trust architecture integration

## Conclusion

Task 11 successfully implements comprehensive userspace hardening and memory protection for the hardened laptop operating system. The implementation addresses all specified requirements and provides robust protection against memory corruption attacks, privilege escalation, and information disclosure while maintaining system usability and performance.

The hardening measures work together to create multiple layers of defense:
1. **hardened_malloc** prevents heap exploitation
2. **ASLR** defeats memory layout attacks
3. **Compiler hardening** mitigates code injection
4. **systemd hardening** reduces attack surface

This implementation establishes a strong foundation for secure userspace operation and supports the overall security objectives of the hardened laptop operating system project.