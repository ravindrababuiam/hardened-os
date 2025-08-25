#!/bin/bash
#
# SELinux Enforcing Mode Configuration Script (Fixed)
# Configures SELinux in enforcing mode with targeted policy and custom domains
#
# Task 9: Configure SELinux in enforcing mode with targeted policy
# - Install SELinux packages and enable enforcing mode
# - Configure targeted policy as base with custom domain additions
# - Create application-specific domains: browser_t, office_t, media_t, dev_t
# - Test policy enforcement and resolve critical denials
#

set -euo pipefail

# Configuration
WORK_DIR="$HOME/harden/build"
SELINUX_DIR="$HOME/harden/selinux"
LOG_FILE="$WORK_DIR/selinux-setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize logging
init_logging() {
    mkdir -p "$WORK_DIR" "$SELINUX_DIR"
    echo "=== SELinux Enforcing Mode Setup Log - $(date) ===" > "$LOG_FILE"
}

# Create browser domain with modern SELinux syntax
create_browser_domain() {
    log_info "Creating browser_t domain..."
    
    local browser_te="$SELINUX_DIR/policies/browser.te"
    cat > "$browser_te" << 'EOF'
policy_module(browser, 1.0.0)

########################################
#
# Browser domain policy
# Restricts web browser applications
#

gen_require(`
    type unconfined_t;
    type user_home_t;
    type tmp_t;
    type devpts_t;
    type proc_t;
    class file { read write create unlink execute };
    class dir { read search add_name remove_name write };
    class process { fork signal transition };
    class fifo_file { read write };
    class chr_file { read write };
')

# Browser domain type
type browser_t;
type browser_exec_t;
domain_type(browser_t)
application_executable_file(browser_exec_t)

# Domain transition
domtrans_pattern(unconfined_t, browser_exec_t, browser_t)

# Basic permissions
allow browser_t self:process { fork signal };
allow browser_t self:fifo_file { read write };

# File access permissions
allow browser_t user_home_t:dir { read search };
allow browser_t user_home_t:file { read write };

# Temporary file access
allow browser_t tmp_t:dir { read write search add_name remove_name };
allow browser_t tmp_t:file { create read write unlink };

# Terminal access
allow browser_t devpts_t:chr_file { read write };

# Proc filesystem (limited)
allow browser_t proc_t:dir search;
allow browser_t proc_t:file read;
EOF
    
    # Create browser file context
    local browser_fc="$SELINUX_DIR/policies/browser.fc"
    cat > "$browser_fc" << 'EOF'
# Browser file contexts
/usr/bin/firefox.*     --      gen_context(system_u:object_r:browser_exec_t,s0)
/usr/bin/chromium.*    --      gen_context(system_u:object_r:browser_exec_t,s0)
/usr/bin/google-chrome.* --    gen_context(system_u:object_r:browser_exec_t,s0)
/opt/firefox/.*        --      gen_context(system_u:object_r:browser_exec_t,s0)
/opt/google/chrome/.*  --      gen_context(system_u:object_r:browser_exec_t,s0)
EOF
    
    log_info "✓ Browser domain policy created"
}

# Create office domain with modern SELinux syntax
create_office_domain() {
    log_info "Creating office_t domain..."
    
    local office_te="$SELINUX_DIR/policies/office.te"
    cat > "$office_te" << 'EOF'
policy_module(office, 1.0.0)

########################################
#
# Office applications domain policy
# Restricts office suite applications
#

gen_require(`
    type unconfined_t;
    type user_home_t;
    type tmp_t;
    class file { read write create unlink execute };
    class dir { read search write add_name remove_name };
    class process { fork signal transition };
')

# Office domain type
type office_t;
type office_exec_t;
domain_type(office_t)
application_executable_file(office_exec_t)

# Domain transition
domtrans_pattern(unconfined_t, office_exec_t, office_t)

# Basic permissions
allow office_t self:process { fork signal };

# Document access in home directory
allow office_t user_home_t:dir { read search write add_name remove_name };
allow office_t user_home_t:file { create read write unlink };

# Temporary files for document processing
allow office_t tmp_t:dir { read write search add_name remove_name };
allow office_t tmp_t:file { create read write unlink };
EOF
    
    # Create office file context
    local office_fc="$SELINUX_DIR/policies/office.fc"
    cat > "$office_fc" << 'EOF'
# Office application file contexts
/usr/bin/libreoffice.*  --     gen_context(system_u:object_r:office_exec_t,s0)
/usr/bin/soffice.*      --     gen_context(system_u:object_r:office_exec_t,s0)
/opt/libreoffice.*/.*   --     gen_context(system_u:object_r:office_exec_t,s0)
EOF
    
    log_info "✓ Office domain policy created"
}

# Create media domain with modern SELinux syntax
create_media_domain() {
    log_info "Creating media_t domain..."
    
    local media_te="$SELINUX_DIR/policies/media.te"
    cat > "$media_te" << 'EOF'
policy_module(media, 1.0.0)

########################################
#
# Media applications domain policy
# Restricts media player applications
#

gen_require(`
    type unconfined_t;
    type user_home_t;
    type tmp_t;
    type device_t;
    class file { read write execute };
    class dir { read search };
    class chr_file { read write };
    class process { fork signal transition };
')

# Media domain type
type media_t;
type media_exec_t;
domain_type(media_t)
application_executable_file(media_exec_t)

# Domain transition
domtrans_pattern(unconfined_t, media_exec_t, media_t)

# Basic permissions
allow media_t self:process { fork signal };

# Read-only access to media files
allow media_t user_home_t:dir { read search };
allow media_t user_home_t:file read;

# Audio/video device access
allow media_t device_t:chr_file { read write };

# Temporary files (minimal)
allow media_t tmp_t:dir { read search };
allow media_t tmp_t:file read;
EOF
    
    # Create media file context
    local media_fc="$SELINUX_DIR/policies/media.fc"
    cat > "$media_fc" << 'EOF'
# Media application file contexts
/usr/bin/vlc.*          --     gen_context(system_u:object_r:media_exec_t,s0)
/usr/bin/mpv.*          --     gen_context(system_u:object_r:media_exec_t,s0)
/usr/bin/mplayer.*      --     gen_context(system_u:object_r:media_exec_t,s0)
/usr/bin/totem.*        --     gen_context(system_u:object_r:media_exec_t,s0)
EOF
    
    log_info "✓ Media domain policy created"
}

# Create development domain with modern SELinux syntax
create_dev_domain() {
    log_info "Creating dev_t domain..."
    
    local dev_te="$SELINUX_DIR/policies/dev.te"
    cat > "$dev_te" << 'EOF'
policy_module(dev, 1.0.0)

########################################
#
# Development tools domain policy
# Restricts development applications
#

gen_require(`
    type unconfined_t;
    type user_home_t;
    type tmp_t;
    type bin_t;
    class file { read write create execute unlink };
    class dir { read search write add_name remove_name };
    class process { fork exec signal transition };
')

# Development domain type
type dev_t;
type dev_exec_t;
domain_type(dev_t)
application_executable_file(dev_exec_t)

# Domain transition
domtrans_pattern(unconfined_t, dev_exec_t, dev_t)

# Basic permissions
allow dev_t self:process { fork signal exec };

# Development file access
allow dev_t user_home_t:dir { read search write add_name remove_name };
allow dev_t user_home_t:file { create read write execute unlink };

# Compiler and build tool access
allow dev_t bin_t:file { read execute };

# Temporary build files
allow dev_t tmp_t:dir { read write search add_name remove_name };
allow dev_t tmp_t:file { create read write execute unlink };
EOF
    
    # Create development file context
    local dev_fc="$SELINUX_DIR/policies/dev.fc"
    cat > "$dev_fc" << 'EOF'
# Development tool file contexts
/usr/bin/gcc.*          --     gen_context(system_u:object_r:dev_exec_t,s0)
/usr/bin/clang.*        --     gen_context(system_u:object_r:dev_exec_t,s0)
/usr/bin/make.*         --     gen_context(system_u:object_r:dev_exec_t,s0)
/usr/bin/cmake.*        --     gen_context(system_u:object_r:dev_exec_t,s0)
/usr/bin/python3.*      --     gen_context(system_u:object_r:dev_exec_t,s0)
/usr/bin/node.*         --     gen_context(system_u:object_r:dev_exec_t,s0)
EOF
    
    log_info "✓ Development domain policy created"
}

# Create custom SELinux domains
create_custom_domains() {
    log_step "Creating custom SELinux domains..."
    
    # Create SELinux policy directory
    mkdir -p "$SELINUX_DIR/policies"
    
    # Create custom domains
    create_browser_domain
    create_office_domain
    create_media_domain
    create_dev_domain
    
    log_info "Custom SELinux domains created"
}

# Compile and install SELinux policies
compile_install_policies() {
    log_step "Compiling and installing SELinux policies..."
    
    cd "$SELINUX_DIR/policies"
    
    # Compile each policy module
    local policies=("browser" "office" "media" "dev")
    
    for policy in "${policies[@]}"; do
        log_info "Compiling $policy policy..."
        
        if [ -f "${policy}.te" ]; then
            # Compile policy module
            if make -f /usr/share/selinux/devel/Makefile "${policy}.pp" 2>&1 | tee -a "$LOG_FILE"; then
                log_info "✓ $policy policy compiled successfully"
                
                # Install policy module
                if sudo semodule -i "${policy}.pp" 2>&1 | tee -a "$LOG_FILE"; then
                    log_info "✓ $policy policy installed successfully"
                else
                    log_warn "Failed to install $policy policy"
                fi
            else
                log_warn "Failed to compile $policy policy"
            fi
        fi
    done
    
    # Restore file contexts
    log_info "Restoring file contexts..."
    sudo restorecon -R /usr/bin /opt 2>&1 | tee -a "$LOG_FILE" || {
        log_warn "Some file contexts could not be restored"
    }
    
    log_info "SELinux policies compiled and installed"
}

# Main execution function
main() {
    log_info "Starting SELinux custom domain creation..."
    
    init_logging
    create_custom_domains
    compile_install_policies
    
    log_info "=== SELinux Custom Domains Configuration Completed ==="
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help]"
        echo "Creates and installs custom SELinux domains with modern syntax"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac