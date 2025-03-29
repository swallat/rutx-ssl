#!/bin/sh

# Uninstall option
if [ "$1" = "uninstall" ]; then
  echo "Uninstalling SSL setup..."
  sed -i '/\/root\/ssl.sh/d' /etc/rc.local
  rm -f /root/ssl.sh
  sed -i '/export HETZNER_Token/d' /root/.profile
  sed -i '/export CF_Token/d' /root/.profile
  sed -i '/export CF_Account_ID/d' /root/.profile
  sed -i '/export CF_API_EMAIL/d' /root/.profile
  echo "Uninstallation completed."
  exit 0
fi

# Test installation option
echo "Do you want to perform a test installation? (yes/no):"
read TEST_INSTALL

# User prompts for domains, email address, certificate authority, and DNS service
echo "Please enter your domains (separated by spaces):"
read DOMAINS
echo "Please enter your email address:"
read MAIL
echo "Please enter the certificate authority (e.g., letsencrypt):"
read CA

# DNS service selection
echo "Please select your DNS service:"
echo "1) Hetzner"
echo "2) Cloudflare"
read opt
case $opt in
  1)
    SERVICE="dns_hetzner"
    echo "Please enter your HETZNER_Token:"
    read HETZNER_TOKEN
    ;;
  2)
    SERVICE="dns_cf"
    echo "Please enter your Cloudflare_Token:"
    read CF_TOKEN
    echo "Please enter your Cloudflare_Account_ID:"
    read CF_ACCOUNT_ID
    echo "Please enter your Cloudflare_API_Email:"
    read CF_API_EMAIL
    ;;
  *)
    echo "Invalid option $opt"
    exit 1
    ;;
esac

# SSL script creation
echo "Creating ssl.sh script..."
cat > ./ssl.sh << EOF
#!/bin/sh

# Domains and email configuration
# Wildcard domains are supported, e.g., *.example.com
DOMAINS="$DOMAINS"
MAIL="$MAIL"

# DNS service for ACME
SERVICE="$SERVICE"
SERVICE_TOKEN="HETZNER_Token"
if [ "\$SERVICE" = "dns_cf" ]; then
  SERVICE_TOKEN="CF_Token"
fi

# Certificate authority
CA="$CA"

# Export environment variables
export HETZNER_Token="$HETZNER_TOKEN"
export CF_API_EMAIL="$CF_API_EMAIL"
export CF_DNS_API_TOKEN="$CF_TOKEN"
export CF_Account_ID="$CF_ACCOUNT_ID"

# Install ACME client if not already installed
if [ ! -f /root/.acme.sh/acme.sh ]; then
  curl -s https://get.acme.sh | sh -s email=\$MAIL
fi

# Request and import certificates
for DOMAIN in \$DOMAINS; do
  /root/.acme.sh/acme.sh --force --issue --dns \$SERVICE --server \$CA -d \$DOMAIN \
    --fullchainpath /etc/uhttpd.crt --keypath /etc/uhttpd.key \
    --reloadcmd "/etc/init.d/uhttpd restart" --log
done
EOF

chmod a+x ./ssl.sh

if [ "$TEST_INSTALL" != "yes" ]; then
  # Update rc.local
  echo "Updating rc.local..."
  if ! grep -q '/root/ssl.sh' /etc/rc.local; then
    sed -i '/^exit 0/i /root/ssl.sh >/dev/null 2>&1 &' /etc/rc.local
  fi

  # Update .profile
  echo "Updating .profile..."
  if [ ! -f /root/.profile ]; then
    echo "Creating .profile..."
    touch /root/.profile
  fi

  # Add HETZNER_Token if Hetzner is selected
  if [ "$SERVICE" = "dns_hetzner" ]; then
    if ! grep -q '^export HETZNER_Token=' /root/.profile; then
      echo "Adding HETZNER_Token to .profile..."
      echo "export HETZNER_Token=\"$HETZNER_TOKEN\"" >> /root/.profile
    fi
  fi

  # Add CF_Token, CF_Account_ID, and CF_API_EMAIL if Cloudflare is selected
  if [ "$SERVICE" = "dns_cf" ]; then
    if ! grep -q '^export CF_Token=' /root/.profile; then
      echo "Adding CF_Token to .profile..."
      echo "export CF_Token=\"$CF_TOKEN\"" >> /root/.profile
    fi
    if ! grep -q '^export CF_Account_ID=' /root/.profile; then
      echo "Adding CF_Account_ID to .profile..."
      echo "export CF_Account_ID=\"$CF_ACCOUNT_ID\"" >> /root/.profile
    fi
    if ! grep -q '^export CF_API_EMAIL=' /root/.profile; then
      echo "Adding CF_API_EMAIL to .profile..."
      echo "export CF_API_EMAIL=\"$CF_API_EMAIL\"" >> /root/.profile
    fi
  fi
fi

echo "Installation completed."
