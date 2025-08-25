# Implementation Plan

## Milestone Overview

**M1: Boot Security Foundation** (Tasks 1-5) - Secure boot chain with TPM2 and LUKS2
**M2: Kernel Hardening & MAC** (Tasks 6-11) - Hardened kernel with SELinux enforcing  
**M3: Application Security** (Tasks 12-14) - Sandboxing and network controls
**M4: Updates & Supply Chain** (Tasks 15-17) - Secure updates and reproducible builds
**M5: Production & Documentation** (Tasks 18-21) - HSM keys, logging, and user guides
**M6: Advanced Features** (Tasks 22-25) - Side-channel mitigations and privacy features (stretch goals)

## M1: Boot Security Foundation

- [x] 1. Bootstrap development environment and workspace





  - Create ~/harden/{src,keys,build,ci,artifacts} directory structure
  - Install required tooling: git, clang, gcc, python3, make, cmake, qemu/kvm, cryptsetup, sbctl
  - Set up Ubuntu LTS build host with 16-64GB RAM and 250+ GB SSD
  - Verify target laptop hardware: TPM2, UEFI, x86_64 architecture
  - _Requirements: All requirements depend on proper development environment_

- [x] 2. Create development signing keys and recovery infrastructure





  - Generate Platform Keys (PK), Key Exchange Keys (KEK), and Database (DB) keys for development
  - Set up key storage in ~/harden/keys with proper permissions (600)
  - Create signed recovery partition and fallback kernel for safe boot
  - Document key hierarchy, usage procedures, and recovery workflows
  - _Requirements: 1.1, 1.2, 1.4, 12.1, 12.3, 11.2_

- [x] 3. Set up Debian stable base system with custom partitioning





  - Download and verify Debian stable netinst ISO
  - Create custom preseed configuration for automated installation
  - Implement LUKS2 full disk encryption with Argon2id KDF (1GB memory, 4 iterations)
  - Configure partition layout: 512MB EFI + 1GB recovery + encrypted LVM root/swap
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 4. Implement UEFI Secure Boot with custom keys





  - Install and configure sbctl for Secure Boot management
  - Enroll custom Platform Keys, KEK, and DB keys in UEFI firmware
  - Sign shim bootloader, GRUB2, and recovery kernel with custom keys
  - Test Secure Boot enforcement and unauthorized kernel rejection
  - _Requirements: 1.1, 1.2, 1.3_




- [x] 5. Configure TPM2 measured boot and key sealing with recovery

  - Set up TPM2 tools and systemd-cryptenroll integration
  - Configure PCR measurements for firmware, bootloader, and kernel (PCRs 0,2,4,7)
  - Implement LUKS key sealing to TPM2 with PCR policy
  - Create fallback passphrase mechanism and recovery boot options
  - Test Evil Maid attack simulation and TPM unsealing failure scenarios
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 15.3_

## M2: Kernel Hardening & Mandatory Access Control

- [x] 6. Build hardened kernel with KSPP configuration and exploit testing




  - Download Linux kernel source and apply Debian patches
  - Create hardened kernel configuration with all KSPP-recommended flags
  - Enable KASLR, KPTI, Spectre/Meltdown mitigations, and memory protection features
  - Disable debugging features and reduce attack surface (CONFIG_DEVMEM=n, etc.)
  - Test kernel against known CVE exploits to validate mitigations
  - _Requirements: 4.1, 4.3_

- [x] 7. Implement compiler hardening for kernel and userspace



  - Configure Clang CFI and ShadowCallStack for supported architectures
  - Set up GCC hardening flags: -fstack-protector-strong, -fstack-clash-protection
  - Enable kernel lockdown mode and signature verification
  - Build kernel with hardening flags and verify configuration
  - _Requirements: 4.2, 13.1, 13.4_


- [x] 8. Create signed kernel packages and initramfs


  - Package hardened kernel as .deb with proper dependencies
  - Generate signed initramfs with TPM2 and LUKS support
  - Sign kernel and modules with Secure Boot keys
  - Test kernel installation and boot process
  - _Requirements: 1.1, 4.4_






- [x] 9. Configure SELinux in enforcing mode with targeted policy





  - Install SELinux packages and enable enforcing mode
  - Configure targeted policy as base with custom domain additions
  - Create application-specific domains: browser_t, office_t, media_t, dev_t
  - Test policy enforcement and resolve critical denials
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 10. Implement minimal system services and attack surface reduction



  - Audit and disable unnecessary systemd services
  - Remove or minimize SUID/SGID binaries through capability analysis
  - Blacklist unused kernel modules and configure module signing
  - Set secure sysctl defaults for network and memory protection
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 11. Configure userspace hardening and memory protection





  - Deploy hardened malloc (hardened_malloc) system-wide
  - Enable mandatory ASLR for all executables and libraries
  - Configure compiler hardening flags for all packages: -fPIE, -D_FORTIFY_SOURCE=3
  - Set up PrivateTmp and NoNewPrivileges for systemd services
  - _Requirements: 13.1, 13.2, 13.3, 6.4_

## M3: Application Security & Network Controls

- [x] 12. Implement bubblewrap application sandboxing framework with escape testing



  - Install bubblewrap and create sandbox profile templates
  - Develop browser sandbox with minimal filesystem access and network restrictions
  - Create office application sandbox with document access but no network
  - Implement media application sandbox with read-only media directory access
  - Test sandbox escape resistance using known techniques and fuzzing
  - _Requirements: 7.1, 17.1, 17.2, 17.3_

- [x] 13. Configure per-application network controls with nftables



  - Set up nftables with default DROP policy for input/output
  - Implement per-application firewall rules based on SELinux contexts
  - Create network control interface for enabling/disabling app network access
  - Test network isolation and verify raw socket blocking
  - _Requirements: 7.2, 7.3_

- [x] 14. Create user onboarding wizard and security mode switching



  - Develop user-friendly onboarding wizard for TPM enrollment and passphrase setup
  - Implement security mode switching: normal/paranoid/enterprise profiles
  - Create application permission management interface
  - Test user experience and security mode transitions
  - _Requirements: 17.4, 17.5, 19.1, 19.4_

## M4: Secure Updates & Supply Chain Security

- [x] 15. Implement TUF-based secure update system with transparency logging



  - Set up TUF metadata structure with root, targets, snapshot, and timestamp keys
  - Create update server infrastructure with signature verification
  - Implement client-side update verification and application logic
  - Configure staged rollouts and health check mechanisms
  - Set up public transparency log (Sigstore/Rekor-style) for update metadata
  - _Requirements: 8.1, 8.2, 8.5, 9.5_

- [x] 16. Configure automatic rollback and recovery mechanisms






  - Implement boot counting and automatic rollback on failed boots
  - Create recovery partition with signed recovery kernel
  - Set up system health checks and rollback triggers
  - Test rollback functionality and recovery procedures
  - _Requirements: 8.3, 11.2_




- [x] 17. Establish reproducible build pipeline and SBOM generation





  - Create deterministic build environment using containers or VMs
  - Implement build process with pinned dependency hashes
  - Generate Software Bill of Materials (SBOM) for all components
  - Set up build verification and hash comparison systems
  - Enable independent third-party build verification
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.6_

## M5: Production Deployment & Documentation

- [ ] 18. Migrate to production HSM-based signing infrastructure
  - Set up Hardware Security Module (HSM) for production key storage
  - Implement air-gapped signing infrastructure for release builds
  - Create production key rotation and revocation procedures
  - Test production signing workflow and key backup/recovery
  - _Requirements: 8.6, 12.2, 12.4_

- [ ] 19. Configure tamper-evident logging and audit system
  - Set up systemd-journald with cryptographic signing
  - Implement log forwarding to secure remote storage
  - Configure audit rules for security-relevant events
  - Create log integrity verification and tamper detection
  - _Requirements: 14.1, 14.2, 14.3, 14.5_

- [ ] 20. Implement incident response and recovery procedures
  - Create automated incident response scripts and procedures
  - Set up security event alerting and notification system
  - Document key rotation and compromise response procedures
  - Create forensic analysis tools and secure evidence collection
  - _Requirements: 11.1, 11.3, 11.4_

- [ ] 21. Create comprehensive documentation and user guides
  - Write installation and provisioning documentation
  - Create user guides for security features and recovery procedures
  - Document threat model and security assumptions
  - Develop troubleshooting guides and FAQ
  - _Requirements: 11.1, 19.1, 19.3, 19.4_

## M6: Advanced Features (Stretch Goals)

- [ ] 22. Integrate TPM2 hardware security features (Future Work)
  - Configure TPM2 for cryptographic key generation and storage
  - Implement hardware random number generator integration
  - Set up remote attestation capabilities using TPM2 quotes
  - Enable CPU security features: Intel CET, ARM Pointer Authentication where available
  - _Requirements: 10.1, 10.2, 10.3, 15.1_

- [ ] 23. Implement side-channel attack mitigations (Hardware-Specific)
  - Configure constant-time cryptographic implementations
  - Set up automatic microcode updates for side-channel mitigations
  - Implement cache partitioning for sensitive workloads (vendor-specific)
  - Enable memory scrambling and power analysis countermeasures where available
  - _Requirements: 18.1, 18.2, 18.3, 18.4_

- [ ] 24. Configure DNS security and privacy protection
  - Set up DNS over TLS/HTTPS with systemd-resolved
  - Configure secure DNS resolvers with DNSSEC validation
  - Implement DNS query logging and monitoring
  - Create fallback DNS configuration for reliability
  - _Requirements: 16.1_

- [ ] 25. Implement optional Tor integration and VPN-only modes
  - Install and configure Tor for system-wide traffic routing
  - Create VPN-only network modes to prevent cleartext leakage
  - Implement automatic network disconnection on sleep/lock
  - Set up connection tracking and network monitoring tools
  - _Requirements: 16.2, 16.3, 16.4_

## Testing & Quality Assurance (Continuous)

**Note**: These testing tasks should be integrated throughout M1-M5, not saved for the end:

- **Fuzzing**: Kernel syscall fuzzing, userspace parser fuzzing (integrate with tasks 6-8)
- **Exploit Testing**: Test known CVEs against hardened kernel (integrate with task 6)
- **Evil Maid Simulation**: Physical tampering detection tests (integrate with task 5)
- **Red Team Exercises**: Comprehensive penetration testing (after each milestone)
- **Recovery Testing**: Safe boot and recovery procedures (integrate with tasks 2, 16)

## Success Criteria by Milestone

**M1 Complete**: System boots with Secure Boot + TPM2 sealing, recovery partition works
**M2 Complete**: Hardened kernel boots, SELinux enforcing, minimal services running
**M3 Complete**: Applications run sandboxed, per-app network controls functional
**M4 Complete**: Secure updates work, builds are reproducible, transparency log operational
**M5 Complete**: Production-ready system with HSM keys, documentation, and incident response