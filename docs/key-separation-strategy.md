# Key Separation Strategy: Development vs Production

## Overview
This document outlines the strategy for maintaining clear separation between development and production keys to prevent accidental deployment of development keys in production systems.

## Current Implementation

### Development Key Markers
All development keys are clearly marked with:

1. **Certificate Subject Lines**:
   ```
   CN=Hardened OS Development Platform Key/O=Development/C=US
   CN=Hardened OS Development KEK/O=Development/C=US  
   CN=Hardened OS Development DB/O=Development/C=US
   ```

2. **File Naming Convention**:
   ```
   ~/harden/keys/dev/          # Development keys
   ~/harden/keys/prod/         # Production keys (placeholder)
   ~/harden/keys/staging/      # Staging keys (placeholder)
   ```

3. **Metadata Warnings**:
   ```json
   {
     "purpose": "development",
     "warning": "DEVELOPMENT KEYS ONLY - NOT FOR PRODUCTION"
   }
   ```

4. **Script Warnings**:
   - All key generation scripts display prominent warnings
   - Key manager utilities show development warnings
   - Backup files include development markers

## Production Key Strategy

### 1. HSM-Backed Production Keys

Production keys MUST be generated and stored in Hardware Security Modules (HSMs):

```bash
# Production key generation (HSM-based)
~/harden/keys/prod/
├── PK/
│   ├── PK.crt              # Certificate (public)
│   ├── PK.der              # DER format
│   ├── PK.esl              # EFI signature list
│   ├── PK.auth             # Signed for enrollment
│   └── hsm_reference.txt   # HSM slot reference (NO PRIVATE KEY FILE)
├── KEK/
└── DB/
```

### 2. Production Key Characteristics

- **Subject Lines**: `CN=Hardened OS Production Platform Key/O=Production/C=US`
- **Validity**: Shorter validity periods (1-2 years vs 10 years for dev)
- **Key Size**: Larger key sizes (4096-bit vs 2048-bit for dev)
- **Storage**: HSM-only, never on filesystem
- **Access Control**: Multi-person authorization required
- **Audit Trail**: All operations logged and monitored

### 3. Key Environment Separation

```
Environment Hierarchy:
┌─────────────────┐
│   Production    │ ← HSM-backed, multi-auth, audited
├─────────────────┤
│    Staging      │ ← HSM-backed, single-auth, logged  
├─────────────────┤
│  Development    │ ← File-based, local, warned
└─────────────────┘
```

## Safeguards Against Accidental Production Deployment

### 1. Build System Checks

```bash
#!/bin/bash
# build-system-key-check.sh

check_production_keys() {
    local key_dir="$1"
    
    # Check for development markers
    if find "$key_dir" -name "*.crt" -exec grep -l "Development" {} \; | grep -q .; then
        echo "ERROR: Development keys detected in production build!"
        echo "Found development certificates:"
        find "$key_dir" -name "*.crt" -exec grep -l "Development" {} \;
        exit 1
    fi
    
    # Check for HSM references
    if ! find "$key_dir" -name "hsm_reference.txt" | grep -q .; then
        echo "ERROR: No HSM references found - production keys must be HSM-backed!"
        exit 1
    fi
    
    # Check for private key files (should not exist in production)
    if find "$key_dir" -name "*.key" | grep -q .; then
        echo "ERROR: Private key files found - production keys must be HSM-only!"
        find "$key_dir" -name "*.key"
        exit 1
    fi
}
```

### 2. ISO Build Validation

```bash
# iso-build-validation.sh

validate_iso_keys() {
    local iso_path="$1"
    
    # Mount ISO and check for development keys
    local mount_point="/tmp/iso_check_$$"
    mkdir -p "$mount_point"
    
    mount -o loop "$iso_path" "$mount_point"
    
    # Check for development key markers
    if grep -r "Development" "$mount_point/keys/" 2>/dev/null; then
        echo "CRITICAL: Development keys found in production ISO!"
        umount "$mount_point"
        exit 1
    fi
    
    # Check for private key files
    if find "$mount_point" -name "*.key" 2>/dev/null | grep -q .; then
        echo "CRITICAL: Private key files found in ISO!"
        umount "$mount_point"
        exit 1
    fi
    
    umount "$mount_point"
    echo "ISO key validation passed"
}
```

### 3. Deployment Checks

```bash
# deployment-key-check.sh

pre_deployment_validation() {
    local target_system="$1"
    
    # Check UEFI key database for development keys
    if efi-readvar -v db | grep -q "Development"; then
        echo "ERROR: Development keys enrolled in target system!"
        echo "System: $target_system"
        echo "Action: Remove development keys before production deployment"
        return 1
    fi
    
    # Verify production key enrollment
    if ! efi-readvar -v db | grep -q "Production"; then
        echo "ERROR: Production keys not enrolled in target system!"
        echo "System: $target_system"
        echo "Action: Enroll production keys before deployment"
        return 1
    fi
    
    echo "Deployment key validation passed for $target_system"
}
```

## Key Lifecycle Management

### Development Keys
- **Generation**: Automated, local filesystem
- **Rotation**: Monthly or as needed
- **Backup**: Encrypted, local storage
- **Access**: Developer workstations
- **Audit**: Basic logging

### Staging Keys  
- **Generation**: HSM-backed, controlled process
- **Rotation**: Quarterly
- **Backup**: HSM backup, encrypted offsite
- **Access**: Staging environment only
- **Audit**: Detailed logging

### Production Keys
- **Generation**: HSM-backed, ceremony process
- **Rotation**: Annually or emergency
- **Backup**: Multiple HSM sites, offline backup
- **Access**: Multi-person authorization
- **Audit**: Full audit trail, compliance reporting

## Implementation Checklist

### ✅ Current Implementation
- [x] Development keys clearly marked
- [x] Warning messages in all tools
- [x] Separate directory structure
- [x] Metadata includes purpose markers
- [x] Certificate subject lines indicate development

### 🔄 In Progress  
- [ ] HSM integration for production keys
- [ ] Build system validation scripts
- [ ] ISO validation tools
- [ ] Deployment check scripts

### 📋 Future Enhancements
- [ ] Automated key rotation for staging
- [ ] Certificate transparency logging
- [ ] Key escrow procedures
- [ ] Compliance reporting tools
- [ ] Multi-signature key operations

## Emergency Procedures

### Development Key Compromise
1. Rotate development keys immediately
2. Update all developer workstations
3. Re-sign all development artifacts
4. No production impact (keys are isolated)

### Production Key Compromise
1. **IMMEDIATE**: Revoke compromised keys via DBX
2. **URGENT**: Generate new production keys via ceremony
3. **CRITICAL**: Update all production systems
4. **REQUIRED**: Incident report and compliance notification

## Compliance and Auditing

### Development Environment
- Basic logging of key operations
- Monthly key rotation reports
- Developer access tracking

### Production Environment
- Full audit trail of all key operations
- Real-time monitoring and alerting
- Compliance reporting (SOC2, ISO27001, etc.)
- Annual security assessments
- Penetration testing of key infrastructure

## Conclusion

The current implementation provides strong separation between development and production keys through:

1. **Clear Marking**: All development keys are obviously marked
2. **Directory Separation**: Different paths for different environments  
3. **Tool Warnings**: Prominent warnings in all utilities
4. **Build Validation**: Planned checks prevent accidental deployment

This strategy ensures that development keys cannot accidentally be deployed in production while maintaining developer productivity and security best practices.