#!/bin/sh
# ---------- Constants ----------
SCRIPT_NAME="install_acme.sh"
VERSION="1.0.0"
BACKUP_DIR="/root/ssl-backup"
LOG_FILE="/var/log/ssl-setup.log"
SSL_CERT_PATH="/etc/uhttpd.crt"
SSL_KEY_PATH="/etc/uhttpd.key"
#REPO_URL="https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh"
REQUIRED_TOOLS="curl sed grep tr"

# ---------- Default values ----------
ACTION="install"
DRY_RUN="no"
VERBOSE="no"

# ---------- Helper functions ----------
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

execute() {
    if [ "$DRY_RUN" = "yes" ]; then
        log "DRY-RUN" "$1"
    else
        if [ "$VERBOSE" = "yes" ]; then
            log "EXECUTE" "$1"
        fi
        eval "$1"
    fi
}

# ---------- Validation functions ----------
check_requirements() {
    for cmd in $REQUIRED_TOOLS; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_exit "Required command '$cmd' not found"
        fi
    done
}

validate_email() {
    if ! echo "$1" | grep -E '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' >/dev/null; then
        return 1
    fi
    return 0
}

validate_domains() {
    local domains="$1"
    for domain in $(echo "$domains" | tr ',' ' '); do
        if ! echo "$domain" | grep -E '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' >/dev/null; then
            return 1
        fi
    done
    return 0
}

backup_certs() {
    local backup_dir="${BACKUP_DIR}/$(date +%Y%m%d_%H%M%S)"
    if [ -f "$SSL_CERT_PATH" ] || [ -f "$SSL_KEY_PATH" ]; then
        log "INFO" "Creating backup of existing certificates"
        execute "mkdir -p $backup_dir"
        execute "cp -f /etc/uhttpd.* $backup_dir/ 2>/dev/null || true"
    fi
}

format_domains() {
    echo "$1" | tr ',' ' ' | sed 's/[^ ]* */-d & /g'
}

# Read password without echoing
read_secure_token() {
    local prompt="$1"
    local var_name="$2"
    local token=""

    # Use stty to disable echo, read the token, then restore echo
    echo "$prompt"
    stty -echo
    read -r token
    stty echo
    echo "" # Add a newline since read doesn't add one with echo disabled

    # Set the variable using eval (be careful with this!)
    eval "$var_name=\"$token\""
}

# ---------- Action functions ----------
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [Action] [Flags]

Actions:
  help       Shows this help message
  install    Installs the SSL setup (default)
  uninstall  Removes acme.sh and restores original certificates

Flags:
  -d, --dry-run  Show commands without executing them
  -v, --verbose  Enable verbose output

Version: $VERSION
EOF
}

uninstall_setup() {
    log "INFO" "Starting uninstallation process..."

    # Check if acme.sh is installed
    if [ -f /root/.acme.sh/acme.sh ]; then
        log "INFO" "Uninstalling acme.sh..."
        execute "/root/.acme.sh/acme.sh --uninstall"
        execute "rm -rf /root/.acme.sh"
    else
        log "INFO" "acme.sh is not installed, skipping uninstall step"
    fi

    # Find the earliest backup (original certificates)
    local earliest_backup
    if [ -d "$BACKUP_DIR" ]; then
        earliest_backup=$(find "$BACKUP_DIR" -type d -name "20*" | sort | head -n 1)
    fi

    # Restore original certificates if a backup exists
    if [ -n "$earliest_backup" ] && [ -d "$earliest_backup" ]; then
        log "INFO" "Restoring original certificates from $earliest_backup"
        if [ -f "$earliest_backup/uhttpd.crt" ]; then
            execute "cp -f $earliest_backup/uhttpd.crt $SSL_CERT_PATH"
        fi
        if [ -f "$earliest_backup/uhttpd.key" ]; then
            execute "cp -f $earliest_backup/uhttpd.key $SSL_KEY_PATH"
        fi
        execute "/etc/init.d/uhttpd restart"
    else
        log "WARN" "No certificate backups found. Cannot restore original certificates."
    fi

    if [ "$DRY_RUN" != "yes" ]; then
        log "INFO" "Uninstallation completed."
        echo ""
        echo "===================== Uninstall Complete ====================="
        echo "acme.sh has been removed from your system."
        echo "Please remove this script via: rm install.sh"
        if [ -n "$earliest_backup" ] && [ -d "$earliest_backup" ]; then
            echo "Original certificates have been restored."
        else
            echo "Note: Original certificates could not be restored (no backup found)."
        fi
        echo "================================================================"
    else
        log "DRY-RUN" "Uninstall simulation completed. No changes were made."
    fi
}

# ---------- Main installation function ----------
setup_ssl() {
    log "INFO" "Starting SSL setup..."
    check_requirements

    # Collect domain information
    local valid_domains=0
    while [ $valid_domains -eq 0 ]; do
        echo "Please enter your domains (separated by commas):"
        read -r DOMAINS
        if validate_domains "$DOMAINS"; then
            valid_domains=1
        else
            log "WARN" "Invalid domain name found. Please try again."
        fi
    done

    # Collect email information
    local valid_email=0
    while [ $valid_email -eq 0 ]; do
        echo "Please enter your email address:"
        read -r MAIL
        if validate_email "$MAIL"; then
            valid_email=1
        else
            log "WARN" "Invalid email address. Please try again."
        fi
    done

    # Certificate Authority selection
    echo "Please select certificate authority:"
    echo "1) Let's Encrypt (letsencrypt)"
    echo "2) ZeroSSL (zerossl)"
    read -r ca_opt
    case $ca_opt in
        1) CA="letsencrypt" ;;
        2) CA="zerossl" ;;
        *) CA="letsencrypt"; log "INFO" "Using default: Let's Encrypt" ;;
    esac

    # DNS service selection with secure token reading
    echo "Please select your DNS service:"
    echo "1) Hetzner"
    echo "2) Cloudflare"
    read -r opt
    case $opt in
        1)
            SERVICE="dns_hetzner"
            read_secure_token "Please enter your HETZNER_Token (input will be hidden):" HETZNER_Token
            [ -z "$HETZNER_Token" ] && error_exit "HETZNER_Token cannot be empty"
            export HETZNER_Token
            ;;
        2)
            SERVICE="dns_cf"
            read_secure_token "Please enter your Cloudflare_Token (input will be hidden):" CF_Token
            [ -z "$CF_Token" ] && error_exit "CF_Token cannot be empty"
            echo "Please enter your Cloudflare_Account_ID:"
            read -r CF_Account_ID
            [ -z "$CF_Account_ID" ] && error_exit "CF_Account_ID cannot be empty"
            export CF_Token
            export CF_Account_ID
            ;;
        *)
            error_exit "Invalid option $opt"
            ;;
    esac

    # Backup existing certificates
    backup_certs

    # Format domains for acme.sh
    local formatted_domains=$(format_domains "$DOMAINS")

    # Install acme.sh if not already installed
    if [ ! -f /root/.acme.sh/acme.sh ]; then
        log "INFO" "Installing acme.sh client..."
        execute "curl -s https://get.acme.sh | sh -s email=\"$MAIL\""
        if [ "$DRY_RUN" != "yes" ] && [ ! -f /root/.acme.sh/acme.sh ]; then
            error_exit "Failed to install acme.sh"
        fi
    else
        log "INFO" "acme.sh is already installed"
    fi

    # Request certificates
    log "INFO" "Requesting SSL certificates from $CA using $SERVICE..."
    execute "/root/.acme.sh/acme.sh --force --issue --dns \"$SERVICE\" --server \"$CA\" $formatted_domains \
      --fullchainpath \"$SSL_CERT_PATH\" --keypath \"$SSL_KEY_PATH\" \
      --reloadcmd \"/etc/init.d/uhttpd restart\" --log"

    if [ "$DRY_RUN" != "yes" ]; then
        log "INFO" "SSL setup completed successfully!"
        log "INFO" "Certificates will be automatically renewed by acme.sh's cronjob"
        echo ""
        echo "===================== Setup Complete ====================="
        echo "Your SSL certificates have been installed at:"
        echo "  - Certificate: $SSL_CERT_PATH"
        echo "  - Private Key: $SSL_KEY_PATH"
        echo ""
        echo "The web server has been restarted with the new certificates."
        echo "Automatic renewal is handled by acme.sh's cronjob."
        echo "=========================================================="
    else
        log "DRY-RUN" "SSL setup simulation completed. No changes were made."
    fi
}

# ---------- Main ----------
# Parse command-line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        help)
            ACTION="help"
            shift
            ;;
        install)
            ACTION="install"
            shift
            ;;
        uninstall)
            ACTION="uninstall"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN="yes"
            shift
            ;;
        -v|--verbose)
            VERBOSE="yes"
            shift
            ;;
        *)
            error_exit "Unknown option '$1'. Run '$SCRIPT_NAME help' for usage information."
            ;;
    esac
done

# Display banner
cat << EOF
========================================================
      SSL Setup Script v$VERSION
      Auto-configures SSL certificates using acme.sh
========================================================
EOF

# Execute selected action
case "$ACTION" in
    help)
        show_help
        ;;
    install)
        setup_ssl
        ;;
    uninstall)
        uninstall_setup
        ;;
    *)
        error_exit "Unknown action '$ACTION'"
        ;;
esac

exit 0