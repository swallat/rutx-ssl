#!/bin/sh

# Default values
ACTION="install"
TEST_INSTALL="no"
DRY_RUN="no"

# Parse command line arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    help)
      ACTION="help"
      ;;
    install)
      ACTION="install"
      ;;
    uninstall)
      ACTION="uninstall"
      ;;
    update)
      ACTION="update"
      ;;
    -t|--test)
      TEST_INSTALL="yes"
      ;;
    -d|--dry-run)
      DRY_RUN="yes"
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Function to execute commands, respecting dry-run mode
execute() {
  if [ "$DRY_RUN" = "yes" ]; then
    echo "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

# Help option
if [ "$ACTION" = "help" ]; then
  echo "Usage: sh install.sh [option] [flags]"
  echo "Options:"
  echo "  help       Display this help message"
  echo "  install    Install the SSL setup (default)"
  echo "  uninstall  Uninstall the SSL setup"
  echo "  update     Update the SSL setup script to the latest version"
  echo "Flags:"
  echo "  -t, --test     Perform a test installation"
  echo "  -d, --dry-run  Show commands without executing them"
  exit 0
fi

# Uninstall option
if [ "$ACTION" = "uninstall" ]; then
  echo "Uninstalling SSL setup..."
  execute "sed -i '/\/root\/ssl.sh/d' /etc/rc.local"
  execute "rm -f /root/ssl.sh"
  execute "sed -i '/export HETZNER_Token/d' /root/.profile"
  execute "sed -i '/export CF_Token/d' /root/.profile"
  execute "sed -i '/export CF_Account_ID/d' /root/.profile"
  echo "Uninstallation completed."
  exit 0
fi

# Update option
if [ "$ACTION" = "update" ]; then
  echo "Updating SSL setup script..."
  execute "curl -s -o install.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh"
  echo "Update completed. Please run the script again without the update option."
  exit 0
fi

# Installation process
if [ "$ACTION" = "install" ]; then
  # User prompts for domains, email address, certificate authority, and DNS service
  echo "Please enter your domains (separated by spaces):"
  read -r DOMAINS
  echo "Please enter your email address:"
  read -r MAIL
  echo "Please enter the certificate authority (e.g., letsencrypt):"
  read -r CA

  # DNS service selection
  echo "Please select your DNS service:"
  echo "1) Hetzner"
  echo "2) Cloudflare"
  read -r opt
  case $opt in
    1)
      SERVICE="dns_hetzner"
      echo "Please enter your HETZNER_Token:"
      read -r HETZNER_TOKEN
      ;;
    2)
      SERVICE="dns_cf"
      echo "Please enter your Cloudflare_Token:"
      read -r CF_TOKEN
      echo "Please enter your Cloudflare_Account_ID:"
      read -r CF_ACCOUNT_ID
      ;;
    *)
      echo "Invalid option $opt"
      exit 1
      ;;
  esac

  # SSL script creation
  echo "Creating ssl.sh script..."
  execute "cat > ./ssl.sh << EOF
#!/bin/sh

# Domains and email configuration
# Wildcard domains sind unterstützt, z.B. *.example.com
DOMAINS=\"$DOMAINS\"
MAIL=\"$MAIL\"

# DNS service for ACME
SERVICE=\"$SERVICE\"
SERVICE_TOKEN=\"HETZNER_Token\"
if [ \"\$SERVICE\" = \"dns_cf\" ]; then
  SERVICE_TOKEN=\"CF_Token\"
fi

# Certificate authority
CA=\"$CA\"

# Export environment variables
export HETZNER_Token=\"$HETZNER_TOKEN\"
export CF_Token=\"$CF_TOKEN\"
export CF_Account_ID=\"$CF_ACCOUNT_ID\"

# Install ACME client if not already installed
if [ ! -f /root/.acme.sh/acme.sh ]; then
  curl -s https://get.acme.sh | sh -s email=\$MAIL
fi

# Format domains correctly
DOMAINS=\$(echo \$DOMAINS | sed 's/[^ ]* */-d \"&\"/g')

# Request and import certificates
/root/.acme.sh/acme.sh --force --issue --dns \$SERVICE --server \$CA \$DOMAINS \
  --fullchainpath /etc/uhttpd.crt --keypath /etc/uhttpd.key \
  --reloadcmd \"/etc/init.d/uhttpd restart\" --log
EOF"

  execute "chmod a+x ./ssl.sh"

  if [ "$TEST_INSTALL" != "yes" ]; then
    # Update rc.local
    echo "Updating rc.local..."
    if ! grep -q '/root/ssl.sh' /etc/rc.local; then
      if [ "$SERVICE" = "dns_hetzner" ]; then
        execute "sed -i '/^exit 0/i export HETZNER_Token=\"$HETZNER_TOKEN\"\n/root/ssl.sh >/dev/null 2>&1 &' /etc/rc.local"
      elif [ "$SERVICE" = "dns_cf" ]; then
        execute "sed -i '/^exit 0/i export CF_Token=\"$CF_TOKEN\"\nexport CF_Account_ID=\"$CF_ACCOUNT_ID\"\n/root/ssl.sh >/dev/null 2>&1 &' /etc/rc.local"
      fi
    fi

    # Update .profile
    echo "Updating .profile..."
    if [ ! -f /root/.profile ]; then
      execute "touch /root/.profile"
    fi

    # Add HETZNER_Token if Hetzner is selected
    if [ "$SERVICE" = "dns_hetzner" ]; then
      if ! grep -q '^export HETZNER_Token=' /root/.profile; then
        execute "echo \"export HETZNER_Token=\\\"$HETZNER_TOKEN\\\"\" >> /root/.profile"
      else
        execute "sed -i \"s|^export HETZNER_Token=.*|export HETZNER_Token=\\\"$HETZNER_TOKEN\\\"|\" /root/.profile"
      fi
    fi

    # Add CF_Token and CF_Account_ID if Cloudflare is selected
    if [ "$SERVICE" = "dns_cf" ]; then
      if ! grep -q '^export CF_Token=' /root/.profile; then
        execute "echo \"export CF_Token=\\\"$CF_TOKEN\\\"\" >> /root/.profile"
      else
        execute "sed -i \"s|^export CF_Token=.*|export CF_Token=\\\"$CF_TOKEN\\\"|\" /root/.profile"
      fi
      if ! grep -q '^export CF_Account_ID=' /root/.profile; then
        execute "echo \"export CF_Account_ID=\\\"$CF_ACCOUNT_ID\\\"\" >> /root/.profile"
      else
        execute "sed -i \"s|^export CF_Account_ID=.*|export CF_Account_ID=\\\"$CF_ACCOUNT_ID\\\"|\" /root/.profile"
      fi
    fi
  fi

  echo "Installation completed."
fi

