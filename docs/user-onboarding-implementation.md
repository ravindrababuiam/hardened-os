# Task 14: User Onboarding Wizard and Security Mode Switching Implementation

## Overview

This document describes the implementation of Task 14: "Create user onboarding wizard and security mode switching" for the hardened laptop operating system. This task implements comprehensive user-friendly interfaces for system setup, security management, and application permission control while maintaining strong security principles.

## Requirements Addressed

### Requirement 17.4: Development Tools Isolation with Explicit Permission Models
- **Requirement**: WHEN development tools run THEN they SHALL be isolated from personal data and have explicit permission models
- **Implementation**: Application Permission Manager with explicit permission controls for development tools

### Requirement 17.5: Least Privilege Principle
- **Requirement**: WHEN application profiles are defined THEN they SHALL be based on principle of least privilege with deny-by-default policies
- **Implementation**: Security profiles with deny-by-default policies and minimal permission sets

### Requirement 19.1: Clear, Non-Technical Explanations
- **Requirement**: WHEN security operations are required THEN user interfaces SHALL provide clear, non-technical explanations
- **Implementation**: User-friendly onboarding wizard and security manager with plain language explanations

### Requirement 19.4: Actionable Security Warnings
- **Requirement**: WHEN security warnings are displayed THEN they SHALL be actionable and explain the risk in plain language
- **Implementation**: Security interfaces with clear risk explanations and actionable recommendations

## Implementation Details

### 1. User-Friendly Onboarding Wizard

#### Core Features
```python
# Main onboarding wizard: /usr/local/bin/wizard/hardened-os-onboarding
class OnboardingWizard:
    - Welcome and system information
    - Security level selection (normal/paranoid/enterprise)
    - TPM setup and configuration
    - Secure passphrase setup
    - Application permissions configuration
    - Final configuration and completion
```

#### Security Level Selection
- **Normal Mode**: Balanced security and usability
  - Standard application sandboxing
  - Basic network controls
  - User-friendly recovery options
  
- **Paranoid Mode**: Maximum security with usability trade-offs
  - Strict application isolation
  - No network access for office/media apps
  - Enhanced monitoring and logging
  
- **Enterprise Mode**: Corporate security policies
  - Centralized policy management
  - Comprehensive audit logging
  - Remote administration support

#### TPM Integration
- **Hardware Detection**: Automatic TPM availability checking
- **User Guidance**: Clear explanations of TPM benefits
- **Setup Process**: Guided TPM enrollment for disk encryption
- **Fallback Options**: Passphrase-only encryption when TPM unavailable

#### Passphrase Management
- **Security Requirements**: Minimum 12 characters with complexity rules
- **User Guidance**: Clear instructions and examples
- **Strength Validation**: Real-time passphrase strength checking
- **Recovery Options**: Secure recovery mechanism setup

### 2. Security Mode Switching System

#### Security Manager Application
```python
# Security manager: /usr/local/bin/security-manager
class SecurityManager:
    - Security mode selection and switching
    - Application permissions management
    - Network controls integration
    - System status monitoring
```

#### Mode-Specific Configurations

**Normal Mode Configuration**
```bash
# Network permissions
browser: allow (80,443,8080,8443)
office: block
media: block
dev: restrict (22,80,443)

# Application sandboxing: standard profiles
# Logging: basic security events
# Recovery: user-friendly options
```

**Paranoid Mode Configuration**
```bash
# Network permissions
browser: restrict (80,443)
office: block
media: block
dev: restrict (22,443)

# Application sandboxing: strict isolation
# Logging: comprehensive monitoring
# Recovery: secure but limited options
```

**Enterprise Mode Configuration**
```bash
# Network permissions
browser: restrict (80,443,8080)
office: block
media: block
dev: restrict (22,80,443,9418)

# Application sandboxing: policy-based profiles
# Logging: audit-compliant comprehensive logging
# Recovery: centrally managed options
```

#### Configuration Persistence
- **JSON Configuration**: `/etc/hardened-os/security-config.json`
- **Atomic Updates**: Safe configuration changes with rollback
- **Validation**: Configuration integrity checking
- **Backup**: Automatic configuration backup and recovery

### 3. Application Permission Management Interface

#### Permission Categories
```python
# Application categories with default permissions
app_categories = {
    "Web Browsers": {
        "network": "full",
        "filesystem": "downloads_only",
        "devices": "audio_video",
        "clipboard": "restricted"
    },
    "Office Applications": {
        "network": "blocked",
        "filesystem": "documents_only",
        "devices": "none", 
        "clipboard": "restricted"
    },
    "Media Players": {
        "network": "blocked",
        "filesystem": "media_readonly",
        "devices": "audio_video",
        "clipboard": "blocked"
    },
    "Development Tools": {
        "network": "restricted",
        "filesystem": "projects_only",
        "devices": "none",
        "clipboard": "full"
    }
}
```

#### Permission Types and Levels

**Network Permissions**
- **Full Access**: Complete internet access for all protocols
- **Restricted**: Limited access to essential services (HTTP/HTTPS)
- **Blocked**: No network access - complete isolation

**Filesystem Permissions**
- **Full Access**: Access to entire filesystem (not recommended)
- **Documents Only**: Access limited to Documents folder
- **Downloads Only**: Access limited to Downloads folder
- **Media Read-only**: Read-only access to media files
- **Projects Only**: Access limited to development folders
- **Sandboxed**: Access only to application's private directory

**Device Permissions**
- **Audio & Video**: Access to microphone, camera, speakers
- **Audio Only**: Access to audio devices only
- **None**: No device access - software-only operation

**Clipboard Permissions**
- **Full**: Can read and write clipboard freely
- **Restricted**: Limited clipboard access with user confirmation
- **Blocked**: No clipboard access

#### Security Impact Explanations
Each permission change includes clear explanations of security implications:
- Risk assessment for each permission level
- Trade-offs between security and functionality
- Recommendations based on use case
- Plain language explanations of technical concepts

### 4. User Experience Design Principles

#### Requirement 19.1 Implementation: Clear, Non-Technical Explanations

**Language Guidelines**
- Plain language instead of technical jargon
- Clear explanations of security concepts
- Step-by-step guidance with visual cues
- Context-sensitive help and tooltips

**Example Explanations**
```
TPM (Trusted Platform Module):
"The TPM is a security chip that helps protect your encryption keys and system integrity.

What the TPM does for you:
• Stores encryption keys securely in hardware
• Detects if someone tampers with your system  
• Automatically unlocks your disk when the system is trusted
• Provides an extra layer of protection for your data"
```

#### Requirement 19.4 Implementation: Actionable Security Warnings

**Warning Design Principles**
- Clear description of the security risk
- Explanation of potential consequences
- Specific actions the user can take
- Alternative options when available

**Example Security Warning**
```
Security Impact: Office applications with no network access
• High security - no data exfiltration risk
• Documents cannot be automatically synced to cloud services
• Email attachments must be saved and opened separately

Recommended Action: Keep network access blocked unless you specifically 
need cloud integration for this session.
```

### 5. Desktop Integration and Accessibility

#### Desktop Entries
```ini
# Onboarding wizard desktop entry
[Desktop Entry]
Name=Hardened OS Setup Wizard
Comment=Initial setup wizard for hardened operating system
Categories=System;Settings;
Icon=preferences-system

# Security manager desktop entry  
[Desktop Entry]
Name=Security Manager
Comment=Manage security modes and system policies
Categories=System;Settings;Security;
Icon=security-high

# Permission manager desktop entry
[Desktop Entry]
Name=Application Permission Manager
Comment=Manage application permissions and sandboxing
Categories=System;Settings;Security;
Icon=preferences-desktop-security
```

#### Accessibility Features
- **Keyboard Navigation**: Full keyboard accessibility
- **Screen Reader Support**: Proper labeling and structure
- **High Contrast**: Support for high contrast themes
- **Font Scaling**: Respect system font size settings
- **Error Handling**: Clear error messages with recovery options

### 6. Integration with Security Components

#### Network Controls Integration
```python
# Automatic network policy application based on security mode
def apply_security_mode(mode):
    if mode == "paranoid":
        subprocess.run(['/usr/local/bin/app-network-control', 'restrict', 'browser', '80,443'])
        subprocess.run(['/usr/local/bin/app-network-control', 'disable', 'office'])
        subprocess.run(['/usr/local/bin/app-network-control', 'disable', 'media'])
    elif mode == "enterprise":
        subprocess.run(['/usr/local/bin/app-network-control', 'restrict', 'browser', '80,443,8080'])
        subprocess.run(['/usr/local/bin/app-network-control', 'disable', 'office'])
        subprocess.run(['/usr/local/bin/app-network-control', 'disable', 'media'])
    else:  # normal mode
        subprocess.run(['/usr/local/bin/app-network-control', 'enable', 'browser', '80,443,8080'])
        subprocess.run(['/usr/local/bin/app-network-control', 'disable', 'office'])
        subprocess.run(['/usr/local/bin/app-network-control', 'disable', 'media'])
```

#### Bubblewrap Sandboxing Integration
- **Profile Selection**: Automatic sandbox profile selection based on security mode
- **Permission Mapping**: Translation of UI permissions to sandbox configurations
- **Real-time Updates**: Dynamic sandbox reconfiguration when permissions change

#### TPM and Encryption Integration
- **Hardware Detection**: Integration with TPM detection from Task 5
- **Key Management**: Coordination with existing key management systems
- **Recovery Integration**: Seamless integration with recovery mechanisms

## Security Benefits

### User Empowerment
1. **Informed Decisions**: Users understand security implications of their choices
2. **Granular Control**: Fine-grained permission management for each application
3. **Flexible Security**: Multiple security modes for different use cases
4. **Easy Recovery**: Clear recovery options when things go wrong

### Security by Design
1. **Deny by Default**: All permissions start with minimal access
2. **Least Privilege**: Applications get only necessary permissions
3. **Clear Boundaries**: Explicit permission models prevent confusion
4. **Audit Trail**: All permission changes are logged and trackable

### Usability Without Compromise
1. **Progressive Disclosure**: Complex options hidden until needed
2. **Contextual Help**: Explanations provided when and where needed
3. **Reversible Actions**: All changes can be undone or reset
4. **Multiple Interfaces**: GUI and command-line options available

## Usage Examples

### Initial System Setup
```bash
# Launch onboarding wizard
/usr/local/bin/wizard/hardened-os-onboarding

# Or from desktop environment
# Applications → System → Hardened OS Setup Wizard
```

### Security Mode Management
```bash
# Command line security mode switching
/usr/local/bin/security-manager set-mode paranoid

# GUI security management
/usr/local/bin/security-manager

# Or from desktop environment  
# Applications → System → Security Manager
```

### Application Permission Management
```bash
# Launch permission manager
/usr/local/bin/app-permission-manager

# Or from desktop environment
# Applications → System → Application Permission Manager
```

### Security Mode Comparison
| Feature | Normal Mode | Paranoid Mode | Enterprise Mode |
|---------|-------------|---------------|-----------------|
| Browser Network | Full Access | Restricted | Restricted |
| Office Network | Blocked | Blocked | Blocked |
| Media Network | Blocked | Blocked | Blocked |
| Dev Tools Network | Restricted | Minimal | Controlled |
| Logging Level | Basic | Comprehensive | Audit-Compliant |
| Recovery Options | User-Friendly | Secure | Centrally Managed |
| Sandboxing | Standard | Strict | Policy-Based |

## Testing and Validation

### Automated Testing
- **Functionality Tests**: All UI components work correctly
- **Integration Tests**: Proper integration with security components
- **Usability Tests**: User interface accessibility and clarity
- **Performance Tests**: Acceptable startup and response times

### Manual Verification
- User experience walkthrough for each security mode
- Permission change verification and effect testing
- Error handling and recovery procedure testing
- Desktop integration and accessibility testing

### Continuous Monitoring
- User feedback collection and analysis
- Security mode effectiveness monitoring
- Permission change audit and analysis
- Performance impact assessment

## Troubleshooting

### Common Issues

#### GUI Application Won't Start
```bash
# Check GUI dependencies
python3 -c "import tkinter; print('GUI available')"

# Check X11 forwarding (if using SSH)
echo $DISPLAY

# Check permissions
ls -la /usr/local/bin/wizard/hardened-os-onboarding
```

#### Security Mode Changes Don't Take Effect
```bash
# Check configuration file
cat /etc/hardened-os/security-config.json

# Verify network controls integration
/usr/local/bin/app-network-control list

# Check for permission errors
sudo /usr/local/bin/security-manager set-mode normal
```

#### Permission Changes Not Applied
```bash
# Check application permission manager logs
journalctl -u app-permission-manager --since "1 hour ago"

# Verify bubblewrap integration
bwrap --version

# Test network control integration
/usr/local/bin/app-network-control show
```

#### Configuration File Corruption
```bash
# Check configuration file syntax
python3 -c "import json; json.load(open('/etc/hardened-os/security-config.json'))"

# Reset to defaults
rm /etc/hardened-os/security-config.json
/usr/local/bin/security-manager set-mode normal

# Restore from backup
ls /etc/hardened-os/security-config.json.backup.*
```

### Recovery Procedures

#### Reset All Settings to Defaults
```bash
# Remove configuration
sudo rm -f /etc/hardened-os/security-config.json

# Reset security mode
sudo /usr/local/bin/security-manager set-mode normal

# Reset application permissions
sudo /usr/local/bin/app-network-control reload

# Restart onboarding wizard
/usr/local/bin/wizard/hardened-os-onboarding
```

#### Recover from Failed Security Mode Change
```bash
# Check current mode
grep security_mode /etc/hardened-os/security-config.json

# Force reset to normal mode
sudo /usr/local/bin/security-manager set-mode normal

# Verify network controls are working
/usr/local/bin/app-network-control list

# Re-apply desired mode
sudo /usr/local/bin/security-manager set-mode paranoid
```

## Compliance and Auditing

### Security Standards Compliance
- **NIST SP 800-53**: System and Information Integrity controls
- **ISO 27001**: Information security management requirements
- **Common Criteria**: User interface and access control requirements
- **GDPR**: Privacy by design and user control principles

### Audit Procedures
1. Regular user interface accessibility testing
2. Security mode effectiveness validation
3. Permission change audit trail review
4. User experience feedback analysis
5. Integration testing with security components

### Documentation Requirements
- User interface design documentation
- Security mode specifications
- Permission model documentation
- Recovery procedure documentation

## Future Enhancements

### Advanced User Interface Features
- **Multi-language Support**: Internationalization for global users
- **Accessibility Improvements**: Enhanced screen reader and keyboard support
- **Mobile Interface**: Touch-friendly interface for tablet devices
- **Voice Control**: Voice-activated security management

### Enhanced Security Features
- **Biometric Integration**: Fingerprint and face recognition setup
- **Hardware Token Support**: FIDO2/WebAuthn integration
- **Risk-Based Authentication**: Adaptive security based on behavior
- **Zero-Trust Integration**: Continuous verification and validation

### Usability Improvements
- **Guided Tours**: Interactive tutorials for new users
- **Smart Recommendations**: AI-powered security recommendations
- **Usage Analytics**: Privacy-preserving usage pattern analysis
- **Community Features**: Shared security configurations and best practices

## Conclusion

Task 14 successfully implements comprehensive user onboarding and security management interfaces that make advanced security features accessible to users of all technical levels. The implementation addresses all specified requirements while providing:

1. **User-Friendly Onboarding**: Step-by-step wizard for initial system setup
2. **Flexible Security Modes**: Multiple security profiles for different use cases
3. **Granular Permission Control**: Fine-grained application permission management
4. **Clear Communication**: Plain language explanations of security concepts
5. **Seamless Integration**: Coordination with all existing security components

The user interfaces establish a strong foundation for secure system operation while maintaining excellent usability and accessibility. Users can now easily configure and manage their security settings without compromising the underlying security architecture of the hardened laptop operating system.